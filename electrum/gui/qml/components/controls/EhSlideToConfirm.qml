// Easy Heirs (schȅi): horizontal "Scorri per inviare" slider. The knob must be
// dragged all the way to the right; released early, it goes back.
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property string text
    property url iconSource
    property bool busy: false
    signal confirmed

    implicitHeight: 76
    radius: height / 2
    opacity: enabled ? 1 : 0.45
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: '#f3e3e8' }
        GradientStop { position: 1.0; color: '#e9cdd6' }
    }

    readonly property real maxX: width - knob.width - 12

    Label {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 30
        text: root.busy ? qsTr('Sending…') : root.text + '  ›'
        font.pixelSize: 19
        font.bold: true
        color: '#5e1a33'
        opacity: 1 - knob.x / Math.max(1, root.maxX)
    }

    Rectangle {
        id: knob
        width: 64
        height: 64
        radius: 32
        y: 6
        x: 6
        color: '#5e1a33'
        Image {
            anchors.centerIn: parent
            source: root.iconSource
            sourceSize.width: 34
            sourceSize.height: 34
        }
        Behavior on x {
            enabled: !drag.active
            NumberAnimation { duration: 250; easing.type: Easing.OutBack }
        }
        DragHandler {
            id: drag
            enabled: root.enabled && !root.busy
            yAxis.enabled: false
            xAxis.minimum: 6
            xAxis.maximum: root.maxX + 6
            onActiveChanged: {
                if (!active) {
                    if (knob.x >= root.maxX - 4) {
                        AppController.haptic()
                        root.confirmed()
                    } else {
                        knob.x = 6
                    }
                }
            }
        }
    }

    function reset() { knob.x = 6 }
}
