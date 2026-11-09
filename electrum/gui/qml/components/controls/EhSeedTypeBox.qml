// Easy Heirs (schèi): the kind of seed, to write on the paper under the 12 words.
// Schèi seeds are Electrum seeds (segwit), NOT BIP39: another wallet that only
// knows BIP39 would refuse them or show an empty wallet.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root
    property bool review: false        // false: creating the wallet, true: "see the 12 words again"
    property string kind: 'segwit'     // Electrum seed type, '' = not an Electrum seed (BIP39)

    readonly property string label: kind === '' ? 'BIP39'
        : qsTr('Electrum seed') + ' · ' + (kind === 'standard' ? 'standard' : kind) + ' · ' + qsTr('NOT BIP39')

    Layout.fillWidth: true
    Layout.preferredHeight: col.implicitHeight + 20
    radius: 14
    color: '#fbf0d6'
    border.width: 2
    border.color: '#e0a020'

    ColumnLayout {
        id: col
        x: 12; y: 10
        width: parent.width - 24
        spacing: 2
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.review ? qsTr('KIND') : qsTr('WRITE THIS TOO, UNDER THE WORDS')
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 0.5
            color: '#8a5a12'
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.label
            color: '#3f0f21'
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 18
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            font.pixelSize: 13
            color: '#4a4038'
            text: root.review
                  ? qsTr('Check that this is written on your paper too.')
                  : qsTr('It is needed to get the money back with another program: <b>Electrum</b> (or Schèi) is fine. No extra word (passphrase).')
        }
    }
}
