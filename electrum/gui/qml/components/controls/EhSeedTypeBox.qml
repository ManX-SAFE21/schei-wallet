// Easy Heirs (schȅi): the kind of seed, to write on the paper under the 12 words.
// Schȅi seeds are Electrum seeds (segwit), NOT BIP39: another wallet that only
// knows BIP39 would refuse them or show an empty wallet.
// "Bottega" (WP1): ivory box with a gold border, like EhInfoBox 'warn'.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

Rectangle {
    id: root
    property bool review: false        // false: creating the wallet, true: "see the 12 words again"
    property string kind: 'segwit'     // Electrum seed type, '' = not an Electrum seed (BIP39)

    readonly property string label: kind === '' ? 'BIP39'
        : qsTr('Electrum seed') + ' · ' + (kind === 'standard' ? 'standard' : kind) + ' · ' + qsTr('NOT BIP39')

    Layout.fillWidth: true
    Layout.preferredHeight: col.implicitHeight + 20
    radius: 16
    color: S.ivory
    border.width: 2
    border.color: S.gold

    ColumnLayout {
        id: col
        x: 12; y: 10
        width: parent.width - 24
        spacing: 2
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.review ? qsTr('KIND') : qsTr('WRITE THIS TOO, UNDER THE WORDS')
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 16
            font.bold: true
            font.letterSpacing: 0.5
            color: S.waitInk
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.label
            color: S.wineDark
            font.family: FixedFont
            font.bold: true
            font.pixelSize: 18
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 16
            lineHeight: 1.1
            color: S.ink
            text: root.review
                  ? qsTr('Check that this is written on your paper too.')
                  : qsTr('It is needed to get the money back with another program: <b>Electrum</b> (or Schȅi) is fine. No extra word (passphrase).')
        }
    }
}
