// Easy Heirs (schèi): one coin, simple drawing (owner 12/11: euro and US dollar).
// EUR: 2 € silver outside / gold inside, 1 € the other way round, 50-10 cent gold, 5 and 1 cent copper.
// USD: 25, 10, 5 cent silver, 1 cent copper.
// c = value in cents. Size is set by the user.
import QtQuick
import QtQuick.Controls

Rectangle {
    id: cn
    property int c: 200
    property string ccy: app.ehCcy()
    readonly property bool usd: ccy === 'USD'
    readonly property bool bimetal: !usd && c >= 100
    readonly property bool copper: usd ? c === 1 : c < 10
    readonly property bool silver: usd ? c > 1 : c === 200
    radius: width / 2
    gradient: Gradient {
        GradientStop { position: 0; color: cn.silver ? '#eef1f4' : (cn.copper ? '#f0b48a' : '#fbe7a3') }
        GradientStop { position: 1; color: cn.silver ? '#a9b0b6' : (cn.copper ? '#a95a34' : '#c9a13f') }
    }
    border.width: Math.max(1, width * 0.04)
    border.color: Qt.rgba(0, 0, 0, 0.12)
    Rectangle {
        visible: cn.bimetal
        anchors.centerIn: parent
        width: parent.width * 0.68; height: width; radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: cn.c === 200 ? '#f0d88a' : '#eef1f4' }
            GradientStop { position: 1; color: cn.c === 200 ? '#c39c3a' : '#a9b0b6' }
        }
    }
    Label {
        anchors.centerIn: parent
        textFormat: Text.StyledText
        text: cn.usd ? cn.c + '<small>¢</small>'
                     : (cn.c >= 100 ? (cn.c / 100) + '<small>€</small>' : cn.c + '<small>c</small>')
        color: cn.copper ? '#3d1d0c' : '#3a2f12'
        font.family: TitleFont ? TitleFont : font.family
        font.weight: Font.Black
        font.pixelSize: Math.max(7, parent.width * 0.32)
    }
}
