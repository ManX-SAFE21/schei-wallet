// Easy Heirs (schèi): 4-digit PIN entry: four dots, a message line and big
// 0-9 keys. Emits completed(pin) when the 4th digit is typed.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ColumnLayout {
    id: root
    property int length: 4
    property string pin: ''
    property string message: ''
    property bool messageBad: false
    property bool busy: false

    signal completed(string pin)

    spacing: 10

    function clear() { pin = '' }

    function press(d) {
        if (busy || pin.length >= length)
            return
        pin = pin + d
        if (pin.length === length)
            Qt.callLater(function() { root.completed(root.pin) })
    }

    function back() {
        if (!busy && pin.length > 0)
            pin = pin.substring(0, pin.length - 1)
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 6
        spacing: 20
        Repeater {
            model: root.length
            Rectangle {
                required property int index
                width: 26; height: 26; radius: 13
                color: index < root.pin.length ? '#5e1a33' : 'transparent'
                border.width: 3
                border.color: '#5e1a33'
            }
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.preferredHeight: 26
        horizontalAlignment: Text.AlignHCenter
        text: root.message
        color: root.messageBad ? '#5e1a33' : '#6b5d55'
        font.pixelSize: 17
        font.bold: root.messageBad
        wrapMode: Text.WordWrap
    }

    Item { Layout.fillHeight: true }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 10
        columnSpacing: 10
        Repeater {
            model: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del']
            delegate: Rectangle {
                id: key
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: height / 2
                visible: true
                opacity: modelData === '' ? 0 : 1
                color: modelData === 'del' ? '#efe6d3' : (tapk.pressed ? '#f3ecdd' : '#ffffff')
                border.width: modelData === 'del' ? 0 : 2
                border.color: '#e2d7c1'
                EhBackspaceIcon { visible: key.modelData === 'del'; anchors.centerIn: parent; width: 38; height: 27; fill: '#efe6d3' }
                Label {
                    anchors.centerIn: parent
                    visible: key.modelData !== 'del'
                    text: key.modelData
                    font.pixelSize: 32
                    font.bold: true
                    color: '#2a2220'
                }
                TapHandler {
                    id: tapk
                    enabled: key.modelData !== ''
                    onTapped: key.modelData === 'del' ? root.back() : root.press(key.modelData)
                }
            }
        }
    }
}
