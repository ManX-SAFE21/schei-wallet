// Easy Heirs (schèi): INVIA steps 2 and 3 and the "Inviati!" screen.
//  amount : how much, in euro, big keys (skipped if the QR already has it)
//  review : what you send, sending cost, total, address with the last 4
//           letters highlighted, "cannot be undone" warning, slide to send
//  sent   : "Inviati!" with the confirmation note
// "Bottega": parchment page, the receipt on a paper sheet, info boxes, stitched buttons.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"
import "controls/EhStyle.js" as S

ElDialog {
    id: dialog
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.wine
    font.family: BodyFont ? BodyFont : Qt.application.font.family

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
    property bool coinsMode: app.ehOption('coins') && !app.ehBtcOnly() && app.ehHasCash()
    readonly property bool useCoins: coinsMode && !btcMode
    onBtcModeChanged: if (!btcMode && coinsMode) coinPad.clear()
    // big amounts need two coins pushed up (expert option, on by default at 500 euro)
    // big payment: one coin as always, then the PIN (like a contactless card).
    // The old double-coin screen is kept in the file but never shown.
    readonly property var reviewAmount: finalizer.valid ? finalizer.effectiveAmount : (chosen ? chosen : finalizer.amount)
    readonly property bool needsPin: phase === 'review' && (useMax || app.ehNeedsDouble(reviewAmount))
    readonly property bool needsDouble: false

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    background: Rectangle { color: S.parch }

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
        var sym = btcMode ? '' : app.ehSym() + ' '
        if (euroInput === '') return btcMode ? '0 BTC' : sym + '0'
        if (btcMode) return euroInput.replace(',', app.ehLocale().decimalPoint) + ' ' + app.ehBtcUnit()
        var parts = euroInput.split(',')
        var intPart = Number(parts[0] || '0').toLocaleString(app.ehLocale(), 'f', 0)
        return app.ehSym() + ' ' + intPart + (parts.length > 1 ? app.ehLocale().decimalPoint + parts[1] : '')
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
        if (euroInput.replace(',', '').length >= (btcMode ? 10 : 7 + Math.round(Math.log(app.ehCcyMult()) / Math.LN10))) return
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
            if (i === a.length - 4) out += '<span style="background-color:' + S.highlight + '"><font color="' + S.wineDark + '"><u>'
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

    // owner 13/11: the middle of "Check carefully" scrolls between the two slides: a soft
    // parchment edge at the top / bottom when there is more text there (no hard cut box)
    Rectangle {
        parent: midFlick
        z: 10
        visible: dialog.phase === 'review' && midFlick.contentY > 1
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 22
        gradient: Gradient {
            GradientStop { position: 0.0; color: S.parch }
            GradientStop { position: 1.0; color: 'transparent' }
        }
    }
    Rectangle {
        parent: midFlick
        z: 10
        visible: dialog.phase === 'review' && midFlick.contentY < midFlick.contentHeight - midFlick.height - 1
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 22
        gradient: Gradient {
            GradientStop { position: 0.0; color: 'transparent' }
            GradientStop { position: 1.0; color: S.parch }
        }
    }

    // ---------- layout ----------
    // every page scrolls (nothing under the phone keys). In "Check carefully" the page fits and
    // does not move: only the middle scrolls, the two slides stay always visible.
    Flickable {
        id: pageFlick
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        flickableDirection: Flickable.VerticalFlick
        contentHeight: Math.max(height, col.implicitHeight + 16)
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height + 1
        clip: true

    ColumnLayout {
        id: col
        x: S.margin
        width: pageFlick.width - 2 * S.margin
        height: Math.max(pageFlick.height - 16, implicitHeight)
        spacing: 8

        EhPageTop {
            title: ''
            steps: app.ehSendSteps()
            stepNow: dialog.phase === 'amount' ? 2 : (dialog.phase === 'sent' ? 4 : 3)
            stepsBack: dialog.phase !== 'sent' && !dialog.busy
            onStepClicked: (n) => dialog.goToStep(n)
        }

        EhBackLink {
            visible: dialog.phase !== 'sent'
            enabled: !dialog.busy        // review 2026-11-11: no "Back" while the payment is leaving
            opacity: enabled ? 1 : 0.35
            onClicked: {
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

        Label {
            visible: false   // the steps bar at the top says it now
            text: qsTr('STEP %1 OF %2').arg(dialog.phase === 'amount' ? 2 : 3).arg(3)
            color: S.olive
            font.pixelSize: 16
            font.bold: true
        }

        EhTitle {
            visible: dialog.phase !== 'sent'
            text: dialog.phase === 'amount' ? qsTr('How much are you sending?') : qsTr('Check carefully')
        }

        // ===== amount =====
        EhSegmented {
            visible: dialog.phase === 'amount' && app.ehOption('euro_btc') && !app.ehBtcOnly()
            model: [ (app.ehSym() !== app.ehCcy() ? app.ehSym() + '  ' : '') + app.ehCcyTitle(), 'Bitcoin (BTC)' ]
            currentIndex: dialog.btcMode ? 1 : 0
            onActivated: (i) => {
                var b = (i === 1)
                if (dialog.btcMode === b) return
                // convert what is typed to the other unit
                var sats = dialog.inputSats()
                dialog.btcMode = b
                if (sats <= 0) { dialog.euroInput = ''; return }
                if (dialog.btcMode) {
                    dialog.euroInput = (sats / 100000000).toFixed(8).replace(/0+$/, '').replace(/\.$/, '').replace('.', ',')
                } else {
                    var e = Daemon.fx.fiatValue(dialog.satsToAmount(sats), true)
                    dialog.euroInput = isNaN(Number(e)) || e === '' ? '' : Number(e).toFixed(2).replace('.', ',')
                }
            }
        }
        Label {
            visible: dialog.phase === 'amount' && !dialog.useCoins
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: col.width
            text: dialog.euroDisplay()
            color: S.wineDark
            font.family: SerifFont ? SerifFont : font.family
            font.weight: Font.ExtraBold
            font.pixelSize: 50
            fontSizeMode: Text.HorizontalFit   // T13: shrinks instead of pushing the page out
            minimumPixelSize: 22
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -6
            visible: dialog.phase === 'amount' && !app.ehBtcOnly() && !dialog.useCoins
            text: dialog.btcMode ? qsTr('about %1').arg(app.ehEuro(dialog.satsToAmount(dialog.inputSats())))
                                 : qsTr('about %1').arg(app.ehBtc(dialog.satsToAmount(dialog.inputSats())))
            color: S.muted
            font.pixelSize: 16
        }
        RowLayout {
            visible: dialog.phase === 'amount' && dialog.inputSats() <= dialog.balanceSats()
            Layout.fillWidth: true
            Layout.topMargin: 2
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: dialog.btcMode
                Label { text: qsTr('YOU HAVE'); color: S.olive; font.pixelSize: 16; font.bold: true; font.letterSpacing: 0.5 }
                Label {
                    Layout.fillWidth: dialog.btcMode
                    text: app.ehMoney(dialog.satsToAmount(dialog.balanceSats()))
                    color: S.wineDark
                    font.family: SerifFont ? SerifFont : font.family
                    font.weight: Font.ExtraBold
                    font.pixelSize: 24
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 16
                }
            }
            Item { Layout.fillWidth: true; visible: !dialog.btcMode }
            ColumnLayout {
                // T13 (owner): typing in bitcoin, "Left" goes away: too many decimals
                visible: !dialog.btcMode
                spacing: 0
                Label { Layout.alignment: Qt.AlignRight; text: qsTr('LEFT'); color: S.olive; font.pixelSize: 16; font.bold: true; font.letterSpacing: 0.5 }
                Label {
                    Layout.alignment: Qt.AlignRight
                    text: app.ehMoney(dialog.satsToAmount(Math.max(0, dialog.balanceSats() - dialog.inputSats())))
                    color: S.oliveInk
                    font.family: SerifFont ? SerifFont : font.family
                    font.weight: Font.ExtraBold
                    font.pixelSize: 24
                }
            }
        }
        EhInfoBox {
            id: haveL
            visible: dialog.phase === 'amount' && dialog.inputSats() > dialog.balanceSats()
            kind: dialog.inputSats() > dialog.balanceSats() ? 'danger' : 'warn'
            text: dialog.inputSats() > dialog.balanceSats()
                  ? '<b>' + qsTr('You do not have enough schei') + '</b>'
                  : qsTr('You have %1').arg(app.ehMoney(Daemon.currentWallet.ehTotal))
        }
        EhStitchButton {
            visible: dialog.phase === 'amount' && app.ehOption('max')
            kind: 'paper'
            text: qsTr('All the balance')
            onClicked: { dialog.useMax = true; dialog.goReview(MAX) }
        }
        EhCoinPad {
            id: coinPad
            visible: dialog.phase === 'amount' && dialog.useCoins
            // owner 13/11: big notes at BASE and MEDIO (the page scrolls), ESPERTO may shrink them
            bigNotes: app.ehLevel() !== 'esperto'
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: visible ? implicitHeight : 0
            onEuroInputChanged: if (dialog.useCoins) dialog.euroInput = euroInput
        }
        EhBackLink {
            visible: dialog.phase === 'amount' && dialog.useCoins
            Layout.topMargin: 0
            Layout.alignment: Qt.AlignHCenter
            text: qsTr('Prefer to write the numbers?')
            onClicked: dialog.coinsMode = false
        }
        Item { visible: dialog.phase === 'amount' && !dialog.useCoins; Layout.fillHeight: true }
        GridLayout {
            visible: dialog.phase === 'amount' && !dialog.useCoins
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 8
            columnSpacing: 9
            Repeater {
                model: ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', 'del']
                delegate: EhKey {
                    id: key
                    required property string modelData
                    text: modelData === ',' ? app.ehLocale().decimalPoint : modelData
                    isDelete: modelData === 'del'
                    onActivated: dialog.press(key.modelData)
                }
            }
        }
        // third review (#7): no euro price yet: say it, and offer to write in bitcoin
        EhInfoBox {
            id: nrCol
            visible: dialog.phase === 'amount' && dialog.noRate
            kind: 'warn'
            text: '<b>' + qsTr('I do not know the price in %1 right now.').arg(app.ehCcyName()) + '</b> '
                  + qsTr('Wait a few seconds, or write the amount in bitcoin.')
            EhStitchButton {
                kind: 'paper'
                text: qsTr('Write in bitcoin')
                onClicked: { dialog.euroInput = ''; dialog.btcMode = true }
                Label { anchors.centerIn: parent; text: '₿'; font.pixelSize: 22; font.bold: true; color: S.wine }
            }
        }
        EhStitchButton {
            visible: dialog.phase === 'amount'
            kind: 'wine'
            endIcon: 'next'
            enabled: dialog.inputSats() > 0 && dialog.inputSats() <= dialog.balanceSats()
            text: qsTr('Next')
            onClicked: dialog.goReview(dialog.satsToAmount(dialog.inputSats()))
        }

        // ===== review =====
        // double confirmation: amount on one line and the address across the
        // whole width; the two bars start below them (kept, never shown: needsDouble is false)
        EhSheet {
            visible: dialog.phase === 'review' && dialog.needsDouble
            topPadding: 8
            bottomPadding: 8
            ColumnLayout {
                id: dsCol
                Layout.fillWidth: true
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: qsTr('You send'); font.pixelSize: 17; color: S.ink }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: app.ehMoney(finalizer.valid ? finalizer.effectiveAmount : (dialog.chosen ? dialog.chosen : finalizer.amount))
                        font.family: SerifFont ? SerifFont : font.family
                        font.weight: Font.ExtraBold
                        font.pixelSize: 24
                        color: S.wine
                    }
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap
                    font.pixelSize: 16
                    color: S.muted
                    text: qsTr('Sending cost') + ' ' + (finalizer.valid ? app.ehMoney(finalizer.fee) : '…') + ' · ' + qsTr('Total') + ' '
                          + (finalizer.valid ? app.ehMoney(dialog.satsToAmount(finalizer.effectiveAmount.satsInt + finalizer.fee.satsInt)) : '…')
                    TapHandler { onTapped: app.ehShowFeeInfo() }
                }
            }
        }
        EhSheet {
            visible: dialog.phase === 'review' && dialog.needsDouble
            topPadding: 8
            bottomPadding: 8
            ColumnLayout {
                id: daCol
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Label { text: qsTr('TO THIS ADDRESS'); font.pixelSize: 16; font.bold: true; color: S.wine }
                    Image { source: Qt.resolvedUrl('../../icons/eh_zoom.svg'); sourceSize.width: 20; sourceSize.height: 20 }
                }
                Label {
                    id: dAddr
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                    text: app.ehAddressRich(dialog.invoice ? dialog.invoice.address : '', S.wineDark, S.highlight,
                                            Math.max(1, Math.floor((width + dFm.averageCharacterWidth) / (dFm.averageCharacterWidth * 5))))
                    font.family: FixedFont
                    font.bold: true
                    font.pixelSize: 18
                    color: S.ink
                    lineHeight: 1.2
                    FontMetrics { id: dFm; font: dAddr.font }
                }
                TapHandler { onTapped: app.ehZoomAddress(dialog.invoice.address, false) }
            }
        }

        // T24: the first slide on top, the second at the bottom; the middle scrolls,
        // the two slides stay always visible
        ColumnLayout {
            visible: dialog.phase === 'review'
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            // T24: first slide, above the text
            EhSlideH {
                id: sl1
                Layout.fillWidth: true
                enabled: finalizer.valid && dialog.countdown < 0
                onReached: dialog.checkSlides()
            }

            Flickable {
                id: midFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 4        // owner 13/11: the first box no longer starts right under the slide
                Layout.minimumHeight: 150
                contentHeight: textCol.implicitHeight + 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
            ColumnLayout {
                id: textCol
                width: parent.width
                spacing: 8

                // the receipt: You send / sending cost / Total on one paper sheet
                EhSheet {
                    visible: !dialog.needsDouble
                    ColumnLayout {
                        id: sumCol
                        Layout.fillWidth: true
                        spacing: 0
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.minimumHeight: 44
                            spacing: 8
                            Label { Layout.fillWidth: true; text: qsTr('You send'); font.pixelSize: 17; color: S.ink; wrapMode: Text.WordWrap }
                            Label {
                                text: app.ehMoney(finalizer.valid ? finalizer.effectiveAmount : (dialog.chosen ? dialog.chosen : finalizer.amount))
                                font.family: SerifFont ? SerifFont : font.family
                                font.weight: Font.ExtraBold
                                font.pixelSize: 26
                                color: S.wineDark
                            }
                        }
                        EhDotLine {}
                        // the sending cost is a button: tap to choose it (EhFeeDialog)
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(64, costRow.implicitHeight + 10)
                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: -6
                                anchors.rightMargin: -6
                                anchors.topMargin: 2
                                anchors.bottomMargin: 2
                                radius: 10
                                color: S.sand
                                opacity: costTap.pressed ? 0.4 : 0
                            }
                            RowLayout {
                                id: costRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Label {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        textFormat: Text.StyledText
                                        text: qsTr('Sending cost') + ' <font color="' + S.muted + '">' + qsTr('(tip to the miners)') + '</font>'
                                        font.pixelSize: 16
                                        color: S.ink
                                    }
                                    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: app.ehFeeEta(finalizer.sliderPos); font.pixelSize: 16; color: S.muted }
                                    // T6: the invitation is inside the button, not below it
                                    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: qsTr('tap to change it'); font.pixelSize: 16; font.bold: true; font.underline: true; color: S.wine }
                                }
                                Label {
                                    text: finalizer.valid ? app.ehMoney(finalizer.fee) : '…'
                                    font.family: SerifFont ? SerifFont : font.family
                                    font.weight: Font.ExtraBold
                                    font.pixelSize: 21
                                    color: S.wineDark
                                }
                                Label { text: '›'; font.pixelSize: 30; font.bold: true; color: S.wine }
                            }
                            TapHandler { id: costTap; onTapped: dialog.chooseFee() }
                        }
                        // T46 (owner 12/11): what the tip is, here next to the cost (not under the coins)
                        Label {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 6
                            wrapMode: Text.WordWrap
                            textFormat: Text.StyledText
                            font.pixelSize: 16
                            lineHeight: 1.05
                            color: S.muted
                            text: qsTr('It is the small tip to the "miners" who write your payment on the blockchain.')
                                  + ' <u><font color="' + S.wine + '"><b>' + qsTr('More information') + '</b></font></u>'
                            TapHandler { onTapped: app.ehShowFeeInfo() }
                        }
                        // owner 13/11: the general explanation of the coins, here too
                        EhDotLine {}
                        EhRow {
                            icon: 'eh_goldcoin.svg'
                            iconColor: S.brassRing
                            minHeight: 56
                            text: qsTr('How do bitcoin coins work?')
                            last: true
                            onClicked: app.ehOpenPage(Qt.resolvedUrl('EhCoinsHowPage.qml'))
                        }
                        // which gold coins the payment melts: chosen by the app, or by hand
                        // (owner 12/11: only with "Gold coins (UTXO)" on in Advanced)
                        EhDotLine { visible: app.ehOption('utxo') }
                        EhRow {
                            id: coinsRow
                            visible: app.ehOption('utxo')
                            icon: 'eh_goldcoin.svg'
                            text: qsTr('Coins used')
                            hint: (finalizer.valid ? finalizer.ehInputCount + ' · ' : '')
                                  + (finalizer.ehCoins.length > 0 ? qsTr('chosen by you') : qsTr('chosen by itself'))
                            last: true
                            onClicked: dialog.chooseCoins()
                        }
                        // T20: privacy warning, it never blocks the payment
                        EhInfoBox {
                            id: mixCol
                            visible: dialog.mixCoins.length > 0 && !dialog.mixOk
                            Layout.topMargin: 4
                            Layout.bottomMargin: 8
                            kind: 'warn'
                            title: qsTr('You are mixing coins')
                            text: qsTr('This payment uses coins of <b>different origins</b>. Who receives can understand that they are all yours.')
                            Repeater {
                                model: dialog.mixCoins
                                RowLayout {
                                    id: mx
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Image { source: Qt.resolvedUrl('../../icons/eh_goldcoin.svg'); sourceSize.width: 22; sourceSize.height: 22 }
                                    Label { Layout.fillWidth: true; text: app.ehMoney(dialog.satsToAmount(mx.modelData.sats)); font.pixelSize: 16; font.bold: true; color: S.ink; elide: Text.ElideRight }
                                    Rectangle { Layout.preferredWidth: 10; Layout.preferredHeight: 10; radius: 5; color: mx.modelData.cat.color }
                                    Label { Layout.maximumWidth: mixCol.width * 0.4; text: mx.modelData.cat.name; font.pixelSize: 16; font.bold: true; color: mx.modelData.cat.color; elide: Text.ElideRight }
                                }
                            }
                            // one under the other: side by side the words do not fit in the box
                            EhStitchButton {
                                Layout.topMargin: 2
                                kind: 'paper'
                                compact: true
                                text: qsTr('I choose the coins')
                                onClicked: dialog.chooseCoins()
                            }
                            EhStitchButton {
                                kind: 'paper'
                                compact: true
                                text: qsTr('It is fine')
                                onClicked: dialog.mixOk = true
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 2; color: S.edge }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.minimumHeight: 44
                            spacing: 8
                            Label { Layout.fillWidth: true; text: qsTr('Total'); font.pixelSize: 18; font.bold: true; color: S.ink; wrapMode: Text.WordWrap }
                            Label {
                                text: finalizer.valid ? app.ehMoney(dialog.satsToAmount(finalizer.effectiveAmount.satsInt + finalizer.fee.satsInt)) : '…'
                                font.family: SerifFont ? SerifFont : font.family
                                font.weight: Font.ExtraBold
                                font.pixelSize: 24
                                color: S.wine
                            }
                        }
                    }
                }

                // address card: first and last 4 letters, tap to enlarge
                EhSheet {
                    visible: !dialog.needsDouble
                    topPadding: 8
                    bottomPadding: 8
                    ColumnLayout {
                        id: addrCol
                        Layout.fillWidth: true
                        spacing: 6
                        Label {
                            Layout.fillWidth: true
                            text: qsTr('TO THIS ADDRESS')
                            font.pixelSize: 16
                            font.bold: true
                            font.letterSpacing: 0.5
                            color: S.wine
                            wrapMode: Text.WordWrap
                        }
                        EhDotLine { Layout.topMargin: -2 }
                        Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            textFormat: Text.RichText
                            id: sAddr
                            text: app.ehAddressRich(dialog.invoice ? dialog.invoice.address : '', S.wineDark, S.highlight,
                                                    Math.max(1, Math.floor((width + sFm.averageCharacterWidth) / (sFm.averageCharacterWidth * 5))))
                            font.family: FixedFont
                            font.bold: true
                            font.pixelSize: 18
                            color: S.ink
                            lineHeight: 1.25
                            FontMetrics { id: sFm; font: sAddr.font }
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: addrCol.width
                            spacing: 6
                            Image { source: Qt.resolvedUrl('../../icons/eh_zoom.svg'); sourceSize.width: 20; sourceSize.height: 20 }
                            Label { Layout.fillWidth: true; text: qsTr('tap to enlarge'); font.pixelSize: 16; font.bold: true; color: S.muted; wrapMode: Text.WordWrap }
                        }
                        TapHandler { onTapped: app.ehZoomAddress(dialog.invoice.address, false) }
                    }
                }

                EhInfoBox {
                    id: askL
                    kind: 'warn'
                    readonly property var parts: app.ehAddressParts(dialog.invoice ? dialog.invoice.address : '')
                    text: (parts.prefix !== ''
                           ? qsTr('<b>Ask the person receiving</b> what comes after %1 and how their address ends:').arg(parts.prefix)
                           : qsTr('<b>Ask the person receiving</b> how their address starts and ends:'))
                          + ' <b>' + (parts.prefix !== '' ? parts.prefix + ' ' : '') + parts.first + ' … ' + parts.last + '</b>'
                }

                // big payment: the PIN comes after the coin
                EhInfoBox {
                    id: pinNote
                    visible: dialog.needsPin
                    kind: 'warn'
                    icon: 'eh_lock_brass.svg'
                    text: qsTr('<b>It is a big payment</b> (more than %1). When you have pushed the two sliding bitcoin coins to the right, I will ask you for the PIN.').arg(app.ehBigLimitText())
                }

                Label {
                    visible: finalizer.warning !== ''
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: S.wine
                    font.pixelSize: 16
                    text: finalizer.warning
                }

                EhInfoBox {
                    id: maxNote
                    visible: dialog.useMax
                    kind: 'warn'
                    text: qsTr('You send <b>everything you have</b>. The sending cost is already taken off: the wallet will be left at zero.')
                }

                EhInfoBox {
                    id: irrL
                    kind: 'danger'
                    text: '<b>' + qsTr('It cannot be undone.') + '</b> ' + qsTr('Once sent, only the person who receives them can give them back.')
                }

                EhInfoBox {
                    id: dblL
                    visible: dialog.needsDouble
                    kind: 'danger'
                    text: '<b>' + qsTr('It is a big amount.') + '</b> ' + qsTr('Push <b>both coins to the right together</b>, with two fingers.')
                }

            }
            }

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: 16
                font.bold: true
                lineHeight: 1.0
                color: sl1.locked !== sl2.locked ? S.oliveInk : S.ink
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
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr('Sent!')
                font.family: SerifFont ? SerifFont : font.family
                font.weight: Font.ExtraBold
                font.pixelSize: 26
                color: S.wineDark
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: col.width
                text: dialog.sentEuro !== '' ? dialog.sentEuro : dialog.sentBtc
                font.family: SerifFont ? SerifFont : font.family
                font.weight: Font.ExtraBold
                font.pixelSize: 44
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 24
                color: S.wine
            }
            Label { Layout.alignment: Qt.AlignHCenter; text: qsTr('have left'); font.pixelSize: 16; color: S.muted }
            EhInfoBox {
                id: sentNote
                kind: 'warn'
                text: qsTr('They reach the other person after the <b>first confirmation</b>, usually about ten minutes. In the list of movements you will see "⏳ Unconfirmed" and then "✓ Confirmed".')
            }
            EhStitchButton {
                kind: 'paper'
                icon: 'eh_info.svg'
                text: qsTr('More information')
                onClicked: app.ehShowConfirmationsInfo()
            }
        }
        Item { visible: dialog.phase === 'sent'; Layout.fillHeight: true }
        EhStitchButton {
            visible: dialog.phase === 'sent'
            kind: 'wine'
            icon: 'eh_home_ivory.svg'
            text: qsTr('Back to home')
            onClicked: dialog.doAccept()
        }
    }
    }

    TxFinalizer {
        id: finalizer
        wallet: Daemon.currentWallet
        canRbf: true
        // owner 12/11: every payment starts from the middle of the slider, "in about 1 hour" (eta:5)
        Component.onCompleted: { method = 1; sliderPos = 4 }
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
        color: S.parch
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
                color: S.wineDark
                font.family: SerifFont ? SerifFont : font.family
                font.weight: Font.ExtraBold
                font.pixelSize: 26
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width
                text: finalizer.valid ? app.ehMoney(dialog.satsToAmount(finalizer.effectiveAmount.satsInt + finalizer.fee.satsInt)) : ''
                color: S.wine
                font.family: SerifFont ? SerifFont : font.family
                font.weight: Font.ExtraBold
                font.pixelSize: 30
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 20
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width
                readonly property var parts: app.ehAddressParts(dialog.invoice ? dialog.invoice.address : '')
                text: qsTr('to %1').arg((parts.prefix !== '' ? parts.prefix + ' ' : '') + parts.first + ' … ' + parts.last)
                font.family: FixedFont
                font.pixelSize: 17
                font.bold: true
                color: S.ink
                wrapMode: Text.WordWrap
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
                        c.strokeStyle = S.sand
                        c.beginPath(); c.arc(95, 95, 84, 0, 2 * Math.PI); c.stroke()
                        if (part > 0) {
                            c.strokeStyle = S.bitcoin
                            c.beginPath(); c.arc(95, 95, 84, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * part); c.stroke()
                        }
                    }
                }
                Label {
                    anchors.centerIn: parent
                    text: Math.max(0, dialog.countdown)
                    color: S.bitcoin
                    font.family: SerifFont ? SerifFont : font.family
                    font.weight: Font.ExtraBold
                    font.pixelSize: 96
                }
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr('Until zero you can still stop it.')
                color: S.muted
                font.pixelSize: 17
            }
            EhStitchButton {
                id: cdCancel
                Layout.topMargin: 12
                kind: 'paper'
                icon: 'eh_cross.svg'
                text: qsTr('Cancel')
                onClicked: dialog.cancelCountdown()
            }
        }
    }

}
