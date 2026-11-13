// Easy Heirs (schȅi): vertical "push up to send" bar. The Bitcoin coin starts
// at the bottom; pushed all the way up it confirms. With lockSeconds > 0 the
// coin stays locked at the top for that time (used by the double confirmation)
// and then falls back by itself.
import QtQuick
import QtQuick.Controls

Item {
    id: root

    property string label: qsTr('SEND')
    property string hint: qsTr('push up')
    property int lockSeconds: 0
    property bool locked: false
    property int secondsLeft: 0
    property bool busy: false
    property bool numberInRing: false   // double confirmation: "1" / "2" inside the ring, no title

    signal confirmed
    signal released          // lock time over

    implicitWidth: 100
    opacity: enabled ? 1 : 0.45

    readonly property real coinSize: Math.min(78, width - 12)
    readonly property real ringSize: Math.min(coinSize + 6, width - 8)
    // the coin stops with its centre on the centre of the ring
    readonly property real travel: Math.max(0, (height - coinSize - 12) - (topCol.y + ring.y + ring.height / 2 - coinSize / 2))

    function reset() {
        locked = false
        lockTimer.stop()
        coin.offset = 0
    }

    Rectangle {
        anchors.fill: parent
        radius: 34
        border.width: root.locked ? 4 : 0
        border.color: '#45541f'
        gradient: Gradient {
            GradientStop { position: 0.0; color: '#e9cdd6' }
            GradientStop { position: 0.45; color: '#f3e3e8' }
            GradientStop { position: 1.0; color: '#f6f1e6' }
        }
    }

    Column {
        id: topCol
        anchors.top: parent.top
        anchors.topMargin: root.numberInRing ? 4 : 10
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2
        Label { visible: !root.numberInRing; anchors.horizontalCenter: parent.horizontalCenter; text: root.label; font.pixelSize: 17; font.bold: true; color: '#5e1a33' }
        Label { visible: !root.numberInRing || root.busy; anchors.horizontalCenter: parent.horizontalCenter; text: root.busy ? qsTr('Sending…') : root.hint; font.pixelSize: 11; color: '#6b5d55' }
        Rectangle {
            id: ring
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.ringSize; height: width; radius: width / 2
            color: 'transparent'
            border.width: 3
            border.color: Qt.rgba(0.37, 0.10, 0.20, 0.3)
            Label {
                visible: root.numberInRing
                anchors.centerIn: parent
                text: root.label
                color: Qt.rgba(0.37, 0.10, 0.20, 0.45)
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 28
            }
        }
    }

    // thin rail from the coin up to the ring, as on the home slide
    Rectangle {
        readonly property real railTop: topCol.y + ring.y + ring.height + 6
        anchors.horizontalCenter: parent.horizontalCenter
        y: railTop
        width: 4
        radius: 2
        height: Math.max(0, (root.height - root.coinSize - 12) - railTop - 4)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.37, 0.10, 0.20, 0.10) }
            GradientStop { position: 1.0; color: Qt.rgba(0.37, 0.10, 0.20, 0.45) }
        }
    }

    Label {
        visible: root.locked
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        text: qsTr('locked · %1 s').arg(root.secondsLeft)
        font.pixelSize: 12
        font.bold: true
        color: '#45541f'
    }

    Column {
        visible: !root.locked && root.enabled
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: coin.top
        anchors.bottomMargin: 10
        spacing: -2
        Repeater {
            model: 3
            Canvas {
                id: arrow
                required property int index
                width: 26; height: 15
                opacity: app.ehOption('no_anim') ? 0.6 : 0.2
                onPaint: {
                    var c = getContext('2d'); c.reset()
                    c.strokeStyle = '#5e1a33'; c.lineWidth = 3.5; c.lineCap = 'round'; c.lineJoin = 'round'
                    c.beginPath(); c.moveTo(4, 12); c.lineTo(13, 4); c.lineTo(22, 12); c.stroke()
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: !app.ehOption('no_anim')
                    onRunningChanged: if (!running) arrow.opacity = 0.6
                    PauseAnimation { duration: (2 - index) * 200 }
                    NumberAnimation { to: 0.9; duration: 500 }
                    NumberAnimation { to: 0.2; duration: 500 }
                    PauseAnimation { duration: index * 200 }
                }
            }
        }
    }

    Image {
        id: coin
        property real offset: 0
        width: root.coinSize
        height: root.coinSize
        x: (root.width - width) / 2
        y: root.height - height - 12 - offset
        source: Qt.resolvedUrl('../../../icons/eh_bitcoin_logo.svg')
        sourceSize.width: 192
        sourceSize.height: 192
        Behavior on offset {
            enabled: !drag.active
            SpringAnimation { spring: 4; damping: 0.25; epsilon: 0.5 }
        }
        DragHandler {
            id: drag
            target: null
            enabled: root.enabled && !root.locked && !root.busy
            xAxis.enabled: false
            property real start: 0
            onActiveChanged: {
                if (active) {
                    start = coin.offset
                } else if (coin.offset >= root.travel * 0.85) {
                    coin.offset = root.travel
                    AppController.haptic()
                    if (root.lockSeconds > 0) {
                        root.locked = true
                        root.secondsLeft = root.lockSeconds
                        lockTimer.start()
                    }
                    root.confirmed()
                } else {
                    coin.offset = 0
                }
            }
            onTranslationChanged: coin.offset = Math.max(0, Math.min(root.travel, start - translation.y))
        }
    }

    Timer {
        id: lockTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.secondsLeft--
            if (root.secondsLeft <= 0) {
                root.reset()
                root.released()
            }
        }
    }
}
