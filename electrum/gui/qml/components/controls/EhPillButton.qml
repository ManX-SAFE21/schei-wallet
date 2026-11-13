// Easy Heirs (schèi): big pill button of the "Colline del vino" style.
// "Bottega" (WP1, plan section 2 "Migration"): it is now a thin wrapper over EhStitchButton,
// height 60: color picks the kind (wine-ish -> 'wine', olive-ish -> 'olive', light -> 'paper');
// the children of the old round tile go in the icon place, on a small disc of tileColor (so the
// old dark icons stay visible on leather). fontSize / textColor / outlined are ignored.
// The pages then move to EhStitchButton directly (WP2-WP6) and this file goes away.
//
// Kept exactly as before when the user forces a tall button (> 84 px): the home "buttons
// instead of the bar" option and the language picker size it 92 and draw their own ring /
// stitching around it, so they must not change here.
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
    default property alias tileContent: holder.data

    signal clicked

    readonly property bool legacy: height > 84
    readonly property bool light: color.r > 0.8 && color.g > 0.8 && color.b > 0.8

    implicitHeight: 60
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight

    // ---------------- the stitched button (every page) ----------------
    EhStitchButton {
        id: stitched
        visible: !root.legacy
        anchors.fill: parent
        kind: root.light ? 'paper' : ((root.color.g > root.color.r) ? 'olive' : 'wine')
        text: root.text
        enabled: root.enabled
        onClicked: root.clicked()
        // place of the old tile's children (they are drawn by `holder`, above)
        Item { width: 34; height: 34; anchors.centerIn: parent }
        iconSize: 34
    }
    Rectangle {
        // small disc behind the old tile children, in the old tile colour
        visible: !root.legacy && holder.children.length > 0
        x: 16
        y: (root.height - height) / 2
        width: 34; height: 34; radius: 17
        color: root.tileColor
    }

    // ---------------- the old pill (only when forced tall, see above) ----------------
    Item {
        anchors.fill: parent
        visible: root.legacy

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
            enabled: root.legacy
            onTapped: root.clicked()
        }
    }

    // the old tile's children (62 x 62 box): over the old tile, or scaled into the small disc
    Item {
        id: holder
        width: 62
        height: 62
        x: root.legacy ? 14 : 16 + 17 - 31
        y: (root.height - 62) / 2
        scale: root.legacy ? 1 : 34 / 62
    }
}
