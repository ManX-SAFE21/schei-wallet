// Easy Heirs (schȅi), "Bottega": the back link at the top of a page: "‹ Indietro", Lexend 17
// bold wine with a 2 px wine underline; 48 px touch height. It pulls itself up 14 px (the old
// hand-made links used Layout.topMargin: -14 under EhPageTop): override it if needed.
//   EhBackLink { onClicked: app.stack.pop() }
//   EhBackLink { text: '‹ ' + qsTr('Movements'); onClicked: ... }
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

Item {
    id: root
    property string text: '‹ ' + qsTr('Back')
    property color color: S.wine
    signal clicked

    implicitWidth: lbl.implicitWidth
    implicitHeight: 48
    Layout.topMargin: -14
    Layout.preferredHeight: 48
    Layout.alignment: Qt.AlignLeft

    Label {
        id: lbl
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.color
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 17
        font.bold: true
        opacity: tap.pressed ? 0.6 : 1
    }
    Rectangle {
        x: lbl.x
        y: lbl.y + lbl.height + 1
        width: lbl.width
        height: 2
        color: root.color
        opacity: lbl.opacity
    }
    TapHandler {
        id: tap
        margin: 8
        onTapped: root.clicked()
    }
}
