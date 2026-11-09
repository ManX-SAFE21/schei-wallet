// Easy Heirs (schèi): plain "go on" button. Text in the middle with a golden
// arrow next to it; nothing to drag (unlike the round tile of EhPillButton).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    property string text: qsTr('Next')
    property color color: '#5e1a33'
    property color textColor: '#ffffff'
    property color arrowColor: '#d9b25a'
    property real fontSize: 23

    signal clicked

    implicitHeight: 68
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    opacity: enabled ? 1 : 0.4

    // soft shadow
    Repeater {
        model: 3
        Rectangle {
            required property int index
            anchors.fill: body
            anchors.margins: -index * 2
            anchors.topMargin: -index * 2 + 5 + index
            radius: body.radius + index * 2
            color: '#2a2220'
            opacity: 0.06 - index * 0.015
        }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: height / 2
        color: tap.pressed ? Qt.darker(root.color, 1.25) : root.color

        Row {
            anchors.centerIn: parent
            spacing: 14
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: root.textColor
                font.pixelSize: root.fontSize
                font.bold: true
            }
            Canvas {
                id: arrow
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                onPaint: {
                    var c = getContext('2d')
                    c.reset()
                    c.scale(width / 24, height / 24)
                    c.strokeStyle = root.arrowColor
                    c.lineWidth = 3
                    c.lineCap = 'round'
                    c.lineJoin = 'round'
                    c.beginPath()
                    c.moveTo(4, 12); c.lineTo(18, 12)
                    c.moveTo(13, 6); c.lineTo(19, 12); c.lineTo(13, 18)
                    c.stroke()
                }
                Connections {
                    target: root
                    function onArrowColorChanged() { arrow.requestPaint() }
                }
            }
        }
    }

    TapHandler {
        id: tap
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
