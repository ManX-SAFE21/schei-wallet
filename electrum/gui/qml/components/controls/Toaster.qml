import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

import ".."
import "EhStyle.js" as S

Item {
    id: toaster
    width: rect.width
    height: rect.height
    visible: false

    property int _y
    property string _text

    function show(item, text) {
        _text = text
        var r = item.mapToItem(parent, 0, 0)
        x = r.x + 0.5*(item.width - toaster.width)
        y = r.y - toaster.height - constants.paddingLarge
        toaster._y = y - toaster.height
        ani.restart()
    }

    SequentialAnimation {
        id: ani
        running: false
        PropertyAction { target: toaster; property: 'visible'; value: true }
        PropertyAction { target: toaster; property: 'opacity'; value: 1 }
        PauseAnimation { duration: 1000}
        ParallelAnimation {
            NumberAnimation { target: toaster; property: 'y'; to: toaster._y; duration: 1000; easing.type: Easing.InQuad }
            NumberAnimation { target: toaster; property: 'opacity'; to: 0; duration: 1000 }
        }
        PropertyAction { target: toaster; property: 'visible'; value: false }
    }

    // "Bottega" (WP1): dark ink tag with ivory text 17, radius 14
    Rectangle {
        id: rect
        width: Math.min(label.implicitWidth, toaster.parent ? toaster.parent.width - 32 : label.implicitWidth)
        height: label.implicitHeight
        radius: 14
        color: S.ink

        Label {
            id: label
            width: parent.width
            padding: 12
            leftPadding: 18
            rightPadding: 18
            text: toaster._text
            color: S.ivory
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 17
            font.bold: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
