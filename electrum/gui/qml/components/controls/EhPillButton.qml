// Easy Heirs (schèi): big pill button of the "Colline del vino" style.
// A round tile on the left holds an icon or a flag; soft shadow underneath.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    property string text
    property color color: '#ffffff'          // button colour
    property color textColor: '#2a2220'
    property color tileColor: '#efe6d3'
    property bool outlined: true             // thin beige ring (for light buttons)
    property real fontSize: 25
    default property alias tileContent: tile.data

    signal clicked

    implicitHeight: 92
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight

    // soft shadow: a few transparent layers, larger and fainter
    Repeater {
        model: 4
        Rectangle {
            required property int index
            anchors.fill: body
            anchors.margins: -index * 2
            anchors.topMargin: -index * 2 + 5 + index
            radius: body.radius + index * 2
            color: '#2a2220'
            opacity: 0.06 - index * 0.012
        }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: height / 2
        color: tap.pressed ? Qt.darker(root.color, 1.08) : root.color
        border.width: root.outlined ? 2 : 0
        border.color: '#e2d7c1'

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 22
            spacing: 16

            Rectangle {
                id: tile
                Layout.preferredWidth: 62
                Layout.preferredHeight: 62
                radius: 31
                color: root.tileColor
            }

            Label {
                Layout.fillWidth: true
                text: root.text
                color: root.textColor
                font.pixelSize: root.fontSize
                font.bold: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }

    TapHandler {
        id: tap
        onTapped: root.clicked()
    }
}
