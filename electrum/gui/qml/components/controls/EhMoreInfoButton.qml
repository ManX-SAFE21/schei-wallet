// Easy Heirs (schȅi): "Maggiori informazioni" button. "Bottega" (WP1): a thin wrapper over
// EhStitchButton (paper, info icon, height 60).
import QtQuick
import QtQuick.Layouts

EhStitchButton {
    kind: 'paper'
    text: qsTr('More information')
    icon: 'eh_info.svg'
}
