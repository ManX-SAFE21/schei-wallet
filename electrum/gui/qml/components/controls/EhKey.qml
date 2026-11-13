// Easy Heirs (schèi), "Bottega": a key of a keypad (PIN, amount, fee, letter keyboard).
// Paper, radius 18, 1.5 border, hard 3 px shadow; pressed = sand and the key "goes down" 2 px.
// Digit: Fraunces 34 wineDark. letter: true = Lexend 20 bold. isDelete: true = the delete key
// (sand fill, drawn backspace symbol in wine).
// fireOnPress: true = activated() as soon as the key is TOUCHED (PIN pad, owner 13/11: fast typing
// loses nothing); false = on a normal tap.
//   EhKey { text: '7'; onActivated: pad.press('7') }
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

Item {
    id: root
    property string text: ''
    property bool isDelete: false
    property bool letter: false
    property bool fireOnPress: false
    property real fontSize: letter ? 20 : 34
    property real keyRadius: 18
    readonly property bool down: tap.pressed
    signal activated

    implicitHeight: S.keyH
    implicitWidth: 64
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    opacity: enabled ? 1 : 0.4

    // hard shadow (hidden while pressed: the key went down)
    Rectangle {
        visible: !root.down
        y: 3
        width: parent.width
        height: parent.height - 3
        radius: root.keyRadius
        color: S.edgeShadow
    }
    Rectangle {
        id: face
        y: root.down ? 2 : 0
        width: parent.width
        height: parent.height - 3
        radius: root.keyRadius
        color: root.isDelete ? (root.down ? Qt.darker(S.sandDel, 1.08) : S.sandDel) : (root.down ? S.sand : S.paper)
        border.width: 1.5
        border.color: S.edge

        EhBackspaceIcon {
            visible: root.isDelete
            anchors.centerIn: parent
            width: 38
            height: 27
            ink: S.wine
            fill: face.color
        }
        Label {
            visible: !root.isDelete
            anchors.centerIn: parent
            text: root.text
            color: S.wineDark
            font.family: root.letter ? (BodyFont ? BodyFont : font.family) : (SerifFont ? SerifFont : font.family)
            font.weight: root.letter ? Font.Bold : Font.ExtraBold
            font.pixelSize: root.fontSize
        }
    }

    TapHandler {
        id: tap
        enabled: root.enabled
        gesturePolicy: TapHandler.DragThreshold
        onPressedChanged: if (pressed && root.fireOnPress) root.activated()
        onTapped: if (!root.fireOnPress) root.activated()
    }
}
