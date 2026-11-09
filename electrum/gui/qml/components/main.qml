import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import QtQuick.Window

import QtQml

import org.electrum 1.0

import "controls"

ApplicationWindow
{
    id: app

    visible: false // initial value

    readonly property int statusBarHeight: AppController ? AppController.getStatusBarHeight() : 0
    readonly property int navigationBarHeight: AppController ? AppController.getNavigationBarHeight() : 0

    // dimensions ignored on android
    width: 480
    height: 800

    Material.theme: Material.Dark
    Material.primary: Material.Indigo
    Material.accent: Material.LightBlue
    font.pixelSize: constants.fontSizeMedium
    font.family: AppFont ? AppFont : Qt.application.font.family  // Easy Heirs: Red Hat Text

    property QtObject constants: appconstants
    Constants { id: appconstants }

    property alias stack: mainStackView
    property alias keyboardFreeZone: _keyboardFreeZone
    property alias infobanner: _infobanner
    property color _navigationBarBackgroundColor: 'transparent'

    property string pendingIntent: ""

    property variant activeDialogs: []

    property var _exceptionDialog

    property var pluginobjects: ({})

    property QtObject appMenu: Menu {
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
            icon.source: '../../icons/network.png'
            action: Action {
                text: qsTr('Network')
                onTriggered: menu.openPage(Qt.resolvedUrl('NetworkOverview.qml'))
                enabled: stack.currentItem.objectName != 'NetworkOverview'
            }
        }

        MenuItem {
            icon.color: action.enabled ? 'transparent' : Material.iconDisabledColor
            icon.source: '../../icons/preferences.png'
            action: Action {
                text: qsTr('Preferences')
                onTriggered: menu.openPage(Qt.resolvedUrl('Preferences.qml'))
                enabled: stack.currentItem.objectName != 'Properties'
            }
        }

        MenuItem {
            icon.color: action.enabled ? 'transparent' : Material.iconDisabledColor
            icon.source: '../../icons/electrum.png'
            action: Action {
                text: qsTr('About');
                onTriggered: menu.openPage(Qt.resolvedUrl('About.qml'))
                enabled: stack.currentItem.objectName != 'About'
            }
        }

        function openPage(url) {
            stack.pushOnRoot(url)
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

    function openAppMenu() {
        appMenu.open()
        appMenu.x = app.width - appMenu.width
        appMenu.y = toolbar.height
    }

    header: ToolBar {
        id: toolbar
        // Easy Heirs: pages with their own top bar hide the app header
        visible: !(mainStackView.currentItem && mainStackView.currentItem.ehHideHeader === true)

        // Add top margin for status bar on Android when using edge-to-edge
        topPadding: app.statusBarHeight

        background: Rectangle {
            implicitHeight: 48
            color: constants.dialogColor

            layer.enabled: true
            layer.effect: ElevationEffect {
                elevation: 4
                fullWidth: true
            }
        }

        ColumnLayout {
            spacing: 0
            anchors.left: parent.left
            anchors.right: parent.right
            height: toolbar.availableHeight

            RowLayout {
                id: toolbarTopLayout

                Layout.fillWidth: true
                Layout.rightMargin: constants.paddingMedium
                Layout.alignment: Qt.AlignVCenter

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(implicitHeight, toolbarTopLayout.height)

                    MouseArea {
                        anchors.fill: parent
                        enabled: Daemon.currentWallet &&
                            (!stack.currentItem || !stack.currentItem.title || stack.currentItem.title == Daemon.currentWallet.name)
                        onClicked: {
                            stack.getRoot().menu.open()  // open wallet-menu
                            stack.getRoot().menu.y = toolbar.height
                        }
                    }

                    RowLayout {
                        width: parent.width

                        Item {
                            Layout.preferredWidth: constants.paddingXLarge
                            Layout.preferredHeight: 1
                        }

                        Image {
                            Layout.preferredWidth: constants.iconSizeSmall
                            Layout.preferredHeight: constants.iconSizeSmall
                            visible: Daemon.currentWallet &&
                                (!stack.currentItem || !stack.currentItem.title || stack.currentItem.title == Daemon.currentWallet.name)
                            source: '../../icons/wallet.png'
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(implicitHeight, toolbarTopLayout.height)
                            text: stack.currentItem && stack.currentItem.title
                                ? stack.currentItem.title
                                : Daemon.currentWallet.name
                            elide: Label.ElideRight
                            verticalAlignment: Qt.AlignVCenter
                            font.pixelSize: constants.fontSizeMedium
                            font.bold: true
                        }
                    }
                }

                Item {
                    implicitHeight: 48
                    implicitWidth: statusIconsLayout.width

                    MouseArea {
                        anchors.fill: parent
                        onClicked: openAppMenu()  // open global-app-menu
                    }

                    RowLayout {
                        id: statusIconsLayout
                        anchors.verticalCenter: parent.verticalCenter
                        Item {
                            Layout.preferredWidth: constants.paddingLarge
                            Layout.preferredHeight: 1
                        }

                        Item {
                            visible: Network.isTestNet
                            width: column.width
                            height: column.height

                            ColumnLayout {
                                id: column
                                spacing: 0
                                Image {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: constants.iconSizeSmall
                                    Layout.preferredHeight: constants.iconSizeSmall
                                    source: "../../icons/info.png"
                                }

                                Label {
                                    id: networkNameLabel
                                    text: Network.networkName
                                    color: Material.accentColor
                                    font.pixelSize: constants.fontSizeXSmall
                                }
                            }
                        }

                        LightningNetworkStatusIndicator {
                            id: lnnsi
                        }
                        OnchainNetworkStatusIndicator { }
                    }
                }
            }

            // hack to force relayout of toolbar
            // since qt6 LightningNetworkStatusIndicator.visible doesn't trigger relayout(?)
            Item {
                Layout.preferredHeight: 1
                Layout.topMargin: -1
                Layout.preferredWidth: lnnsi.visible
                    ? 1
                    : 2
            }
        }
    }

    ColumnLayout {
        width: parent.width
        height: _keyboardFreeZone.height - (header.visible ? header.height : 0)  // Easy Heirs: header can be hidden
        spacing: 0

        InfoBanner {
            id: _infobanner
            Layout.fillWidth: true
        }

        StackView {
            id: mainStackView
            Layout.fillHeight: true
            Layout.fillWidth: true

            initialItem: Component {
                Wallets {}
            }

            function getRoot() {
                return mainStackView.get(0)
            }
            function pushOnRoot(item) {
                if (mainStackView.depth > 1) {
                    mainStackView.replace(mainStackView.get(1), item)
                } else {
                    mainStackView.push(item)
                }
            }
            function replaceRoot(item_url) {
                mainStackView.clear()
                mainStackView.push(Qt.resolvedUrl(item_url))
            }
            function updateStylingFromItem(item) {
                _navigationBarBackgroundColor = item && 'navigationBarBackgroundColor' in item
                    ? item.navigationBarBackgroundColor
                    : 'transparent'
            }
            onCurrentItemChanged: updateStylingFromItem(currentItem)
        }

        // Add bottom padding for navigation bar on Android when UI is edge-to-edge
        Item {
            visible: app.navigationBarHeight > 0 && _keyboardFreeZone.state != 'visible'
            Layout.fillWidth: true
            Layout.preferredHeight: app.navigationBarHeight

            Rectangle { anchors.fill: parent; color: _navigationBarBackgroundColor }
        }
    }

    Timer {
        id: coverTimer
        interval: 10
        onTriggered: {
            app.visible = true
            cover.opacity = 0
        }
    }

    Rectangle {
        id: cover
        parent: Overlay.overlay
        anchors.fill: parent

        z: 1000
        color: 'black'

        Behavior on opacity {
            enabled: AppController ? AppController.isAndroid() : false
            NumberAnimation {
                duration: 1000
                easing.type: Easing.OutQuad;
            }
        }
    }

    Item {
        id: _keyboardFreeZone
        // Item as first child in Overlay that adjusts its size to the available
        // screen space minus the virtual keyboard (e.g. to center dialogs in)
        // see also ElDialog.resizeWithKeyboard property
        parent: Overlay.overlay
        width: parent.width
        height: parent.height

        states: [
            State {
                name: 'visible'
                when: Qt.inputMethod.keyboardRectangle.y
                PropertyChanges {
                    target: _keyboardFreeZone
                    height: _keyboardFreeZone.parent.height - (Screen.desktopAvailableHeight - (Qt.inputMethod.keyboardRectangle.y/Screen.devicePixelRatio))
                }
            }
        ]

        transitions: [
            Transition {
                from: ''
                to: 'visible'
                NumberAnimation {
                    properties: 'height'
                    duration: 100
                    easing.type: Easing.OutQuad
                }
            },
            Transition {
                from: 'visible'
                to: ''
                SequentialAnimation {
                    PauseAnimation {
                        duration: 200
                    }
                    NumberAnimation {
                        properties: 'height'
                        duration: 50
                        easing.type: Easing.OutQuad
                    }
                }
            }
        ]
    }

    property alias newWalletWizard: _newWalletWizard
    Component {
        id: _newWalletWizard
        NewWalletWizard {
            onClosed: destroy()
        }
    }

    // Easy Heirs: first screen, language choice
    property alias languagePicker: _languagePicker
    Component {
        id: _languagePicker
        LanguagePicker {
            onClosed: destroy()
        }
    }

    property alias termsOfUseWizard: _termsOfUseWizard
    Component {
        id: _termsOfUseWizard
        TermsOfUseWizard {
            onClosed: destroy()
        }
    }

    property alias serverConnectWizard: _serverConnectWizard
    Component {
        id: _serverConnectWizard
        ServerConnectWizard {
            onClosed: destroy()
        }
    }

    property alias messageDialog: _messageDialog
    Component {
        id: _messageDialog
        MessageDialog {
            onClosed: destroy()
        }
    }

    property alias helpDialog: _helpDialog
    Component {
        id: _helpDialog
        HelpDialog {
            onClosed: destroy()
        }
    }

    // Easy Heirs: PIN pad dialog (open wallet / confirm) and 'wallet ready' screen
    property alias ehPinDialog: _ehPinDialog
    Component {
        id: _ehPinDialog
        EhPinDialog {
            onClosed: destroy()
        }
    }
    property alias ehReadyDialog: _ehReadyDialog
    Component {
        id: _ehReadyDialog
        EhReadyDialog {
            onClosed: destroy()
        }
    }
    property bool _ehShowReady: false

    property alias passwordDialog: _passwordDialog
    Component {
        id: _passwordDialog
        PasswordDialog {
            onClosed: destroy()
        }
    }

    property alias genericShareDialog: _genericShareDialog
    Component {
        id: _genericShareDialog
        GenericShareDialog {
            onClosed: destroy()
        }
    }

    property alias openWalletDialog: _openWalletDialog
    Component {
        id: _openWalletDialog
        OpenWalletDialog {
            onClosed: destroy()
        }
    }

    property alias loadingWalletDialog: _loadingWalletDialog
    Component {
        id: _loadingWalletDialog
        LoadingWalletDialog {
            onClosed: destroy()
        }
    }

    property alias scanDialog: _scanDialog
    Component {
        id: _scanDialog
        ScanDialog {}
    }

    Component {
        id: crashDialog
        ExceptionDialog {
            onClosed: destroy()
        }
    }

    property alias channelOpenProgressDialog: _channelOpenProgressDialog
    ChannelOpenProgressDialog {
        id: _channelOpenProgressDialog
    }

    property alias signVerifyMessageDialog: _signVerifyMessageDialog
    Component {
        id: _signVerifyMessageDialog
        SignVerifyMessageDialog {
            onClosed: destroy()
        }
    }

    property alias nostrSwapServersDialog: _nostrSwapServersDialog
    Component {
        id: _nostrSwapServersDialog
        NostrSwapServersDialog {
            onClosed: destroy()
        }
    }

    Component {
        id: swapDialog
        SwapDialog {
            id: _swapdialog
            onClosed: destroy()
            swaphelper: SwapHelper {
                id: _swaphelper
                wallet: Daemon.currentWallet
                onAuthRequired: (method, authMessage) => {
                    app.handleAuthRequired(_swaphelper, method, authMessage)
                }
                onError: (message) => {
                    var dialog = app.messageDialog.createObject(app, {
                        title: qsTr('Error'),
                        iconSource: Qt.resolvedUrl('../../icons/warning.png'),
                        text: message
                    })
                    dialog.open()
                }
                onUndefinedNPub: {
                    var dialog = app.nostrSwapServersDialog.createObject(app, {
                        swaphelper: _swaphelper,
                        selectedPubkey: Config.swapServerNPub
                    })
                    dialog.accepted.connect(function() {
                        Config.swapServerNPub = dialog.selectedPubkey
                        _swaphelper.setReadyState()
                    })
                    dialog.rejected.connect(function() {
                        _swaphelper.npubSelectionCancelled()
                    })
                    dialog.open()
                }
            }
        }
    }

    NotificationPopup {
        id: notificationPopup
        width: parent.width
    }

    Component.onCompleted: {
        coverTimer.start()

        // Easy Heirs: amounts in bitcoin (not mBTC) and in euro, with the value of each day
        if (Config.baseUnit !== 'BTC') Config.baseUnit = 'BTC'
        // 'Solo bitcoin' (expert): no exchange rates at all
        Daemon.fx.enabled = !ehBtcOnly()
        if (Daemon.fx.fiatCurrency !== 'EUR') Daemon.fx.fiatCurrency = 'EUR'
        if (!Daemon.fx.historicRates) Daemon.fx.historicRates = true

        // Easy Heirs: no terms of use and no server choice. After the language
        // the app connects automatically and goes straight to the wallet.
        function continueWithServerConnection() {
            if (!Network.autoConnectDefined) {
                Network.enableAutoConnect()
            }
            Daemon.startNetwork()
            if (Daemon.availableWallets.rowCount() > 0) {
                Daemon.loadWallet()
            } else {
                var newww = app.newWalletWizard.createObject(app)
                newww.walletCreated.connect(function() {
                    app._ehShowReady = true  // Easy Heirs
                    Daemon.availableWallets.reload()
                    // and load the new wallet
                    Daemon.loadWallet(newww.path, newww.wizard_data['password'])
                })
                newww.open()
            }
        }

        // Easy Heirs: at first start, choose the language before anything else
        if (!Config.languageChosen) {
            var langDialog = languagePicker.createObject(app)
            langDialog.accepted.connect(function() {
                continueWithServerConnection()
            })
            langDialog.open()
        } else {
            continueWithServerConnection()
        }
    }

    onClosing: (close) => {
        if (AppController.wantClose) {
            // destroy most GUI components so that we don't dump so many null reference warnings on exit
            app.header.visible = false
            mainStackView.clear()
            return
        }
        if (activeDialogs.length > 0) {
            var activeDialog = activeDialogs[activeDialogs.length - 1]
            if (activeDialog.allowClose) {
                console.log('main: dialog.doClose')
                activeDialog.doClose()
            } else {
                console.log('dialog disallowed close')
            }
            close.accepted = false
            return
        }
        if (stack.depth > 1) {
            close.accepted = false
            stack.pop()
        } else {
            var dialog = Qt.createComponent(Qt.resolvedUrl('EhAskDialog.qml')).createObject(app, {
                text: qsTr('Close Schèi Wallet?')
            })
            dialog.accepted.connect(function() {
                AppController.wantClose = true
                app.close()
            })
            dialog.open()
            close.accepted = false
        }
    }

    // Easy Heirs: amount formatting (euro first, bitcoin under it), locale by language
    function ehFeeRate(s) {
        var m = ('' + (s || '')).match(/([0-9]+(?:[.,][0-9]+)?)\s*sat\/v(?:B|byte)/i)
        if (!m) return ''
        return m[1].replace('.', ehLocale().decimalPoint).replace(',', ehLocale().decimalPoint) + ' sat/vB'
    }
    function ehLocale() { return Config.language === 'en_UK' ? Qt.locale('en_GB') : Qt.locale('it_IT') }
    function ehGroup(intStr) {
        var sep = Config.language === 'en_UK' ? ',' : '.'
        return intStr.replace(/\B(?=(\d{3})+(?!\d))/g, sep)
    }
    function ehEuroNumber(plain) {
        var n = Number(plain)
        if (plain === '' || isNaN(n)) return ''
        var neg = n < 0
        var parts = Math.abs(n).toFixed(2).split('.')
        var dec = Config.language === 'en_UK' ? '.' : ','
        return (neg ? '-' : '') + '€ ' + ehGroup(parts[0]) + dec + parts[1]
    }
    function ehEuro(amount) {
        if (!Daemon.fx.enabled) return ''
        return ehEuroNumber(Daemon.fx.fiatValue(amount, true))
    }
    function ehBtc(amount) {
        var s = Config.formatSats(amount).trim()
        if (s.indexOf('.') >= 0) s = s.replace(/0+$/, '').replace(/\.$/, '')
        if (Config.language !== 'en_UK') s = s.replace(/,/g, ' ').replace('.', ',')
        return s + ' BTC'
    }
    // amount of a history item: historic euro value if known, else today's, else BTC
    function ehTxAmount(amount, timestamp, signed) {
        var e = ''
        if (Daemon.fx.enabled) {
            if (Daemon.fx.historicRates && timestamp)
                e = ehEuroNumber(Daemon.fx.fiatValueHistoric(amount, timestamp, true))
            if (e === '')
                e = ehEuroNumber(Daemon.fx.fiatValue(amount, true))
        }
        var txt = e !== '' ? e : ehBtc(amount)
        if (signed) {
            txt = txt.replace('-', '')
            txt = (amount.satsInt >= 0 ? '+ ' : '− ') + txt
        }
        return txt
    }

    // Easy Heirs: 'Maggiori informazioni' pages
    property alias ehInfoDialog: _ehInfoDialog
    Component { id: _ehInfoDialog; EhInfoDialog { onClosed: destroy() } }
    function ehShowConfirmationsInfo() {
        ehInfoDialog.createObject(app, {
            pageTitle: qsTr('What are confirmations?'),
            showBlocks: true,
            bodyText: qsTr('About every <b>10 minutes</b> the Bitcoin network writes a new "block" with the payments. When your payment enters a block it has <b>1 confirmation</b>; every block after that adds another one.')
                + '<br><br>' + qsTr('The more confirmations, the more impossible it is to go back. People moving <b>millions of euro</b> wait for 6 confirmations, about one hour.'),
            tipText: qsTr('<b>Schèi is a pocket wallet</b>, made for everyday amounts. For these amounts <b>1 confirmation is more than enough</b>: that is why we already show it as "✓ Confirmed".')
        }).open()
    }
    function ehShowFeeInfo() {
        ehInfoDialog.createObject(app, {
            pageTitle: qsTr('What is the sending cost?'),
            bodyText: qsTr('Bitcoin payments are written on the <b>blockchain</b>, the big public register, by computers called <b>"miners"</b>.')
                + '<br><br>' + qsTr('To do it they ask for a small <b>tip</b>: whoever offers more goes first, like in a queue.')
                + '<br><br>' + qsTr('The cost <b>does not depend on how much you send</b>: sending 10 € or 1,000 € costs the same. It only changes a little with the network traffic.'),
            tipText: qsTr('<b>Schèi chooses a "normal" tip by itself</b>: the payment usually arrives in about ten minutes. The whole tip goes to the miners: Schèi takes nothing.')
        }).open()
    }

    // Easy Heirs: options (expert mode etc.), stored with Config.ehSet
    property int ehOptRev: 0
    function ehOption(key) { ehOptRev; return Config.ehGet('opt_' + key) === true }
    function ehSetOption(key, value) { Config.ehSet('opt_' + key, value); ehOptRev++ }
    // T20 step 3: "where the coins come from" (advanced privacy). The list is kept
    // as JSON text in the config; the coins keep only the id of their category.
    readonly property var ehCatColors: ['#1f6fb2', '#b4690e', '#6a4c93', '#2c7a4b', '#c0392b', '#0e8a8a', '#b03a8c', '#5a5a5a']
    function ehCats() {
        ehOptRev
        var raw = Config.ehGet('privacy_cats')
        if (raw) {
            try { var l = JSON.parse(raw); if (l && l.length !== undefined) return l } catch (e) { }
        }
        return [ { 'id': 'ex', 'name': qsTr('exchange'), 'color': '#1f6fb2' },
                 { 'id': 'am', 'name': qsTr('friend'), 'color': '#b4690e' },
                 { 'id': 'pe', 'name': qsTr('pension'), 'color': '#6a4c93' } ]
    }
    function ehSetCats(list) { Config.ehSet('privacy_cats', JSON.stringify(list)); ehOptRev++ }
    // T20 step 4: the warnings, 'warn_mix' and 'warn_dust'
    function ehPrivWarn(k) { ehOptRev; return ehOption('privacy') && Config.ehGet('opt_' + k) !== false }
    function ehSetPrivWarn(k, on) { Config.ehSet('opt_' + k, on); ehOptRev++ }
    // tiny coins the user said he knows: no more warning for them
    function ehDustOk() { ehOptRev; try { return JSON.parse(Config.ehGet('privacy_dust_ok') || '[]') } catch (e) { return [] } }
    function ehSetDustOk(outpoint) { var l = ehDustOk(); if (l.indexOf(outpoint) < 0) l.push(outpoint); Config.ehSet('privacy_dust_ok', JSON.stringify(l)); ehOptRev++ }
    // the category of an id; unknown or empty = "I do not know"
    function ehCat(id) {
        var l = ehCats()
        for (var i = 0; i < l.length; i++) if (l[i].id === id) return l[i]
        return { 'id': '', 'name': qsTr('I do not know'), 'color': '#8a7d70' }
    }
    // double confirmation: on by default, from 500 euro
    function ehDoubleOn() { ehOptRev; var v = Config.ehGet('opt_double'); return (v === null || v === undefined) ? true : v === true }
    // big payment threshold (PIN above it, like a contactless card)
    function ehDoubleEur() { ehOptRev; var v = Config.ehGet('pin_eur'); return v ? v : 100 }
    function ehSetDoubleEur(v) { Config.ehSet('pin_eur', v); ehOptRev++ }
    // time for Electrum's ETA fee targets [1008, 144, 25, 10, 5, 2, 1] blocks (~10 min each)
    function ehFeeEta(pos) {
        return [qsTr('within a week'), qsTr('within a day'), qsTr('in a few hours'), qsTr('in less than 2 hours'),
                qsTr('in about 1 hour'), qsTr('in about 20 minutes'), qsTr('in about 10 minutes')][Math.max(0, Math.min(6, pos))]
    }
    // the 4 steps of a payment, for the steps bar at the top of the pages
    function ehSendSteps() {
        return [
            { icon: 'qr', word: qsTr('Who to'), title: qsTr('Who to'), text: qsTr('Scan the QR code or paste the address of the person you pay.') },
            { icon: 'coins', word: qsTr('How much'), title: qsTr('How much'), text: qsTr('Choose how much you send.') },
            { icon: 'eye', word: qsTr('Check'), title: qsTr('Check carefully'), text: qsTr('Look again at amount, cost and address before sending. Then push up the bitcoin coin.') },
            { icon: 'send', word: qsTr('Sent'), title: qsTr('Sent'), text: qsTr('The money has left. It arrives after the first confirmation.') }
        ]
    }
    // going back to step 1 ("Who to") from the amount / check pages: the address
    // and the amount typed are kept, so nothing has to be typed again
    property var _ehDraft: null
    property real _ehPinOkUntil: 0
    function ehBackToStep1(draft) {
        app._ehDraft = draft
        var mv = app.stack.currentItem
        if (!mv || mv.openSendDialog === undefined) return
        mv.openSendDialog()
        if (mv._sendDialog) mv._sendDialog.pasted = draft.address
    }
    function ehBigLimitText() { return ehBtcOnly() || !Daemon.fx.enabled ? qsTr('20% of the balance') : '€ ' + ehGroup('' + ehDoubleEur()) }
    function ehNeedsDouble(amount) {
        if (!ehDoubleOn() || !amount) return false
        if (amount.isMax) return true
        if (ehBtcOnly() || !Daemon.fx.enabled) {
            // only bitcoin: double confirmation from 20% of what is in the wallet
            var total = Daemon.currentWallet ? Daemon.currentWallet.totalBalance.satsInt : 0
            return amount.satsInt >= Math.ceil(total * 0.2)
        }
        var e = Number(Daemon.fx.fiatValue(amount, true))
        return isNaN(e) ? true : e >= ehDoubleEur()
    }
    // address checks: prefix (bc1q / tb1q ...), first 4 after it, last 4
    function ehAddressParts(a) {
        a = a || ''
        var p = 0
        var m = /^(bc1[qp]|tb1[qp]|bcrt1[qp])/i.exec(a)
        if (m) p = m[0].length
        return { prefix: a.substring(0, p), first: a.substring(p, p + 4), last: a.slice(-4) }
    }
    // address: prefix (bc1q), first 4, middle in groups of 4, last 4; first and last highlighted
    function ehAddressRich(a, fg, bg, perLine) {
        a = a || ''
        if (a.length < 12) return a
        var parts = ehAddressParts(a)
        var p = parts.prefix.length
        var mid = a.substring(p + 4, a.length - 4)
        var groups = mid.match(/.{1,4}/g) || []
        var hl = function(s) { return '<span style="background-color:' + bg + '"><font color="' + fg + '"><u>' + s + '</u></font></span>' }
        var tokens = []
        if (p > 0) tokens.push(parts.prefix)
        tokens.push(hl(parts.first))
        for (var i = 0; i < groups.length; i++) tokens.push(groups[i])
        tokens.push(hl(parts.last))
        if (!perLine) {
            var half = Math.ceil(tokens.length / 2)
            return tokens.slice(0, half).join(' ') + '<br>' + tokens.slice(half).join(' ')
        }
        // as many lines as needed, all about the same length, so every line
        // stays centred even with the big phone font
        var lines = Math.ceil(tokens.length / Math.max(1, perLine))
        var per = Math.ceil(tokens.length / lines)
        var out = []
        for (var k = 0; k < tokens.length; k += per) out.push(tokens.slice(k, k + per).join(' '))
        return out.join('<br>')
    }
    property alias ehAddressZoom: _ehAddressZoom
    Component { id: _ehAddressZoom; EhAddressZoom { onClosed: destroy() } }
    function ehZoomAddress(address, mine) { ehAddressZoom.createObject(app, { address: address, mine: mine }).open() }

    function ehBtcOnly() { ehOptRev; return Config.ehGet('opt_btc_only') === true }
    function ehSetBtcOnly(on) {
        ehSetOption('btc_only', on)
        Daemon.fx.enabled = !on
        if (!on) {
            if (Daemon.fx.fiatCurrency !== 'EUR') Daemon.fx.fiatCurrency = 'EUR'
            if (!Daemon.fx.historicRates) Daemon.fx.historicRates = true
        }
    }
    // amount for display: euro if known, else bitcoin
    function ehMoney(amount) { var e = ehEuro(amount); return e !== '' ? e : ehBtc(amount) }

    function ehExpertAny() {
        var keys = ['euro_btc', 'max', 'request_amount', 'multi', 'watch', 'buttons', 'btc_only']
        for (var i = 0; i < keys.length; i++) if (ehOption(keys[i])) return true
        return false
    }
    function ehWalletKey() { return Daemon.currentWallet ? Daemon.currentWallet.name : '' }
    function ehWalletName() { return ehWalletNameFor(ehWalletKey()) }
    function ehWalletColor() { return ehWalletColorFor(ehWalletKey()) }
    function ehWalletNameFor(n) {
        ehOptRev
        var v = Config.ehGet('name_' + n)
        if (v) return v
        return n === 'Portafoglio' ? qsTr('My wallet') : n.replace('_', ' ')
    }
    function ehWalletColorFor(n) {
        ehOptRev
        var v = Config.ehGet('color_' + n)
        if (v) return v
        var palette = ['#5e1a33', '#45541f', '#1f4f6e', '#7a4a12', '#3e3a6e', '#2d5c4f', '#6b3a2a']
        var m = /_(\d+)$/.exec(n)
        return palette[m ? (parseInt(m[1]) - 1) % 7 : 0]
    }
    function ehAddWallet(full) {
        if (full) {
            app.messageDialog.createObject(app, { text: qsTr('You already have 7 wallets, the maximum.') }).open()
            return
        }
        var w = app.newWalletWizard.createObject(app)
        w.walletCreated.connect(function() {
            Daemon.availableWallets.reload()
            Daemon.loadWallet(w.path, w.wizard_data['password'])
        })
        w.open()
    }
    function ehSetWalletLook(name, color) {
        Config.ehSet('name_' + ehWalletKey(), name)
        Config.ehSet('color_' + ehWalletKey(), color)
        ehOptRev++
    }
    function ehResetSettings() {
        var keys = ['euro_btc', 'max', 'request_amount', 'multi', 'watch', 'sign_elsewhere', 'buttons', 'coins', 'no_anim', 'privacy']
        for (var i = 0; i < keys.length; i++) Config.ehSet('opt_' + keys[i], false)
        Config.ehSet('opt_double', true)
        Config.ehSet('pin_eur', 100)
        ehSetBtcOnly(false)
        Config.ehSet('color_' + ehWalletKey(), null)
        ehOptRev++
    }
    property bool _ehWantSeed: false
    function ehShowSeed() { _ehWantSeed = true; Daemon.currentWallet.requestShowSeed() }
    Connections {
        target: Daemon.currentWallet
        ignoreUnknownSignals: true
        function onSeedRetrieved() {
            if (app._ehWantSeed) { app._ehWantSeed = false; mainStackView.push(Qt.resolvedUrl('EhSeedPage.qml')) }
        }
    }
    property alias ehChangePinDialog: _ehChangePinDialog
    Component { id: _ehChangePinDialog; EhChangePinDialog { onClosed: destroy() } }
    function ehChangePin() { ehChangePinDialog.createObject(app).open() }
    property alias ehAskAmountDialog: _ehAskAmountDialog
    Component { id: _ehAskAmountDialog; EhAskAmountDialog { onClosed: destroy() } }
    function ehChangeLanguage() {
        var d = languagePicker.createObject(app)
        d.accepted.connect(function() {
            var m = app.messageDialog.createObject(app, { text: qsTr('Close and reopen Schèi to see everything in the new language.') })
            m.open()
        })
        d.open()
    }

    function quitApp() {
        // quit the app immediately
        app.visible = false
        AppController.wantClose = true
        Qt.callLater(Qt.quit)
    }

    property var _pendingBiometricAuth: null
    property var _loadingWalletContext: null

    Connections {
        target: Biometrics
        function onUnlockSuccess(password) {
            if (app._pendingBiometricAuth) {
                if (app._pendingBiometricAuth.action === 'load_wallet') {
                    app._loadingWalletContext = _pendingBiometricAuth
                    Daemon.loadWallet(app._pendingBiometricAuth.path, password)
                    app._pendingBiometricAuth = null
                    return
                }

                let qtobject = app._pendingBiometricAuth.qtobject
                let method = app._pendingBiometricAuth.method

                if (Daemon.currentWallet.verifyPassword(password)) {
                    qtobject.authProceed()
                } else {
                    console.warn("Biometric password invalid falling back to manual input")
                    // this shouldn't really happen so we better disable biometric auth
                    Biometrics.disable()
                    handleManualAuth(qtobject, method, app._pendingBiometricAuth.authMessage)
                }
                app._pendingBiometricAuth = null
            }
        }

        function onUnlockError(error) {
            console.log("Biometric auth failed: " + error)
            // we end up here if QEBiometrics fails to give us the decrypted password. The user might
            // have cancelled the biometric auth popup or the key got invalidated because a new fingerprint got registered.
            if (app._pendingBiometricAuth) {
                if (app._pendingBiometricAuth.action === 'load_wallet') {
                    // set loadingWalletContext to disable biometric auth until the OpenWalletDialog is closed
                    app._loadingWalletContext = app._pendingBiometricAuth
                    showOpenWalletDialog(app._pendingBiometricAuth.name, app._pendingBiometricAuth.path)
                } else {
                    console.log('biometric auth failed, not falling back to passwordDialog')
                    app._pendingBiometricAuth.qtobject.authCancel()  // no fallback to password dialog
                }
                app._pendingBiometricAuth = null
            }
        }

        function onAuthRequired(method, authMessage) {
            handleAuthRequired(Biometrics, method, authMessage)
        }
    }

    property var _opendialog: null
    property var _opendialog_startup: true

    // Easy Heirs: the wallet opens with the secret kept by the phone's safe,
    // without asking anything. Only old wallets (PIN+"00") still ask the PIN
    // once; right after, they are moved to the safe (see onWalletLoaded).
    property var _ehVaultTried: ({})
    property string _ehPendingPin: ''
    function showOpenWalletDialog(name, path) {
        var secret = Daemon.ehVaultReady() ? Daemon.ehVaultSecret() : ''
        if (secret !== '' && !_ehVaultTried[path]) {
            _ehVaultTried[path] = true
            Daemon.loadWallet(path, secret)
            return
        }
        if (!_opendialog) {
            _opendialog = ehPinDialog.createObject(app, {  // Easy Heirs: PIN pad
                mode: 'open',
                name: name,
                path: path,
                isStartup: _opendialog_startup,
            })
            _opendialog.closed.connect(function() {
                _opendialog = null
                app._loadingWalletContext = null  // dialog closed, we can allow trying biometric auth again
                _opendialog_startup = false
            })
            _opendialog.open()
        }
    }

    function showStartupWarnings() {
        if (!Daemon.currentWallet)
            return
        let warnings = Daemon.currentWallet.startupWarnings
        // show the warnings one after another, as the dialogs are not modal
        function showWarning(i) {
            if (i >= warnings.length)
                return
            let dialog = app.messageDialog.createObject(app, {
                title: warnings[i].title,
                iconSource: Qt.resolvedUrl('../../icons/warning.png'),
                text: warnings[i].message
            })
            dialog.accepted.connect(function() {
                Daemon.currentWallet.acknowledgeWarning(warnings[i].key)
            })
            dialog.closed.connect(function() {
                showWarning(i + 1)
            })
            dialog.open()
        }
        showWarning(0)
    }

    Connections {
        target: Daemon
        function onWalletRequiresPassword(name, path) {
            console.log('wallet requires password')
            if (Biometrics.isAvailable && Biometrics.isEnabled && !app._loadingWalletContext) {
                if (!app._pendingBiometricAuth) {
                    app._pendingBiometricAuth = {
                        action: 'load_wallet',
                        name: name,
                        path: path
                    }
                    Biometrics.unlock()
                }
            } else {
                showOpenWalletDialog(name, path)
            }
        }
        function onWalletOpenError(error) {
            console.log('wallet open error')
            var dialog = app.messageDialog.createObject(app, {
                title: qsTr('Error'),
                iconSource: Qt.resolvedUrl('../../icons/warning.png'),
                text: error
            })
            dialog.open()
        }
        function onAuthRequired(method, authMessage) {
            handleAuthRequired(Daemon, method, authMessage)
        }
        function onLoadingChanged() {
            if (!Daemon.loading)
                return
            console.log('wallet loading')
            var dialog = loadingWalletDialog.createObject(app, { allowClose: false } )
            dialog.open()
        }
        function onWalletLoaded() {
            app._loadingWalletContext = null  // either biometric auth or manual auth was successful
            // Easy Heirs: free the addresses kept busy by old empty "Receive" requests
            if (Daemon.currentWallet) Daemon.currentWallet.ehCleanRequests()
            // Easy Heirs: opened with the PIN (old wallet): move to the phone's safe
            if (app._ehPendingPin !== '') {
                var ehPin = app._ehPendingPin
                app._ehPendingPin = ''
                Daemon.ehMigrateToVault(ehPin)
            }
            app._ehVaultTried = ({})
            if (app._ehShowReady) {  // Easy Heirs: 'your wallet is ready' + few-schei notice
                app._ehShowReady = false
                app.ehReadyDialog.createObject(app).open()
            }
            showStartupWarnings()
        }
    }

    Connections {
        target: AppController
        function onUserNotify(wallet_name, message) {
            notificationPopup.show(wallet_name, message)
        }
        function onShowException(crash_data) {
            if (app._exceptionDialog)
                return
            app._exceptionDialog = crashDialog.createObject(app, {
                crashData: crash_data
            })
            app._exceptionDialog.onClosed.connect(function() {
                app._exceptionDialog = null
            })
            app._exceptionDialog.open()
        }
        function onPluginLoaded(name) {
            console.log('plugin ' + name + ' loaded')
            var loader = AppController.plugin(name).loader
            if (loader == undefined)
                return
            var url = Qt.resolvedUrl('../../../plugins/' + name + '/qml/' + loader)
            var comp = Qt.createComponent(url)
            if (comp.status == Component.Error) {
                console.log('Could not find/parse PluginLoader for plugin ' + name)
                console.log(comp.errorString())
                return
            }
            var obj = comp.createObject(app)
            if (obj != null)
                app.pluginobjects[name] = obj
        }
        function onUriReceived(uri) {
            console.log('uri received (main): ' + uri)
            app.pendingIntent = uri
        }
    }

    function pluginsComponentsByName(comp_name) {
        // return named QML components from plugins
        var plugins = AppController.plugins
        var result = []
        for (var i=0; i < plugins.length; i++) {
            if (!plugins[i].enabled)
                continue
            var pluginobject = app.pluginobjects[plugins[i].name]
            if (!pluginobject)
                continue
            if (!(comp_name in pluginobject))
                continue
            var comp = pluginobject[comp_name]
            if (!comp)
                continue

            result.push(comp)
        }
        return result
    }

    Connections {
        target: Daemon.currentWallet
        function onAuthRequired(method, authMessage) {
            handleAuthRequired(Daemon.currentWallet, method, authMessage)
        }
        // TODO: add to notification queue instead of barging through
        function onPaymentSucceeded(key) {
            notificationPopup.show(Daemon.currentWallet.name, qsTr('Payment succeeded'))
        }
        function onPaymentFailed(key, reason) {
            notificationPopup.show(Daemon.currentWallet.name, qsTr('Payment failed') + ': ' + reason)
        }
    }

    Connections {
        target: Config
        function onAuthRequired(method, authMessage) {
            handleAuthRequired(Config, method, authMessage)
        }
    }

    // PIN pad, then onOk() if the PIN is right (advanced settings...)
    function ehAskPin(prompt, onOk) {
        var d = ehPinDialog.createObject(app, { mode: 'verify', prompt: prompt })
        d.verified.connect(onOk)
        d.open()
    }

    // T18: 5 wrong PINs in a row -> no more tries for 1 hour. Counter and end of
    // the wait are in the config, so closing the app does not reset them.
    readonly property int ehPinMaxTries: 5
    readonly property int ehPinWaitMs: 60 * 60 * 1000
    function ehPinLockedUntil() {
        var u = Config.ehGet('pin_lock_until')
        return (u && Date.now() < u) ? u : 0
    }
    // '' when the PIN can be typed, otherwise the text to show on the pad
    function ehPinLockMessage() {
        var u = ehPinLockedUntil()
        if (!u) return ''
        return qsTr('Too many wrong PINs. Try again at %1.').arg(Qt.formatTime(new Date(u), 'hh:mm'))
    }
    function ehCheckPin(pin) {
        if (ehPinLockedUntil()) return false
        var ok = Daemon.ehPinIsSet() ? Daemon.ehPinCheck(pin)
                 : (Daemon.currentWallet ? Daemon.currentWallet.verifyPassword(pin + '00') : false)
        if (ok) {
            Config.ehSet('pin_fails', 0)
            Config.ehSet('pin_lock_until', 0)
        } else {
            var n = (Config.ehGet('pin_fails') || 0) + 1
            if (n >= ehPinMaxTries) {
                Config.ehSet('pin_lock_until', Date.now() + ehPinWaitMs)
                n = 0
            }
            Config.ehSet('pin_fails', n)
        }
        return ok
    }

    function handleAuthRequired(qtobject, method, authMessage) {
        console.log('auth using method ' + method)

        // Easy Heirs, like a contactless card: signing a payment asks nothing here
        // (our send page asks the PIN above the threshold); everything else
        // (12 words, delete wallet...) asks the PIN.
        if (Daemon.ehVaultReady()) {
            // inside the advanced settings the PIN was just typed: no second PIN
            if (Date.now() < app._ehPinOkUntil) {
                qtobject.authProceed()
                return
            }
            if (method === 'payment_auth' && qtobject === Daemon.currentWallet) {
                qtobject.authProceed()
            } else {
                handleManualAuth(qtobject, 'wallet', authMessage)
            }
            return
        }

        if (method === 'payment_auth') {
            if (Config.paymentAuthentication) {
                // treat like a wallet auth request
                method = 'wallet'
            } else {
                handleAuthConfirmationOnly(qtobject, authMessage)
                return
            }
        }

        if (Daemon.currentWallet.verifyPassword('')) {
            // wallet has no password
            qtobject.authProceed()
            return
        }

        if (method !== 'wallet_password_only') {
            if (Biometrics.isAvailable && Biometrics.isEnabled) {
                if (!app._pendingBiometricAuth) {
                    app._pendingBiometricAuth = {
                        qtobject: qtobject,
                        method: method,
                        authMessage: authMessage
                    }
                    Biometrics.unlock(authMessage)
                }
                return
            }
        }

        handleManualAuth(qtobject, method, authMessage)
    }

    function handleManualAuth(qtobject, method, authMessage) {
        // 'payment_auth' should have been converted to 'wallet' at this point
        if (method === 'wallet' || method === 'wallet_password_only') {
            // Easy Heirs: PIN pad instead of the password dialog
            var dialog = app.ehPinDialog.createObject(app, {mode: 'verify', prompt: authMessage ? authMessage : ''})
            dialog.verified.connect(function() {
                qtobject.authProceed()
            })
            dialog.rejected.connect(function() {
                qtobject.authCancel()
            })
            dialog.open()
        } else {
            console.log('unknown auth method ' + method)
            qtobject.authCancel()
        }
    }

    function handleAuthConfirmationOnly(qtobject, authMessage) {
        if (!authMessage) {
            qtobject.authProceed()
            return
        }
        var dialog = app.messageDialog.createObject(app, {
            title: authMessage,
            yesno: true
        })
        dialog.accepted.connect(function() {
            qtobject.authProceed()
        })
        dialog.rejected.connect(function() {
            qtobject.authCancel()
        })
        dialog.open()
    }

    function startSwap() {
        var swapdialog = swapDialog.createObject(app)
        swapdialog.open()
    }

    property var _lastActive: 0 // record time of last activity
    property bool _lockDialogShown: false

    // We want all Text/Label/etc components to use PlainText by default.
    // Qt normally defaults to AutoText, which allows rich text.
    // For our Android builds, we patch Qt at compile-time to change this.
    // (see "qt-6-10-rich-text-should-be-opt-in.patch")
    // FIXME other platforms? (e.g. running QML on desktop Linux / dev environment)
    // This runtime check here aims to prevent regressions by hard-failing.
    Label {
        id: richtext_sanity_label
        Component.onCompleted: {
            if (richtext_sanity_label.textFormat !== 0 && AppController.isAndroid()) {
                console.log(
                    "richtext_sanity_label failed check: expected PlainText, "
                    + "got " + richtext_sanity_label.textFormat + ". Exiting...")
                app.quitApp()
            }
        }
    }
}
