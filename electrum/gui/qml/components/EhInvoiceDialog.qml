// Easy Heirs (schèi): INVIA steps 2 and 3 and the "Inviati!" screen.
//  amount : how much, in euro, big keys (skipped if the QR already has it)
//  review : what you send, sending cost, total, address with the last 4
//           letters highlighted, "cannot be undone" warning, slide to send
//  sent   : "Inviati!" with the confirmation note
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"

ElDialog {
    id: dialog
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'

    property var invoice            // InvoiceParser from WalletMainView
    property string phase: 'amount'
    property string euroInput: ''   // digits typed, e.g. "25,5"
    property var chosen: null       // QEAmount to send
    property string sentEuro: ''
    property string sentBtc: ''
    property bool btcMode: app.ehBtcOnly()     // typing in bitcoin (expert toggle, or 'only bitcoin')
    property bool useMax: false      // expert: all the balance
    property alias pad: coinPad
    // expert: banknotes and coins instead of the keypad (euro only)
    property bool coinsMode: app.ehOption('coins') && !app.ehBtcOnly()
    readonly property bool useCoins: coinsMode && !btcMode
    onBtcModeChanged: if (!btcMode && coinsMode) coinPad.clear()
    // big amounts need two coins pushed up (expert option, on by default at 500 euro)
    // big payment: one coin as always, then the PIN (like a contactless card).
    // The old double-coin screen is kept in the file but never shown.
    readonly property var reviewAmount: finalizer.valid ? finalizer.effectiveAmount : (chosen ? chosen : finalizer.amount)
    readonly property bool needsPin: phase === 'review' && app.ehNeedsDouble(reviewAmount)
    readonly property bool needsDouble: false

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    background: Rectangle {
        color: '#faf7ef'
        // luce colorata: rose = sending, green once sent
        EhGlow { tone: dialog.phase === 'sent' ? 'green' : 'rose'; z: 0; x: -parent.width * 0.25; y: 30; width: parent.width * 1.5; height: 340 }
    }

    // ---------- helpers ----------
    // blocked gold coins cannot be spent: "you have" is what can be spent
    function balanceSats() { return Math.max(0, Daemon.currentWallet.ehTotal.satsInt - Daemon.currentWallet.frozenBalance.satsInt) }
    // third review (#7): the euro price can arrive after the page opened: count it again then
    property int fxRev: 0
    Connections { target: Daemon.fx; function onQuotesUpdated() { dialog.fxRev++ } }
    readonly property bool noRate: { dialog.fxRev; return !btcMode && Daemon.fx.satoshiValue('1', true) === '' }
    function euroPlain() { return (euroInput === '' ? '0' : euroInput).replace(',', '.') }
    function inputSats() {
        if (btcMode) {
            var b = Number(euroPlain())
            return isNaN(b) ? 0 : Math.round(b * 100000000)
        }
        dialog.fxRev
        var s = Daemon.fx.satoshiValue(euroPlain(), true)
        var n = parseInt(s)
        return isNaN(n) ? 0 : n
    }
    function satsToAmount(sats) { return Config.unitsToSats((sats / 100000000).toFixed(8)) }
    function euroDisplay() {
        var sym = btcMode ? '' : '€ '
        if (euroInput === '') return btcMode ? '0 BTC' : sym + '0'
        if (btcMode) return euroInput.replace(',', app.ehLocale().decimalPoint) + ' BTC'
        var parts = euroInput.split(',')
        var intPart = Number(parts[0] || '0').toLocaleString(app.ehLocale(), 'f', 0)
        return '€ ' + intPart + (parts.length > 1 ? app.ehLocale().decimalPoint + parts[1] : '')
    }
    function press(k) {
        if (k === 'del') { euroInput = euroInput.slice(0, -1); return }
        if (k === ',') {
            if (euroInput.indexOf(',') >= 0) return
            euroInput = (euroInput === '' ? '0' : euroInput) + ','
            return
        }
        var dec = euroInput.indexOf(',')
        if (dec >= 0 && euroInput.length - dec > (btcMode ? 8 : 2)) return
        if (euroInput === '0') euroInput = ''
        if (euroInput.replace(',', '').length >= (btcMode ? 10 : 7)) return
        euroInput += k
    }
    function goReview(amount) {
        chosen = amount
        invoice.amountOverride = amount
        finalizer.address = invoice.address
        finalizer.amount = amount
        finalizer.doUpdate()
        phase = 'review'
    }
    function groupedAddress() {
        var a = invoice ? invoice.address : ''
        var n = Math.ceil(a.length / 4), half = Math.ceil(n / 2), out = ''
        for (var i = 0; i < a.length; i++) {
            if (i === a.length - 4) out += '<span style="background-color:#f7e3e8"><font color="#3f0f21"><u>'
            out += a[i]
            if (i === a.length - 1) out += '</u></font></span>'
            var left = a.length - 1 - i
            if (left > 0 && left % 4 === 0)
                out += (left === 4 * Math.floor(n / 2)) ? '<br>' : ' '
        }
        return out
    }
    property bool busy: false
    // the Android back key does not close the page while the payment is leaving
    allowClose: !busy
    function setBusy(b) { busy = b }
    // steps bar: back to a step already done, keeping what was typed
    function goToStep(n) {
        if (n === 2 && dialog.phase === 'review' && dialog.invoice.amount.isEmpty) {
            dialog.useMax = false
            dialog.phase = 'amount'
        } else if (n === 1) {
            var draft = { address: dialog.invoice.address, euroInput: dialog.euroInput, btcMode: dialog.btcMode }
            dialog.doClose()
            Qt.callLater(function() { app.ehBackToStep1(draft) })
        }
    }
    function resetBars() { setBusy(false); stopCountdown(); sl1.reset(); sl2.reset() }
    // T24: both slides at the end (together, or one after the other while the first waits)
    function checkSlides() {
        if (!(sl1.locked && sl2.locked)) return
        sl1.hold = true; sl2.hold = true
        dialog.confirmSend()
    }
    // T25: 5 4 3 2 1 0, then the payment really leaves; "Annulla" stops everything
    property int countdown: -1          // -1 = not running
    function startCountdown() { dialog.countdown = 5; AppController.haptic(); cdTimer.restart() }
    function stopCountdown() { cdTimer.stop(); dialog.countdown = -1 }
    function cancelCountdown() { stopCountdown(); dialog.resetBars() }
    Timer {
        id: cdTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (dialog.countdown > 0) { dialog.countdown--; AppController.haptic(); return }
            cdTimer.stop()
            dialog.countdown = -1
            dialog.doSend()
        }
    }
    // T20 step 4: the coins of this payment come from different places?
    property bool mixOk: false          // "Va bene lo stesso" for this payment
    readonly property alias ehFinalizer: finalizer   // for the PC tests
    readonly property var mixCoins: {
        if (!app.ehPrivWarn('warn_mix') || !finalizer || !finalizer.valid || !Daemon.currentWallet) return []
        var ins = finalizer.inputs, out = [], ids = {}, n = 0
        for (var i = 0; i < ins.length; i++) {
            if (!ins[i].outpoint) continue
            var cat = app.ehCat(Daemon.currentWallet.ehCoinOrigin(ins[i].outpoint))
            if (ids[cat.id] === undefined) { ids[cat.id] = true; n++ }
            out.push({ 'sats': ins[i].value.satsInt, 'cat': cat })
        }
        return n > 1 ? out : []
    }
    function chooseCoins() {
        var need = (finalizer.valid ? finalizer.effectiveAmount.satsInt + finalizer.fee.satsInt
                                    : (dialog.reviewAmount ? dialog.reviewAmount.satsInt : 0))
        var d = Qt.createComponent(Qt.resolvedUrl('EhCoinPickerDialog.qml')).createObject(app, { finalizer: finalizer, needSats: need })
        d.closed.connect(function() { d.destroy() })
        d.open()
    }
    function chooseFee() {
        var d = Qt.createComponent(Qt.resolvedUrl('EhFeeDialog.qml')).createObject(app, { finalizer: finalizer })
        d.closed.connect(function() { d.destroy() })
        d.open()
    }
    function confirmSend() {
        if (!dialog.needsPin) { startCountdown(); return }
        var d = app.ehPinDialog.createObject(app, {
            mode: 'verify',
            prompt: qsTr('Type the PIN to send %1').arg(app.ehMoney(dialog.reviewAmount))
        })
        d.verified.connect(function() { dialog.startCountdown() })
        d.rejected.connect(function() { dialog.resetBars() })
        d.open()
    }
    function doSend() {
        if (invoice.canSave)
            invoice.saveInvoice()
        sentEuro = app.ehMoney(finalizer.effectiveAmount)
        sentBtc = app.ehBtc(finalizer.effectiveAmount)
        dialog.setBusy(true)
        app._ehSendOk = true      // our screens (slides, PIN when needed, countdown) were passed
        finalizer.signAndSend()
    }

    // ---------- layout ----------
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.bottomMargin: 18 + app.navigationBarHeight
        spacing: 9

        EhPageTop {
            title: ''
            steps: app.ehSendSteps()
            stepNow: dialog.phase === 'amount' ? 2 : (dialog.phase === 'sent' ? 4 : 3)
            stepsBack: dialog.phase !== 'sent' && !dialog.busy
            onStepClicked: (n) => dialog.goToStep(n)
        }

        Label {
            visible: dialog.phase !== 'sent'
            enabled: !dialog.busy        // review 2026-11-11: no "Back" while the payment is leaving
            opacity: enabled ? 1 : 0.35
            Layout.topMargin: -14
            text: '‹ ' + qsTr('Back')
            color: '#5e1a33'
            font.pixelSize: 17
            font.bold: true
            TapHandler {
                margin: 10
                onTapped: {
                    if (dialog.phase === 'review' && dialog.invoice.amount.isEmpty) {
                        dialog.useMax = false
                        dialog.phase = 'amount'
                    }
                    else {
                        app._ehDraft = null
                        dialog.doClose()
                    }
                }
            }
        }

        Label {
            visible: false   // the steps bar at the top says it now
            text: qsTr('STEP %1 OF %2').arg(dialog.phase === 'amount' ? 2 : 3).arg(3)
            color: '#5e1a33'
            font.pixelSize: 14
            font.bold: true
        }

        RowLayout {
            visible: dialog.phase !== 'sent'
            spacing: 10
            Image {
                source: Qt.resolvedUrl('../../icons/eh_tx_wine.svg')
                sourceSize.width: 34
                sourceSize.height: 34
            }
            Label {
                text: dialog.phase === 'amount' ? qsTr('How much are you sending?') : qsTr('Check carefully')
                color: '#5e1a33'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 26
            }
        }

        // ===== amount =====
        Rectangle {
            visible: dialog.phase === 'amount' && app.ehOption('euro_btc') && !app.ehBtcOnly()
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            radius: 25
            color: '#efe6d3'
            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4
                Repeater {
                    model: [ { b: false, t: '€  Euro' }, { b: true, t: 'Bitcoin (BTC)' } ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: height / 2
                        color: dialog.btcMode === modelData.b ? '#ffffff' : 'transparent'
                        Label { anchors.centerIn: parent; text: modelData.t; font.pixelSize: 17; font.bold: true; color: dialog.btcMode === modelData.b ? '#3f0f21' : '#6b5d55' }
                        TapHandler {
                            onTapped: {
                                if (dialog.btcMode === modelData.b) return
                                // convert what is typed to the other unit
                                var sats = dialog.inputSats()
                                dialog.btcMode = modelData.b
                                if (sats <= 0) { dialog.euroInput = ''; return }
                                if (dialog.btcMode) {
                                    dialog.euroInput = (sats / 100000000).toFixed(8).replace(/0+$/, '').replace(/\.$/, '').replace('.', ',')
                                } else {
                                    var e = Daemon.fx.fiatValue(dialog.satsToAmount(sats), true)
                                    dialog.euroInput = isNaN(Number(e)) || e === '' ? '' : Number(e).toFixed(2).replace('.', ',')
                                }
                            }
                        }
                    }
                }
            }
        }
        Label {
            visible: dialog.phase === 'amount' && !dialog.useCoins
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            text: dialog.euroDisplay()
            color: '#3f0f21'
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 50
            fontSizeMode: Text.HorizontalFit   // T13: shrinks instead of pushing the page out
            minimumPixelSize: 22
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: dialog.phase === 'amount' && !app.ehBtcOnly() && !dialog.useCoins
            text: dialog.btcMode ? qsTr('about %1').arg(app.ehEuro(dialog.satsToAmount(dialog.inputSats())))
                                 : qsTr('about %1').arg(app.ehBtc(dialog.satsToAmount(dialog.inputSats())))
            color: '#6b5d55'
            font.pixelSize: 15
        }
        RowLayout {
            visible: dialog.phase === 'amount' && dialog.inputSats() <= dialog.balanceSats()
            Layout.fillWidth: true
            Layout.topMargin: 2
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: dialog.btcMode
                Label { text: qsTr('YOU HAVE'); color: '#6b5d55'; font.pixelSize: 12; font.bold: true }
                Label {
                    Layout.fillWidth: dialog.btcMode
                    text: app.ehMoney(dialog.satsToAmount(dialog.balanceSats()))
                    color: '#3f0f21'
                    font.family: TitleFont ? TitleFont : font.family
                    font.weight: Font.Black
                    font.pixelSize: 24
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 14
                }
            }
            Item { Layout.fillWidth: true; visible: !dialog.btcMode }
            ColumnLayout {
                // T13 (owner): typing in bitcoin, "Left" goes away: too many decimals
                visible: !dialog.btcMode
                spacing: 0
                Label { Layout.alignment: Qt.AlignRight; text: qsTr('LEFT'); color: '#6b5d55'; font.pixelSize: 12; font.bold: true }
                Label {
                    Layout.alignment: Qt.AlignRight
                    text: app.ehMoney(dialog.satsToAmount(Math.max(0, dialog.balanceSats() - dialog.inputSats())))
                    color: '#45541f'
                    font.family: TitleFont ? TitleFont : font.family
                    font.weight: Font.Black
                    font.pixelSize: 24
                }
            }
        }
        Rectangle {
            visible: dialog.phase === 'amount' && dialog.inputSats() > dialog.balanceSats()
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 26
            Layout.preferredWidth: haveL.implicitWidth + 24
            radius: 13
            color: dialog.inputSats() > dialog.balanceSats() ? '#f7e3e8' : '#efe6d3'
            Label {
                id: haveL
                anchors.centerIn: parent
                font.pixelSize: 14
                font.bold: dialog.inputSats() > dialog.balanceSats()
                color: dialog.inputSats() > dialog.balanceSats() ? '#3f0f21' : '#4a4038'
                text: dialog.inputSats() > dialog.balanceSats()
                      ? qsTr('You do not have enough schei')
                      : qsTr('You have %1').arg(app.ehMoney(Daemon.currentWallet.ehTotal))
            }
        }
        Rectangle {
            visible: dialog.phase === 'amount' && app.ehOption('max')
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 24
            color: maxTap.pressed ? '#fbeef2' : '#ffffff'
            border.width: 2
            border.color: '#e9cdd6'
            Label { anchors.centerIn: parent; text: qsTr('All the balance'); color: '#5e1a33'; font.pixelSize: 17; font.bold: true }
            TapHandler { id: maxTap; onTapped: { dialog.useMax = true; dialog.goReview(MAX) } }
        }
        EhCoinPad {
            id: coinPad
            visible: dialog.phase === 'amount' && dialog.useCoins
            Layout.fillWidth: true
            Layout.fillHeight: true
            onEuroInputChanged: if (dialog.useCoins) dialog.euroInput = euroInput
        }
        Label {
            visible: dialog.phase === 'amount' && dialog.useCoins
            Layout.alignment: Qt.AlignHCenter
            text: qsTr('Prefer to write the numbers?')
            color: '#5e1a33'; font.pixelSize: 15; font.bold: true; font.underline: true
            TapHandler { margin: 8; onTapped: dialog.coinsMode = false }
        }
        Item { visible: dialog.phase === 'amount' && !dialog.useCoins; Layout.fillHeight: true }
        GridLayout {
            visible: dialog.phase === 'amount' && !dialog.useCoins
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 9
            columnSpacing: 9
            Repeater {
                model: ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', 'del']
                delegate: Rectangle {
                    id: key
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    radius: 27
                    color: modelData === 'del' ? '#efe6d3' : (kt.pressed ? '#f3ecdd' : '#ffffff')
                    border.width: modelData === 'del' ? 0 : 2
                    border.color: '#e2d7c1'
                    EhBackspaceIcon { visible: key.modelData === 'del'; anchors.centerIn: parent; width: 38; height: 27; fill: '#efe6d3' }
                    Label {
                        anchors.centerIn: parent
                        visible: key.modelData !== 'del'
                        text: key.modelData === ',' ? app.ehLocale().decimalPoint : key.modelData
                        font.pixelSize: 27
                        font.bold: true
                        color: '#2a2220'
                    }
                    TapHandler { id: kt; onTapped: dialog.press(key.modelData) }
                }
            }
        }
        // third review (#7): no euro price yet: say it, and offer to write in bitcoin
        Rectangle {
            visible: dialog.phase === 'amount' && dialog.noRate
            Layout.fillWidth: true
            Layout.preferredHeight: nrCol.implicitHeight + 22
            radius: 16
            color: '#fbf0d8'
            border.width: 2
            border.color: '#d9b25a'
            ColumnLayout {
                id: nrCol
                x: 12; y: 11
                width: parent.width - 24
                spacing: 8
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font.pixelSize: 14
                    text: '<b>' + qsTr('I do not know the euro price right now.') + '</b> '
                          + qsTr('Wait a few seconds, or write the amount in bitcoin.')
                }
                EhPillButton {
                    text: qsTr('Write in bitcoin')
                    fontSize: 16
                    color: '#ffffff'
                    textColor: '#5e1a33'
                    onClicked: { dialog.euroInput = ''; dialog.btcMode = true }
                    Label { anchors.centerIn: parent; text: '₿'; font.pixelSize: 20; font.bold: true; color: '#5e1a33' }
                }
            }
        }
        EhNextButton {
            visible: dialog.phase === 'amount'
            enabled: dialog.inputSats() > 0 && dialog.inputSats() <= dialog.balanceSats()
            text: qsTr('Next')
            onClicked: dialog.goReview(dialog.satsToAmount(dialog.inputSats()))
        }

        // ===== review =====
        // double confirmation: amount on one line and the address across the
        // whole width; the two bars start below them
        Rectangle {
            visible: dialog.phase === 'review' && dialog.needsDouble
            Layout.fillWidth: true
            Layout.preferredHeight: dsCol.implicitHeight + 16
            radius: 16
            color: '#ffffff'
            ColumnLayout {
                id: dsCol
                anchors.fill: parent
                anchors.margins: 8
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: qsTr('You send'); font.pixelSize: 16 }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: app.ehMoney(finalizer.valid ? finalizer.effectiveAmount : (dialog.chosen ? dialog.chosen : finalizer.amount))
                        font.pixelSize: 24
                        font.bold: true
                        color: '#3f0f21'
                    }
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap
                    font.pixelSize: 14
                    color: '#6b5d55'
                    text: qsTr('Sending cost') + ' ' + (finalizer.valid ? app.ehMoney(finalizer.fee) : '…') + ' · ' + qsTr('Total') + ' '
                          + (finalizer.valid ? app.ehMoney(dialog.satsToAmount(finalizer.effectiveAmount.satsInt + finalizer.fee.satsInt)) : '…')
                    TapHandler { onTapped: app.ehShowFeeInfo() }
                }
            }
        }
        Rectangle {
            visible: dialog.phase === 'review' && dialog.needsDouble
            Layout.fillWidth: true
            Layout.preferredHeight: daCol.implicitHeight + 14
            radius: 16
            color: '#ffffff'
            border.width: 2
            border.color: '#f3e3e8'
            ColumnLayout {
                id: daCol
                anchors.fill: parent
                anchors.margins: 7
                spacing: 2
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Label { text: qsTr('TO THIS ADDRESS'); font.pixelSize: 13; font.bold: true; color: '#5e1a33' }
                    Image { source: Qt.resolvedUrl('../../icons/eh_zoom.svg'); sourceSize.width: 18; sourceSize.height: 18 }
                }
                Label {
                    id: dAddr
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                    text: app.ehAddressRich(dialog.invoice ? dialog.invoice.address : '', '#3f0f21', '#f7e3e8',
                                            Math.max(1, Math.floor((width + dFm.averageCharacterWidth) / (dFm.averageCharacterWidth * 5))))
                    font.family: FixedFont
                    font.bold: true
                    font.pixelSize: 17
                    lineHeight: 1.2
                    FontMetrics { id: dFm; font: dAddr.font }
                }
            }
            TapHandler { onTapped: app.ehZoomAddress(dialog.invoice.address, false) }
        }

        // single confirmation: one push-up bar on the left, text on the right.
        // double confirmation (big amounts): text on the left, two long bars on the right.
        ColumnLayout {
            visible: dialog.phase === 'review'
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // T24: first slide, above the text
            EhSlideH {
                id: sl1
                Layout.fillWidth: true
                enabled: finalizer.valid && dialog.countdown < 0
                onReached: dialog.checkSlides()
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: textCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
            ColumnLayout {
                id: textCol
                width: parent.width
                spacing: 8

                Rectangle {
                    visible: !dialog.needsDouble
                    Layout.fillWidth: true
                    Layout.preferredHeight: sumCol.implicitHeight + 18
                    radius: 16
                    color: '#ffffff'
                    ColumnLayout {
                        id: sumCol
                        anchors.fill: parent
                        anchors.margins: 9
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 3
                        Label { text: qsTr('You send'); font.pixelSize: 16 }
                        Label {
                            text: app.ehMoney(finalizer.valid ? finalizer.effectiveAmount : (dialog.chosen ? dialog.chosen : finalizer.amount))
                            font.pixelSize: 24
                            font.bold: true
                            color: '#3f0f21'
                        }
                        // the sending cost is a button: tap to choose it (EhFeeDialog)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: costRow.implicitHeight + 14
                            radius: 12
                            color: costTap.pressed ? '#f3dde5' : '#fbf4f6'
                            border.width: 1.5
                            border.color: '#e2b8c6'
                            RowLayout {
                                id: costRow
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                ColumnLayout {
                                    spacing: 0
                                    Label { textFormat: Text.StyledText; text: qsTr('Sending cost') + ' <font color="#6b5d55">' + qsTr('(tip to the miners)') + '</font>'; font.pixelSize: 16 }
                                    Label { text: app.ehFeeEta(finalizer.sliderPos); font.pixelSize: 13; color: '#6b5d55' }
                                    // T6: the invitation is inside the button, not below it
                                    Label { text: qsTr('tap to change it'); font.pixelSize: 13; font.bold: true; color: '#5e1a33' }
                                    // T46 (owner 12/11): what the tip is, here next to the cost (not under the coins)
                                    Label {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 3
                                        wrapMode: Text.WordWrap
                                        textFormat: Text.StyledText
                                        font.pixelSize: 13
                                        color: '#6b5d55'
                                        text: qsTr('It is the small tip to the "miners" who write your payment on the blockchain.')
                                              + ' <u><font color="#5e1a33"><b>' + qsTr('More information') + '</b></font></u>'
                                        TapHandler { onTapped: app.ehShowFeeInfo() }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Label { text: finalizer.valid ? app.ehMoney(finalizer.fee) : '…'; font.pixelSize: 16; font.bold: true }
                                Label { text: '›'; font.pixelSize: 24; font.bold: true; color: '#5e1a33' }
                            }
                            TapHandler { id: costTap; onTapped: dialog.chooseFee() }
                        }
                        // which gold coins the payment melts: chosen by the app, or by hand
                        // (owner 12/11: only with "Gold coins (UTXO)" on in Advanced)
                        Rectangle {
                            visible: app.ehOption('utxo')
                            Layout.fillWidth: true
                            Layout.preferredHeight: coinsRow.implicitHeight + 14
                            radius: 12
                            color: coinsTap.pressed ? '#f4ead2' : '#fbf6e8'
                            RowLayout {
                                id: coinsRow
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6
                                Image { source: Qt.resolvedUrl('../../icons/eh_goldcoin.svg'); sourceSize.width: 26; sourceSize.height: 26 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Label { text: qsTr('Coins used'); font.pixelSize: 15 }
                                    Label {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.pixelSize: 13
                                        color: '#6b5d55'
                                        text: (finalizer.valid ? finalizer.ehInputCount + ' · ' : '')
                                              + (finalizer.ehCoins.length > 0 ? qsTr('chosen by you') : qsTr('chosen by itself'))
                                    }
                                }
                                Label { text: '›'; font.pixelSize: 22; font.bold: true; color: '#5e1a33' }
                            }
                            TapHandler { id: coinsTap; onTapped: dialog.chooseCoins() }
                        }
                        // T20: privacy warning, it never blocks the payment
                        Rectangle {
                            visible: dialog.mixCoins.length > 0 && !dialog.mixOk
                            Layout.fillWidth: true
                            Layout.preferredHeight: mixCol.implicitHeight + 20
                            radius: 14
                            color: '#fdf1d4'
                            border.width: 2
                            border.color: '#e0a21a'
                            ColumnLayout {
                                id: mixCol
                                x: 10; y: 10
                                width: parent.width - 20
                                spacing: 6
                                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: qsTr('You are mixing coins'); font.pixelSize: 16; font.bold: true; color: '#7a4d00' }
                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    textFormat: Text.StyledText
                                    font.pixelSize: 14
                                    text: qsTr('This payment uses coins of <b>different origins</b>. Who receives can understand that they are all yours.')
                                }
                                Repeater {
                                    model: dialog.mixCoins
                                    RowLayout {
                                        id: mx
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Image { source: Qt.resolvedUrl('../../icons/eh_goldcoin.svg'); sourceSize.width: 20; sourceSize.height: 20 }
                                        Label { Layout.fillWidth: true; text: app.ehMoney(dialog.satsToAmount(mx.modelData.sats)); font.pixelSize: 14; font.bold: true }
                                        Rectangle { Layout.preferredWidth: 9; Layout.preferredHeight: 9; radius: 4.5; color: mx.modelData.cat.color }
                                        Label { text: mx.modelData.cat.name; font.pixelSize: 13; font.bold: true; color: mx.modelData.cat.color }
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 18
                                        color: '#45541f'
                                        Label { anchors.centerIn: parent; text: qsTr('I choose the coins'); color: '#ffffff'; font.pixelSize: 14; font.bold: true }
                                        MouseArea { anchors.fill: parent; onClicked: dialog.chooseCoins() }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 18
                                        color: '#ffffff'; border.width: 2; border.color: '#e3d9c6'
                                        Label { anchors.centerIn: parent; text: qsTr('It is fine'); color: '#3f0f21'; font.pixelSize: 14; font.bold: true }
                                        MouseArea { anchors.fill: parent; onClicked: dialog.mixOk = true }
                                    }
                                }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 2; color: '#ece4d2' }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: qsTr('Total'); font.pixelSize: 18; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: finalizer.valid ? app.ehMoney(dialog.satsToAmount(finalizer.effectiveAmount.satsInt + finalizer.fee.satsInt)) : '…'
                                font.pixelSize: 18
                                font.bold: true
                                color: '#5e1a33'
                            }
                        }
                    }
                }

                // address card: first and last 4 letters, tap to enlarge
                Rectangle {
                    visible: !dialog.needsDouble
                    Layout.fillWidth: true
                    Layout.preferredHeight: addrCol.implicitHeight + 18
                    radius: 16
                    color: '#ffffff'
                    border.width: 2
                    border.color: '#f3e3e8'
                    ColumnLayout {
                        id: addrCol
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 4
                        Label { text: qsTr('TO THIS ADDRESS'); font.pixelSize: 13; font.bold: true; color: '#5e1a33' }
                        Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            textFormat: Text.RichText
                            id: sAddr
                            text: app.ehAddressRich(dialog.invoice ? dialog.invoice.address : '', '#3f0f21', '#f7e3e8',
                                                    Math.max(1, Math.floor((width + sFm.averageCharacterWidth) / (sFm.averageCharacterWidth * 5))))
                            font.family: FixedFont
                            font.bold: true
                            font.pixelSize: 16
                            lineHeight: 1.25
                            FontMetrics { id: sFm; font: sAddr.font }
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 6
                            Image { source: Qt.resolvedUrl('../../icons/eh_zoom.svg'); sourceSize.width: 20; sourceSize.height: 20 }
                            Label { text: qsTr('tap to enlarge'); font.pixelSize: 13; font.bold: true; color: '#5e1a33' }
                        }
                    }
                    TapHandler { onTapped: app.ehZoomAddress(dialog.invoice.address, false) }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: askL.implicitHeight + 18
                    radius: 14
                    color: '#fbf0d6'
                    Label {
                        id: askL
                        anchors.fill: parent
                        anchors.margins: 9
                        anchors.leftMargin: 11
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        font.pixelSize: 16
                        lineHeight: 1.15
                        readonly property var parts: app.ehAddressParts(dialog.invoice ? dialog.invoice.address : '')
                        text: (parts.prefix !== ''
                               ? qsTr('<b>Ask the person receiving</b> what comes after %1 and how their address ends:').arg(parts.prefix)
                               : qsTr('<b>Ask the person receiving</b> how their address starts and ends:'))
                              + ' <b>' + (parts.prefix !== '' ? parts.prefix + ' ' : '') + parts.first + ' … ' + parts.last + '</b>'
                    }
                }

                // big payment: the PIN comes after the coin
                Rectangle {
                    visible: dialog.needsPin
                    Layout.fillWidth: true
                    Layout.preferredHeight: pinNote.implicitHeight + 18
                    radius: 14
                    color: '#fbf0d6'
                    border.width: 2
                    border.color: '#ecd49a'
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 8
                        Image {
                            Layout.alignment: Qt.AlignTop
                            source: Qt.resolvedUrl('../../icons/eh_lock.svg')
                            sourceSize.width: 22
                            sourceSize.height: 22
                        }
                        Label {
                            id: pinNote
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            textFormat: Text.StyledText
                            font.pixelSize: 15
                            lineHeight: 1.1
                            color: '#2a2220'
                            text: qsTr('<b>It is a big payment</b> (more than %1). When you have pushed up the bitcoin coin, I will ask you for the PIN.').arg(app.ehBigLimitText())
                        }
                    }
                }

                Label {
                    visible: finalizer.warning !== ''
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: '#5e1a33'
                    font.pixelSize: 15
                    text: finalizer.warning
                }

                Rectangle {
                    visible: dialog.useMax
                    Layout.fillWidth: true
                    Layout.preferredHeight: maxNote.implicitHeight + 18
                    radius: 14
                    color: '#fbf0d6'
                    Label {
                        id: maxNote
                        anchors.fill: parent
                        anchors.margins: 9
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        font.pixelSize: 15
                        text: qsTr('You send <b>everything you have</b>. The sending cost is already taken off: the wallet will be left at zero.')
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: irrL.implicitHeight + 18
                    radius: 14
                    color: '#f7e3e8'
                    Label {
                        id: irrL
                        anchors.fill: parent
                        anchors.margins: 9
                        anchors.leftMargin: 11
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        font.pixelSize: 15
                        lineHeight: 1.1
                        color: '#3f0f21'
                        text: '<b>' + qsTr('It cannot be undone.') + '</b> ' + qsTr('Once sent, only the person who receives them can give them back.')
                    }
                }

                Rectangle {
                    visible: dialog.needsDouble
                    Layout.fillWidth: true
                    Layout.preferredHeight: dblL.implicitHeight + 18
                    radius: 14
                    color: '#f7e3e8'
                    border.width: 2
                    border.color: '#5e1a33'
                    Label {
                        id: dblL
                        anchors.fill: parent
                        anchors.margins: 9
                        anchors.leftMargin: 11
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        font.pixelSize: 16
                        color: '#3f0f21'
                        text: '<b>' + qsTr('It is a big amount.') + '</b> ' + qsTr('Push up <b>both coins together</b>, with two fingers.')
                    }
                }

            }
            }

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                font.bold: true
                color: sl1.locked !== sl2.locked ? '#45541f' : '#6b5d55'
                text: sl1.locked !== sl2.locked ? qsTr('Now the other one, quickly!')
                                                : qsTr('Push both coins to the right: together with two fingers, or one after the other.')
            }
            // T24: second slide, at the bottom
            EhSlideH {
                id: sl2
                Layout.fillWidth: true
                enabled: finalizer.valid && dialog.countdown < 0
                onReached: dialog.checkSlides()
            }
        }

        // ===== sent =====
        ColumnLayout {
            visible: dialog.phase === 'sent'
            Layout.fillWidth: true
            Layout.topMargin: 10
            spacing: 8
            Image {
                Layout.alignment: Qt.AlignHCenter
                source: Qt.resolvedUrl('../../icons/eh_check_wine.svg')
                sourceSize.width: 110
                sourceSize.height: 110
            }
            Label { Layout.alignment: Qt.AlignHCenter; text: qsTr('Sent!'); font.pixelSize: 22; font.bold: true }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: dialog.sentEuro !== '' ? dialog.sentEuro : dialog.sentBtc
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 44
                color: '#5e1a33'
            }
            Label { Layout.alignment: Qt.AlignHCenter; text: qsTr('have left'); font.pixelSize: 16; color: '#6b5d55' }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: sentNote.implicitHeight + 24
                radius: 16
                color: '#fbf0d6'
                Label {
                    id: sentNote
                    anchors.fill: parent
                    anchors.margins: 12
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font.pixelSize: 16
                    text: qsTr('They reach the other person after the <b>first confirmation</b>, usually about ten minutes. In the list of movements you will see "⏳ Unconfirmed" and then "✓ Confirmed".')
                }
            }
            EhMoreInfoButton { Layout.fillWidth: true; onClicked: app.ehShowConfirmationsInfo() }
        }
        Item { visible: dialog.phase === 'sent'; Layout.fillHeight: true }
        EhPillButton {
            visible: dialog.phase === 'sent'
            text: qsTr('Back to home')
            color: '#5e1a33'
            textColor: '#ffffff'
            tileColor: '#d9b25a'
            outlined: false
            onClicked: dialog.doAccept()
            Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_home_wine.svg'); sourceSize.width: 28; sourceSize.height: 28 }
        }
    }

    TxFinalizer {
        id: finalizer
        wallet: Daemon.currentWallet
        canRbf: true
        // every payment starts from the normal cost (Electrum's eta:2)
        Component.onCompleted: { method = 1; sliderPos = 5 }
        onFinished: (signed, saved, complete) => {
            if (!complete) {
                dialog.resetBars()
            }
        }
        onSignError: (message) => {
            dialog.resetBars()
            var d = app.messageDialog.createObject(app, { title: qsTr('Error'), text: message })
            d.open()
        }
    }

    Connections {
        target: Daemon.currentWallet
        function onBroadcastSucceeded(txid) {
            dialog.setBusy(false)
            dialog.phase = 'sent'
        }
        function onBroadcastFailed(txid, code, reason) {
            dialog.resetBars()
            // third review: say only what we know. A rejection: it did not leave. A broken
            // connection: maybe it left, look at the movements before paying again.
            var info = code === 'rejected'
                ? { pageTitle: qsTr('The payment did not leave'),
                    bodyText: qsTr('The bitcoin network refused this payment. Your money is still in the wallet.'),
                    tipText: '<small>' + reason + '</small>' }
                : { pageTitle: qsTr('I am not sure the payment left'),
                    bodyText: qsTr('The connection broke while the payment was leaving.')
                              + '<br><br>' + qsTr('<b>Before paying again</b>, wait a few minutes and look at the movements: if the payment is there, it left.'),
                    tipText: '' }
            app.ehInfoDialog.createObject(app, info).open()
        }
    }

    Component.onCompleted: {
        if (invoice && !invoice.amount.isEmpty)
            goReview(invoice.amount)
        else
            phase = 'amount'
        // back from step 1 with the same address: the amount typed is still there
        var d = app._ehDraft
        app._ehDraft = null
        if (d && invoice && d.address === invoice.address && invoice.amount.isEmpty && d.euroInput !== '') {
            btcMode = d.btcMode
            coinsMode = false      // shown as numbers (the coin heap is not rebuilt)
            euroInput = d.euroInput
        }
    }

    // ===== T25: countdown before the payment leaves =====
    Rectangle {
        id: cdPane
        visible: dialog.countdown >= 0
        anchors.fill: parent
        z: 100
        color: '#faf7ef'
        MouseArea { anchors.fill: parent }    // nothing behind can be touched
        Rectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -80
            width: 380; height: 380; radius: 190
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0.97, 0.58, 0.10, 0.18) }
                GradientStop { position: 1; color: Qt.rgba(0.97, 0.58, 0.10, 0) }
            }
        }
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 12
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr('Sending the bitcoin…')
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 26
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: finalizer.valid ? app.ehMoney(dialog.satsToAmount(finalizer.effectiveAmount.satsInt + finalizer.fee.satsInt)) : ''
                color: '#5e1a33'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 30
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                readonly property var parts: app.ehAddressParts(dialog.invoice ? dialog.invoice.address : '')
                text: qsTr('to %1').arg((parts.prefix !== '' ? parts.prefix + ' ' : '') + parts.first + ' … ' + parts.last)
                font.family: FixedFont
                font.pixelSize: 15
                font.bold: true
            }
            // the ring empties second after second, the big number in the middle
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 190
                Layout.preferredHeight: 190
                Canvas {
                    id: ring
                    anchors.fill: parent
                    property real part: Math.max(0, dialog.countdown) / 5
                    Behavior on part { NumberAnimation { duration: 900 } }
                    onPartChanged: requestPaint()
                    onPaint: {
                        var c = getContext('2d')
                        c.reset()
                        c.lineWidth = 12
                        c.lineCap = 'round'
                        c.strokeStyle = '#efe3c8'
                        c.beginPath(); c.arc(95, 95, 84, 0, 2 * Math.PI); c.stroke()
                        if (part > 0) {
                            c.strokeStyle = '#f7931a'
                            c.beginPath(); c.arc(95, 95, 84, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * part); c.stroke()
                        }
                    }
                }
                Label {
                    anchors.centerIn: parent
                    text: Math.max(0, dialog.countdown)
                    color: '#f7931a'
                    font.family: TitleFont ? TitleFont : font.family
                    font.weight: Font.Black
                    font.pixelSize: 96
                }
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr('Until zero you can still stop it.')
                color: '#6b5d55'
                font.pixelSize: 15
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 12
                Layout.preferredHeight: 68
                radius: 26
                color: cdMa.pressed ? '#fbeef2' : '#ffffff'
                border.width: 3
                border.color: '#5e1a33'
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    Image { source: Qt.resolvedUrl('../../icons/eh_cross.svg'); sourceSize.width: 22; sourceSize.height: 22 }
                    Label { text: qsTr('Cancel'); color: '#5e1a33'; font.pixelSize: 22; font.bold: true }
                }
                MouseArea { id: cdMa; anchors.fill: parent; onClicked: dialog.cancelCountdown() }
            }
        }
    }

}
