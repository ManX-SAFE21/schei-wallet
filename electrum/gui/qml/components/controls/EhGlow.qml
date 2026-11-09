// Easy Heirs (schèi): a soft coloured light ("luce colorata" style).
// tone: wine = your money, rose = sending, green = receiving / all ok,
// gold = attention, white = small halo. Place it behind content (z: -1)
// and give it a size: it fades to nothing at its edges, no border.
import QtQuick

Image {
    property string tone: 'wine'
    source: Qt.resolvedUrl('../../../icons/eh_glow_' + tone + '.svg')
    sourceSize.width: 128
    sourceSize.height: 128
    fillMode: Image.Stretch
    smooth: true
    z: -1
}
