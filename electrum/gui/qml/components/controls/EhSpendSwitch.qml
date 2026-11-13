// Easy Heirs (schèi): switch of one gold coin. Green "si spende" (default),
// red "bloccata" (the app will not use the coin to pay).
// "Bottega" (WP1): track 60x34 with the brass knob, label 16 bold.
import QtQuick
import QtQuick.Controls

import "EhStyle.js" as S

Column {
    id: root
    property bool spendable: true
    property string blockedText: qsTr('blocked')   // a coin: 'bloccata'; an address: 'bloccato'
    signal toggled(bool spendable)
    spacing: 3
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 60; height: 34; radius: 17
        color: root.spendable ? S.olive : S.red
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 28; height: 28; radius: 14
            y: 3
            x: root.spendable ? parent.width - width - 3 : 3
            border.width: 1.5
            border.color: S.brassRing
            gradient: Gradient {
                GradientStop { position: 0.0; color: S.brassLight }
                GradientStop { position: 0.55; color: S.brass }
                GradientStop { position: 1.0; color: S.brassDark }
            }
            Behavior on x { NumberAnimation { duration: 150 } }
        }
        // T10: MouseArea (not TapHandler) so a row under it cannot take the tap
        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            onClicked: { root.spendable = !root.spendable; root.toggled(root.spendable) }
        }
    }
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.spendable ? qsTr('spendable') : root.blockedText
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 16
        font.bold: true
        color: root.spendable ? S.olive : S.red
    }
}
