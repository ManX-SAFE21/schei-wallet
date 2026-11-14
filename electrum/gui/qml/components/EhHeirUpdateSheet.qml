// Easy Heirs (schȅi): "update the inheritance" (inheritance, screen 8). Opened over the home
// by main.qml ehHeirDecide when the envelope no longer covers the coins: money received,
// a payment made (owner 9.1), or an inheritance left unfinished. The PIN, then bal.update():
// free, the delivery moves one day earlier (owner 9.2). It closes when the update is done.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "controls"
import "controls/EhStyle.js" as S

EhBottomSheet {
    id: root
    property string reason: 'received'         // received | spent | changed | unfinished
    readonly property var bal: AppController.plugin('bal')
    readonly property var st: bal ? bal.state : ({})
    property string error: ''
    property bool _mine: false

    dimOpacity: 0.32
    closable: !(bal && bal.busy && _mine)

    onClosed: destroy()

    Connections {
        target: root.bal
        function onDone(op, result) {
            if (op !== 'update') return
            root._mine = false
            root.close()
        }
        function onFailed(op, code, message) {
            if (op !== 'update') return
            root._mine = false
            root.error = app.ehHeirErrorText(code, message)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        EhIconRing {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 48
            color: S.paper
            ringColor: root.reason === 'received' ? S.olive : S.wine
            iconSize: 28
            icon: root.reason === 'received' ? 'eh_rx_olive.svg'
                : root.reason === 'spent' ? 'eh_tx_wine.svg' : 'eh_will.svg'
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 17
            lineHeight: 1.15
            color: S.ink
            text: root.reason === 'received'
                  ? qsTr('You received <b>%1</b>.<br>Do I update the inheritance so it covers them too?')
                        .arg('<font color="' + S.oliveInk + '">' + app.ehHeirSats(root.st.uncoveredSats || 0) + '</font>')
                  : root.reason === 'unfinished'
                  ? qsTr('The inheritance is not finished.<br>Do I finish it now?')
                  : qsTr('You made a payment.<br>Do I update the inheritance with what is left?')
        }
    }

    Label {
        visible: root.bal !== null && root.bal.busy && root._mine
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 17
        font.bold: true
        color: S.wine
        text: root.bal ? app.ehHeirStepText(root.bal.step) : ''
    }
    EhInfoBox {
        visible: root.error !== '' && !(root.bal && root.bal.busy)
        kind: 'danger'
        text: root.error
    }

    EhStitchButton {
        kind: 'wine'
        icon: 'eh_lock_white.svg'
        endIcon: 'next'
        text: qsTr('Update with the PIN')
        enabled: !(root.bal && root.bal.busy)
        onClicked: app.ehAskPin(qsTr('Type the PIN to update the inheritance'), function() {
            if (!root.bal) return
            root.error = ''
            root._mine = true
            root.bal.update()
        })
    }
    EhInfoBox {
        kind: 'tip'
        // each free update dates the envelope one day earlier (an unfinished one keeps its date)
        text: qsTr('It costs nothing. The delivery becomes <b>%1</b>.')
                .arg(app.ehHeirDate((root.st.delivery || 0) - (root.reason === 'unfinished' ? 0 : 86400)))
    }
}
