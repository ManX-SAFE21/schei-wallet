// Easy Heirs (schèi): one euro banknote, simple drawing (not the real one).
// c = value in cents (10000, 5000, 2000, 1000, 500). Size is set by the user.
import QtQuick
import QtQuick.Controls

Rectangle {
    id: nt
    property int c: 5000
    readonly property var col1: ({ 10000: '#5e9f5a', 5000: '#e08a35', 2000: '#4a78bd', 1000: '#cf5653', 500: '#87929b' })
    readonly property var col2: ({ 10000: '#3d7a3a', 5000: '#c4661b', 2000: '#2f5b9a', 1000: '#ad3837', 500: '#666f78' })
    radius: Math.max(3, height * 0.08)
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: nt.col1[nt.c] }
        GradientStop { position: 1; color: nt.col2[nt.c] }
    }
    clip: true
    Rectangle {
        anchors.fill: parent; anchors.margins: Math.max(2, parent.height * 0.06)
        radius: Math.max(2, parent.radius - 2); color: 'transparent'
        border.width: Math.max(1, parent.height * 0.03); border.color: Qt.rgba(1, 1, 1, 0.45)
    }
    Rectangle {
        width: parent.height * 0.75; height: width; radius: width / 2
        x: parent.width - width * 0.7; anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(1, 1, 1, 0.18)
    }
    Label {
        x: parent.height * 0.16; anchors.verticalCenter: parent.verticalCenter
        text: nt.c / 100
        color: '#ffffff'
        font.family: TitleFont ? TitleFont : font.family
        font.weight: Font.Black
        font.pixelSize: Math.max(7, parent.height * (nt.c >= 10000 ? 0.34 : 0.42))
    }
    Label {
        visible: parent.height > 34
        anchors.right: parent.right; anchors.rightMargin: parent.height * 0.18
        anchors.verticalCenter: parent.verticalCenter
        text: 'EURO'
        color: Qt.rgba(1, 1, 1, 0.88)
        font.family: TitleFont ? TitleFont : font.family
        font.weight: Font.Black
        font.pixelSize: Math.max(8, parent.height * 0.19)
    }
}
