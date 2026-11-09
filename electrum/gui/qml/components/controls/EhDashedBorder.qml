// Easy Heirs (schèi): dashed rounded outline, drawn (QML borders are solid).
import QtQuick

Canvas {
    id: root
    property color color: '#5e1a33'
    property real radius: 24
    property real lineWidth: 2.5
    property real inset: 4
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var c = getContext('2d')
        c.reset()
        var i = inset, w = width - 2 * i, h = height - 2 * i, r = Math.min(radius, w / 2, h / 2)
        if (w <= 0 || h <= 0 || r < 0) return   // not laid out yet
        c.strokeStyle = root.color
        c.lineWidth = root.lineWidth
        c.setLineDash([7, 5])
        c.beginPath()
        c.moveTo(i + r, i)
        c.lineTo(i + w - r, i); c.arcTo(i + w, i, i + w, i + r, r)
        c.lineTo(i + w, i + h - r); c.arcTo(i + w, i + h, i + w - r, i + h, r)
        c.lineTo(i + r, i + h); c.arcTo(i, i + h, i, i + h - r, r)
        c.lineTo(i, i + r); c.arcTo(i, i, i + r, i, r)
        c.closePath()
        c.stroke()
    }
}
