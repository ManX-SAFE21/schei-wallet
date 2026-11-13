// Easy Heirs (schȅi): the steps to do, as icons joined by a line, at the top
// of the page over the hills (like the Àncòra plugin and the offline multisig).
// Done steps: green with a tick; the current one: wine and bigger; later: light.
// Tapping a step that is done goes back to it (the data typed stay); the current
// step and the next ones only show a small bubble that explains them.
// steps: [{ icon: 'qr', title: '...', text: '...' }, ...]   current: 1-based
// "Bottega" (WP1): paper track with an olive progress line; done = olive disc, current = wine
// disc with a gold ring, later = paper with an edge ring; the words 14 bold on a paper pill.
import QtQuick
import QtQuick.Controls

import "EhStyle.js" as S

Item {
    id: root
    property var steps: []
    property int current: 1
    property bool allowBack: true      // false once the money has left
    signal stepClicked(int n)
    readonly property real small: 42
    readonly property real big: 48

    implicitHeight: big + 6 + 22      // circles + the short word under each one

    // the line that joins the icons: a light track, green where it is done
    Rectangle {
        id: track
        x: small / 2
        width: root.width - small
        y: root.big / 2 + 3 - height / 2
        height: 8
        radius: 4
        color: S.paper
        border.width: 1.5
        border.color: S.edge
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            anchors.leftMargin: 2
            radius: 2
            color: S.olive
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

            // the current step: a gold ring with a thin brass line round it
            Rectangle {
                visible: st.now
                anchors.centerIn: parent
                width: parent.width + 9
                height: width
                radius: width / 2
                color: S.gold
                border.width: 1.5
                border.color: S.brassRing
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: st.done ? S.olive : st.now ? S.wine : S.paper
                border.width: st.done || st.now ? 0 : 2
                border.color: S.edge
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
                border.color: S.olive
                Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../../icons/eh_st_check_o.svg'); sourceSize.width: 12; sourceSize.height: 12 }
            }
            // short word under the circle, always visible
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (root.big / 2 + 3 - st.d / 2 > 0 ? root.big + 6 - (root.big / 2 + 3 - st.d / 2) : root.big + 6) + (st.now ? 2 : -1)
                width: wordL.implicitWidth + 12
                height: wordL.implicitHeight + 2
                radius: 9
                color: S.paper
                Label {
                    id: wordL
                    anchors.centerIn: parent
                    text: st.modelData.word
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 14
                    font.bold: true
                    color: st.done ? S.oliveInk : (st.now ? S.wine : S.muted)
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
        width: Math.min(root.width, 290)
        padding: 12
        modal: false
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
        background: Item {
            Rectangle { anchors.fill: parent; radius: 14; color: S.ink }
            Rectangle {
                width: 14; height: 14; rotation: 45; color: S.ink
                x: bubble.arrowX - 7; y: -6
            }
        }
        contentItem: Column {
            spacing: 2
            Label { width: bubble.availableWidth; text: bubble.title; color: S.ivory; font.family: BodyFont ? BodyFont : font.family; font.pixelSize: 17; font.bold: true; wrapMode: Text.WordWrap }
            Label { width: bubble.availableWidth; text: bubble.text; color: S.ivory; font.family: BodyFont ? BodyFont : font.family; font.pixelSize: 16; wrapMode: Text.WordWrap; lineHeight: 1.15 }
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
