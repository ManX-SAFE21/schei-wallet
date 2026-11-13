// Easy Heirs (schèi), "Bottega": a paper sheet on the parchment page. Paper, radius 18,
// 1.5 border, and a hard 3 px shadow (one more Rectangle, no blur). The children go in a
// ColumnLayout (spacing 0) with 12 px side padding: put EhRow's in it, or any content.
//   EhSheet { EhRow { ... } EhRow { ...; last: true } }
//   EhSheet { topPadding: 12; bottomPadding: 12; spacing: 8; Label { ... } }
import QtQuick
import QtQuick.Layouts

import "EhStyle.js" as S

Item {
    id: root
    default property alias content: col.data
    property real padding: 12          // left and right
    property real topPadding: 0
    property real bottomPadding: 0
    property alias spacing: col.spacing
    property alias radius: face.radius
    property color color: S.paper
    property color borderColor: S.edge

    Layout.fillWidth: true
    implicitWidth: col.implicitWidth + 2 * padding
    implicitHeight: col.implicitHeight + topPadding + bottomPadding + 3
    Layout.preferredHeight: implicitHeight

    // hard shadow
    Rectangle {
        y: 3
        width: face.width
        height: face.height
        radius: face.radius
        color: S.edgeShadow
    }
    Rectangle {
        id: face
        width: parent.width
        height: parent.height - 3
        radius: 18
        color: root.color
        border.width: 1.5
        border.color: root.borderColor
    }
    ColumnLayout {
        id: col
        x: root.padding
        y: root.topPadding
        width: root.width - 2 * root.padding
        spacing: 0
    }
}
