// Easy Heirs (schèi): one banknote, simple drawing (not the real one), owner 12/11
// (preview banconote-euro-dollaro.html).
// EUR: real colours, arch in the middle, silver strip, stars, big value bottom right.
// USD: classic green, dark green frame, a coloured stripe for the value, big value.
// c = value in cents. Size is set by the user.
import QtQuick
import QtQuick.Controls

Rectangle {
    id: nt
    property int c: 5000
    property string ccy: app.ehCcy()
    readonly property bool usd: ccy === 'USD'
    readonly property var col1: ({ 10000: '#6fae6a', 5000: '#ef9a4a', 2000: '#5f8fd0', 1000: '#e0706c', 500: '#a3adb5' })
    readonly property var col2: ({ 10000: '#3f7d3b', 5000: '#c4661b', 2000: '#2f5b9a', 1000: '#ad3837', 500: '#666f78' })
    readonly property var usStripe: ({ 10000: '#5aa5c8', 5000: '#d65a6e', 2000: '#e8a87c', 1000: '#e48a2e', 500: '#9b6cc4', 100: '#7d9a6a' })
    readonly property real u: height            // unit for the drawing
    radius: Math.max(2, u * 0.07)
    clip: true
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: nt.usd ? '#dfe8d2' : (nt.col1[nt.c] || '#999999') }
        GradientStop { position: 1; color: nt.usd ? '#a9c095' : (nt.col2[nt.c] || '#666666') }
    }
    border.width: nt.usd ? Math.max(1, u * 0.05) : 0
    border.color: '#2f4a2a'

    // inner frame
    Rectangle {
        anchors.fill: parent; anchors.margins: Math.max(2, nt.u * 0.07)
        radius: Math.max(1, nt.radius - 1); color: 'transparent'
        border.width: Math.max(1, nt.u * 0.025)
        border.color: nt.usd ? Qt.rgba(0.12, 0.23, 0.11, 0.45) : Qt.rgba(1, 1, 1, 0.38)
    }
    // ---- euro: arch, silver strip, stars ----
    Rectangle {
        visible: !nt.usd && nt.u > 14
        x: parent.width * 0.30; y: nt.u * 0.22
        width: parent.width * 0.26; height: nt.u * 0.9
        radius: width / 2
        color: 'transparent'
        border.width: Math.max(1, nt.u * 0.04); border.color: Qt.rgba(1, 1, 1, 0.38)
    }
    Rectangle {
        visible: !nt.usd
        anchors.right: parent.right; anchors.rightMargin: nt.u * 0.12
        width: Math.max(2, nt.u * 0.14); height: parent.height
        gradient: Gradient {
            GradientStop { position: 0.0; color: '#e9eef2' }
            GradientStop { position: 0.35; color: '#b8c4cc' }
            GradientStop { position: 0.65; color: '#f4f6f8' }
            GradientStop { position: 1.0; color: '#aab6bf' }
        }
    }
    Label {
        visible: !nt.usd && nt.u > 22
        x: nt.u * 0.12; anchors.bottom: parent.bottom; anchors.bottomMargin: nt.u * 0.04
        text: '✦ ✦ ✦'
        color: '#ffe680'
        font.pixelSize: Math.max(5, nt.u * 0.13)
    }
    // ---- dollar: the coloured stripe of the value ----
    Rectangle {
        visible: nt.usd
        width: Math.max(3, nt.u * 0.2); height: parent.height
        color: nt.usStripe[nt.c] || '#7d9a6a'
    }
    // small value top left
    Label {
        visible: nt.u > 16
        x: nt.usd ? nt.u * 0.3 : nt.u * 0.12; y: nt.u * 0.05
        text: nt.c / 100
        color: nt.usd ? '#1f3a1d' : Qt.rgba(1, 1, 1, 0.9)
        font.family: TitleFont ? TitleFont : font.family
        font.weight: Font.Black
        font.pixelSize: Math.max(5, nt.u * 0.22)
    }
    // big value bottom right
    Label {
        anchors.right: parent.right; anchors.rightMargin: nt.usd ? nt.u * 0.14 : nt.u * 0.36
        anchors.bottom: parent.bottom; anchors.bottomMargin: nt.u * 0.02
        textFormat: Text.StyledText
        text: (nt.c / 100) + '<small>' + (nt.usd ? '$' : '€') + '</small>'
        color: nt.usd ? '#1f3a1d' : '#ffffff'
        style: nt.usd ? Text.Normal : Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.3)
        font.family: TitleFont ? TitleFont : font.family
        font.weight: Font.Black
        font.pixelSize: Math.max(7, nt.u * (nt.usd ? (nt.c >= 10000 ? 0.42 : 0.48) : (nt.c >= 10000 ? 0.32 : 0.38)))
    }
}
