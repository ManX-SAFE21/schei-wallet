// Easy Heirs (schȅi): dashed rounded outline (QML borders are solid).
// Owner 17/11 (Samsung): drawn as a Shape, not a Canvas. A Canvas paints once into an image; on
// Android that image was lost (app long in the background, the system frees memory) and never
// painted again: the stitching of a wallet vanished. A Shape is geometry: the scene graph builds it
// again by itself every time it is needed.
import QtQuick
import QtQuick.Shapes

Shape {
    id: root
    property color color: '#5e1a33'
    property real radius: 24
    property real lineWidth: 2.5
    property real inset: 4

    readonly property real i: inset
    readonly property real w: Math.max(0, width - 2 * inset)
    readonly property real h: Math.max(0, height - 2 * inset)
    readonly property real r: Math.max(0, Math.min(radius, w / 2, h / 2))

    visible: w > 0 && h > 0
    preferredRendererType: Shape.CurveRenderer   // smooth edges without a layer

    ShapePath {
        strokeColor: root.color
        strokeWidth: root.lineWidth
        fillColor: 'transparent'
        strokeStyle: ShapePath.DashLine
        // same dashes as the Canvas before: its setLineDash([7, 5]) counts in line widths too
        dashPattern: [7, 5]
        capStyle: ShapePath.FlatCap
        joinStyle: ShapePath.MiterJoin
        startX: root.i + root.r; startY: root.i
        PathLine { x: root.i + root.w - root.r; y: root.i }
        PathArc { x: root.i + root.w; y: root.i + root.r; radiusX: root.r; radiusY: root.r }
        PathLine { x: root.i + root.w; y: root.i + root.h - root.r }
        PathArc { x: root.i + root.w - root.r; y: root.i + root.h; radiusX: root.r; radiusY: root.r }
        PathLine { x: root.i + root.r; y: root.i + root.h }
        PathArc { x: root.i; y: root.i + root.h - root.r; radiusX: root.r; radiusY: root.r }
        PathLine { x: root.i; y: root.i + root.r }
        PathArc { x: root.i + root.r; y: root.i; radiusX: root.r; radiusY: root.r }
    }
}
