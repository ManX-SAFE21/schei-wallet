// Easy Heirs (schèi): one euro coin, simple drawing.
// c = value in cents (200, 100, 50, 20, 10, 5, 2, 1). Size is set by the user.
import QtQuick
import QtQuick.Controls

Rectangle {
    id: cn
    property int c: 200
    readonly property bool bimetal: c >= 100
    readonly property bool copper: c < 10
    radius: width / 2
    gradient: Gradient {
        GradientStop { position: 0; color: cn.c === 200 ? '#e3e7ea' : (cn.copper ? '#e09c6e' : '#f0d88a') }
        GradientStop { position: 1; color: cn.c === 200 ? '#a9b0b6' : (cn.copper ? '#a95a34' : '#c39c3a') }
    }
    Rectangle {
        visible: cn.bimetal
        anchors.centerIn: parent
        width: parent.width * 0.68; height: width; radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: cn.c === 200 ? '#f0d88a' : '#e3e7ea' }
            GradientStop { position: 1; color: cn.c === 200 ? '#c39c3a' : '#a9b0b6' }
        }
    }
    Label {
        anchors.centerIn: parent
        textFormat: Text.StyledText
        text: cn.c >= 100 ? (cn.c / 100) + '<small>€</small>' : cn.c + '<small>c</small>'
        color: cn.copper ? '#3d1d0c' : '#3a2f12'
        font.family: TitleFont ? TitleFont : font.family
        font.weight: Font.Black
        font.pixelSize: Math.max(7, parent.width * 0.34)
    }
}
