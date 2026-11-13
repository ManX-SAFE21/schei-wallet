// Easy Heirs (schèi), "Bottega": level tag MEDIO / ESPERTO (14 bold caps: one of the allowed
// texts under 16 px). Paper fill, 1.5 border; olive = MEDIO (level 1), wine = ESPERTO (2).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

Rectangle {
    id: root
    property int level: 0
    visible: level > 0
    readonly property color ink: level === 2 ? S.wine : S.olive
    implicitWidth: tagL.implicitWidth + 12
    implicitHeight: tagL.implicitHeight + 2
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    radius: 6
    color: S.paper
    border.width: 1.5
    border.color: ink
    Label {
        id: tagL
        anchors.centerIn: parent
        text: root.level === 2 ? qsTr('EXPERT') : qsTr('MEDIUM')
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 14
        font.bold: true
        font.letterSpacing: 0.4
        color: root.ink
    }
}
