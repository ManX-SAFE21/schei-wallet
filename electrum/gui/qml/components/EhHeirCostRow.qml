// Easy Heirs (schȅi), owner 17/11: the cost of the operation that cancels the envelope in force
// (renewal, "Cancel the inheritance", a longer period). Chosen LIKE A PAYMENT: the same row as the
// send page (cost, when it arrives, "tap to change it"), the same speed page (EhFeeDialog, starts
// from "in about 1 hour") and, when the servers give no estimate, the same "How much to pay the
// miner?" (EhManualFeeSheet). Never the 20 sat/vB of the dated envelopes.
// The row prices the real transaction: the will coins (state.invalidate.coins) -> one own address,
// all of it. commit(bal) hands that cost to the bridge right before renew()/cancelWill()/confirm().
//   EhHeirCostRow { id: cost; heirSt: root.st }   ...   if (!cost.commit(bal)) return
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.electrum 1.0

import "controls"
import "controls/EhStyle.js" as S

Item {
    id: root
    objectName: "ehHeirCostRow"
    property var heirSt: ({})   // app.ehHeirState(bal) of the page that holds the row
    readonly property var coins: heirSt && heirSt.invalidate ? (heirSt.invalidate.coins || []) : []
    readonly property string to: heirSt && heirSt.invalidate ? (heirSt.invalidate.to || '') : ''
    readonly property bool ready: finalizer.valid && finalizer.fee.satsInt > 0
    property bool byHand: false             // written by hand (no estimate from the servers)
    property string rateByHand: ''          // sat/vB with the dot
    property bool _dlgOpen: false
    property var _sheet: null

    Layout.fillWidth: true
    implicitHeight: Math.max(64, costRow.implicitHeight + 10)
    visible: root.coins.length > 0

    TxFinalizer {
        id: finalizer
        wallet: Daemon.currentWallet
        canRbf: true
        // like a payment: every time from the middle of the slider, "in about 1 hour"
        Component.onCompleted: { method = 1; sliderPos = 4 }
    }
    // no estimate yet (the servers often send it a few seconds after the app opens): try again
    // every 3 seconds; the "by hand" sheet opens only when the person taps the row or goes on
    Timer {
        interval: 3000
        repeat: true
        running: root.visible && finalizer.ehNoEstimate && !root.byHand
        onTriggered: finalizer.doUpdate()
    }
    function price() {
        if (root.coins.length === 0 || root.to === '') return
        finalizer.ehCoins = root.coins
        finalizer.address = root.to
        finalizer.amount = MAX
        finalizer.doUpdate()
    }
    // before the PIN: true when there is a cost; without an estimate it opens "by hand"
    function ensure() {
        if (root.ready) return true
        if (finalizer.ehNoEstimate) root.askFee()
        return false
    }
    onCoinsChanged: price()
    onToChanged: price()
    Component.onCompleted: price()

    // the bridge gets the cost of THIS operation, right before it starts
    function commit(bal) {
        if (!bal || !root.ready) return false
        bal.setInvalidationFee({ sats: finalizer.fee.satsInt, rate: Number(finalizer.feeRate) || 0,
                                 coins: root.coins })
        return true
    }

    function chooseFee() {
        if (root.byHand || finalizer.ehNoEstimate) { root.askFee(); return }
        var d = Qt.createComponent(Qt.resolvedUrl('EhFeeDialog.qml')).createObject(app, { finalizer: finalizer })
        root._dlgOpen = true
        d.closed.connect(function() { d.destroy(); root._dlgOpen = false })
        d.open()
    }
    function askFee() {
        if (root._sheet) return
        var start = root.rateByHand !== '' ? root.rateByHand
                    : (app.ehTest ? '' : (Config.ehGet('manual_feerate') || ''))
        var d = Qt.createComponent(Qt.resolvedUrl('EhManualFeeSheet.qml')).createObject(app, {
            finalizer: finalizer, amountSats: Number(finalizer.effectiveAmount ? finalizer.effectiveAmount.satsInt : 0) || 0,
            startRate: '' + start })
        root._sheet = d
        d.chosen.connect(function(rate) {
            root.byHand = true
            root.rateByHand = rate
            if (!app.ehTest) Config.ehSet('manual_feerate', rate)
            finalizer.ehSetManualFeerate(rate)
        })
        d.closed.connect(function() { root._sheet = null; d.destroy() })
        d.open()
    }

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
                text: qsTr('Cost of the operation') + ' <font color="' + S.muted + '">' + qsTr('(tip to the miners)') + '</font>'
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                color: S.ink
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.byHand ? app.ehFeeRate(root.rateByHand + ' sat/vB')
                      : finalizer.userFeerate !== '' ? app.ehFeeRate(finalizer.userFeerate + ' sat/vB')
                      : finalizer.ehNoEstimate ? qsTr('to be written by hand')
                      : app.ehFeeEta(finalizer.sliderPos)
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                color: S.muted
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr('tap to change it')
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                font.bold: true
                font.underline: true
                color: S.wine
            }
        }
        Label {
            text: root.ready ? app.ehMoney(finalizer.fee) : '…'
            font.family: SerifFont ? SerifFont : font.family
            font.weight: Font.ExtraBold
            font.pixelSize: app.ehFsStrong
            color: S.wineDark
        }
        Label { text: '›'; font.pixelSize: app.ehFsBox; font.bold: true; color: S.wine }
    }
    TapHandler { id: costTap; onTapped: root.chooseFee() }
}
