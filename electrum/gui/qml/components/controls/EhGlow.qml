// Easy Heirs (schèi): a soft coloured light ("luce colorata" style).
// tone: wine = your money, rose = sending, green = receiving / all ok,
// gold = attention, white = small halo. Place it behind content (z: -1)
// and give it a size: it fades to nothing at its edges, no border.
// "Bottega" (WP1, owner 13/11): the big coloured lights behind the pages are gone (parchment
// pages). Only a small halo round one element (both sides <= 120 px, e.g. the home's "add
// wallet" tile) is still drawn. The page packages delete their EhGlow lines when they pass.
import QtQuick

Image {
    property string tone: 'wine'
    visible: width <= 120 && height <= 120
    source: visible ? Qt.resolvedUrl('../../../icons/eh_glow_' + tone + '.svg') : ''
    sourceSize.width: 128
    sourceSize.height: 128
    fillMode: Image.Stretch
    smooth: true
    z: -1
}
