// Easy Heirs (schèi): switch of one gold coin. Green "si spende" (default),
// red "bloccata" (the app will not use the coin to pay).
import QtQuick
import QtQuick.Controls

Column {
    id: root
    property bool spendable: true
    property string blockedText: qsTr('blocked')   // a coin: 'bloccata'; an address: 'bloccato'
    signal toggled(bool spendable)
    spacing: 3
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 48; height: 28; radius: 14
        color: root.spendable ? '#45541f' : '#c0392b'
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 22; height: 22; radius: 11
            y: 3
            x: root.spendable ? parent.width - width - 3 : 3
            color: '#ffffff'
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
        font.pixelSize: 11
        font.bold: true
        color: root.spendable ? '#45541f' : '#c0392b'
    }
}
