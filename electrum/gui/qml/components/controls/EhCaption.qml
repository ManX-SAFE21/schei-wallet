// Easy Heirs (schȅi), "Bottega": section caption (YOUR WALLET, STEP 1 OF 3, ...): 16 bold caps olive.
// rule: true = the double gold rule under it (captions INSIDE a sheet, e.g. movement periods).
// tail: a few words after the caption NOT in capitals ("YOUR HEIRS (or backup wallet)", owner 15/11).
// Margins: 16 top / 6 bottom / 4 left (set Layout.topMargin again to change the top one).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

ColumnLayout {
    id: root
    property string text
    property string tail: ''
    property color color: S.olive
    property bool rule: false

    Layout.fillWidth: true
    Layout.topMargin: 16
    Layout.bottomMargin: 6
    spacing: 4

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: root.rule ? 0 : 4
        text: root.tail === '' ? root.text : root.text.toLocaleUpperCase() + ' ' + root.tail
        color: root.color
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 16
        font.bold: true
        font.letterSpacing: 0.5
        font.capitalization: root.tail === '' ? Font.AllUppercase : Font.MixedCase
        wrapMode: Text.WordWrap
    }
    EhRule { visible: root.rule }
}
