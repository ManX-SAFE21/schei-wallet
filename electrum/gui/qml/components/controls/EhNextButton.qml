// Easy Heirs (schèi): "go on" button. "Bottega" (WP1): a thin wrapper over EhStitchButton
// (wine leather, or olive when color is olive; the arrow on the right). Old API kept so the
// pages keep working until they use EhStitchButton directly: color picks the kind,
// textColor / arrowColor / fontSize are ignored.
import QtQuick
import QtQuick.Layouts

EhStitchButton {
    id: root
    property color color: '#5e1a33'
    property color textColor: '#ffffff'
    property color arrowColor: '#d9b25a'
    property real fontSize: 23

    text: qsTr('Next')
    kind: (root.color.g > root.color.r) ? 'olive' : 'wine'
    endIcon: 'next'
}
