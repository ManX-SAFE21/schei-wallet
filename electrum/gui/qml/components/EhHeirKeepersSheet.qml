// Easy Heirs (schȅi): Settings › Inheritance › "How many keepers" (owner 15/11, point 4c):
// 3 (default), 5, 7 … 19 (state.keepersChoices), bal.setKeepers(n). The number counts from
// the next envelope (a new inheritance, an update or a renewal).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "controls"
import "controls/EhStyle.js" as S

EhBottomSheet {
    id: root
    readonly property var bal: AppController.plugin('bal')
    readonly property var st: bal ? bal.state : ({})
    readonly property var choices: st.keepersChoices || [3, 5, 7, 9, 11, 13, 15, 17, 19]
    readonly property int wanted: st.keepersWanted || 3
    property string error: ''
    onClosed: destroy()

    Connections {
        target: root.bal
        function onFailed(op, code, message) {
            if (op !== 'setKeepers' || code === 'busy') return
            root.error = app.ehHeirErrorText(code, message)
        }
    }

    EhTitle {
        text: qsTr('How many keepers?')
        icon: 'eh_shield_olive.svg'
        fontSize: app.ehFsBox
        Layout.bottomMargin: 0
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.StyledText
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: app.ehFsText
        lineHeight: 1.15
        color: S.ink
        text: qsTr('The envelope goes to several keepers: if one switches off, the others send it. More keepers is safer; at the delivery only one is paid. The new number counts from the next envelope (update or renewal).')
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 5
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: root.choices
            delegate: Rectangle {
                id: chip
                required property int modelData
                readonly property bool on: modelData === root.wanted
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 14
                color: on ? S.leatherWine2 : (chipTap.pressed ? S.sand : S.paper)
                border.width: 2
                border.color: on ? S.wineDark : S.edge
                Label {
                    anchors.centerIn: parent
                    text: chip.modelData
                    color: chip.on ? S.ivory : S.wine
                    font.family: SerifFont ? SerifFont : font.family
                    font.weight: Font.ExtraBold
                    font.pixelSize: app.ehFsStrong
                }
                TapHandler {
                    id: chipTap
                    enabled: !(root.bal && root.bal.busy)
                    onTapped: if (root.bal && !chip.on) { root.error = ''; root.bal.setKeepers(chip.modelData) }
                }
            }
        }
    }
    Label {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: app.ehFsSmall
        color: S.muted
        text: qsTr('%1 (default)').arg(3)
    }
    EhInfoBox {
        visible: root.error !== ''
        kind: 'danger'
        text: root.error
    }
    EhStitchButton {
        kind: 'paper'
        text: qsTr('Close')
        onClicked: root.close()
    }
}
