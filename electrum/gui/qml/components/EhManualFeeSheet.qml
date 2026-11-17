// Easy Heirs (schȅi), owner Q8 (16/11): "How much to pay the miner?". Shown when the servers
// give NO fee estimate (Electrum would stop, or use 150 sat/vB): the wallet does not guess,
// the user writes the fee by hand, in sat/vB with one decimal (0,7). The link only opens
// mempool.space in the browser: the wallet itself never asks mempool.space anything.
//  - start: 2 sat/vB on test networks; on mainnet the last fee written by hand (eh_manual_feerate)
//  - − / +: 0,1 below 2 sat/vB, 1 from 2 up; minimum 0,1; the number can be typed (comma or dot)
//  - under 1 sat/vB a note; over 100 sat/vB or more than 10 % of the amount: "Are you sure?"
//   EhManualFeeSheet { finalizer: f; amountSats: 25000; onChosen: (rate) => ...; onCancelled: ... }
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "controls"
import "controls/EhStyle.js" as S

EhBottomSheet {
    id: root

    property var finalizer
    property real amountSats: 0             // what is sent, for the "more than 10 %" check
    property string startRate: ''           // '' = 2 on testnet, the last one on mainnet
    signal chosen(string rate)              // rate with the dot, e.g. '0.7'
    signal cancelled

    readonly property real highRate: 100
    property string rate: '2'               // with the dot
    property string typed: ''               // what is typed on the keypad, with the comma
    property bool padOpen: false
    property bool askHigh: false            // the red "Are you sure?" is shown
    property bool _done: false

    readonly property real rateNum: Number(rate)
    readonly property int costSats: finalizer ? finalizer.ehCostForRate(rate) : -1
    readonly property real minRate: finalizer ? finalizer.ehServerMinFeerate() : 0
    readonly property bool tooLow: rateNum < minRate - 0.0001
    readonly property bool isHigh: rateNum > highRate
                                   || (costSats > 0 && amountSats > 0 && costSats > amountSats * 0.1)
    // little room (e.g. 360x740 with the Android bars): the two buttons side by side
    readonly property bool tight: _room < 700
    readonly property bool slowNote: !tooLow && rateNum < 1
    function shown(r) { return ('' + r).replace('.', app.ehLocale().decimalPoint) }
    function costText() { return costSats >= 0 ? app.ehBtc(costSats) : '…' }
    function step(up) {
        typed = ''
        askHigh = false
        rate = finalizer ? finalizer.ehFeeStep(rate, up) : rate
    }
    function press(k) {
        var t = typed
        if (k === 'del') t = t.slice(0, -1)
        else if (k === ',') { if (t.indexOf(',') < 0) t = (t === '' ? '0' : t) + ',' }
        else {
            var d = t.indexOf(',')
            if (d >= 0 && t.length - d > 1) return          // one decimal is enough
            if (t.replace(',', '').length >= 4) return
            if (t === '0') t = ''
            t += k
        }
        typed = t
        askHigh = false
        var r = finalizer ? finalizer.ehParseFeerate(t) : ''
        if (r !== '') rate = r
    }
    function go() {
        if (isHigh && !askHigh) { askHigh = true; padOpen = false; return }
        _done = true
        root.chosen(rate)
        root.close()
    }

    Component.onCompleted: {
        var r = finalizer ? finalizer.ehParseFeerate(startRate) : ''
        rate = r !== '' ? r : '2'
    }
    onClosed: if (!_done) { _done = true; root.cancelled() }

    EhTitle {
        text: qsTr('How much to pay the miner?')
        fontSize: root.tight ? app.ehFsStrong : app.ehFsStrong
        Layout.bottomMargin: 0
    }
    // while the keypad is open the explanation and the link step aside (the keys need the room)
    EhInfoBox {
        visible: !root.padOpen
        kind: 'warn'
        icon: 'eh_warn.svg'
        text: '<b>' + qsTr('Today the servers do not say the right fee.') + '</b> '
              + qsTr('Write it yourself: it is what you pay for each «little piece» of the transaction (sat/vB).')
    }
    // the user's choice: it opens the browser, the wallet does not fetch anything
    Item {
        id: linkBtn
        visible: !root.padOpen && !root.askHigh
        Layout.fillWidth: true
        Layout.preferredHeight: linkRow.implicitHeight + 22
        Rectangle {     // hard 3 px shadow, as the paper buttons
            y: 3
            width: parent.width
            height: parent.height
            radius: 18
            color: S.edgeShadow
        }
        Rectangle {
            id: linkBody
            anchors.fill: parent
            radius: 18
            color: linkTap.pressed ? S.sand : S.paper
            border.width: 1.5
            border.color: S.edge
        }
        EhDashedBorder {
            anchors.fill: linkBody
            inset: 5
            radius: linkBody.radius - inset
            lineWidth: 1.6
            color: S.wine
        }
        RowLayout {
            id: linkRow
            x: 16
            width: parent.width - 32
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    Layout.fillWidth: true
                    text: qsTr('Look on mempool.space')
                    color: S.wine
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: app.ehFsText
                    font.bold: true
                    wrapMode: Text.WordWrap
                }
                Label {
                    Layout.fillWidth: true
                    text: qsTr('Take the number of «Medium priority»')
                    color: S.muted
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: app.ehFsText
                    wrapMode: Text.WordWrap
                }
            }
            Image {
                Layout.alignment: Qt.AlignVCenter
                source: Qt.resolvedUrl('../../icons/eh_open_wine.svg')
                sourceSize.width: 22
                sourceSize.height: 22
            }
        }
        TapHandler {
            id: linkTap
            onTapped: if (root.finalizer) Qt.openUrlExternally(root.finalizer.ehMempoolUrl())
        }
    }
    Label {
        text: qsTr('FEE')
        color: S.oliveInk
        font.pixelSize: app.ehFsSmall
        font.bold: true
        font.letterSpacing: 1
        Layout.topMargin: 0
        Layout.bottomMargin: -8
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Rectangle {
            id: stepper
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: 16
            color: S.paper
            border.width: 2
            border.color: root.askHigh || root.tooLow ? S.wine : (root.padOpen ? S.wine : S.edge)
            clip: true
            RowLayout {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 0
                Rectangle {
                    id: minusKey
                    Layout.preferredWidth: 58
                    Layout.fillHeight: true
                    radius: 14
                    color: minusTap.pressed ? S.sand : '#efe3c3'
                    opacity: root.rateNum <= 0.1 ? 0.4 : 1
                    Label { anchors.centerIn: parent; text: '−'; font.pixelSize: app.ehFsBox; font.bold: true; color: S.wine }
                    TapHandler { id: minusTap; onTapped: root.step(false) }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Label {
                        id: rateLabel
                        anchors.centerIn: parent
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: root.typed !== '' ? root.typed.replace(',', app.ehLocale().decimalPoint) : root.shown(root.rate)
                        color: S.wineDark
                        font.family: SerifFont ? SerifFont : font.family
                        font.weight: Font.ExtraBold
                        font.pixelSize: app.ehFsBox
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 18
                    }
                    TapHandler { onTapped: { root.padOpen = !root.padOpen; root.typed = '' } }
                }
                Rectangle {
                    id: plusKey
                    Layout.preferredWidth: 58
                    Layout.fillHeight: true
                    radius: 14
                    color: plusTap.pressed ? S.sand : '#efe3c3'
                    Label { anchors.centerIn: parent; text: '+'; font.pixelSize: app.ehFsBox; font.bold: true; color: S.wine }
                    TapHandler { id: plusTap; onTapped: root.step(true) }
                }
            }
        }
        Label {
            text: 'sat/vB'
            font.pixelSize: app.ehFsText
            font.bold: true
            color: S.muted
        }
    }
    GridLayout {
        visible: root.padOpen
        Layout.fillWidth: true
        columns: 3; rowSpacing: 8; columnSpacing: 8
        Repeater {
            model: ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', 'del']
            delegate: EhKey {
                required property string modelData
                implicitHeight: 52
                text: modelData === ',' ? app.ehLocale().decimalPoint : modelData
                isDelete: modelData === 'del'
                onActivated: root.press(modelData)
            }
        }
    }
    // what it costs, live, with the real size of this payment
    Rectangle {
        visible: !root.askHigh
        Layout.fillWidth: true
        Layout.preferredHeight: costCol.implicitHeight + 16
        radius: 14
        color: root.slowNote ? S.ivory : S.paper
        border.width: 2
        border.color: root.slowNote ? S.gold : S.edge
        Column {
            id: costCol
            x: 12
            y: 8
            width: parent.width - 24
            spacing: 4
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                font.pixelSize: app.ehFsText
                color: S.ink
                text: qsTr('This sending costs about %1').arg('<b>' + root.costText() + '</b>')
            }
            // under 1 sat/vB: the note goes here, in the same box
            Label {
                visible: root.slowNote
                width: parent.width
                wrapMode: Text.WordWrap
                font.pixelSize: app.ehFsText
                color: S.waitInk
                text: qsTr('Under 1 sat/vB it can take a long time to arrive.')
            }
        }
    }
    EhInfoBox {
        visible: !root.askHigh && root.tooLow
        kind: 'danger'
        text: '<b>' + qsTr('Too low.') + '</b> '
              + qsTr('The connected server accepts at least %1 sat/vB.').arg(root.shown(root.minRate.toFixed(1)))
    }
    EhInfoBox {
        visible: root.askHigh
        kind: 'danger'
        text: qsTr('%1 sat/vB is <b>very high</b>: this sending would cost about %2. Are you sure?')
              .arg(root.shown(root.rate)).arg(root.costText())
    }
    GridLayout {
        Layout.fillWidth: true
        columns: root.tight && !root.askHigh ? 2 : 1
        columnSpacing: 10
        rowSpacing: 12
        EhStitchButton {
            kind: 'wine'
            endIcon: root.askHigh || root.tight ? '' : 'next'
            // controllo-mainnet 3.2: a number typed that is not valid (e.g. "0,0") never goes on
            // with the rate that was there before
            enabled: !root.tooLow && root.costSats >= 0
                     && (root.typed === '' || (root.finalizer !== null && root.finalizer.ehParseFeerate(root.typed) !== ''))
            text: root.askHigh ? qsTr('Yes, continue anyway') : qsTr('Fine, continue')
            onClicked: root.go()
        }
        EhStitchButton {
            Layout.fillWidth: !(root.tight && !root.askHigh)
            Layout.preferredWidth: root.tight && !root.askHigh ? Math.max(implicitWidth, 116) : -1
            kind: 'paper'
            text: root.askHigh ? qsTr('Change the number') : qsTr('Cancel')
            onClicked: if (root.askHigh) root.askHigh = false; else root.close()
        }
    }
}
