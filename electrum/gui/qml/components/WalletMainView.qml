import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import QtQml

import org.electrum 1.0

import "controls"

Item {
    id: mainView

    property string title: Daemon.currentWallet.name

    property var _sendDialog

    property string _request_amount
    property string _request_description
    property string _request_expiry

    function openInvoice(key) {
        invoice.key = key
        var dialog = invoiceDialog.createObject(app, { invoice: invoice })
        dialog.open()
        return dialog
    }

    function openRequest(key) {
        // Easy Heirs: our Ricevi screen
        var ehdialog = ehReceiveDialog.createObject(app, { key: key })
        ehdialog.open()
        return ehdialog
    }
    function openRequestElectrum(key) {
        var dialog = receiveDialog.createObject(app, { key: key })
        dialog.open()
        return dialog
    }

    function openSendDialog() {
        _sendDialog = ehSendDialog.createObject(mainView, {invoiceParser: invoiceParser, piResolver: piResolver})  // Easy Heirs
        _sendDialog.open()
    }

    function closeSendDialog() {
        if (_sendDialog) {
            _sendDialog.doClose()
            _sendDialog = null
        }
    }

    function restartSendDialog() {
        if (_sendDialog) {
            _sendDialog.restart()
        }
    }

    function showExport(data, helptext) {
        var dialog = exportTxDialog.createObject(app, {
            text: data[0],
            text_qr: data[1],
            text_help: helptext,
            text_warn: data[2]
                ? ''
                : [qsTr('Warning: Some data (prev txs / "full utxos") was left out of the QR code as it would not fit.'),
                   qsTr('This might cause issues if signing offline.'),
                   qsTr('As a workaround, copy to clipboard or use the Share option instead.')].join(' '),
            tx_label: data[3]
        })
        dialog.open()
    }

    function payOnchain(invoicedialog, invoice) {
        var dialog = confirmPaymentDialog.createObject(mainView, {
                address: invoice.address,
                satoshis: invoice.amountOverride.isEmpty
                    ? invoice.amount
                    : invoice.amountOverride,
                message: invoice.message
        })
        var canComplete = !Daemon.currentWallet.isWatchOnly && Daemon.currentWallet.canSignWithoutCosigner
        dialog.accepted.connect(function() {
            if (invoice.canSave)
                if (!invoice.saveInvoice())
                    return
            if (!canComplete) {
                if (Daemon.currentWallet.isWatchOnly) {
                    dialog.finalizer.saveOrShow()
                } else {
                    dialog.finalizer.sign()
                }
            } else {
                // store txid in invoicedialog so the dialog can detect broadcast success
                invoicedialog.broadcastTxid = dialog.finalizer.finalizedTxid
                dialog.finalizer.signAndSend()
            }
        })
        dialog.open()
    }

    function createRequest(lightning, reuse_address) {
        var qamt = Config.unitsToSats(_request_amount)
        Daemon.currentWallet.createRequest(qamt, _request_description, _request_expiry, lightning, reuse_address)
    }

    function startSweep() {
        var dialog = sweepDialog.createObject(app)
        dialog.accepted.connect(function() {
            var finalizerDialog = confirmSweepDialog.createObject(mainView, {
                privateKeys: dialog.privateKeys,
                message: qsTr('Sweep transaction'),
                showOptions: false,
                amountLabelText: qsTr('Total sweep amount'),
                sendButtonText: Daemon.currentWallet.isWatchOnly
                    ? qsTr('Sweep...')
                    : qsTr('Sweep')
            })
            finalizerDialog.accepted.connect(function() {
                if (Daemon.currentWallet.isWatchOnly) {
                    var confirmdialog = app.messageDialog.createObject(mainView, {
                        title: qsTr('Confirm Sweep'),
                        text: qsTr('Current wallet is watch-only. You might not be able to spend from these addresses.\n\nAre you sure?'),
                        yesno: true
                    })
                    confirmdialog.accepted.connect(function() {
                        finalizerDialog.finalizer.send()
                        close()
                    })
                    confirmdialog.open()
                    return
                }
                console.log("Sending sweep transaction")
                finalizerDialog.finalizer.send()
            })
            finalizerDialog.open()
        })
        dialog.open()
    }

    property QtObject menu: Menu {
        id: menu

        parent: Overlay.overlay
        dim: true
        modal: true
        Overlay.modal: Rectangle {
            color: "#44000000"
        }

        property int implicitChildrenWidth: 64
        width: implicitChildrenWidth + 60 + constants.paddingLarge

        MenuItem {
            icon.color: action.enabled ? 'transparent' : Material.iconDisabledColor
            icon.source: '../../icons/wallet.png'
            action: Action {
                text: qsTr('Wallet details')
                enabled: app.stack.currentItem.objectName != 'WalletDetails'
                onTriggered: menu.openPage(Qt.resolvedUrl('WalletDetails.qml'))
            }
        }
        MenuItem {
            icon.color: action.enabled ? 'transparent' : Material.iconDisabledColor
            icon.source: '../../icons/tab_addresses.png'
            action: Action {
                text: qsTr('Addresses/Coins');
                onTriggered: menu.openPage(Qt.resolvedUrl('Addresses.qml'));
                enabled: app.stack.currentItem.objectName != 'Addresses'
            }
        }
        MenuItem {
            icon.color: action.enabled ? 'transparent' : Material.iconDisabledColor
            icon.source: '../../icons/lightning.png'
            action: Action {
                text: qsTr('Channels');
                enabled: Daemon.currentWallet.isLightning && app.stack.currentItem.objectName != 'Channels'
                onTriggered: menu.openPage(Qt.resolvedUrl('Channels.qml'))
            }
        }

        MenuItem {
            icon.color: action.enabled ? 'transparent' : Material.iconDisabledColor
            icon.source: '../../icons/pen.png'
            action: Action {
                text: Daemon.currentWallet.canSignMessage
                    ? qsTr('Sign/Verify Message')
                    : qsTr('Verify Message')
                onTriggered: {
                    var dialog = app.signVerifyMessageDialog.createObject(app)
                    dialog.open()
                    menu.deselect()
                }
            }
        }

        MenuItem {
            icon.color: action.enabled ? 'transparent' : Material.iconDisabledColor
            icon.source: '../../icons/sweep.png'
            action: Action {
                text: qsTr('Sweep key(s)')
                onTriggered: {
                    startSweep()
                    menu.deselect()
                }
            }
        }

        MenuSeparator { }

        MenuItem {
            icon.color: action.enabled ? 'transparent' : Material.iconDisabledColor
            icon.source: '../../icons/file.png'
            action: Action {
                text: qsTr('Other wallets')
                enabled: app.stack.currentItem.objectName != 'Wallets'
                onTriggered: menu.openPage(Qt.resolvedUrl('Wallets.qml'))
            }
        }

        function openPage(url) {
            stack.pushOnRoot(url)
            deselect()
        }

        function deselect() {
            currentIndex = -1
        }

        // determine widest element and store in implicitChildrenWidth
        function updateImplicitWidth() {
            for (let i = 0; i < menu.count; i++) {
                var item = menu.itemAt(i)
                var txt = item.text
                var txtwidth = fontMetrics.advanceWidth(txt)
                if (txtwidth > menu.implicitChildrenWidth) {
                    menu.implicitChildrenWidth = txtwidth
                }
            }
        }

        FontMetrics {
            id: fontMetrics
            font: menu.font
        }

        Component.onCompleted: updateImplicitWidth()
    }

    // Easy Heirs (schèi): home in the "Colline del vino" style.
    // The app header is hidden on this page (ehHideHeader); our own top bar has
    // the logo and a small gear button for the settings.
    property bool ehHideHeader: true
    // T2 (phone test 2026-11-09): on the Pixel the home already starts below the
    // status bar, so adding statusBarHeight again pushed logo and sun down.
    // ehTop = only the part of the status bar that really covers this page.
    property real ehTop: app.statusBarHeight
    function ehFixTop() {
        var p = mainView.mapToItem(null, 0, 0)
        mainView.ehTop = Math.max(0, app.statusBarHeight - p.y)
    }
    onHeightChanged: Qt.callLater(ehFixTop)
    Material.theme: Material.Light
    Material.foreground: '#2a2220'

    Rectangle {
        anchors.fill: parent
        color: '#faf7ef'
    }

    // hills behind the top of the page: the wallet card sits on them
    EhHills {
        band: true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: mainView.ehTop + 104   // T19: hills only behind the logo, the movements start below
        sunSize: 40
        sunTop: mainView.ehTop + 6
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.bottomMargin: 16 + app.navigationBarHeight
        spacing: 6

        // logo "schèi Wallet" at the top, in the sky
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: mainView.ehTop + 96   // T19: the movements start under the hills (title fully visible)
            Image {
                id: ehLogo
                x: 16
                y: mainView.ehTop + 6
                width: 92
                height: 92 * 345 / 756
                source: Qt.resolvedUrl('../../icons/eh_logo_wine.png')
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }
            Label {
                anchors.left: ehLogo.right
                anchors.leftMargin: 6
                anchors.bottom: ehLogo.bottom
                anchors.bottomMargin: 2
                text: 'Wallet'
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 18
            }
        }

        // offline banner
        Rectangle {
            visible: !Network.isConnected
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: offRow.implicitHeight + 20
            radius: 14
            color: '#fbf0d6'
            border.width: 2
            border.color: '#ecd49a'
            RowLayout {
                id: offRow
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                Image {
                    source: Qt.resolvedUrl('../../icons/eh_nowifi.svg')
                    sourceSize.width: 28
                    sourceSize.height: 28
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    color: '#5a3a08'
                    font.pixelSize: 15
                    text: '<b>' + qsTr('No internet.') + '</b> ' + qsTr('The balance may not be up to date.')
                }
            }
        }

        // expert option "two buttons": the card stays wide, above the buttons
        EhBalanceCard {
            visible: app.ehOption('buttons') && !app.ehOption('multi')
            showGear: true
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
        }
        EhWalletCarousel {
            visible: app.ehOption('buttons') && app.ehOption('multi')
            Layout.fillWidth: true
        }

        // expert option: two big buttons instead of the slide bar
        ColumnLayout {
            visible: app.ehOption('buttons')
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 10
            EhPillButton {
                text: qsTr('RECEIVE')
                fontSize: 26
                color: '#45541f'; textColor: '#ffffff'; tileColor: '#e6e9cf'; outlined: false
                onClicked: Daemon.currentWallet.ehReceive()
                Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_rx_olive.svg'); sourceSize.width: 38; sourceSize.height: 38 }
            }
            EhPillButton {
                visible: Daemon.currentWallet && !Daemon.currentWallet.isWatchOnly
                text: qsTr('SEND')
                fontSize: 26
                color: '#5e1a33'; textColor: '#ffffff'; tileColor: '#d9b25a'; outlined: false
                onClicked: openSendDialog()
                Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_tx_wine.svg'); sourceSize.width: 38; sourceSize.height: 38 }
            }
            EhHistoryPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        // T37/T38 (owner 2026-11-11, preview portafoglio-si-apre.html): on top the movements on the
        // left and the coin's rail on the right (SEND at the top); at the bottom the wallet, as wide
        // as the page. "pull down RECEIVE" is right above the wallet: pulling the coin down OPENS
        // the wallet (the card leans forward and the inside rises), and the coin goes in.
        ColumnLayout {
            visible: !app.ehOption('buttons')
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 14
                Layout.rightMargin: 6
                spacing: 4
                EhHistoryPanel {
                    glass: true
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
                EhSlideBar {
                    id: slideBar
                    Layout.preferredWidth: 88
                    Layout.fillHeight: true
                    sendEnabled: Daemon.currentWallet && !Daemon.currentWallet.isWatchOnly
                    onSendRequested: openSendDialog()
                    onReceiveRequested: {
                        // same address until money arrives on it (see qewallet.ehReceive)
                        Daemon.currentWallet.ehReceive()
                    }
                }
            }

            // more wallets: which one receives
            Label {
                visible: app.ehOption('multi') && Daemon.currentWallet !== null
                Layout.leftMargin: 22
                Layout.topMargin: 2
                textFormat: Text.StyledText
                font.pixelSize: 13
                color: '#45541f'
                text: qsTr('receive in:') + ' <b>' + (Daemon.currentWallet ? app.ehWalletName() : '') + '</b>'
            }

            // one wallet: the card with its inside behind it
            Item {
                visible: !app.ehOption('multi')
                Layout.fillWidth: true
                Layout.leftMargin: 19    // room for the strap on the left edge of the card
                Layout.rightMargin: 14
                Layout.topMargin: 4
                Layout.bottomMargin: 8
                Layout.preferredHeight: homeCard.implicitHeight
                EhWalletInside {
                    anchors.fill: parent
                    baseColor: homeCard.baseColor
                    openK: slideBar.receiveProgress
                }
                EhBalanceCard {
                    id: homeCard
                    anchors.left: parent.left
                    anchors.right: parent.right
                    showGear: true
                    compact: true
                    strapLeft: true
                    // T37: the front comes down from the top (opening), the inside appears above it
                    transform: Scale {
                        origin.y: homeCard.height
                        yScale: 1 - 0.22 * slideBar.receiveProgress
                    }
                }
            }
            EhWalletCarousel {
                visible: app.ehOption('multi')
                compact: true
                strapLeft: true
                openK: slideBar.receiveProgress
                Layout.fillWidth: true
                Layout.leftMargin: 19
                Layout.rightMargin: 6
                Layout.bottomMargin: 6
            }
        }
    }

    property color navigationBarBackgroundColor: constants.highlightBackground

    PIResolver {
        id: piResolver
        wallet: Daemon.currentWallet

        onResolveError: (code, message) => {
            var dialog = app.messageDialog.createObject(app, {
                title: qsTr('Error'),
                iconSource: Qt.resolvedUrl('../../icons/warning.png'),
                text: message
            })
            dialog.closed.connect(function() {
                restartSendDialog()
            })
            dialog.open()
        }

        onInvoiceResolved: (pi) => {
            invoiceParser.fromResolvedPaymentIdentifier(pi)
        }

        onRequestResolved: (pi) => {
            requestDetails.fromResolvedPaymentIdentifier(pi)
        }
    }

    RequestDetails {
        id: requestDetails
        wallet: Daemon.currentWallet
        onNeedsLNURLUserInput: {
            closeSendDialog()
            var dialog = lnurlWithdrawDialog.createObject(app, {
                requestDetails: requestDetails
            })
            dialog.open()
        }
        onLnurlError: (code, message) => {
            var dialog = app.messageDialog.createObject(app, {
                title: qsTr('Error'),
                iconSource: Qt.resolvedUrl('../../icons/warning.png'),
                text: message
            })
            dialog.open()
        }
    }

    Invoice {
        id: invoice
        wallet: Daemon.currentWallet
    }

    InvoiceParser {
        id: invoiceParser
        wallet: Daemon.currentWallet
        onValidationError: (code, message) => {
            var dialog = app.messageDialog.createObject(app, {
                title: qsTr('Error'),
                iconSource: Qt.resolvedUrl('../../icons/warning.png'),
                text: message
            })
            dialog.closed.connect(function() {
                restartSendDialog()
            })
            dialog.open()
        }
        onValidationWarning: (code, message) => {
            if (code == 'no_channels') {
                var dialog = app.messageDialog.createObject(app, {
                    text: message
                })
                dialog.closed.connect(function() {
                    restartSendDialog()
                })
                dialog.open()
                // TODO: ask user to open a channel, if funds allow
                // and maybe store invoice if expiry allows
            }
        }
        onValidationSuccess: {
            closeSendDialog()
            if (Daemon.currentWallet && Daemon.currentWallet.isWatchOnly) {
                // third review: a wallet "only to look at" has no keys, it cannot pay
                app.ehInfoDialog.createObject(app, {
                    pageTitle: qsTr('This wallet can only look'),
                    bodyText: qsTr('It shows the balance, but it does not have the keys to pay. Open a wallet with its 12 words to pay.')
                }).open()
                return
            }
            if (invoiceParser.invoiceType == Invoice.OnchainInvoice) {
                // Easy Heirs: our amount / check / slide-to-send screens
                var ehdialog = ehInvoiceDialog.createObject(app, { invoice: invoiceParser })
                ehdialog.open()
                return
            }
            // Easy Heirs (review 2026-11-11): Schèi pays only plain bitcoin addresses, through its
            // own screens (PIN, two slides, countdown). Lightning invoices, also those with an
            // on-chain fallback, would open Electrum's dialog and pay with none of that: refuse them.
            app.ehInfoDialog.createObject(app, {
                pageTitle: qsTr('This code cannot be paid with Schèi'),
                bodyText: qsTr('It is a <b>Lightning</b> payment request. Schèi pays only normal bitcoin addresses (they start with bc1, 1 or 3).')
                          + '<br><br>' + qsTr('Ask the person you pay for a normal bitcoin address.')
            }).open()
        }
        onInvoiceCreateError: (code, message) => {
            var msg = qsTr('Cannot save invoice') + ': ' + message
            var dialog = app.messageDialog.createObject(app, {
                text: msg
            })
            dialog.open()
        }
        onLnurlRetrieved: {
            closeSendDialog()
            if (invoiceParser.invoiceType === Invoice.Type.LNURLPayRequest) {
                var dialog = lnurlPayDialog.createObject(app, {
                    invoiceParser: invoiceParser
                })
            } else {
                console.log("Unsupported LNURL type:", invoiceParser.invoiceType)
                return
            }
            dialog.open()
        }
        onLnurlError: (code, message) => {
            var dialog = app.messageDialog.createObject(app, {
                title: qsTr('Error'),
                iconSource: Qt.resolvedUrl('../../icons/warning.png'),
                text: message
            })
            dialog.open()
        }
    }

    Bitcoin {
        id: bitcoin
    }

    Connections {
        target: Daemon
        function onWalletLoaded() {
            if (!Daemon.currentWallet) {  // wallet got deleted
                app.stack.replaceRoot('Wallets.qml')
                return
            }
            infobanner.hide() // start hidden when switching wallets
        }
    }

    Connections {
        target: app
        function onPendingIntentChanged() {
            if (app.pendingIntent) {
                piResolver.recipient = app.pendingIntent
                app.pendingIntent = ""
            }
        }
    }

    Connections {
        target: Daemon.currentWallet
        function onRequestCreateSuccess(key) {
            openRequest(key)
        }
        function onRequestCreateError(error) {
            console.log(error)
            var dialog = app.messageDialog.createObject(app, {
                title: qsTr('Error'),
                iconSource: Qt.resolvedUrl('../../icons/warning.png'),
                text: error
            })
            dialog.open()
        }
        function onOtpRequested() {
            console.log('OTP requested')
            var dialog = otpDialog.createObject(mainView)
            dialog.open()
        }
        function onBroadcastFailed(txid, code, message) {
            // Easy Heirs (third review): the payment page says it, with words for people
        }
        function onPaymentFailed(invoice_id, message) {
            var dialog = app.messageDialog.createObject(app, {
                title: qsTr('Error'),
                iconSource: Qt.resolvedUrl('../../icons/warning.png'),
                text: message ? message : qsTr('Payment failed')
            })
            dialog.open()
        }
        function onImportChannelBackupFailed(message) {
            var dialog = app.messageDialog.createObject(app, {
                title: qsTr('Error'),
                iconSource: Qt.resolvedUrl('../../icons/warning.png'),
                text: message
            })
            dialog.open()
        }
        function onBalanceChanged() {
            // ln low reserve warning
            if (Daemon.currentWallet.isLowReserve) {
                var message = [
                    qsTr('You do not have enough on-chain funds to protect your Lightning channels.'),
                    qsTr('You should have at least %1 on-chain in order to be able to sweep channel outputs.').arg(Config.formatSats(Config.lnUtxoReserve) + ' ' + Config.baseUnit)
                ].join(' ')
                infobanner.show(message, function() {
                    var dialog = app.messageDialog.createObject(app, {
                        text: message + '\n\n' + qsTr('Do you want to perform a swap?'),
                        yesno: true
                    })
                    dialog.accepted.connect(function() {
                        app.startSwap()
                    })
                    dialog.open()
                })
            } else {
                infobanner.hide()
            }
        }
    }

    Component {
        id: invoiceDialog
        InvoiceDialog {
            id: _invoiceDialog

            width: parent.width
            height: parent.height

            onDoPay: {
                var lninvoiceButPayOnchain = false
                if (invoice.invoiceType == Invoice.LightningInvoice && invoice.address) {
                    // ln invoice with fallback
                    var amountToSend = invoice.amountOverride.isEmpty
                        ? invoice.amount.satsInt
                        : invoice.amountOverride.satsInt
                    if (amountToSend > Daemon.currentWallet.lightningCanSend.satsInt) {
                        lninvoiceButPayOnchain = true
                    }
                }
                if (invoice.invoiceType == Invoice.OnchainInvoice) {
                    payOnchain(_invoiceDialog, invoice)
                } else if (invoice.invoiceType == Invoice.LightningInvoice) {
                    if (lninvoiceButPayOnchain) {
                        var dialog = app.messageDialog.createObject(mainView, {
                            title: qsTr('Insufficient balance to pay over Lightning. Pay on-chain instead?'),
                            yesno: true
                        })
                        dialog.accepted.connect(function() {
                            payOnchain(_invoiceDialog, invoice)
                        })
                        dialog.open()
                    } else {
                        console.log('About to pay lightning invoice')
                        invoice.payLightningInvoice()
                    }
                }
            }

            onClosed: destroy()

            Connections {
                target: Daemon.currentWallet
                function onSaveTxSuccess(txid) {
                    _invoiceDialog.close()
                }
            }
        }
    }

    Component {
        id: qtSendDialog
        SendDialog {}
    }

    Component {
        id: ehSendDialog
        EhSendDialog {}
    }

    Component {
        id: ehInvoiceDialog
        EhInvoiceDialog { onClosed: destroy() }
    }

    Component {
        id: receiveDetailsDialog

        ReceiveDetailsDialog {
            id: _receiveDetailsDialog
            width: parent.width * 0.9
            anchors.centerIn: parent
            onAccepted: {
                console.log('accepted')
                _request_amount = _receiveDetailsDialog.amount
                _request_description = _receiveDetailsDialog.description
                _request_expiry = _receiveDetailsDialog.expiry
                createRequest(_receiveDetailsDialog.isLightning, false)
            }
            onRejected: {
                console.log('rejected')
            }
            onClosed: destroy()
        }
    }

    Component {
        id: ehReceiveDialog
        EhReceiveDialog {
            onClosed: destroy()
        }
    }

    Component {
        id: receiveDialog
        ReceiveDialog {
            width: parent.width
            height: parent.height

            onRequestPaid: {
                close()
                var capturedHistoryModel = Daemon.currentWallet.historyModel
                if (isLightning) {
                    var page = app.stack.push(Qt.resolvedUrl('LightningPaymentDetails.qml'), {'key': key})
                    var capturedKey = key
                    page.detailsChanged.connect(function() {
                            capturedHistoryModel.updateTxLabel(capturedKey, page.label)
                        }
                    )
                } else {
                    let paidTxid = getPaidTxid()
                    var page = app.stack.push(Qt.resolvedUrl('TxDetails.qml'), {'txid': paidTxid})
                    page.detailsChanged.connect(function() {
                            capturedHistoryModel.updateTxLabel(paidTxid, page.label)
                        }
                    )
                }
            }
            onClosed: destroy()
        }
    }

    Component {
        id: confirmPaymentDialog
        ConfirmTxDialog {
            id: _confirmPaymentDialog
            title: qsTr('Confirm Payment')
            finalizer: TxFinalizer {
                wallet: Daemon.currentWallet
                canRbf: true
                onFinished: (signed, saved, complete) => {
                    if (!complete) {
                        var msg
                        if (wallet.isWatchOnly) {
                            // tx created in watchonly wallet. Show QR for signer(s)
                            if (wallet.isMultisig) {
                                msg = qsTr('Transaction created. Present this QR code to one of the co-cigners or signing devices')
                            } else {
                                msg = qsTr('Transaction created. Present this QR code to the signing device')
                            }
                        } else {
                            if (signed) {
                                msg = qsTr('Transaction created and partially signed by this wallet. Present this QR code to the next co-signer')
                            } else {
                                msg = qsTr('Transaction created but not signed by this wallet yet. Sign the transaction and present this QR code to the next co-signer')
                            }
                        }
                        showExport(getSerializedTx(), msg)
                    }
                    _confirmPaymentDialog.destroy()
                }
                onSignError: (message) => {
                    var dialog = app.messageDialog.createObject(mainView, {
                        title: qsTr('Error'),
                        text: [qsTr('Could not sign tx'), message].join('\n\n'),
                        iconSource: '../../../icons/warning.png'
                    })
                    dialog.open()
                }
            }

            // TODO: lingering confirmPaymentDialogs can raise exceptions in
            // the child finalizer when currentWallet disappears, but we need
            // it long enough for the finalizer to finish..
            // onClosed: destroy()
        }
    }

    Component {
        id: confirmSweepDialog
        ConfirmTxDialog {
            id: _confirmSweepDialog

            property string privateKeys
            title: qsTr('Confirm Sweep')
            satoshis: MAX
            finalizer: SweepFinalizer {
                wallet: Daemon.currentWallet
                canRbf: true
                privateKeys: _confirmSweepDialog.privateKeys
            }
        }
    }

    Component {
        id: lnurlPayDialog
        LnurlPayRequestDialog {
            width: parent.width * 0.9
            anchors.centerIn: parent

            onClosed: destroy()
        }
    }

    Component {
        id: lnurlWithdrawDialog
        LnurlWithdrawRequestDialog {
            width: parent.width * 0.9
            anchors.centerIn: parent

            onClosed: destroy()
        }
    }

    Component {
        id: otpDialog
        OtpDialog {
            width: parent.width * 2/3
            anchors.centerIn: parent

            onClosed: destroy()
        }
    }

    Component {
        id: exportTxDialog
        ExportTxDialog {
            onClosed: destroy()
        }
    }

    Component {
        id: sweepDialog
        SweepDialog {
            onClosed: destroy()
        }
    }

    Component.onCompleted: {
        console.log("WalletMainView completed: ", Daemon.currentWallet.name)
        Qt.callLater(ehFixTop)  // T2
        if (app.pendingIntent) {
            piResolver.recipient = app.pendingIntent
            app.pendingIntent = ""
        }
    }
}
