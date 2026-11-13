// Easy Heirs (schȅi), "Bottega": dotted separator between rows (one tiled SVG, no Canvas).
import QtQuick
import QtQuick.Layouts

Image {
    Layout.fillWidth: true
    Layout.preferredHeight: 2
    height: 2
    source: Qt.resolvedUrl('../../../icons/eh_dotline.svg')
    sourceSize.width: 8
    sourceSize.height: 2
    fillMode: Image.TileHorizontally
    horizontalAlignment: Image.AlignLeft
}
