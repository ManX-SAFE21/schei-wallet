// Easy Heirs (schȅi): 4-digit PIN entry: four dots, a message line and big
// 0-9 keys. Emits completed(pin) when the 4th digit is typed.
// "Bottega" look (WP1): brass dots, paper keys (EhKey); the behaviour is the owner's of 13/11.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

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
                readonly property bool lit: index < root.pin.length
                width: 26; height: 26; radius: 13
                // empty: paper with a brass ring; typed: brass; checking: all green
                border.width: lit ? 2 : 3
                border.color: root.checking ? '#2f3a12' : S.brassRing
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.checking ? '#6f8038' : (lit ? S.brassLight : S.paper) }
                    GradientStop { position: 0.55; color: root.checking ? S.olive : (lit ? S.brass : S.paper) }
                    GradientStop { position: 1.0; color: root.checking ? '#2f3a12' : (lit ? S.brassDark : S.paper) }
                }
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
        color: root.checking ? S.olive : (root.messageBad ? S.wine : S.muted)
        font.family: BodyFont ? BodyFont : font.family
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
            delegate: EhKey {
                id: key
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                opacity: modelData === '' ? 0 : 1
                enabled: modelData !== ''
                text: modelData === 'del' ? '' : modelData
                isDelete: modelData === 'del'
                // owner 13/11: the digit counts when the key is TOUCHED, so fast typing loses nothing
                // (on release, a finger already on the next key or slipping a little lost the tap)
                fireOnPress: true
                onActivated: key.modelData === 'del' ? root.back() : root.press(key.modelData)
            }
        }
    }
}
