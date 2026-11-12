// Easy Heirs (schèi): wine balance card: wallet name, status pill,
// balance in euro (big) and in bitcoin (small).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root

    property string euroText: ''
    property string previewName: ''
    property string previewColor: ''
    readonly property color baseColor: previewColor !== '' ? previewColor : app.ehWalletColor()
    property string btcText: ''
    readonly property bool showCash: cashRoom && root.euroText !== ''
    // owner 12/11: at startup the exchange rate comes a few seconds later; the card keeps the room
    // of the second line and of the cash button meanwhile, so it does not grow and jump up
    readonly property bool cashRoom: app.ehOption('coins') && !app.ehBtcOnly() && app.ehHasCash() && root.hasMoney
    readonly property bool fiatRoom: !app.ehBtcOnly() && Daemon.fx.enabled
    property bool hasMoney: false
    property real frozenSats: 0         // coins blocked in "Le tue monete d'oro"
    property real arrivingSats: 0       // received, not confirmed yet (gold pill)
    property real totalSats: 0
    function satsAmount(s) { return Config.unitsToSats((s / 100000000).toFixed(8)) }
    property bool showGear: false      // home: the settings button lives in the card
    property bool compact: false       // narrow card next to the slide: status on its own line
    property bool strapLeft: false     // T19 home: the slide is on the right, so the strap comes out on the left
    // the balance is covered (only "€ 1" + little blocks) until it is tapped,
    // so a stranger looking at the phone cannot read it; covered again after 20 s
    property bool revealed: false
    // T1 (owner 2026-11-09, phone test): the blurred cover looked bad -> balance always visible
    readonly property bool covered: false
    function euroHead(s) {
        var m = s.match(/[0-9]/)
        return m ? s.substring(0, m.index + 1) : s
    }
    // "€ 1.250,00" -> ["€ 1", ".2", "50,00"]: clear, a little blurred, blurred
    function euroParts(s) {
        var m = s.match(/[0-9]/)
        if (!m) return [s, '', '']
        var i = m.index + 1
        var rest = s.substring(i)
        var m2 = rest.match(/[0-9]/)
        var j = m2 ? m2.index + 1 : rest.length
        return [s.substring(0, i), rest.substring(0, j), rest.substring(j)]
    }
    // text drawn small and stretched back: soft blur, the digits cannot be read
    // (plain QtQuick, no extra Qt module)
    component Blurred: Item {
        id: bz
        property string text
        property real k: 6            // how much: 1 = sharp, 6 = blurred
        implicitWidth: bzL.implicitWidth + 6
        implicitHeight: bzL.implicitHeight
        Label {
            id: bzL
            x: 3
            text: bz.text
            color: root.watch ? root.baseColor : '#ffffff'
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 42
        }
        ShaderEffectSource {
            id: pass1
            anchors.fill: bzL
            sourceItem: bzL
            hideSource: true
            smooth: true
            visible: false
            textureSize: Qt.size(Math.max(1, Math.round(bzL.width / bz.k)), Math.max(1, Math.round(bzL.height / bz.k)))
        }
        ShaderEffectSource {
            anchors.fill: bzL
            sourceItem: pass1
            smooth: true
            textureSize: Qt.size(Math.max(1, Math.round(bzL.width * 2 / bz.k)), Math.max(1, Math.round(bzL.height * 2 / bz.k)))
        }
    }
    Timer { id: coverTimer; interval: 20000; onTriggered: root.revealed = false }
    Connections {
        target: Qt.application
        function onStateChanged() { if (Qt.application.state !== Qt.ApplicationActive) root.revealed = false }
    }

    function refresh() {
        if (!Daemon.currentWallet)
            return
        var total = Daemon.currentWallet.ehTotal      // third review: with the money arriving
        root.arrivingSats = Daemon.currentWallet.ehArriving.satsInt
        root.euroText = app.ehEuro(total)
        root.btcText = app.ehBtc(total)
        root.hasMoney = total.satsInt > 0
        root.frozenSats = Daemon.currentWallet.frozenBalance.satsInt
        root.totalSats = total.satsInt
    }

    implicitHeight: col.implicitHeight + 30
    readonly property bool watch: Daemon.currentWallet ? Daemon.currentWallet.isWatchOnly : false
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    readonly property color lightC: Qt.lighter(root.baseColor, 1.3)
    readonly property color darkC: Qt.darker(root.baseColor, 1.35)
    // translucent card ("luce colorata"): the hills and lights show through.
    // Watch-only: light, almost clear, dashed outline in the wallet colour.
    radius: 18
    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: root.watch ? Qt.rgba(1, 1, 1, 0.66) : root.tint(root.lightC, 0.74) }
        GradientStop { position: 0.5; color: root.watch ? Qt.rgba(1, 1, 1, 0.55) : root.tint(root.baseColor, 0.72) }
        GradientStop { position: 1.0; color: root.watch ? root.tint(root.baseColor, 0.10) : root.tint(root.darkC, 0.68) }
    }
    // thin light edge: keeps the see-through card apart from the hills behind
    border.width: root.watch ? 0 : 1
    border.color: Qt.rgba(1, 1, 1, 0.3)
    // soft coloured shadow under the card
    Rectangle {
        z: -1
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.bottomMargin: -8
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        radius: parent.radius
        color: root.tint(root.baseColor, root.watch ? 0.10 : 0.18)
    }
    // leather wallet: stitching all round, 7 px from the edge
    EhDashedBorder {
        anchors.fill: parent
        inset: 7
        radius: 12
        lineWidth: 1.6
        color: root.watch ? root.tint(root.baseColor, 0.55) : Qt.rgba(1, 0.91, 0.77, 0.6)
    }
    // closing strap on the right; its golden button = settings
    EhWalletStrap {
        id: strap
        visible: root.showGear
        z: 2
        x: root.strapLeft ? -7 : root.width - width + 7
        // mirrored: rounded end towards the middle, fold on the left edge
        transform: Scale { origin.x: strap.width / 2; xScale: root.strapLeft ? -1 : 1 }
        // home (strap on the left): half way up the side, like a real wallet (owner 2026-11-11);
        // long as before: more realistic (owner 2026-11-11)
        width: 92
        y: root.strapLeft ? Math.round((root.height - height) / 2) : root.height - height - 12
        leather: root.baseColor
        light: root.watch
        stitch: root.watch ? root.tint(root.baseColor, 0.55) : Qt.rgba(1, 0.91, 0.77, 0.6)
        onTapped: app.stack.push(Qt.resolvedUrl('../EhSettings.qml'))
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        anchors.leftMargin: root.strapLeft && root.showGear ? 92 : 18   // room for the strap on the left
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Image {
                source: Qt.resolvedUrl(root.watch ? '../../../icons/eh_eye.svg' : '../../../icons/eh_key_white.svg')
                sourceSize.width: 22
                sourceSize.height: 22
            }
            Label {
                Layout.fillWidth: true
                text: root.previewName !== '' ? root.previewName : app.ehWalletName()
                color: root.watch ? root.baseColor : '#ffffff'
                font.pixelSize: 15
                elide: Text.ElideRight
            }
            Rectangle {
                visible: root.watch && !root.compact   // narrow card: on its own line (T40)
                Layout.preferredHeight: 20
                Layout.preferredWidth: watchTag.implicitWidth + 14
                radius: 6
                color: root.tint(root.baseColor, 0.85)
                Label { id: watchTag; anchors.centerIn: parent; text: qsTr('WATCH ONLY'); color: '#ffffff'; font.pixelSize: 11; font.bold: true }
            }
            Rectangle {
                visible: !root.watch && !root.compact
                Layout.preferredHeight: 22
                Layout.preferredWidth: statusLabel.implicitWidth + 16
                radius: 11
                color: Qt.rgba(1, 1, 1, 0.15)
                Label {
                    id: statusLabel
                    anchors.centerIn: parent
                    font.pixelSize: 12
                    font.bold: true
                    color: Network.isConnected ? '#cfe3a0' : '#ffd88a'
                    text: Network.isConnected ? '● ' + qsTr('Up to date') : '● ' + qsTr('Not connected')
                }
            }
            Rectangle {
                visible: false   // the settings button is now the snap on the strap
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: gearTap.pressed ? Qt.rgba(1, 1, 1, 0.35) : (root.watch ? '#ffffff' : Qt.rgba(1, 1, 1, 0.18))
                border.width: 1.5
                border.color: root.watch ? '#e2d7c1' : Qt.rgba(1, 1, 1, 0.5)
                Image {
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl(root.watch ? '../../../icons/eh_gear.svg' : '../../../icons/eh_gear_white.svg')
                    sourceSize.width: 24
                    sourceSize.height: 24
                }
                TapHandler {
                    id: gearTap
                    margin: 8   // bigger touch area than the drawing
                    onTapped: app.stack.push(Qt.resolvedUrl('../EhSettings.qml'))
                }
            }
        }
        // T40: in the narrow card the "solo da guardare" tag goes under the name
        Rectangle {
            visible: root.watch && root.compact
            Layout.topMargin: 2
            Layout.preferredHeight: 20
            Layout.preferredWidth: watchTag2.implicitWidth + 14
            radius: 6
            color: root.tint(root.baseColor, 0.85)
            Label { id: watchTag2; anchors.centerIn: parent; text: qsTr('WATCH ONLY'); color: '#ffffff'; font.pixelSize: 11; font.bold: true }
        }

        Label {
            visible: !root.watch && root.compact
            font.pixelSize: 12
            font.bold: true
            color: Network.isConnected ? '#cfe3a0' : '#ffd88a'
            text: Network.isConnected ? '● ' + qsTr('Up to date') : '● ' + qsTr('Not connected')
        }
        // covered balance: "€ 1" sharp, the next digit a little blurred, the rest
        // blurred: you can tell there is an amount, but not read it
        Item {
            visible: root.covered
            Layout.fillWidth: true
            Layout.preferredHeight: 52
        Row {
            id: covRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            transformOrigin: Item.Left
            scale: Math.min(1, parent.width / Math.max(1, implicitWidth))
            readonly property var parts: root.euroParts(root.euroText)
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parts[0]
                color: root.watch ? root.baseColor : '#ffffff'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 42
            }
            Blurred { anchors.verticalCenter: parent.verticalCenter; text: parent.parts[1]; k: 5 }
            Blurred { anchors.verticalCenter: parent.verticalCenter; text: parent.parts[2]; k: 11 }
        }
        }
        Label {
            visible: !root.covered
            Layout.fillWidth: true
            text: root.euroText !== '' ? root.euroText : root.btcText
            color: root.watch ? root.baseColor : '#ffffff'
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 42
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 14     // review 2026-11-11: 26 was too big for the narrow home card
            clip: true
        }
        Label {
            visible: root.euroText !== '' || root.fiatRoom
            Layout.fillWidth: true
            text: root.euroText === '' ? ' ' : (root.covered ? qsTr('tap to see') : root.btcText)
            color: root.watch ? '#6b5d55' : '#ffffff'
            opacity: 0.85
            font.pixelSize: 15
            font.bold: root.covered
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8
            layoutDirection: root.strapLeft ? Qt.RightToLeft : Qt.LeftToRight
            // expert option "banknotes and coins": the balance as real money.
            // Only a round button with banknotes drawn on it, no text.
            Rectangle {
                visible: root.cashRoom
                opacity: root.showCash ? 1 : 0
                enabled: root.showCash
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: 24
                color: cashTap.pressed ? Qt.rgba(1, 1, 1, 0.38) : Qt.rgba(1, 1, 1, 0.18)
                border.width: 1.5
                border.color: root.watch ? '#c8961e' : Qt.rgba(1, 1, 1, 0.45)
                Image {
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl('../../../icons/eh_cash.svg')
                    sourceSize.width: 34
                    sourceSize.height: 34
                }
                TapHandler { id: cashTap; margin: 6; gesturePolicy: TapHandler.WithinBounds; onTapped: app.stack.push(Qt.resolvedUrl('../EhCashPage.qml')) }
            }
            Item { Layout.fillWidth: true }
        }
        // third review: money received but not confirmed yet; goes away at the first confirmation
        Rectangle {
            visible: root.arrivingSats > 0 && !root.covered
            Layout.topMargin: 4
            Layout.preferredWidth: arL.implicitWidth + 20
            Layout.preferredHeight: 24
            radius: 12
            color: '#d9b25a'
            Label { id: arL; anchors.centerIn: parent; font.pixelSize: 12; font.bold: true; color: '#3f0f21'
                    text: '⏳ ' + qsTr('arriving %1').arg(app.ehMoney(root.satsAmount(root.arrivingSats))) }
        }
        // some coins blocked: how much can be spent and how much is blocked;
        // tapping "blocked" opens the gold coins (no PIN)
        Flow {
            visible: root.frozenSats > 0 && !root.watch
            Layout.fillWidth: true
            Layout.rightMargin: root.showGear && !root.strapLeft ? 70 : 0
            Layout.topMargin: 4
            spacing: 6
            Rectangle {
                visible: !root.covered
                width: spL.implicitWidth + 18
                height: 24
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.18)
                Label { id: spL; anchors.centerIn: parent; font.pixelSize: 12; font.bold: true; color: '#ffffff'
                        text: '● ' + qsTr('spendable %1').arg(app.ehMoney(root.satsAmount(Math.max(0, root.totalSats - root.frozenSats)))) }
            }
            Rectangle {
                width: blRow.implicitWidth + 18
                height: 24
                radius: 12
                color: blTap.pressed ? Qt.rgba(0.75, 0.22, 0.17, 0.8) : Qt.rgba(0.75, 0.22, 0.17, 0.55)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.6)
                Row {
                    id: blRow
                    anchors.centerIn: parent
                    spacing: 4
                    Image { anchors.verticalCenter: parent.verticalCenter; source: Qt.resolvedUrl('../../../icons/eh_lock_white.svg'); sourceSize.width: 13; sourceSize.height: 13 }
                    Label { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; font.bold: true; color: '#ffffff'
                            text: (root.covered ? qsTr('coins blocked') : qsTr('blocked %1').arg(app.ehMoney(root.satsAmount(root.frozenSats)))) + ' ›' }
                }
                TapHandler { id: blTap; margin: 4; gesturePolicy: TapHandler.WithinBounds; onTapped: app.ehOpenCoins() }
            }
        }
        // no banknotes button: keep room for the strap under the balance
        Item {
            visible: root.showGear && !root.showCash && !root.strapLeft   // strap half way up: no room needed below
            Layout.preferredHeight: 50
            Layout.fillWidth: true
        }
    }

    // tap on the card (not on its buttons) shows or covers the balance
    TapHandler {
        enabled: root.euroText !== ''
        onTapped: {
            root.revealed = !root.revealed
            if (root.revealed) coverTimer.restart(); else coverTimer.stop()
        }
    }

    Connections {
        target: Daemon.currentWallet
        function onBalanceChanged() { root.refresh() }
    }
    Connections {
        target: Daemon.fx
        function onQuotesUpdated() { root.refresh() }
        function onEnabledUpdated() { root.refresh() }
    }
    Connections {
        target: Daemon
        function onWalletLoaded() { root.revealed = false; root.refresh() }
    }
    Component.onCompleted: refresh()
}
