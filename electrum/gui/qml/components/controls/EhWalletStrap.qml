// Easy Heirs (schȅi): the closing strap of the leather wallet card.
// It comes from the back, wraps round the right edge (darker fold) and lies on
// the front with a rounded end. Its golden snap button opens the settings.
import QtQuick

Item {
    id: root
    property color leather: '#5e1a33'
    property bool light: false          // watch-only wallet: light leather
    property color stitch: Qt.rgba(1, 0.91, 0.77, 0.6)
    property bool bottega: false        // home "Bottega": darker leather, brass snap (same size)
    onBottegaChanged: cv.requestPaint()
    onLeatherChanged: cv.requestPaint()
    signal tapped

    width: 92
    height: 56

    // shadow on the leather below
    Rectangle {
        x: -3; y: 5
        width: parent.width; height: parent.height
        radius: 28
        color: Qt.rgba(0.12, 0.02, 0.06, root.light ? 0.12 : 0.28)
    }
    Canvas {
        id: cv
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var c = getContext('2d')
            c.reset()
            var w = width, h = height, r = h / 2, rr = 5
            if (w <= 0 || h <= 0) return
            // body
            c.beginPath()
            c.moveTo(r, 0); c.lineTo(w - rr, 0); c.arcTo(w, 0, w, rr, rr)
            c.lineTo(w, h - rr); c.arcTo(w, h, w - rr, h, rr)
            c.lineTo(r, h); c.arc(r, r, r, Math.PI / 2, Math.PI * 3 / 2, false)
            c.closePath()
            var g = c.createLinearGradient(0, 0, 0, h)
            if (root.light) {
                g.addColorStop(0, '#ffffff'); g.addColorStop(1, '#efe8dc')
            } else if (root.bottega) {
                g.addColorStop(0, Qt.darker(root.leather, 1.05)); g.addColorStop(1, Qt.darker(root.leather, 1.8))
            } else {
                g.addColorStop(0, Qt.lighter(root.leather, 1.3)); g.addColorStop(1, Qt.darker(root.leather, 1.45))
            }
            c.fillStyle = g
            c.fill()
            // light on the top edge
            c.save(); c.clip()
            var s = c.createLinearGradient(0, 0, 0, 14)
            s.addColorStop(0, Qt.rgba(1, 1, 1, root.light ? 0.5 : 0.2)); s.addColorStop(1, Qt.rgba(1, 1, 1, 0))
            c.fillStyle = s
            c.fillRect(0, 0, w, 14)
            // the fold round the edge
            var f = c.createLinearGradient(w - 9, 0, w, 0)
            f.addColorStop(0, Qt.rgba(0, 0, 0, 0.04)); f.addColorStop(1, Qt.rgba(0, 0, 0, 0.32))
            c.fillStyle = f
            c.fillRect(w - 9, 0, 9, h)
            c.restore()
            // stitching along the edge (not on the fold)
            var i = 5, ri = r - i
            c.strokeStyle = root.stitch
            c.lineWidth = 1.4
            c.setLineDash([5, 4])
            c.beginPath()
            c.moveTo(w - 9, i); c.lineTo(r, i)
            c.arc(r, r, ri, Math.PI * 3 / 2, Math.PI / 2, true)
            c.lineTo(w - 9, h - i)
            c.stroke()
        }
    }
    Image {
        x: 9
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        source: Qt.resolvedUrl(root.bottega ? '../../../icons/eh_snap_brass.svg' : '../../../icons/eh_snap.svg')
        sourceSize.width: 76
        sourceSize.height: 76
        scale: tap.pressed ? 0.92 : 1
    }
    TapHandler {
        id: tap
        margin: 6
        gesturePolicy: TapHandler.WithinBounds   // the card behind must not get this tap
        onTapped: root.tapped()
    }
}
