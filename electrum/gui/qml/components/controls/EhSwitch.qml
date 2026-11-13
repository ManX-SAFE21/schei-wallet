// Easy Heirs (schèi), "Bottega": on/off switch. Track 60x34 (off warm grey, on olive) with a
// brass knob. It IS a Switch (only the look changes), so the API is the same as the Material
// Switch it replaces: checked, enabled, toggled() (checked is already the new value in
// onToggled) and a binding on checked is not broken by a tap. 8 px of touch room all round.
//   EhSwitch { checked: app.ehOption(key); enabled: !locked; onToggled: app.ehSetOption(key, checked) }
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

Switch {
    id: root
    property color onColor: S.olive
    property color offColor: S.switchOff

    padding: 8
    spacing: 0
    text: ''
    Layout.alignment: Qt.AlignVCenter
    opacity: enabled ? 1 : 0.5
    background: null
    contentItem: Item {}
    implicitWidth: 60 + leftPadding + rightPadding
    implicitHeight: 34 + topPadding + bottomPadding

    indicator: Item {
        x: root.leftPadding
        y: root.topPadding + (root.availableHeight - height) / 2
        implicitWidth: 60
        implicitHeight: 34

        Rectangle {
            anchors.fill: parent
            radius: 17
            color: root.checked ? root.onColor : root.offColor
            Behavior on color { enabled: !app.ehOption('no_anim'); ColorAnimation { duration: 150 } }
            // a little depth: darker at the top edge
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 1
                height: 8
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.18) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
                }
            }
        }
        // brass knob
        Rectangle {
            width: 28; height: 28; radius: 14
            y: 3
            x: root.checked ? 29 : 3
            Behavior on x { enabled: !app.ehOption('no_anim'); NumberAnimation { duration: 150 } }
            border.width: 1.5
            border.color: S.brassRing
            gradient: Gradient {
                GradientStop { position: 0.0; color: S.brassLight }
                GradientStop { position: 0.55; color: S.brass }
                GradientStop { position: 1.0; color: S.brassDark }
            }
        }
    }
}
