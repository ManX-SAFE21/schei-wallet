// Easy Heirs (schȅi): the "delete" key symbol, drawn (arrow-shaped key with a
// cross). The font character U+232B is missing on many Android phones and
// shows as an empty box, so we never use it.
import QtQuick

Canvas {
    id: root
    property color ink: '#5e1a33'       // "Bottega": wine stroke on the sand delete key
    property color fill: '#ead9b0'
    implicitWidth: 38
    implicitHeight: 27
    onInkChanged: requestPaint()
    onFillChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext('2d')
        ctx.reset()
        // drawn in a 42 x 30 box, scaled to the item
        var sx = width / 42, sy = height / 30
        ctx.scale(sx, sy)
        ctx.lineJoin = 'round'
        ctx.lineCap = 'round'
        ctx.beginPath()
        ctx.moveTo(13, 3)
        ctx.lineTo(37, 3)
        ctx.quadraticCurveTo(40, 3, 40, 6)
        ctx.lineTo(40, 24)
        ctx.quadraticCurveTo(40, 27, 37, 27)
        ctx.lineTo(13, 27)
        ctx.lineTo(2, 15)
        ctx.closePath()
        ctx.fillStyle = root.fill
        ctx.fill()
        ctx.lineWidth = 3
        ctx.strokeStyle = root.ink
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(19, 10); ctx.lineTo(29, 20)
        ctx.moveTo(29, 10); ctx.lineTo(19, 20)
        ctx.lineWidth = 3.4
        ctx.stroke()
    }
}
