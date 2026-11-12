// Easy Heirs (schèi): "Quali monete fondere?". Pick by hand the gold coins
// (UTXOs) the payment will melt; blocked coins are not shown. Empty choice =
// the app chooses by itself (Electrum's normal coin selection).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"

ElDialog {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#45541f'

    property var finalizer
    property real needSats: 0          // amount + current sending cost (real: no 21 BTC limit)
    property var chosen: ({})          // outpoint -> sats
    property real chosenSats: 0

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    background: Rectangle { color: '#faf7ef' }

    function satsAmount(s) { return Config.unitsToSats((s / 100000000).toFixed(8)) }
    function toggle(outpoint, sats) {
        var c = Object.assign({}, chosen)
        if (c[outpoint] !== undefined) delete c[outpoint]; else c[outpoint] = sats
        chosen = c
        var tot = 0
        for (var k in c) tot += c[k]
        chosenSats = tot
    }
    readonly property bool enough: chosenSats >= needSats && chosenSats > 0

    Component.onCompleted: {
        Daemon.currentWallet.addressCoinModel.initModel(true)
        var fm = Daemon.currentWallet.addressCoinModel.filterModel
        fm.showAddressesCoins = 2
        // start from the coins already chosen by hand, if any: filled in ONCE here
        // (review 2026-11-11: doing it in the rows re-ticked coins when they scrolled back)
        preset = finalizer ? finalizer.ehCoins : []
        if (preset.length > 0) {
            var c = {}, tot = 0, addrs = Daemon.currentWallet.ehAddresses()
            for (var i = 0; i < addrs.length; i++) {
                if (addrs[i].held) continue
                for (var j = 0; j < addrs[i].coins.length; j++) {
                    var co = addrs[i].coins[j]
                    if (!co.held && preset.indexOf(co.outpoint) >= 0) { c[co.outpoint] = co.sats; tot += co.sats }
                }
            }
            chosen = c
            chosenSats = tot
        }
    }
    property var preset: []

    EhGlow { tone: 'gold'; x: -root.width * 0.3; y: 40; width: root.width * 1.6; height: 380 }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 14 + app.navigationBarHeight
        spacing: 8

        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6; Layout.bottomMargin: -14 }
        Label {
            text: '‹ ' + qsTr('Back')
            color: '#5e1a33'; font.pixelSize: 17; font.bold: true
            TapHandler { margin: 10; onTapped: root.doReject() }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr('Which coins to melt?')
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 24
            }
            // owner 12/11: "how the gold coins work" (the crucible) opens from here
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: howT.pressed ? '#2f3a12' : '#45541f'
                Label { anchors.centerIn: parent; text: 'i'; color: '#ffffff'; font.pixelSize: 19; font.bold: true; font.family: 'serif' }
                TapHandler { id: howT; margin: 8; onTapped: app.ehOpenPage(Qt.resolvedUrl('EhCoinsHowPage.qml')) }
            }
        }

        // needed / chosen
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: sumCol.implicitHeight + 22
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.75)
            border.width: 2
            border.color: '#ecd49a'
            ColumnLayout {
                id: sumCol
                x: 12; y: 11
                width: parent.width - 24
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: qsTr('Needed'); font.pixelSize: 14; color: '#6b5d55' }
                    Item { Layout.fillWidth: true }
                    Label { text: app.ehMoney(root.satsAmount(root.needSats)); font.pixelSize: 15; font.bold: true }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: qsTr('You chose'); font.pixelSize: 14; color: '#6b5d55' }
                    Item { Layout.fillWidth: true }
                    Label { text: app.ehMoney(root.satsAmount(root.chosenSats)) + (root.enough ? ' ✓' : '')
                            font.pixelSize: 15; font.bold: true; color: root.enough ? '#45541f' : '#2a2220' }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 12
                    radius: 6
                    color: '#ece4d2'
                    Rectangle {
                        height: parent.height
                        radius: 6
                        width: parent.width * Math.min(1, root.needSats > 0 ? root.chosenSats / root.needSats : 0)
                        color: root.enough ? '#45541f' : '#d9b25a'
                    }
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font.pixelSize: 13
                    color: root.enough ? '#4a4038' : '#b3261e'
                    text: root.enough
                          ? qsTr('The change, <b>%1</b>, comes back to you as a new coin.').arg(app.ehMoney(root.satsAmount(root.chosenSats - root.needSats)))
                          : qsTr('Still missing: <b>%1</b>').arg(app.ehMoney(root.satsAmount(root.needSats - root.chosenSats)))
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: Daemon.currentWallet.addressCoinModel.filterModel
            delegate: Item {
                id: d
                required property var model
                readonly property bool on: root.chosen[d.model.outpoint] !== undefined
                width: ListView.view.width
                // blocked coins are not offered
                visible: d.model.outpoint !== undefined && d.model.outpoint !== '' && !d.model.held && !d.model.addr_held
                height: visible ? Math.max(62, dRow.implicitHeight + 14) : 0
                Rectangle {
                    anchors.fill: parent
                    color: dTap.pressed ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.66)
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0.16, 0.13, 0.13, 0.07) }
                }
                RowLayout {
                    id: dRow
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 8
                        color: d.on ? '#45541f' : 'transparent'
                        border.width: 2.5
                        border.color: d.on ? '#45541f' : '#b3a894'
                        Label { anchors.centerIn: parent; visible: d.on; text: '✓'; color: '#ffffff'; font.pixelSize: 17; font.bold: true }
                    }
                    Image {
                        readonly property int sats: d.model.amount ? d.model.amount.satsInt : 0
                        Layout.preferredWidth: 40; Layout.preferredHeight: 40
                        source: Qt.resolvedUrl('../../icons/eh_goldcoin_' + (sats < 100000 ? 1 : (sats < 1000000 ? 2 : 3)) + '.svg')
                        sourceSize.width: 80; sourceSize.height: 80
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label { text: d.model.amount ? app.ehMoney(d.model.amount) : ''; font.pixelSize: 16; font.bold: true }
                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.pixelSize: 13
                            font.italic: true
                            color: d.model.label ? '#5e1a33' : '#6b5d55'
                            text: d.model.label ? d.model.label : qsTr('no note')
                        }
                    }
                }
                TapHandler { id: dTap; onTapped: root.toggle(d.model.outpoint, d.model.amount.satsInt) }
            }
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 12
            color: '#6b5d55'
            text: qsTr('Blocked coins do not appear here.')
        }
        Label {
            Layout.fillWidth: true
            text: '🔒 ' + qsTr('Block coins and addresses') + ' ›'
            color: '#5e1a33'
            font.pixelSize: 15
            font.bold: true
            font.underline: true
            TapHandler { margin: 8; onTapped: app.ehOpenCoins() }
        }
        EhNextButton {
            Layout.fillWidth: true
            enabled: root.enough
            opacity: enabled ? 1 : 0.45
            text: qsTr('Use these coins')
            onClicked: {
                var list = []
                for (var k in root.chosen) list.push(k)
                if (root.finalizer) root.finalizer.ehCoins = list
                root.doAccept()
            }
        }
        EhPillButton {
            text: qsTr('Choose by itself (normal)')
            color: '#ffffff'
            textColor: '#2a2220'
            tileColor: '#efe6d3'
            fontSize: 17
            onClicked: {
                if (root.finalizer) root.finalizer.ehCoins = []
                root.doAccept()
            }
            Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_undo.svg'); sourceSize.width: 24; sourceSize.height: 24 }
        }
    }
}
