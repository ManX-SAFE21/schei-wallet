// Easy Heirs (schèi): vertical slide bar with the Bitcoin logo in the centre.
// Push the coin to the top = send, pull it to the bottom = receive.
// Released early, it springs back. A tap without dragging shows a hint.
import QtQuick
import QtQuick.Controls

Item {
    id: root

    property bool sendEnabled: true      // false for watch-only wallets
    signal sendRequested
    signal receiveRequested

    readonly property real coinSize: Math.min(88, width - 14)

    // watch-only wallet: explain why the coin does not go up
    property bool _watchShown: false
    function explainWatchOnly() {
        if (_watchShown) return
        _watchShown = true
        var d = app.ehInfoDialog.createObject(app, {
            pageTitle: qsTr('Watch-only wallet'),
            bodyText: qsTr('With this wallet you can see the balance and receive, but you <b>cannot send</b>: the keys to sign are not on this phone.')
        })
        d.closed.connect(function() { root._watchShown = false })
        d.open()
    }
    readonly property real travel: Math.max(0, height / 2 - coinSize / 2 - 108)

    implicitWidth: 95

    // "luce colorata": no bar with a border, only soft lights at the two ends
    // and a thin rail of light where the coin travels
    EhGlow { tone: root.sendEnabled ? 'rose' : 'white'; x: -root.width * 0.5; y: -30; width: root.width * 2; height: 190 }
    EhGlow { tone: 'green'; x: -root.width * 0.5; y: root.height - 160; width: root.width * 2; height: 190 }
    Rectangle {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 104
        anchors.bottomMargin: 104
        width: 3
        radius: 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.sendEnabled ? Qt.rgba(0.37, 0.10, 0.20, 0.35) : Qt.rgba(0.42, 0.36, 0.33, 0.2) }
            GradientStop { position: 0.45; color: Qt.rgba(0.37, 0.10, 0.20, 0) }
            GradientStop { position: 0.55; color: Qt.rgba(0.27, 0.33, 0.12, 0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.27, 0.33, 0.12, 0.35) }
        }
    }

    // top end: INVIA
    Column {
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0
        opacity: root.sendEnabled ? 1 : 0.5
        TapHandler { enabled: !root.sendEnabled; margin: 10; onTapped: root.explainWatchOnly() }
        Image {
            // a QR code and a bitcoin address: what you need to send
            anchors.horizontalCenter: parent.horizontalCenter
            source: Qt.resolvedUrl('../../../icons/eh_send_qr2.svg')   // T19: bigger, drawn better
            sourceSize.width: 60
            sourceSize.height: 60
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr('SEND')
            font.pixelSize: 19
            font.bold: true
            color: root.sendEnabled ? '#5e1a33' : '#9a8f80'
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.sendEnabled ? qsTr('push up') : qsTr('not available')
            font.pixelSize: 12
            color: '#6b5d55'
        }
    }

    // bottom end: RICEVI
    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr('pull down')
            font.pixelSize: 12
            color: '#6b5d55'
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr('RECEIVE')
            font.pixelSize: 19
            font.bold: true
            color: '#45541f'
        }
        Image {
            // the wallet with the green arrow going in
            anchors.horizontalCenter: parent.horizontalCenter
            source: Qt.resolvedUrl('../../../icons/eh_rx_wallet.svg')   // T19: bigger, drawn better
            sourceSize.width: 60
            sourceSize.height: 60
        }
    }

    // animated chevrons
    component Chevrons: Column {
        property bool up: true
        property color tint: '#5e1a33'
        spacing: -2
        Repeater {
            model: 3
            Canvas {
                id: arrow
                required property int index
                width: 28; height: 16
                opacity: app.ehOption('no_anim') ? 0.6 : 0.2
                onPaint: {
                    var c = getContext('2d')
                    c.reset()
                    c.strokeStyle = parent.tint
                    c.lineWidth = 3.5
                    c.lineCap = 'round'
                    c.lineJoin = 'round'
                    c.beginPath()
                    if (parent.up) { c.moveTo(4, 13); c.lineTo(14, 4); c.lineTo(24, 13) }
                    else { c.moveTo(4, 3); c.lineTo(14, 12); c.lineTo(24, 3) }
                    c.stroke()
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: !app.ehOption('no_anim')
                    onRunningChanged: if (!running) arrow.opacity = 0.6
                    PauseAnimation { duration: (parent.up ? 2 - index : index) * 200 }
                    NumberAnimation { to: 0.9; duration: 500 }
                    NumberAnimation { to: 0.2; duration: 500 }
                    PauseAnimation { duration: (parent.up ? index : 2 - index) * 200 }
                }
            }
        }
    }

    Chevrons {
        visible: root.sendEnabled
        up: true
        tint: '#5e1a33'
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: coin.top
        anchors.bottomMargin: 6
    }
    Chevrons {
        up: false
        tint: '#45541f'
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: coin.bottom
        anchors.topMargin: 6
    }

    Image {
        id: coin
        width: root.coinSize
        height: root.coinSize
        x: (root.width - width) / 2
        y: (root.height - height) / 2 + offset
        property real offset: 0
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
            yAxis.enabled: true
            xAxis.enabled: false
            property real startOffset: 0
            onActiveChanged: {
                if (active) {
                    hint.visible = false
                    startOffset = coin.offset
                } else {
                    var limit = root.travel * 0.85
                    if (coin.offset <= -limit && root.sendEnabled) {
                        AppController.haptic()
                        root.sendRequested()
                    } else if (coin.offset >= limit) {
                        AppController.haptic()
                        root.receiveRequested()
                    }
                    coin.offset = 0
                }
            }
            onTranslationChanged: {
                // pushing up a watch-only wallet: tell why it cannot send
                if (!root.sendEnabled && translation.y < -30) root.explainWatchOnly()
                var v = startOffset + translation.y
                var minV = root.sendEnabled ? -root.travel : 0
                coin.offset = Math.max(minV, Math.min(root.travel, v))
            }
        }
        TapHandler {
            onTapped: { hint.visible = true; hintTimer.restart() }
        }
    }

    Rectangle {
        id: hint
        visible: false
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 4
        y: coin.y + coin.height + 8
        height: hintText.implicitHeight + 16
        radius: 12
        color: '#2a2220'
        z: 3
        Label {
            id: hintText
            anchors.fill: parent
            anchors.margins: 8
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: '#ffffff'
            font.pixelSize: 13
            text: root.sendEnabled ? qsTr('Hold the coin: up to send, down to receive.')
                                   : qsTr('Hold the coin and pull it down to receive.')
        }
        Timer { id: hintTimer; interval: 2600; onTriggered: hint.visible = false }
    }
}
