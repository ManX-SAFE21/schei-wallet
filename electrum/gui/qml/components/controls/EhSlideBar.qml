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
    // T37: going up the coin can reach and cover the QR code of SEND
    readonly property real travelUp: Math.max(travel, height / 2 - 34)
    // going down, the coin reaches the wallet under the bar (T37)
    readonly property real travelDown: Math.max(travel, height / 2 - coinSize / 2 + coinSize * 0.35)
    // T37: how open the wallet under the bar is: it opens as the coin comes down
    readonly property real rawProgress: coin.offset > 0 && travelDown > 0
                                        ? Math.pow(Math.min(1, coin.offset / travelDown), 1.4) : 0
    // after a receive the wallet closes on its own, softly (with a small bounce), not in one frame
    property real _closeK: 0
    readonly property real receiveProgress: goIn.running ? Math.max(0, _closeK) : rawProgress

    implicitWidth: 95

    // home "Bottega" (owner 13/11, preview home-nuova-grafica.html, proposal B): the column is a
    // leather strap, wine at the top (SEND) and olive at the bottom (RECEIVE), with gold stitching;
    // the coin with its brass rim runs in a dark slot, like in a piggy bank
    readonly property string serif: SerifFont ? SerifFont : app.font.family
    readonly property string body: BodyFont ? BodyFont : app.font.family
    // short column (small phones): fewer drawings at the two ends, so the coin keeps its room
    readonly property bool roomyTop: height >= 280
    readonly property bool roomyBottom: height >= 340
    Rectangle {
        // shadow under the strap
        x: leather.x
        y: leather.y + 4
        width: leather.width
        height: leather.height
        radius: leather.radius
        color: Qt.rgba(0.25, 0.06, 0.13, 0.22)
    }
    Rectangle {
        id: leather
        x: 1
        y: 2
        width: parent.width - 2
        height: parent.height - 8
        radius: 26
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.sendEnabled ? '#6d2140' : '#7d716a' }
            GradientStop { position: 0.5; color: root.sendEnabled ? '#4a1228' : '#5a4f49' }
            GradientStop { position: 0.502; color: '#3d4a1a' }
            GradientStop { position: 1.0; color: '#4f6023' }
        }
    }
    EhDashedBorder {
        anchors.fill: leather
        inset: 6
        radius: 20
        lineWidth: 1.6
        color: '#e3c57e'
    }
    // the dark slot where the coin and the arrows sit
    Rectangle {
        id: slot
        readonly property real top0: topCol.y + topCol.height + 6
        readonly property real bot0: botCol.y - 6
        readonly property real h: Math.max(root.coinSize * 0.7, Math.min(182, bot0 - top0))
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(top0, Math.min(bot0 - h, root.height / 2 - h / 2))
        width: 44
        height: h
        radius: 22
        gradient: Gradient {
            GradientStop { position: 0.0; color: '#2a0a16' }
            GradientStop { position: 1.0; color: '#1c220b' }
        }
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
        // recessed: dark at the top edge
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: 10
            radius: 21
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
            }
        }
    }

    // top end: INVIA
    Column {
        id: topCol
        anchors.top: parent.top
        anchors.topMargin: root.roomyTop ? 16 : 11
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1
        opacity: root.sendEnabled ? 1 : 0.5
        TapHandler { enabled: !root.sendEnabled; margin: 10; onTapped: root.explainWatchOnly() }
        Image {
            // a QR code: what you need to send
            visible: root.roomyTop
            anchors.horizontalCenter: parent.horizontalCenter
            source: Qt.resolvedUrl('../../../icons/eh_qr_gold.svg')
            sourceSize.width: 38
            sourceSize.height: 38
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 74
            horizontalAlignment: Text.AlignHCenter
            text: qsTr('SEND')
            font.family: root.serif
            font.weight: Font.ExtraBold
            font.pixelSize: 20
            font.letterSpacing: 0.5
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 13
            color: '#fbeccb'
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 72
            horizontalAlignment: Text.AlignHCenter
            text: root.sendEnabled ? qsTr('push up') : qsTr('not available')
            font.pixelSize: root.sendEnabled ? 16 : 13
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 10
            color: '#ffffff'
        }
    }

    // bottom end: RICEVI, right above the wallet (T37: the wallet itself is the target)
    Column {
        id: botCol
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.roomyTop ? 20 : 13
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1
        opacity: Math.max(0, 1 - root.receiveProgress * 1.6)
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 72
            horizontalAlignment: Text.AlignHCenter
            text: qsTr('pull down')
            font.pixelSize: 16
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 10
            color: '#ffffff'
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 74
            horizontalAlignment: Text.AlignHCenter
            text: qsTr('RECEIVE')
            font.family: root.serif
            font.weight: Font.ExtraBold
            font.pixelSize: 20
            font.letterSpacing: 0.5
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 13
            color: '#fbeccb'
        }
        Image {
            visible: root.roomyBottom
            anchors.horizontalCenter: parent.horizontalCenter
            source: Qt.resolvedUrl('../../../icons/eh_in_gold.svg')
            sourceSize.width: 34
            sourceSize.height: 34
        }
    }

    // animated chevrons
    component Chevrons: Column {
        property bool up: true
        property color tint: '#e3c57e'
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
                    c.lineWidth = 3.2
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
        // while the coin travels the arrows step aside (they would go over the hills / the wallet)
        opacity: Math.max(0, 1 - Math.abs(coin.offset) / 40)
        up: true
        tint: '#e3c57e'
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: coin.top
        anchors.bottomMargin: 6
    }
    Chevrons {
        opacity: Math.max(0, 1 - Math.abs(coin.offset) / 40)
        up: false
        tint: '#e3c57e'
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
        z: 5
        property real offset: 0
        transformOrigin: Item.Center
        source: Qt.resolvedUrl('../../../icons/eh_coin_brass.svg')   // brass rim (home "Bottega")
        sourceSize.width: 192
        sourceSize.height: 192
        // soft shadow under the coin
        Rectangle {
            z: -1
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.1
            width: parent.width * 0.9
            height: width
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        Behavior on offset {
            enabled: !drag.active
            SpringAnimation { spring: 4; damping: 0.25; epsilon: 0.5 }
        }

        DragHandler {
            id: drag
            target: null
            enabled: !goIn.running   // the coin is going into the wallet: not grabbable
            yAxis.enabled: true
            xAxis.enabled: false
            property real startOffset: 0
            onActiveChanged: {
                if (active) {
                    hint.visible = false
                    startOffset = coin.offset
                } else {
                    var limit = root.travel * 0.85
                    // review: SEND only when the coin really went up (80% of the way to the QR,
                    // at least 40 px), like RECEIVE: never by a small drag on a short screen
                    if (coin.offset <= -Math.max(40, limit, root.travelUp * 0.8) && root.sendEnabled) {
                        AppController.haptic()
                        root.sendRequested()
                    } else if (coin.offset >= Math.max(40, limit, root.travelDown * 0.8)) {
                        AppController.haptic()
                        root._closeK = root.rawProgress
                        // T37: the coin goes into the wallet (smaller, fading), then comes back
                        goIn.restart()
                        root.receiveRequested()
                        return
                    }
                    coin.offset = 0
                }
            }
            onTranslationChanged: {
                // pushing up a watch-only wallet: tell why it cannot send
                if (!root.sendEnabled && translation.y < -30) root.explainWatchOnly()
                var v = startOffset + translation.y
                var minV = root.sendEnabled ? -root.travelUp : 0
                coin.offset = Math.max(minV, Math.min(root.travelDown, v))
            }
        }
        TapHandler {
            enabled: !goIn.running
            onTapped: { hint.visible = true; hintTimer.restart() }
        }
    }

    SequentialAnimation {
        id: goIn
        ParallelAnimation {
            NumberAnimation { target: coin; property: 'offset'; to: root.travelDown + root.coinSize * 0.4; duration: 260; easing.type: Easing.InQuad }
            NumberAnimation { target: coin; property: 'scale'; to: 0.5; duration: 260 }
            NumberAnimation { target: coin; property: 'opacity'; to: 0; duration: 260 }
            // the wallet closes while the coin goes in
            SequentialAnimation {
                PauseAnimation { duration: 140 }
                NumberAnimation { target: root; property: '_closeK'; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            }
        }
        PropertyAction { target: coin; property: 'offset'; value: 0 }
        PauseAnimation { duration: 250 }
        ParallelAnimation {
            NumberAnimation { target: coin; property: 'scale'; to: 1; duration: 220 }
            NumberAnimation { target: coin; property: 'opacity'; to: 1; duration: 220 }
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
