// Easy Heirs (schèi): "Come funzionano le monete d'oro digitale (bitcoin)".
// Euro coins (fixed value) vs gold coins (variable value), then a 12 s loop:
// two gold coins go into the crucible (= the transaction), it melts them, and
// at the same time come out the coin for who receives, the change for you and
// the gold dust tip for the miner. Positions follow the approved mockup
// (anteprima\pepite.html), as fractions of the scene.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: '#2a2220'

    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    EhGlow { tone: 'gold'; x: -page.width * 0.3; y: 40; width: page.width * 1.6; height: 380 }

    // piecewise linear value at time t (0..1): pts = [[t0, v0], [t1, v1], ...]
    function k(t, pts) {
        if (t <= pts[0][0]) return pts[0][1]
        for (var i = 1; i < pts.length; i++) {
            if (t <= pts[i][0]) {
                var a = pts[i - 1], b = pts[i]
                return a[1] + (b[1] - a[1]) * (t - a[0]) / Math.max(0.0001, b[0] - a[0])
            }
        }
        return pts[pts.length - 1][1]
    }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.implicitHeight + 24
        clip: true
        ColumnLayout {
            id: col
            x: 16
            width: parent.width - 32
            spacing: 10

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            Label {
                Layout.topMargin: -14
                text: '‹ ' + qsTr('Your gold coins')
                color: '#5e1a33'; font.pixelSize: 17; font.bold: true
                TapHandler { margin: 10; onTapped: app.stack.pop() }
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr('How do the gold coins of digital gold (bitcoin) work?')
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 23
            }

            // euro coins vs gold coins
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: vsCol.implicitHeight + 24
                radius: 16
                color: Qt.rgba(1, 1, 1, 0.75)
                border.width: 2
                border.color: '#ecd49a'
                ColumnLayout {
                    id: vsCol
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 2
                            EhCoin { Layout.alignment: Qt.AlignHCenter; c: 200; Layout.preferredWidth: 36; Layout.preferredHeight: 36 }
                            Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.pixelSize: 13
                                    textFormat: Text.StyledText; text: '<b>' + qsTr('Euro') + '</b><br>' + qsTr('fixed value, written on it') }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 2
                            Image { Layout.alignment: Qt.AlignHCenter; source: Qt.resolvedUrl('../../icons/eh_goldcoin.svg'); sourceSize.width: 44; sourceSize.height: 44 }
                            Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.pixelSize: 13
                                    textFormat: Text.StyledText; text: '<b>' + qsTr('Digital gold (bitcoin)') + '</b><br>' + qsTr('variable value: what is inside') }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        font.pixelSize: 14
                        text: qsTr('Euro coins have their value printed on them (1 €, 2 €, 50 c) and do not change. Digital gold coins do not: each one is worth what is inside, every time a different amount, and they can be <b>melted</b> to make smaller ones or joined into a bigger one.')
                    }
                }
            }

            // ---------------- the crucible scene ----------------
            Rectangle {
                id: scene
                Layout.fillWidth: true
                Layout.preferredHeight: 330
                radius: 20
                clip: true
                gradient: Gradient {
                    GradientStop { position: 0; color: '#fbf4e4' }
                    GradientStop { position: 1; color: '#f3e6c8' }
                }
                readonly property real sx: width / 293      // mockup scene was 293 px wide
                property real t: 0
                // T12: slower (20 s a round instead of 12) and a tap on the crucible
                // jumps to the next step (1 -> 2 -> 3 -> 1) for whoever wants to go faster
                readonly property real roundMs: 20000
                readonly property var stepStarts: [0.0, 0.32, 0.62]
                Timer {
                    interval: 40; repeat: true; running: page.visible
                    onTriggered: scene.t = (scene.t + interval / scene.roundMs) % 1
                }
                function nextStep() {
                    for (var i = 0; i < stepStarts.length; i++)
                        if (stepStarts[i] > scene.t + 0.005) { scene.t = stepStarts[i]; return }
                    scene.t = 0
                }
                readonly property real heat: page.k(t, [[0.30, 0], [0.40, 1], [0.62, 1], [0.72, 0]])

                // you, who receives, the miner
                Column {
                    x: 8; y: 118
                    width: 70
                    Image { anchors.horizontalCenter: parent.horizontalCenter; source: Qt.resolvedUrl('../../icons/eh_rx_olive.svg'); sourceSize.width: 36; sourceSize.height: 36 }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr('you'); font.pixelSize: 12; font.bold: true; color: '#3f0f21' }
                }
                Column {
                    x: scene.width - 82; y: 118
                    width: 76
                    Image { anchors.horizontalCenter: parent.horizontalCenter; source: Qt.resolvedUrl('../../icons/eh_home_wine.svg'); sourceSize.width: 32; sourceSize.height: 32 }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr('who receives'); font.pixelSize: 12; font.bold: true; color: '#3f0f21' }
                }
                Column {
                    x: scene.width - 82; y: 40
                    width: 70
                    Image { anchors.horizontalCenter: parent.horizontalCenter; source: Qt.resolvedUrl('../../icons/eh_pick.svg'); sourceSize.width: 28; sourceSize.height: 28 }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr('miner'); font.pixelSize: 12; font.bold: true; color: '#8a5a12' }
                }

                // crucible: flames behind, pot, glow in front
                Item {
                    id: cru
                    width: 120; height: 110
                    x: (scene.width - width) / 2
                    y: 58
                    Image {
                        anchors.fill: parent
                        source: Qt.resolvedUrl('../../icons/eh_crucible_fire.svg')
                        sourceSize.width: 240; sourceSize.height: 220
                        opacity: scene.heat
                        transformOrigin: Item.Bottom
                        // flicker while hot
                        scale: 1 + 0.06 * Math.sin(scene.t * 2 * Math.PI * 30)
                    }
                    Image { anchors.fill: parent; source: Qt.resolvedUrl('../../icons/eh_crucible.svg'); sourceSize.width: 240; sourceSize.height: 220 }
                    Image { anchors.fill: parent; source: Qt.resolvedUrl('../../icons/eh_crucible_glow.svg'); sourceSize.width: 240; sourceSize.height: 220; opacity: scene.heat }
                    MouseArea { anchors.fill: parent; anchors.margins: -16; onClicked: scene.nextStep() }
                }
                Rectangle {
                    x: (scene.width - width) / 2
                    y: 172
                    width: Math.min(ctagL.implicitWidth, scene.width - 56) + 16
                    height: ctagL.height + 6
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.88)
                    border.width: 1
                    border.color: '#ecd49a'
                    Label { id: ctagL; anchors.centerIn: parent; textFormat: Text.StyledText; font.pixelSize: 13; font.bold: true; color: '#3f0f21'
                            width: Math.min(implicitWidth, scene.width - 56); wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                            text: qsTr('the <b>crucible</b> = the transaction on the blockchain') }
                }

                // one moving gold coin with its value and UTXO
                component Moving: Item {
                    id: mv
                    property real size: 40
                    property string value
                    property string utxo
                    property var px     // [[t, x], ...] mockup px
                    property var py
                    property var op
                    property var sc: [[0, 1]]
                    z: 3
                    width: size; height: size
                    x: page.k(scene.t, px) * scene.sx
                    y: page.k(scene.t, py)
                    opacity: page.k(scene.t, op)
                    scale: page.k(scene.t, sc)
                    Image { anchors.fill: parent; source: Qt.resolvedUrl('../../icons/eh_goldcoin.svg'); sourceSize.width: 120; sourceSize.height: 120 }
                    Rectangle {
                        visible: mv.value !== ''
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: -4
                        width: tagCol.implicitWidth + 10
                        height: tagCol.implicitHeight + 4
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.88)
                        Column {
                            id: tagCol
                            anchors.centerIn: parent
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: mv.value; font.pixelSize: 11; font.bold: true; color: '#3f0f21' }
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: 'UTXO ' + mv.utxo; font.family: FixedFont; font.pixelSize: 9; font.bold: true; color: '#8a5a12' }
                        }
                    }
                }
                Moving { size: 46; value: '€ 120'; utxo: 'a3f9…:0'
                         px: [[0, 14], [0.08, 14], [0.28, 142]]; py: [[0, 62], [0.08, 62], [0.28, 66]]
                         op: [[0, 1], [0.28, 1], [0.32, 0]] }
                Moving { size: 34; value: '€ 50'; utxo: '7bd0…:1'
                         px: [[0, 74], [0.12, 74], [0.32, 150]]; py: [[0, 36], [0.12, 36], [0.32, 66]]
                         op: [[0, 1], [0.32, 1], [0.36, 0]] }
                Moving { size: 48; value: '€ 150'; utxo: 'e7c2…:0'
                         px: [[0.62, 146], [0.68, 146], [0.88, 248]]; py: [[0.62, 66], [0.68, 66], [0.88, 126]]
                         op: [[0.62, 0], [0.68, 1]]; sc: [[0.62, 0.4], [0.68, 1]] }
                Moving { size: 32; value: '€ 19,90'; utxo: 'e7c2…:1'
                         px: [[0.64, 150], [0.70, 150], [0.90, 26]]; py: [[0.64, 70], [0.70, 70], [0.90, 84]]
                         op: [[0.64, 0], [0.70, 1]]; sc: [[0.64, 0.3], [0.70, 0.85]] }
                // gold dust: the miner's tip, together with the two new coins
                Moving { size: 14
                         px: [[0.62, 160], [0.86, 262]]; py: [[0.62, 60], [0.86, 52]]
                         op: [[0.62, 0], [0.68, 1], [0.86, 1], [0.92, 0]] }

                // captions, one per step
                Repeater {
                    model: [
                        { 'a': 0.0, 'b': 0.30, 'txt': qsTr('<b>1.</b> You have to send <b>€ 150</b>: no coin is enough on its own, so I take two, of 120 € and 50 €.') },
                        { 'a': 0.32, 'b': 0.60, 'txt': qsTr('<b>2.</b> The <b>transaction</b> is the crucible: it melts the coins. The miner seals it in the register (the block).') },
                        { 'a': 0.62, 'b': 0.98, 'txt': qsTr('<b>3.</b> Together come out: <b>€ 150</b> to who receives, the <b>change € 19.90</b> to you (UTXO e7c2…:0 and :1), and <b>the tip to the miner</b>: a few grains of gold that he collects together with those of many other payments.') }
                    ]
                    Rectangle {
                        required property var modelData
                        x: 10
                        width: scene.width - 20
                        y: scene.height - height - 8
                        height: capL.implicitHeight + 16
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.85)
                        opacity: page.k(scene.t, [[modelData.a, 0], [modelData.a + 0.02, 1], [modelData.b, 1], [modelData.b + 0.02, 0]])
                        Label {
                            id: capL
                            x: 8; y: 8
                            width: parent.width - 16
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            textFormat: Text.StyledText
                            font.pixelSize: 14
                            text: modelData.txt
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: whatL.implicitHeight + 22
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.78)
                border.width: 2
                border.color: '#ecd49a'
                Label {
                    id: whatL
                    x: 11; y: 11
                    width: parent.width - 22
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font.pixelSize: 14
                    text: qsTr('<b>What is the crucible?</b> In Bitcoin it is called <b>transaction</b>. It takes some gold coins (the UTXOs you spend), melts them and mints new coins: one for who receives and one with the change for you. The old coins disappear for ever: they cannot be spent twice.')
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: sumL.implicitHeight + 22
                radius: 14
                color: Qt.rgba(0.98, 0.94, 0.84, 0.92)
                Label {
                    id: sumL
                    x: 11; y: 11
                    width: parent.width - 22
                    wrapMode: Text.WordWrap
                    font.pixelSize: 14
                    text: qsTr('120 € + 50 € = 170 € go in · 150 € + 19.90 € = 169.90 € come out · the 10 cents missing are the tip to the miner.')
                }
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                font.pixelSize: 13
                color: '#6b5d55'
                text: qsTr('The change arrives on one of your <b>change addresses</b>: you find it in "Addresses", in the group "Change".')
            }
        }
    }
}
