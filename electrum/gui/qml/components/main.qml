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

    // Schȅi testnet4: the striped band under the status bar takes its room on every page
    readonly property bool ehTest: Network.isTestNet
    readonly property int ehTestBand: ehTest ? 22 : 0
    readonly property int statusBarHeight: (AppController ? AppController.getStatusBarHeight() : 0) + ehTestBand
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
            } else if (app.ehTest) {
                // Schȅi testnet4: first start, what this app is, before the wallet is created
                ehAsk(qsTr('This is the test app'),
                      qsTr('It uses the Bitcoin test network (testnet4): the coins here are worth nothing and cannot be changed into euro. It is for learning and trying without fear.')
                      + '\n\n' + qsTr('For real money use the Schȅi Wallet app.')
                      + '\n\n' + qsTr('Free test coins: search "testnet4 faucet" on the internet.'),
                      ehFirstWizard, ehFirstWizard, qsTr("I understand, let's start"), '')
            } else {
                ehFirstWizard()
            }
        }
        // second review (W5): at first start the wizard cannot just go away (Back on Welcome):
        // without a wallet the home has nothing to show, so it comes back on the first page
        function ehFirstWizard() {
            var newww = app.newWalletWizard.createObject(app)
            var created = false
            newww.walletCreated.connect(function() {
                created = true
                app._ehShowReady = true  // Easy Heirs
                Daemon.availableWallets.reload()
                // and load the new wallet
                Daemon.loadWallet(newww.path, newww.wizard_data['password'])
            })
            newww.closed.connect(function() {
                if (!created && !AppController.wantClose && Daemon.availableWallets.rowCount() === 0)
                    Qt.callLater(ehFirstWizard)
            })
            newww.open()
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

    // Schȅi testnet4: striped blue band, always visible on top of every page
    Rectangle {
        parent: Overlay.overlay
        visible: app.ehTest
        z: 10000
        x: 0
        y: app.statusBarHeight - app.ehTestBand
        width: parent ? parent.width : 0
        height: app.ehTestBand
        color: '#1f6f8b'
        clip: true
        Row {
            x: -20
            Repeater {
                model: 40
                Rectangle { width: 14; height: 60; y: -16; rotation: 45; color: index % 2 ? '#1f6f8b' : '#2a86a6' }
            }
        }
        Label {
            anchors.centerIn: parent
            text: qsTr('TEST NETWORK (testnet4) · coins without value')
            color: '#ffffff'
            font.pixelSize: 12
            font.bold: true
        }
    }

    property var _ehAsks: []          // the open yes / no questions (EhAskDialog)
    onClosing: (close) => {
        if (AppController.wantClose) {
            // destroy most GUI components so that we don't dump so many null reference warnings on exit
            app.header.visible = false
            mainStackView.clear()
            return
        }
        // a yes / no question is open (EhAskDialog): Back = "No", nothing else
        if (_ehAsks.length > 0) {
            _ehAsks[_ehAsks.length - 1].answer(false)
            close.accepted = false
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
                text: qsTr('Close Schȅi Wallet?')
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
    // T48 (owner 12/11): the reference currency (Electrum's fiat currency), its symbol and name
    function ehCcy() { ehFxRev; return Daemon.fx.fiatCurrency || 'EUR' }
    readonly property var ehCcySymbols: ({ EUR: '€', USD: '$', GBP: '£', JPY: '¥', CNY: '¥', INR: '₹', KRW: '₩',
        TRY: '₺', RUB: '₽', UAH: '₴', ILS: '₪', NGN: '₦', PHP: '₱', VND: '₫', BRL: 'R$', AUD: 'A$', CAD: 'C$',
        NZD: 'NZ$', MXN: 'MX$', HKD: 'HK$', SGD: 'S$', CHF: 'CHF', PLN: 'zł', ZAR: 'R' })
    function ehSym() { var c = ehCcy(); return ehCcySymbols[c] || c }
    // name of the currency in the sentences ("amounts in euro / dollars / pounds"): by language
    function ehCcyName() {
        var c = ehCcy()
        var it = { EUR: 'euro', USD: 'dollari', GBP: 'sterline', CHF: 'franchi', JPY: 'yen', CAD: 'dollari canadesi', AUD: 'dollari australiani' }
        var vec = { EUR: 'euro', USD: 'dolari', GBP: 'sterline', CHF: 'franchi', JPY: 'yen', CAD: 'dolari canadesi', AUD: 'dolari australiani' }
        var en = { EUR: 'euro', USD: 'dollars', GBP: 'pounds', CHF: 'francs', JPY: 'yen', CAD: 'Canadian dollars', AUD: 'Australian dollars' }
        var m = Config.language === 'en_UK' ? en : (Config.language === 'vec_IT' ? vec : it)
        return m[c] || c
    }
    function ehHasCash() { return ['EUR', 'USD'].indexOf(ehCcy()) >= 0 }
    // about how many units of the currency make one euro, rounded to 1 / 10 / 100 / 1000:
    // scales the PIN threshold, its chips and the length of the amounts that can be typed
    readonly property var ehCcyScale: ({ CNY: 10, HKD: 10, SEK: 10, NOK: 10, DKK: 10, ZAR: 10, MXN: 10, CZK: 10,
        TRY: 10, THB: 10, TWD: 10, MAD: 10, UAH: 10, BRL: 10, MYR: 10,
        INR: 100, RUB: 100, PHP: 100, PKR: 100, HUF: 100, KES: 100, RSD: 100, EGP: 100,
        NGN: 1000, ARS: 1000, COP: 1000, IDR: 10000 })
    function ehCcyMult(c) { return ehCcyScale[c || ehCcy()] || 1 }
    function ehSetCurrency(code) {
        var oldM = ehCcyMult(ehCcy()), newM = ehCcyMult(code)
        Daemon.fx.ehSetCurrency(code)
        if (oldM !== newM) Config.ehSet('pin_eur', Math.round(ehDoubleEurSaved() / oldM * newM))
        ehOptRev++
    }
    function ehCcyTitle() { var n = ehCcyName(); return n.charAt(0).toUpperCase() + n.slice(1) }
    function ehEuroNumber(plain) {
        var n = Number(plain)
        if (plain === '' || isNaN(n)) return ''
        var neg = n < 0
        var parts = Math.abs(n).toFixed(2).split('.')
        var dec = Config.language === 'en_UK' ? '.' : ','
        return (neg ? '-' : '') + ehSym() + ' ' + ehGroup(parts[0]) + dec + parts[1]
    }
    function ehEuro(amount) {
        ehFxRev   // redrawn when the rates or the currency change
        if (!Daemon.fx.enabled) return ''
        return ehEuroNumber(Daemon.fx.fiatValue(amount, true))
    }
    function ehBtc(amount) {
        var s = Config.formatSats(amount).trim()
        if (s.indexOf('.') >= 0) s = s.replace(/0+$/, '').replace(/\.$/, '')
        if (Config.language !== 'en_UK') s = s.replace(/,/g, ' ').replace('.', ',')
        return s + ' ' + ehBtcUnit()
    }
    function ehBtcUnit() { return app.ehTest ? 'tBTC' : 'BTC' }
    // third review (2.1): the euro of the movements are drawn again when the rates arrive
    property int ehFxRev: 0
    Connections {
        target: Daemon.fx
        function onQuotesUpdated() { app.ehFxRev++ }
        function onFiatCurrencyChanged() { app.ehFxRev++ }
        function onHistoryUpdated() { app.ehFxRev++ }
    }
    // T39: when a movement happened, in words: "oggi 16:55", "ieri 14:51", "9 nov", "9 nov 2025"
    // review: "today / yesterday" follow the clock: refreshed every minute and when the app comes back
    property string ehToday: new Date().toDateString()
    Timer { interval: 60000; repeat: true; running: true; onTriggered: app.ehToday = new Date().toDateString() }
    Connections {
        target: Qt.application
        function onStateChanged() { if (Qt.application.state === Qt.ApplicationActive) app.ehToday = new Date().toDateString() }
    }
    function ehWhen(timestamp, withTime) {
        ehToday
        if (!timestamp) return ''
        var d = new Date(timestamp * 1000)
        var now = new Date()
        var day = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
        var t = d.getTime()
        var hm = Qt.formatTime(d, 'hh:mm')
        if (t >= day) return qsTr('today %1').arg(hm)
        if (t >= day - 86400000) return qsTr('yesterday %1').arg(hm)
        var s = d.toLocaleDateString(ehLocale(), 'd MMM')
        if (d.getFullYear() !== now.getFullYear()) s += ' ' + d.getFullYear()
        if (withTime) s += ', ' + hm
        return s
    }
    // amount of a history item: historic euro value if known, else today's, else BTC
    function ehTxAmount(amount, timestamp, signed) {
        app.ehFxRev   // re-evaluated when the rates arrive
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
    // pages (coins, crucible…) opened above a dialog go into an EhPageDialog: push / pop go there
    property var _ehStackOverride: null
    property var _ehStackDialog: null
    function ehPush(url, props) {
        var s = _ehStackOverride ? _ehStackOverride : stack
        return props ? s.push(url, props) : s.push(url)
    }
    function ehPop() {
        if (_ehStackOverride) {
            if (_ehStackOverride.depth > 1) _ehStackOverride.pop()
            else if (_ehStackDialog) _ehStackDialog.doClose()
            return
        }
        stack.pop()
    }
    Component { id: _ehPageDialog; EhPageDialog { onClosed: destroy() } }
    function ehOpenPage(url, props) {
        if (activeDialogs.length > 0) _ehPageDialog.createObject(app, { page: url, props: props || {} }).open()
        else ehPush(url, props)
    }
    // the coins list: with "advanced privacy" the pockets, else the list of coins and addresses
    // owner 13/11: the word crucible (crogiuolo / crogiolo) in a text becomes a link to its page
    function ehCrucibleLink(s) {
        return s.replace(/(crogiuolo|crogiolo|crucible)/, '<a href="how"><b>$1</b></a>')
    }
    function ehOpenCoins() {
        ehOpenPage(Qt.resolvedUrl(ehOption('privacy') ? 'EhPocketsPage.qml' : 'EhCoinsPage.qml'))
    }
    property alias ehInfoDialog: _ehInfoDialog
    Component { id: _ehInfoDialog; EhInfoDialog { onClosed: destroy() } }
    function ehShowConfirmationsInfo() {
        ehInfoDialog.createObject(app, {
            pageTitle: qsTr('What are confirmations?'),
            showBlocks: true,
            bodyText: qsTr('About every <b>10 minutes</b> the Bitcoin network writes a new "block" with the payments. When your payment enters a block it has <b>1 confirmation</b>; every block after that adds another one.')
                + '<br><br>' + qsTr('The more confirmations, the more impossible it is to go back. People moving <b>millions of euro</b> wait for 6 confirmations, about one hour.'),
            tipText: qsTr('<b>Schȅi is a pocket wallet</b>, made for everyday amounts. For these amounts <b>1 confirmation is more than enough</b>: that is why we already show it as "✓ Confirmed".'),
            // owner 13/11: the general explanation of the coins, at the bottom
            linkText: qsTr('How do bitcoin coins work?'),
            linkUrl: Qt.resolvedUrl('EhCoinsHowPage.qml')
        }).open()
    }
    function ehShowFeeInfo() {
        ehInfoDialog.createObject(app, {
            pageTitle: qsTr('What is the sending cost?'),
            bodyText: qsTr('Bitcoin payments are written on the <b>blockchain</b>, the big public register, by computers called <b>"miners"</b>.')
                + '<br><br>' + qsTr('To do it they ask for a small <b>tip</b>: whoever offers more goes first, like in a queue.')
                + '<br><br>' + qsTr('The cost <b>does not depend on how much you send</b>: sending 10 € or 1,000 € costs the same. It only changes a little with the network traffic.'),
            tipText: qsTr('<b>Schȅi chooses a "normal" tip by itself</b>: the payment usually arrives in about an hour. If you are in a hurry, move the slider to the right. The whole tip goes to the miners: Schȅi takes nothing.')
        }).open()
    }

    // Easy Heirs: options (expert mode etc.), stored with Config.ehSet
    property int ehOptRev: 0
    // options never touched take their default: off, except "Banconote e monete" (owner 2026-11-11)
    readonly property var ehOptDefaultOn: ['coins']
    function ehOption(key) {
        ehOptRev
        var v = Config.ehGet('opt_' + key)
        if (v === null || v === undefined) return ehOptDefaultOn.indexOf(key) >= 0
        return v === true
    }
    function ehSetOption(key, value) { Config.ehSet('opt_' + key, value); ehOptRev++ }
    // T50 (owner 12/11): levels BASE / MEDIO / ESPERTO. A level shows its rows and, when it is
    // chosen, turns on its preset; then every switch can still be changed by hand. Leaving
    // MEDIO or ESPERTO its switches are remembered and given back when coming back to it;
    // BASE is always the same (a relative can say "tap BASE" on the phone).
    readonly property var ehLevels: ['base', 'medio', 'esperto']
    readonly property var ehLevelKeys: ['euro_btc', 'request_amount', 'multi', 'watch', 'utxo', 'privacy',
                                        'max', 'manual_fee', 'buttons', 'no_anim', 'btc_only']
    readonly property var ehLevelPresetOn: ({
        'base': [],
        'medio': ['euro_btc', 'request_amount', 'multi', 'watch', 'utxo'],
        'esperto': ['euro_btc', 'request_amount', 'multi', 'watch', 'utxo', 'privacy', 'max', 'manual_fee'] })
    function ehLevel() {
        ehOptRev
        var v = Config.ehGet('eh_level')
        if (ehLevels.indexOf(v) >= 0) return v
        // first start with the levels: the level that matches the switches already on (none is changed)
        var on = function(k) { return Config.ehGet('opt_' + k) === true }
        if (on('manual_fee') || on('privacy')) v = 'esperto'
        else if (on('show_adv') || on('utxo') || on('multi') || on('watch') || on('euro_btc') || on('request_amount')
                 || on('max') || on('btc_only') || on('buttons') || on('no_anim')) v = 'medio'
        else v = 'base'
        Config.ehSet('eh_level', v)
        return v
    }
    function ehLevelNum() { return ehLevels.indexOf(ehLevel()) }
    function ehLevelValue(k) { return k === 'btc_only' ? ehBtcOnly() : ehOption(k) }
    function ehLevelValues() {
        var o = {}
        for (var i = 0; i < ehLevelKeys.length; i++) {
            var k = ehLevelKeys[i]
            o[k] = k === 'btc_only' ? ehBtcOnly() : ehOption(k)
        }
        return o
    }
    // the level choice in Settings: what changes, then (ESPERTO) the PIN, then the checks going
    // down. Here on the main window, so a window still open after the page is closed works.
    function ehLevelName(to) { return to === 'base' ? qsTr('BASE') : (to === 'medio' ? qsTr('MEDIUM') : qsTr('EXPERT')) }
    function ehLevelLines(to) {
        if (ehLevelRemembered(to))
            return qsTr('You find the switches of this level as you left them.')
        if (to === 'base')
            return '• ' + qsTr('The standard settings come back: the extra options turn off, the PIN for big payments is on.')
                 + '\n• ' + qsTr('The rows for more choices are hidden.')
                 + '\n• ' + qsTr('Your money, the 12 words and the PIN do not change.')
        if (to === 'medio')
            return '• ' + qsTr('You write the amounts in %1 or in bitcoin').arg(ehCcyName())
                 + '\n• ' + qsTr('In Receive you can ask a precise amount')
                 + '\n• ' + qsTr('More wallets, view-only wallets and gold coins turn on')
                 + '\n• ' + qsTr('Other choices appear, off: privacy, send all, node and Tor')
        return '• ' + qsTr('Everything of MEDIUM, and also:')
             + '\n• ' + qsTr('Tip written by hand, advanced privacy and "Send all the balance" turn on')
             + '\n• ' + qsTr('The rows for experts appear: PIN threshold, more addresses')
    }
    function ehAsk(text, detail, onYes, onNo, yesText, noText) {
        var props = { text: text, detail: detail }
        if (yesText) props.yesText = yesText
        if (noText !== undefined && noText !== null) props.noText = noText   // '' = one button only
        var d = Qt.createComponent(Qt.resolvedUrl('EhAskDialog.qml')).createObject(app, props)
        if (onYes) d.accepted.connect(onYes)
        if (onNo) d.rejected.connect(onNo)
        d.open()
    }
    function ehChooseLevel(to) {
        if (to === ehLevel()) return
        ehAsk(qsTr('Switch to %1?').arg(ehLevelName(to)),
              ehLevelLines(to) + '\n\n' + qsTr('You can change level whenever you want.'),
              function() {
                  if (to === 'esperto')
                      ehAskPin(qsTr('Type the PIN to switch to EXPERT.') + '\n' + qsTr('Nobody should ask you to do this by phone.'),
                               function() { ehApplyLevel(to) })
                  else ehApplyLevel(to)
              }, null, qsTr('OK (go ahead)'), qsTr('Cancel'))
    }
    function ehApplyLevel(to) {
        var wasNode = Network.oneServer && !Network.autoConnect
        var wasTor = Network.proxy && Network.proxy.enabled === true
        ehSetLevel(to)
        ehLevelDownChecks(to, wasNode, wasTor)
    }
    // "Back to the initial settings": level BASE, then the same checks as going down
    function ehResetAndCheck() {
        var wasNode = Network.oneServer && !Network.autoConnect
        var wasTor = Network.proxy && Network.proxy.enabled === true
        ehResetSettings()
        ehLevelDownChecks('base', wasNode, wasTor)
    }
    function ehLevelDownChecks(to, wasNode, wasTor) {
        // going down nothing stays on out of sight: blocked coins, own node, Tor
        var w = Daemon.currentWallet
        var blocked = (!ehOption('utxo') && w) ? w.ehFrozenCount() : 0
        var askNode = function() {
            if (to !== 'base' || !(wasNode || wasTor)) return
            ehAsk(qsTr('Back to the automatic connection?'),
                  qsTr('You were using your own node or Tor. In BASE their row is hidden: with "Yes" Schȅi connects by itself to the public servers, as at the start.'),
                  function() {
                      if (wasTor) Network.proxy = { 'enabled': false, 'mode': 'socks5', 'host': '', 'port': '', 'user': '', 'password': '' }
                      if (wasNode) Network.setServerParameters('', true, false)
                  })
        }
        if (blocked > 0)
            ehAsk(qsTr('Unblock the coins?'),
                  qsTr('You have %1 blocked coins: the app does not use them to pay. Without gold coins you do not see them any more. Unblock them all?').arg(blocked),
                  function() { w.ehUnfreezeAll(); askNode() }, askNode)
        else askNode()
    }
    // true when going back to a level left before: its switches come back as they were
    function ehLevelRemembered(to) { return to !== 'base' && !!Config.ehGet('lvl_snap_' + to) }
    function ehSetLevel(to) {
        var from = ehLevel()
        if (to === from || ehLevels.indexOf(to) < 0) return
        if (from !== 'base') Config.ehSet('lvl_snap_' + from, JSON.stringify(ehLevelValues()))
        var vals = null
        if (to !== 'base') { try { vals = JSON.parse(Config.ehGet('lvl_snap_' + to) || 'null') } catch (e) { vals = null } }
        if (!vals) {
            var up = ehLevels.indexOf(to) > ehLevels.indexOf(from)
            vals = {}
            for (var i = 0; i < ehLevelKeys.length; i++) {
                var key = ehLevelKeys[i]
                var inPreset = ehLevelPresetOn[to].indexOf(key) >= 0
                if (to === 'base') vals[key] = false                          // BASE: always the same
                else if (up) vals[key] = inPreset || ehLevelValue(key)        // up: keep the user's choices, turn on the preset
                else vals[key] = key === 'manual_fee' ? false : ehLevelValue(key)  // down to MEDIO: only the expert one goes off
            }
        }
        for (var j = 0; j < ehLevelKeys.length; j++) {
            var k = ehLevelKeys[j]
            if (k !== 'btc_only') Config.ehSet('opt_' + k, vals[k] === true)
        }
        if (ehBtcOnly() !== (vals['btc_only'] === true)) ehSetBtcOnly(vals['btc_only'] === true)
        // with 2 or more wallets "More wallets" stays on, or the others disappear
        if (Daemon.availableWallets.rowCount() > 1) Config.ehSet('opt_multi', true)
        // out of ESPERTO the PIN for big payments cannot be seen: it is on again
        if (to !== 'esperto') Config.ehSet('opt_double', true)
        Config.ehSet('opt_show_adv', to !== 'base')
        Config.ehSet('eh_level', to)
        ehOptRev++
    }
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
    // T50: outside ESPERTO its row cannot be seen, so the PIN for big payments is always on
    // at the standard threshold (also for users who turned it off before the levels)
    function ehDoubleOn() {
        ehOptRev
        if (ehLevel() !== 'esperto') return true
        var v = Config.ehGet('opt_double'); return (v === null || v === undefined) ? true : v === true
    }
    // big payment threshold (PIN above it, like a contactless card)
    function ehDoubleEurSaved() { ehOptRev; var v = Config.ehGet('pin_eur'); return v ? v : 100 * ehCcyMult() }
    function ehDoubleEur() { return ehLevel() === 'esperto' ? ehDoubleEurSaved() : 100 * ehCcyMult() }
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
            { icon: 'eye', word: qsTr('Check'), title: qsTr('Check carefully'), text: qsTr('Look again at amount, cost and address before sending. Then push the two bitcoin coins to the right.') },
            { icon: 'send', word: qsTr('Sent'), title: qsTr('Sent'), text: qsTr('The money has left. It arrives after the first confirmation.') }
        ]
    }
    // going back to step 1 ("Who to") from the amount / check pages: the address
    // and the amount typed are kept, so nothing has to be typed again
    property var _ehDraft: null
    property real _ehPinOkUntil: 0
    // review 2026-11-11: set by EhInvoiceDialog right before signAndSend(); any other payment asks the PIN
    property bool _ehSendOk: false
    function ehBackToStep1(draft) {
        app._ehDraft = draft
        var mv = app.stack.currentItem
        if (!mv || mv.openSendDialog === undefined) return
        mv.openSendDialog()
        if (mv._sendDialog) mv._sendDialog.pasted = draft.address
    }
    function ehBigLimitText() { return ehBtcOnly() || !Daemon.fx.enabled ? qsTr('20% of the balance') : ehSym() + ' ' + ehGroup('' + ehDoubleEur()) }
    function ehNeedsDouble(amount) {
        if (!amount) return false
        if (amount.isMax) return true      // T50: "Send all the balance" always asks the PIN
        if (!ehDoubleOn()) return false
        if (ehBtcOnly() || !Daemon.fx.enabled) {
            // only bitcoin: double confirmation from 20% of what is in the wallet
            var w = Daemon.currentWallet
            var total = w ? Math.max(0, w.ehTotal.satsInt - w.frozenBalance.satsInt) : 0
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

    // Schȅi testnet4: test coins have no price, always in bitcoin
    function ehBtcOnly() { ehOptRev; return app.ehTest || Config.ehGet('opt_btc_only') === true }
    function ehSetBtcOnly(on) {
        ehSetOption('btc_only', on)
        Daemon.fx.enabled = !on
        if (!on) {
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
    // the last balance seen of each wallet (only wallets open one at a time): shown on the
    // cards of the other wallets in the carousel
    // review: written only when it changed (the config file is saved whole at each write)
    property var _ehBalSeen: ({})
    property int ehBalRev: 0
    function ehRememberBalance() {
        if (!Daemon.currentWallet) return
        var k = ehWalletKey(), v = Daemon.currentWallet.ehTotal.satsInt
        if (_ehBalSeen[k] === v) return
        _ehBalSeen[k] = v
        if (Config.ehGet('bal_' + k) !== v) Config.ehSet('bal_' + k, v)
        ehBalRev++
    }
    function ehRememberWatch() {
        if (!Daemon.currentWallet) return
        var k = ehWalletKey(), w = Daemon.currentWallet.isWatchOnly === true
        if (Config.ehGet('watch_' + k) !== w) { Config.ehSet('watch_' + k, w); ehBalRev++ }
    }
    function ehWalletIsWatchFor(n) { ehBalRev; return Config.ehGet('watch_' + n) === true }
    function ehLastBalanceFor(n) {
        ehOptRev; ehBalRev; ehFxRev
        var s = Config.ehGet('bal_' + n)
        if (s === undefined || s === null || s === '') return ''
        return ehMoney(Config.unitsToSats((Number(s) / 100000000).toFixed(8)))
    }
    Connections {
        target: Daemon.currentWallet
        function onBalanceChanged() { app.ehRememberBalance() }
    }
    function ehWalletName() { return ehWalletNameFor(ehWalletKey()) }
    function ehWalletColor() { return ehWalletColorFor(ehWalletKey()) }
    function ehWalletNameFor(n) {
        ehOptRev
        var v = Config.ehGet('name_' + n)
        if (v) return v
        return n === 'Portafoglio' ? qsTr('My wallet') : n.replace(/_/g, ' ')
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
        var keys = ['euro_btc', 'max', 'request_amount', 'multi', 'watch', 'sign_elsewhere', 'buttons', 'coins', 'no_anim', 'privacy', 'utxo', 'show_adv', 'manual_fee']
        for (var i = 0; i < keys.length; i++) Config.ehSet('opt_' + keys[i], ehOptDefaultOn.indexOf(keys[i]) >= 0)
        ehSetCurrency('EUR')
        // second review (S3): with 2 or more wallets "More wallets" stays on, or the others disappear
        if (Daemon.availableWallets.rowCount() > 1) Config.ehSet('opt_multi', true)
        Config.ehSet('opt_double', true)
        Config.ehSet('pin_eur', 100)
        // T50: back to BASE, nothing remembered for MEDIO / ESPERTO
        Config.ehSet('eh_level', 'base')
        Config.ehSet('lvl_snap_medio', null)
        Config.ehSet('lvl_snap_esperto', null)
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
    property alias ehForgotPinDialog: _ehForgotPinDialog
    Component { id: _ehForgotPinDialog; EhForgotPinDialog { onClosed: destroy() } }
    function ehOpenForgotPin() { ehForgotPinDialog.createObject(app).open() }
    property alias ehChangePinDialog: _ehChangePinDialog
    Component { id: _ehChangePinDialog; EhChangePinDialog { onClosed: destroy() } }
    function ehChangePin() { ehChangePinDialog.createObject(app).open() }
    property alias ehAskAmountDialog: _ehAskAmountDialog
    Component { id: _ehAskAmountDialog; EhAskAmountDialog { onClosed: destroy() } }
    function ehChangeLanguage() {
        var d = languagePicker.createObject(app)
        d.accepted.connect(function() {
            var m = app.messageDialog.createObject(app, { text: qsTr('Close and reopen Schȅi to see everything in the new language.') })
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
    // second review (W2): the safe of this phone cannot open the wallet any more: no endless
    // "Wrong PIN", but a page that says so and leads to the 12 words
    property var _ehKeyLost: null
    signal ehWalletPickCancelled()

    // third review: Advanced settings and the 12 words do not stay open for hours. When the
    // app comes back after more than a minute away, the protected pages close (back home).
    property real _ehAwaySince: 0
    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state !== Qt.ApplicationActive) {
                if (app._ehAwaySince === 0) app._ehAwaySince = Date.now()
                return
            }
            var away = app._ehAwaySince > 0 ? Date.now() - app._ehAwaySince : 0
            app._ehAwaySince = 0
            if (away < 60 * 1000) return
            var prot = false
            for (var i = 0; i < mainStackView.depth; i++) {
                var it = mainStackView.get(i, StackView.DontLoad)
                if (it && it.ehProtected === true) { prot = true; break }
            }
            if (prot) {
                app._ehPinOkUntil = 0
                var dl = app.activeDialogs.slice()
                for (var k = dl.length - 1; k >= 0; k--)
                    if (dl[k] && dl[k].allowClose) dl[k].doClose()
                mainStackView.pop(null)
            }
        }
    }
    function ehShowKeyLost(name, path) {
        if (_ehKeyLost) return
        if (_opendialog) { var od = _opendialog; _opendialog = null; od.close() }
        // only when the safe really lost its key do unopenable wallet files go aside after the
        // restore (not when the key-lost page came from 3 PINs on an old wallet with another PIN)
        var vaultWasBroken = Daemon.ehVaultBroken()
        var kl = ehKeyLostDialog.createObject(app, { name: name, path: path })
        _ehKeyLost = kl
        kl.restoreChosen.connect(function() {
            _ehKeyLost = null
            var w = app.newWalletWizard.createObject(app)
            var created = false
            w.walletCreated.connect(function() {
                created = true
                // third review: the old files this phone cannot open any more go aside
                if (vaultWasBroken) Daemon.ehMoveAsideUnopenable()
                Daemon.availableWallets.reload()
                Daemon.loadWallet(w.path, w.wizard_data['password'])
            })
            w.closed.connect(function() { if (!created && !Daemon.currentWallet) Qt.callLater(function() { ehShowKeyLost(name, path) }) })
            w.open()
        })
        kl.retryChosen.connect(function() {
            _ehKeyLost = null
            _ehVaultTried[path] = false
            Qt.callLater(function() { showOpenWalletDialog(name, path) })
        })
        kl.closed.connect(function() { if (_ehKeyLost === kl) _ehKeyLost = null })
        kl.open()
    }
    Component { id: ehKeyLostDialog; EhKeyLostDialog { onClosed: destroy() } }

    function showOpenWalletDialog(name, path) {
        if (Daemon.ehVaultBroken()) {
            ehShowKeyLost(name, path)
            return
        }
        // third review: try the safe's secret whenever there is one (also if the PIN check is
        // missing, e.g. the app died while old wallets were moved to the safe)
        var secret = Daemon.ehVaultSecret()
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
                if (Daemon.currentWallet) app.ehWalletPickCancelled()   // third review: carousel back
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
            Qt.callLater(app.ehRememberBalance)
            Qt.callLater(app.ehRememberWatch)
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
    // review 2026-11-11: the hour is measured with the clock that runs since the phone was
    // switched on (Config.ehMonoMs), not with the date / time of the settings, which anyone
    // can move forward. If the phone was restarted, the hour starts again from zero.
    function ehPinLockLeftMs() {
        var s = Config.ehGet('pin_lock_mono')
        if (!s) return 0
        var now = Config.ehMonoMs()
        if (now < s) { Config.ehSet('pin_lock_mono', now); s = now }
        var left = ehPinWaitMs - (now - s)
        if (left <= 0) { Config.ehSet('pin_lock_mono', 0); return 0 }
        return left
    }
    function ehPinLockedUntil() {
        var left = ehPinLockLeftMs()
        return left > 0 ? Date.now() + left : 0
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
            Config.ehSet('pin_lock_mono', 0)
        } else {
            var n = (Config.ehGet('pin_fails') || 0) + 1
            if (n >= ehPinMaxTries) {
                Config.ehSet('pin_lock_mono', Math.max(1, Config.ehMonoMs()))
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
            if (method === 'payment_auth' && qtobject === Daemon.currentWallet && app._ehSendOk) {
                app._ehSendOk = false
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
