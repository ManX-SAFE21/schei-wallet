// Easy Heirs (schèi): the steps to do, as icons joined by a line, at the top
// of the page over the hills (like the Àncòra plugin and the offline multisig).
// Done steps: green with a tick; the current one: wine and bigger; later: light.
// Tapping a step that is done goes back to it (the data typed stay); the current
// step and the next ones only show a small bubble that explains them.
// steps: [{ icon: 'qr', title: '...', text: '...' }, ...]   current: 1-based
import QtQuick
import QtQuick.Controls

Item {
    id: root
    property var steps: []
    property int current: 1
    property bool allowBack: true      // false once the money has left
    signal stepClicked(int n)
    readonly property real small: 44
    readonly property real big: 52

    implicitHeight: big + 6 + 20      // circles + the short word under each one

    // the line that joins the icons: a light track, green where it is done
    Rectangle {
        id: track
        x: small / 2
        width: root.width - small
        y: root.big / 2 + 3 - height / 2
        height: 8
        radius: 4
        color: Qt.rgba(1, 1, 1, 0.82)
        border.width: 1
        border.color: Qt.rgba(0.27, 0.33, 0.12, 0.25)
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            anchors.leftMargin: 2
            radius: 2
            color: '#45541f'
            width: root.steps.length > 1 ? Math.max(0, (track.width - 4) * (root.current - 1) / (root.steps.length - 1)) : 0
        }
    }

    Repeater {
        model: root.steps
        delegate: Item {
            id: st
            required property var modelData
            required property int index
            readonly property int n: index + 1
            readonly property bool done: n < root.current
            readonly property bool now: n === root.current
            readonly property real d: now ? root.big : root.small
            width: d
            height: d
            y: root.big / 2 + 3 - d / 2
            x: root.steps.length > 1 ? (root.small / 2 + (root.width - root.small) * index / (root.steps.length - 1)) - d / 2 : 0

            // soft light behind the current step
            Rectangle {
                visible: st.now
                anchors.centerIn: parent
                width: parent.width + 12
                height: width
                radius: width / 2
                color: Qt.rgba(0.37, 0.10, 0.20, 0.18)
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: st.done ? Qt.rgba(0.27, 0.33, 0.12, 0.92)
                     : st.now ? Qt.rgba(0.37, 0.10, 0.20, 0.94)
                     : Qt.rgba(1, 1, 1, 0.82)
                border.width: st.done || st.now ? 0 : 2
                border.color: '#d8cdb8'
                scale: stTap.pressed ? 0.92 : 1
                Image {
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl('../../../icons/eh_st_' + st.modelData.icon + (st.done ? '_d' : (st.now ? '' : '_g')) + '.svg')
                    sourceSize.width: st.now ? 26 : 22
                    sourceSize.height: st.now ? 26 : 22
                }
            }
            // small tick on the done ones
            Rectangle {
                visible: st.done
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -3
                anchors.bottomMargin: -3
                width: 18; height: 18; radius: 9
                color: '#ffffff'
                border.width: 2
                border.color: '#45541f'
                Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../../icons/eh_st_check_o.svg'); sourceSize.width: 12; sourceSize.height: 12 }
            }
            // short word under the circle, always visible
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (root.big / 2 + 3 - st.d / 2 > 0 ? root.big + 6 - (root.big / 2 + 3 - st.d / 2) : root.big + 6) - 1
                width: wordL.implicitWidth + 10
                height: wordL.implicitHeight + 2
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.85)
                Label {
                    id: wordL
                    anchors.centerIn: parent
                    text: st.modelData.word
                    font.pixelSize: 12
                    font.bold: true
                    color: st.done ? '#45541f' : (st.now ? '#5e1a33' : '#8a7d70')
                }
            }
            TapHandler {
                id: stTap
                margin: 6
                onTapped: {
                    if (st.done && root.allowBack) root.stepClicked(st.n)
                    else bubble.showFor(st)
                }
            }
        }
    }

    // the explanation bubble (on the overlay, above the page)
    Popup {
        id: bubble
        property string title
        property string text
        property real arrowX: 20
        width: Math.min(root.width, 260)
        padding: 12
        modal: false
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
        background: Item {
            Rectangle { anchors.fill: parent; radius: 14; color: '#2a2220' }
            Rectangle {
                width: 14; height: 14; rotation: 45; color: '#2a2220'
                x: bubble.arrowX - 7; y: -6
            }
        }
        contentItem: Column {
            spacing: 2
            Label { width: bubble.availableWidth; text: bubble.title; color: '#ffffff'; font.pixelSize: 15; font.bold: true; wrapMode: Text.WordWrap }
            Label { width: bubble.availableWidth; text: bubble.text; color: '#ffffff'; font.pixelSize: 14; wrapMode: Text.WordWrap; lineHeight: 1.15 }
        }
        function showFor(st) {
            title = st.n + ' · ' + st.modelData.title
            text = st.modelData.text
            var cx = st.x + st.width / 2
            x = Math.max(0, Math.min(root.width - width, cx - width / 2))
            arrowX = cx - x
            y = st.y + st.height + 12
            open()
            hideTimer.restart()
        }
        Timer { id: hideTimer; interval: 5000; onTriggered: bubble.close() }
    }
}
