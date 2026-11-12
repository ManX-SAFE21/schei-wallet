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

    // owner 13/11: the 4 dots are all lit and green for a moment before the check starts
    // (the check can block the screen: without this the 4th dot was never drawn)
    property bool checking: false
    function clear() { pin = ''; checking = false; doneTimer.stop() }

    function press(d) {
        if (busy || checking || pin.length >= length)
            return
        pin = pin + d
        AppController.haptic()
        if (pin.length === length) {
            checking = true
            doneTimer.restart()
        }
    }

    function back() {
        if (!busy && !checking && pin.length > 0)
            pin = pin.substring(0, pin.length - 1)
    }

    Timer {
        id: doneTimer
        interval: 220
        onTriggered: root.completed(root.pin)
    }
    // the check went on (dialog busy) or the PIN was wrong (cleared): back to normal
    onPinChanged: if (pin.length < length) checking = false
    // wrong PIN: the dots shake
    onMessageBadChanged: if (messageBad) shake.restart()

    Row {
        id: dots
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 6
        spacing: 20
        transform: Translate { id: dotsShift; x: 0 }
        Repeater {
            model: root.length
            Rectangle {
                required property int index
                width: 26; height: 26; radius: 13
                readonly property color ink: root.checking ? '#45541f' : '#5e1a33'
                color: index < root.pin.length ? ink : 'transparent'
                border.width: 3
                border.color: ink
            }
        }
    }
    SequentialAnimation {
        id: shake
        NumberAnimation { target: dotsShift; property: 'x'; to: -14; duration: 50 }
        NumberAnimation { target: dotsShift; property: 'x'; to: 14; duration: 80 }
        NumberAnimation { target: dotsShift; property: 'x'; to: -10; duration: 70 }
        NumberAnimation { target: dotsShift; property: 'x'; to: 8; duration: 60 }
        NumberAnimation { target: dotsShift; property: 'x'; to: 0; duration: 50 }
    }

    Label {
        Layout.fillWidth: true
        Layout.preferredHeight: 26
        horizontalAlignment: Text.AlignHCenter
        text: root.checking ? qsTr('Checking…') : root.message
        color: root.checking ? '#45541f' : (root.messageBad ? '#5e1a33' : '#6b5d55')
        font.pixelSize: 17
        font.bold: root.messageBad || root.checking
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
                // owner 13/11: the digit counts when the key is TOUCHED, so fast typing loses nothing
                // (on release, a finger already on the next key or slipping a little lost the tap)
                TapHandler {
                    id: tapk
                    enabled: key.modelData !== ''
                    gesturePolicy: TapHandler.DragThreshold
                    onPressedChanged: if (pressed) { key.modelData === 'del' ? root.back() : root.press(key.modelData) }
                }
            }
        }
    }
}
