// Easy Heirs (schȅi), "Bottega": a sheet that comes up from the bottom over the page (the
// inheritance questions "Sei ancora qui?" and "Soldi nuovi"). Parchment, radius 24 at the top,
// a handle, the page dimmed behind it. It stays ABOVE the Android keys; when the content is
// taller than the room it scrolls. Children go in a ColumnLayout (spacing 12, 16 px sides).
// The Android Back key closes it (it is in app._ehAsks, as the yes / no questions).
//   EhBottomSheet { EhTitle { ... } EhStitchButton { ... } }
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "EhStyle.js" as S

Popup {
    id: root
    default property alias content: col.data
    property real dimOpacity: 0.5
    property bool closable: true            // false while a job runs: no Back, no tap outside
    readonly property real _room: (parent ? parent.height : 800) - app.statusBarHeight - app.navigationBarHeight - 24

    parent: Overlay.overlay
    modal: true
    dim: true
    closePolicy: closable ? (Popup.CloseOnEscape | Popup.CloseOnPressOutside) : Popup.NoAutoClose
    x: 0
    width: parent ? parent.width : 393
    height: Math.min(col.implicitHeight + topPadding + bottomPadding, _room)
    y: (parent ? parent.height : 800) - height - app.navigationBarHeight
    padding: 0
    leftPadding: 16
    rightPadding: 16
    topPadding: 10 + 5 + 14            // handle area
    bottomPadding: 12
    Material.theme: Material.Light
    Material.foreground: S.ink

    // the dim stops above the Android keys, as the sheet does
    Overlay.modal: Item {
        Rectangle {
            anchors.fill: parent
            anchors.bottomMargin: app.navigationBarHeight
            color: Qt.rgba(0.16, 0.12, 0.12, root.dimOpacity)
        }
    }

    enter: Transition {
        NumberAnimation { property: 'y'; from: (root.parent ? root.parent.height : 800); duration: app.ehOption && app.ehOption('no_anim') ? 0 : 180; easing.type: Easing.OutCubic }
    }

    background: Item {
        // soft shadow above the top edge (a few transparent layers, no blur)
        Repeater {
            model: 4
            Rectangle {
                required property int index
                anchors.fill: parent
                anchors.topMargin: -(index + 1) * 3
                radius: 24 + (index + 1) * 3
                color: '#000000'
                opacity: 0.07 - index * 0.015
            }
        }
        Rectangle {
            id: face
            anchors.fill: parent
            radius: 24
            color: S.parch
            border.width: 1.5
            border.color: S.edge
        }
        // square bottom corners (the sheet sits on the Android keys)
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 30
            color: S.parch
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            width: 46
            height: 5
            radius: 3
            color: S.edge
        }
    }

    contentItem: Flickable {
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight
        interactive: contentHeight > height + 1
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: col
            width: parent.width
            spacing: 12
        }
    }

    // Back key (main.qml onClosing) closes the top sheet as it answers "No" to a question
    function answer(yes) { if (root.closable) close() }
    onOpened: app._ehAsks.push(root)
    onClosed: {
        var i = app._ehAsks.indexOf(root)
        if (i >= 0) app._ehAsks.splice(i, 1)
    }
}
