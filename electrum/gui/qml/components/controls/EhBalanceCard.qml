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
    // owner 12/11: the home card has ONE height in every case (rate or not, pills or not):
    // the second line and the bottom row are always there; the pills sit next to the cash button
    readonly property bool fixedRows: root.strapLeft
    readonly property bool showFrozen: root.frozenSats > 0 && !root.watch
    readonly property bool showArriving: root.arrivingSats > 0 && !root.covered
    // the width the pills have: the card's text column minus the cash button (from the card, not
    // from the pills' own column, so the layout cannot loop)
    readonly property real pillsRoom: Math.max(60, homeBox.width - (root.cashRoom ? 60 : 0))
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
    component Pill: Rectangle {
        id: pl
        property string text
        property color fill: Qt.rgba(1, 1, 1, 0.18)
        property color ink: '#ffffff'
        property bool edge: false
        property bool lock: false
        property bool wait: false        // Bottega: hourglass drawn in front (no emoji)
        property real maxW: 9999
        // home (owner 13/11, home-ritocchi.html): one row of pills under the bitcoin line, 28 high
        readonly property bool big: root.bottega
        // Bottega: the text gets a little smaller when the pill is narrow (from the text and the
        // room given by the card, not from the layout: no loop)
        readonly property real fs0: root.bottega ? 15 : 13
        TextMetrics { id: plTm; font.pixelSize: pl.fs0; font.bold: true; text: pl.text }
        readonly property real fs: root.bottega ? Math.max(10, Math.min(fs0, fs0 * (maxW - ic - 19) / Math.max(1, plTm.advanceWidth)))
                                                : fs0
        readonly property real ic: (lock || wait) ? (root.bottega ? (big ? 21 : 18) : 16) : 0
        height: root.bottega ? 28 : 24
        // natural text width (implicitWidth does not follow the width set below: no loop)
        width: Math.max(30, Math.min(plTm.advanceWidth * fs / fs0 + ic + (root.bottega ? 19 : 16), maxW))
        clip: true
        radius: height / 2
        color: fill
        border.width: edge ? (root.bottega ? 1.5 : 1) : 0
        border.color: root.bottega ? '#3f0f21' : Qt.rgba(1, 1, 1, 0.6)
        Row {
            id: plRow
            anchors.centerIn: parent
            spacing: 4
            Image { visible: pl.lock || pl.wait; anchors.verticalCenter: parent.verticalCenter
                    source: Qt.resolvedUrl(pl.wait ? '../../../icons/eh_wait_wine.svg' : (root.bottega ? '../../../icons/eh_lock.svg' : '../../../icons/eh_lock_white.svg'))
                    sourceSize.width: pl.ic - 4; sourceSize.height: pl.ic - 4 }
            Label { id: plL; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: pl.fs; font.bold: true; color: pl.ink; text: pl.text
                    width: Math.max(0, Math.min(implicitWidth, pl.width - (root.bottega ? 19 : 16) - pl.ic)); elide: Text.ElideRight }
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

    // owner 13/11 (home-ritocchi.html): the home card is 184 high, always (pills or not, rate or not)
    implicitHeight: root.fixedRows ? 184 : col.implicitHeight + 30
    readonly property bool watch: Daemon.currentWallet ? Daemon.currentWallet.isWatchOnly : false
    // home "Bottega" (owner 13/11, preview home-nuova-grafica.html, proposal B): darker leather of
    // the wallet colour, gold stitching, a flap at the top, brass buttons, ivory amount.
    // Only the home card (strap on the left); a watch-only wallet keeps its light look.
    readonly property bool bottega: root.strapLeft && !root.watch
    readonly property string serif: SerifFont ? SerifFont : app.font.family
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    readonly property color lightC: Qt.lighter(root.baseColor, 1.3)
    readonly property color darkC: Qt.darker(root.baseColor, 1.35)
    // translucent card ("luce colorata"): the hills and lights show through.
    // Watch-only: light, almost clear, dashed outline in the wallet colour.
    radius: 18
    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: root.watch ? Qt.rgba(1, 1, 1, 0.66) : (root.bottega ? Qt.lighter(root.baseColor, 1.13) : root.tint(root.lightC, 0.74)) }
        GradientStop { position: root.bottega ? 0.7 : 0.5; color: root.watch ? Qt.rgba(1, 1, 1, 0.55) : (root.bottega ? Qt.darker(root.baseColor, 1.28) : root.tint(root.baseColor, 0.72)) }
        GradientStop { position: 1.0; color: root.watch ? root.tint(root.baseColor, 0.10) : (root.bottega ? Qt.darker(root.baseColor, 1.5) : root.tint(root.darkC, 0.68)) }
    }
    // thin light edge: keeps the see-through card apart from the hills behind
    border.width: root.watch || root.bottega ? 0 : 1
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
        color: root.tint(root.bottega ? root.darkC : root.baseColor, root.watch ? 0.10 : (root.bottega ? 0.3 : 0.18))
    }
    // Bottega: the flap of the wallet, a darker curved shade across the top
    Canvas {
        visible: root.bottega
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 56
        onWidthChanged: requestPaint()
        onPaint: {
            var c = getContext('2d')
            c.reset()
            var w = width, r = root.radius
            if (w <= 0) return
            c.beginPath()
            c.moveTo(0, r); c.arcTo(0, 0, r, 0, r)
            c.lineTo(w - r, 0); c.arcTo(w, 0, w, r, r)
            c.lineTo(w, 34)
            c.bezierCurveTo(w * 0.79, 60, w * 0.21, 60, 0, 34)
            c.closePath()
            c.fillStyle = Qt.rgba(0, 0, 0, 0.2)
            c.fill()
        }
    }
    // leather wallet: stitching all round, 7 px from the edge
    EhDashedBorder {
        anchors.fill: parent
        inset: 7
        radius: 12
        lineWidth: root.bottega ? 2 : 1.6
        color: root.watch ? root.tint(root.baseColor, 0.55) : (root.bottega ? '#e3c57e' : Qt.rgba(1, 0.91, 0.77, 0.6))
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
        bottega: root.bottega
        stitch: root.watch ? root.tint(root.baseColor, 0.55) : (root.bottega ? '#e3c57e' : Qt.rgba(1, 0.91, 0.77, 0.6))
        onTapped: app.stack.push(Qt.resolvedUrl('../EhSettings.qml'))
    }

    ColumnLayout {
        id: col
        visible: !root.fixedRows    // the home card has its own block (homeBox, below)
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
            Layout.preferredHeight: 22     // as the "watch only" tag (20 + 2): same card height
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: root.bottega ? 14 : 12
            font.bold: true
            color: Network.isConnected ? (root.bottega ? '#d6eca0' : '#cfe3a0') : '#ffd88a'
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
            // home: the same height with any font, the card keeps its one height (214)
            Layout.preferredHeight: root.fixedRows ? 56 : -1
            verticalAlignment: Text.AlignVCenter
            text: root.euroText !== '' ? root.euroText : root.btcText
            color: root.watch ? root.baseColor : (root.bottega ? '#fbeccb' : '#ffffff')
            font.family: root.bottega ? root.serif : (TitleFont ? TitleFont : font.family)
            font.weight: root.bottega ? Font.ExtraBold : Font.Black
            font.pixelSize: 42
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 14     // review 2026-11-11: 26 was too big for the narrow home card
            clip: true
        }
        Label {
            visible: root.euroText !== '' || root.fiatRoom || root.fixedRows
            Layout.fillWidth: true
            Layout.preferredHeight: root.fixedRows ? 20 : -1
            verticalAlignment: Text.AlignVCenter
            text: root.euroText === '' ? ' ' : (root.covered ? qsTr('tap to see') : root.btcText)
            color: root.watch ? '#6b5d55' : '#ffffff'
            opacity: root.bottega ? 1 : 0.85
            font.pixelSize: root.bottega ? 16 : 15
            font.bold: root.covered
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.preferredHeight: root.fixedRows ? 50 : -1
            spacing: 8
            layoutDirection: root.strapLeft ? Qt.RightToLeft : Qt.LeftToRight
            // expert option "banknotes and coins": the balance as real money.
            // Only a round button with banknotes drawn on it, no text.
            Rectangle {
                id: cashBtn
                visible: root.cashRoom
                opacity: root.showCash ? 1 : 0
                enabled: root.showCash
                Layout.preferredWidth: root.bottega ? 52 : 48
                Layout.preferredHeight: root.bottega ? 52 : 48
                radius: width / 2
                color: cashTap.pressed ? Qt.rgba(1, 1, 1, 0.38) : Qt.rgba(1, 1, 1, 0.18)
                border.width: root.bottega ? 2 : 1.5
                border.color: root.bottega ? '#8a6a1c' : (root.watch ? '#c8961e' : Qt.rgba(1, 1, 1, 0.45))
                // Bottega: brass button
                Rectangle {
                    visible: root.bottega
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: cashTap.pressed ? '#e6cf8a' : '#f8e3a2' }
                        GradientStop { position: 0.6; color: '#d9b25a' }
                        GradientStop { position: 1.0; color: '#b58d32' }
                    }
                }
                Image {
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl(root.bottega ? '../../../icons/eh_cash_wine.svg' : '../../../icons/eh_cash.svg')
                    sourceSize.width: root.bottega ? 30 : 34
                    sourceSize.height: root.bottega ? 30 : 34
                }
                TapHandler { id: cashTap; margin: 6; gesturePolicy: TapHandler.WithinBounds; onTapped: app.stack.push(Qt.resolvedUrl('../EhCashPage.qml')) }
            }
            Item { Layout.fillWidth: true }
        }
        // third review: money received but not confirmed yet; goes away at the first confirmation
        Rectangle {
            visible: root.showArriving && !root.fixedRows
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
            visible: root.showFrozen && !root.fixedRows
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

    // home card (owner 13/11, preview home-ritocchi.html): on top the key, the name and the status
    // (narrow card of "more wallets": the status under the name); the big amount; under it the
    // bitcoin line and the pills (arriving / blocked); the brass cash button on the right, centred
    // on the bitcoin line and the pills. One fixed height, no empty area.
    readonly property string body: BodyFont ? BodyFont : app.font.family
    readonly property color statusInk: Network.isConnected ? (root.watch ? '#45541f' : '#d6eca0') : (root.watch ? '#7a4a12' : '#ffd88a')
    readonly property string statusText: Network.isConnected ? '● ' + qsTr('Up to date') : '● ' + qsTr('Not connected')
    Item {
        id: homeBox
        visible: root.fixedRows
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        anchors.leftMargin: root.showGear ? 92 : 18    // room for the strap on the left
        anchors.rightMargin: 16

        // owner 13/11: the top row is above the strap, so it can start at the left stitching
        readonly property real topShift: root.showGear ? 68 : 0
        // name and status on one line only when both fit whole; otherwise the status goes under
        readonly property bool statusBelow: root.compact || (hName.implicitWidth + hStatusW.implicitWidth + 22 + 14 > hTop.width)
        TextMetrics { id: hStatusW; font.family: root.body; font.pixelSize: 15; font.bold: true; text: root.statusText }
        RowLayout {
            id: hTop
            x: -homeBox.topShift
            width: parent.width + homeBox.topShift
            height: 24
            spacing: 7
            Image {
                Layout.alignment: Qt.AlignVCenter
                source: Qt.resolvedUrl(root.watch ? '../../../icons/eh_eye.svg' : '../../../icons/eh_key_white.svg')
                sourceSize.width: 22
                sourceSize.height: 22
            }
            Label {
                id: hName
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.previewName !== '' ? root.previewName : app.ehWalletName()
                color: root.watch ? root.baseColor : '#ffffff'
                font.family: root.body
                font.pixelSize: 16
                elide: Text.ElideRight
            }
            Label {
                visible: !homeBox.statusBelow && !root.watch
                Layout.alignment: Qt.AlignVCenter
                text: root.statusText
                color: root.statusInk
                font.family: root.body
                font.pixelSize: 15
                font.bold: true
            }
        }
        // narrow card: the status under the name; "watch only" always under the name (the name stays whole)
        Label {
            id: hStatus2
            visible: homeBox.statusBelow && !root.watch
            x: hTop.x + 29
            y: hTop.height
            height: 20
            verticalAlignment: Text.AlignVCenter
            text: root.statusText
            color: root.statusInk
            font.family: root.body
            font.pixelSize: 15
            font.bold: true
        }
        Rectangle {
            visible: root.watch
            x: hTop.x + 29
            y: hTop.height + 1
            height: 20
            width: hWatch2.implicitWidth + 14
            radius: 6
            color: root.tint(root.baseColor, 0.85)
            Label { id: hWatch2; anchors.centerIn: parent; text: qsTr('WATCH ONLY'); color: '#ffffff'; font.pixelSize: 13; font.bold: true }
        }

        Column {
            id: hMid
            readonly property real top0: hTop.height + (homeBox.statusBelow || root.watch ? 21 : 0) + 2
            width: parent.width
            y: top0 + Math.max(0, Math.round((parent.height - top0 - height) / 2))
            spacing: 0
            Label {
                // the big amount; smaller when long (it must not run under the cash button)
                width: parent.width - (root.cashRoom ? 56 : 0)
                height: 52
                verticalAlignment: Text.AlignVCenter
                text: root.euroText !== '' ? root.euroText : root.btcText
                color: root.watch ? root.baseColor : (root.bottega ? '#fbeccb' : '#ffffff')
                font.family: root.serif
                font.weight: Font.ExtraBold
                font.pixelSize: 44
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 14
            }
            Item {
                width: parent.width
                height: Math.max(hLeft.height, root.cashRoom ? 52 : 0)
                Column {
                    id: hLeft
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.pillsRoom
                    spacing: 4
                    Label {
                        visible: root.euroText !== ''
                        width: parent.width
                        height: 20
                        verticalAlignment: Text.AlignVCenter
                        text: root.btcText
                        color: root.watch ? '#6b5d55' : '#ffffff'
                        font.family: root.body
                        font.pixelSize: 16
                        elide: Text.ElideRight
                    }
                    Row {
                        id: hPills
                        visible: root.showFrozen || root.showArriving
                        spacing: 4
                        // both "arriving" and "blocked": short texts
                        readonly property bool both: root.showFrozen && root.showArriving
                        Pill {
                            id: arrPill
                            visible: root.showArriving
                            maxW: hPills.both ? (root.pillsRoom - 4) / 2 : root.pillsRoom
                            fill: root.bottega ? '#fbeccb' : '#d9b25a'
                            ink: '#3f0f21'
                            wait: true
                            text: hPills.both ? app.ehMoney(root.satsAmount(root.arrivingSats))
                                              : qsTr('arriving %1').arg(app.ehMoney(root.satsAmount(root.arrivingSats)))
                        }
                        Pill {
                            visible: root.showFrozen
                            maxW: hPills.both ? root.pillsRoom - 4 - arrPill.width : root.pillsRoom
                            fill: root.bottega ? (blTap2.pressed ? '#ecd9a8' : '#fbeccb')
                                               : (blTap2.pressed ? Qt.rgba(0.75, 0.22, 0.17, 0.8) : Qt.rgba(0.75, 0.22, 0.17, 0.55))
                            ink: root.bottega ? '#3f0f21' : '#ffffff'
                            edge: true
                            lock: true
                            text: (hPills.both ? app.ehMoney(root.satsAmount(root.frozenSats))
                                               : qsTr('blocked %1').arg(app.ehMoney(root.satsAmount(root.frozenSats)))) + ' ›'
                            // the blocked coins open with a tap (no PIN)
                            TapHandler { id: blTap2; margin: 8; gesturePolicy: TapHandler.WithinBounds; onTapped: app.ehOpenCoins() }
                        }
                    }
                }
                // expert option "banknotes and coins": the round brass button with the banknotes
                Rectangle {
                    id: cashBtn2
                    visible: root.cashRoom
                    opacity: root.showCash ? 1 : 0
                    enabled: root.showCash
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 52
                    height: 52
                    radius: 26
                    color: cashTap2.pressed ? Qt.rgba(1, 1, 1, 0.38) : Qt.rgba(1, 1, 1, 0.18)
                    border.width: 2
                    border.color: root.bottega ? '#8a6a1c' : '#c8961e'
                    Rectangle {
                        visible: root.bottega
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: cashTap2.pressed ? '#e6cf8a' : '#f8e3a2' }
                            GradientStop { position: 0.6; color: '#d9b25a' }
                            GradientStop { position: 1.0; color: '#b58d32' }
                        }
                    }
                    Image {
                        anchors.centerIn: parent
                        source: Qt.resolvedUrl(root.bottega ? '../../../icons/eh_cash_wine.svg' : '../../../icons/eh_cash.svg')
                        sourceSize.width: root.bottega ? 30 : 34
                        sourceSize.height: root.bottega ? 30 : 34
                    }
                    TapHandler { id: cashTap2; margin: 6; gesturePolicy: TapHandler.WithinBounds; onTapped: app.stack.push(Qt.resolvedUrl('../EhCashPage.qml')) }
                }
            }
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
