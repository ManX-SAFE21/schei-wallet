// Easy Heirs (schèi): the inside of the wallet (T37). It stays BEHIND the card: when the coin
// is pulled down the card leans forward and this part rises, showing the dark lining, two
// banknotes and the card slots, like a real bifold wallet that opens.
import QtQuick

Item {
    id: root
    property color baseColor: '#5e1a33'
    property real openK: 0          // 0 closed .. 1 open

    visible: openK > 0.01
    // only the part ABOVE the front shows (the front is see-through: nothing must show through it)
    readonly property real rise: 70 * openK
    readonly property real frontTop: height * 0.22 * openK     // how much the front came down
    Item {
        id: clipBox
        x: 0
        y: -root.rise
        width: root.width
        height: root.rise + root.frontTop + 2
        clip: true
    Item {
        width: root.width
        height: root.height
    Rectangle {
        anchors.fill: parent
        radius: 20
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.darker(root.baseColor, 1.15) }
            GradientStop { position: 1.0; color: '#2a0b18' }
        }
    }
    // the lining
    Rectangle {
        id: lining
        x: 8; y: 8
        width: parent.width - 16
        height: 96
        radius: 14
        gradient: Gradient {
            GradientStop { position: 0.0; color: '#1a0610' }
            GradientStop { position: 0.7; color: '#33101f' }
        }
        // stitching
        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: 10
            color: 'transparent'
            border.width: 1.3
            border.color: Qt.rgba(1, 0.91, 0.77, 0.3)
        }
        // card slots
        Repeater {
            model: 3
            Rectangle {
                required property int index
                x: 18; y: 30 + index * 14
                width: 88; height: 12
                radius: 3
                color: Qt.rgba(0, 0, 0, 0.25)
                Rectangle { width: parent.width; height: 2; color: Qt.rgba(1, 0.91, 0.77, 0.35) }
            }
        }
        // two banknotes sticking out
        Rectangle {
            x: parent.width - 150; y: 14
            width: 120; height: 40; radius: 4
            rotation: -4
            gradient: Gradient { GradientStop { position: 0; color: '#7fb36d' } GradientStop { position: 1; color: '#4f8f4a' } }
        }
        Rectangle {
            x: parent.width - 140; y: 20
            width: 120; height: 40; radius: 4
            rotation: 3
            gradient: Gradient { GradientStop { position: 0; color: '#9cc7e6' } GradientStop { position: 1; color: '#5d93c0' } }
        }
    }
    }
    }
}
