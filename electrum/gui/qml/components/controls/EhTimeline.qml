// Easy Heirs (schȅi), "Bottega": the inheritance dates on a line (screen 4 "In how long?"):
// a paper track (olive up to the reminder, gold after it), three dots (olive today, brass the
// reminder, wine the delivery) and under each one a bold word and its date.
// The same parts as the steps bar. Times are UNIX seconds.
//   EhTimeline { start: s.now; mid: warnAt; end: delivery }
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

Item {
    id: root
    property real start: 0
    property real mid: 0
    property real end: 0
    property string startWord: qsTr('Today')
    property string midWord: qsTr('Reminder')
    property string endWord: qsTr('Delivery')
    property string dateFormat: 'dd/MM/yyyy'

    // where the reminder sits on the line, 0..1
    readonly property real fraction: end > start ? Math.max(0, Math.min(1, (mid - start) / (end - start))) : 0.5
    readonly property real dot: 28

    function day(t) { return t > 0 ? Qt.formatDate(new Date(t * 1000), root.dateFormat) : '…' }

    Layout.fillWidth: true
    implicitHeight: Math.max(92, dot + 10 + Math.max(l0.implicitHeight, l1.implicitHeight, l2.implicitHeight))
    Layout.preferredHeight: implicitHeight

    // the track
    Rectangle {
        id: track
        x: 14
        width: root.width - 28
        y: root.dot / 2 - height / 2
        height: 8
        radius: 4
        color: S.paper
        border.width: 1.5
        border.color: S.edge
        clip: true
        Rectangle {
            x: 1.5; y: 1.5
            height: parent.height - 3
            width: (parent.width - 3) * root.fraction
            radius: 2
            color: S.olive
        }
        Rectangle {
            x: 1.5 + (parent.width - 3) * root.fraction
            y: 1.5
            height: parent.height - 3
            width: (parent.width - 3) * (1 - root.fraction)
            radius: 2
            color: S.gold
        }
    }

    component Dot: Item {
        id: d
        property color fill: S.olive
        property bool brass: false
        width: root.dot
        height: root.dot
        Rectangle {        // the thin edge ring outside
            anchors.fill: parent
            anchors.margins: -1.5
            radius: width / 2
            color: S.edge
        }
        Rectangle {        // the paper border, 3 px
            anchors.fill: parent
            radius: width / 2
            color: S.paper
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: width / 2
                color: d.fill
                gradient: d.brass ? brassG : null
            }
        }
        Gradient {
            id: brassG
            GradientStop { position: 0.0; color: S.brassLight }
            GradientStop { position: 0.55; color: S.brass }
            GradientStop { position: 1.0; color: S.brassDark }
        }
    }

    Dot { x: 0; y: 0; fill: S.olive }
    Dot { x: (root.width - root.dot) * root.fraction; y: 0; brass: true }
    Dot { x: root.width - root.dot; y: 0; fill: S.wine }

    component Word: Label {
        property string word
        property string date
        textFormat: Text.StyledText
        text: '<b><font color="' + S.ink + '">' + word + '</font></b><br>' + date
        color: S.muted
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 15
        lineHeight: 1.1
    }

    Word {
        id: l0
        x: 0
        y: root.dot + 10
        word: root.startWord
        date: root.day(root.start)
    }
    Word {
        id: l1
        // centred under its dot, but never over the two at the ends
        x: Math.max(l0.implicitWidth + 6,
                    Math.min(root.width - l2.implicitWidth - 6 - implicitWidth,
                             (root.width - root.dot) * root.fraction + root.dot / 2 - implicitWidth / 2))
        y: root.dot + 10
        horizontalAlignment: Text.AlignHCenter
        word: root.midWord
        date: root.day(root.mid)
    }
    Word {
        id: l2
        x: root.width - implicitWidth
        y: root.dot + 10
        horizontalAlignment: Text.AlignRight
        word: root.endWord
        date: root.day(root.end)
    }
}
