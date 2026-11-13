// Easy Heirs (schȅi): "Quali monete fondere?". Pick by hand the gold coins
// (UTXOs) the payment will melt; blocked coins are not shown. Empty choice =
// the app chooses by itself (Electrum's normal coin selection).
// "Bottega" (WP5): parchment page, "Needed / You chose" on a paper sheet, the list is
// one paper sheet (delegates draw its sides), stitched buttons.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"
import "controls/EhStyle.js" as S

ElDialog {
    id: root
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.olive

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
    background: Rectangle { color: S.parch }

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

    component Money: Label {
        color: S.wineDark
        font.family: SerifFont ? SerifFont : font.family
        font.weight: Font.ExtraBold
        font.pixelSize: 22
    }
    component Key: Label {
        Layout.fillWidth: true
        color: S.muted
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 17
        wrapMode: Text.WordWrap
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 14 + app.navigationBarHeight
        spacing: 10

        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
        // the back link and, on its right, the "i" (so the title keeps the whole width)
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: -14
            spacing: 10
            EhBackLink {
                Layout.topMargin: 0
                Layout.fillWidth: true
                onClicked: root.doReject()
            }
            // owner 12/11: "how the gold coins work" (the crucible) opens from here;
            // 13/11: a small stitched paper pill, well visible (was a pale "i")
            EhStitchButton {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: false
                Layout.preferredWidth: implicitWidth
                kind: 'paper'
                compact: true
                text: qsTr('How it works') + ' ›'
                onClicked: app.ehOpenPage(Qt.resolvedUrl('EhCoinsHowPage.qml'))
            }
        }
        EhTitle {
            Layout.topMargin: -6
            text: qsTr('Which coins to melt?')
        }

        // needed / chosen
        EhSheet {
            topPadding: 10
            bottomPadding: 12
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Key { text: qsTr('Needed') }
                Money { text: app.ehMoney(root.satsAmount(root.needSats)) }
            }
            RowLayout {
                Layout.fillWidth: true
                Key { text: qsTr('You chose') }
                Money { text: app.ehMoney(root.satsAmount(root.chosenSats)) + (root.enough ? ' ✓' : '')
                        color: root.enough ? S.oliveInk : S.wineDark }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 12
                Layout.topMargin: 2
                radius: 6
                color: S.sand
                Rectangle {
                    height: parent.height
                    radius: 6
                    width: parent.width * Math.min(1, root.needSats > 0 ? root.chosenSats / root.needSats : 0)
                    color: root.enough ? S.olive : S.gold
                }
            }
            Label {
                visible: root.enough
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
                color: S.ink
                text: root.enough ? qsTr('The change, <b>%1</b>, comes back to you as a new coin.').arg(app.ehMoney(root.satsAmount(root.chosenSats - root.needSats))) : ''
            }
            EhInfoBox {
                visible: !root.enough
                Layout.topMargin: 2
                kind: 'danger'
                text: !root.enough ? qsTr('Still missing: <b>%1</b>').arg(app.ehMoney(root.satsAmount(root.needSats - root.chosenSats))) : ''
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: Daemon.currentWallet.addressCoinModel.filterModel
            // rounded top and bottom of the sheet
            header: Item {
                width: list.width
                height: 14
                clip: true
                Rectangle { width: parent.width; height: 40; radius: 18; color: S.paper; border.width: 1.5; border.color: S.edge }
            }
            footer: Item {
                width: list.width
                height: 17
                clip: true
                Rectangle { y: -23; width: parent.width; height: 40; radius: 18; color: S.edgeShadow }
                Rectangle { y: -26; width: parent.width; height: 40; radius: 18; color: S.paper; border.width: 1.5; border.color: S.edge }
            }
            delegate: Item {
                id: d
                required property var model
                required property int index
                readonly property bool on: root.chosen[d.model.outpoint] !== undefined
                width: ListView.view.width
                // blocked coins are not offered
                visible: d.model.outpoint !== undefined && d.model.outpoint !== '' && !d.model.held && !d.model.addr_held
                height: visible ? Math.max(70, dRow.implicitHeight + 20) : 0
                // the sheet's paper and its two side edges
                Rectangle { anchors.fill: parent; color: S.paper }
                Rectangle { x: 0; width: 1.5; height: parent.height; color: S.edge }
                Rectangle { x: parent.width - 1.5; width: 1.5; height: parent.height; color: S.edge }
                // chosen: wine border round the row; pressed: sand
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 6; anchors.rightMargin: 6
                    anchors.topMargin: 3; anchors.bottomMargin: 3
                    radius: 12
                    color: dTap.pressed ? Qt.rgba(0.902, 0.847, 0.714, 0.5) : 'transparent'
                    border.width: d.on ? 2.5 : 0
                    border.color: S.wine
                }
                EhDotLine {
                    visible: !d.on && d.index < list.count - 1
                    x: 12
                    width: parent.width - 24
                    anchors.bottom: parent.bottom
                }
                RowLayout {
                    id: dRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10
                    // the tick: empty paper box, or brass with the tick when chosen
                    Rectangle {
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 9
                        color: S.paper
                        border.width: d.on ? 2 : 2.5
                        border.color: d.on ? S.brassRing : S.switchOff
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: d.on ? S.brassLight : S.paper }
                            GradientStop { position: 0.55; color: d.on ? S.brass : S.paper }
                            GradientStop { position: 1.0; color: d.on ? S.brassDark : S.paper }
                        }
                        Label { anchors.centerIn: parent; visible: d.on; text: '✓'; color: S.wineDark; font.pixelSize: 20; font.bold: true }
                    }
                    Image {
                        readonly property int sats: d.model.amount ? d.model.amount.satsInt : 0
                        Layout.preferredWidth: 40; Layout.preferredHeight: 40
                        source: Qt.resolvedUrl('../../icons/eh_goldcoin_' + (sats < 100000 ? 1 : (sats < 1000000 ? 2 : 3)) + '.svg')
                        sourceSize.width: 80; sourceSize.height: 80
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Label {
                            Layout.fillWidth: true
                            text: d.model.amount ? app.ehMoney(d.model.amount) : ''
                            color: S.wineDark
                            font.family: SerifFont ? SerifFont : font.family
                            font.weight: Font.ExtraBold
                            font.pixelSize: 21
                            wrapMode: Text.WrapAnywhere
                        }
                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 16
                            font.italic: true
                            color: d.model.label ? S.wine : S.muted
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
            wrapMode: Text.WordWrap
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 16
            color: S.muted
            text: qsTr('Blocked coins do not appear here.')
        }
        // text link (not a button): 17 bold wine, 2 px underline, 48 px to the finger
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.topMargin: -8
            Layout.bottomMargin: -4
            RowLayout {
                id: blkL
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                opacity: blkT.pressed ? 0.6 : 1
                Image { source: Qt.resolvedUrl('../../icons/eh_lock.svg'); sourceSize.width: 20; sourceSize.height: 20 }
                Label {
                    id: blkTxt
                    text: qsTr('Block coins and addresses') + ' ›'
                    color: S.wine
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 17
                    font.bold: true
                    Rectangle { y: parent.height + 1; width: parent.width; height: 2; color: S.wine }
                }
            }
            TapHandler { id: blkT; onTapped: app.ehOpenCoins() }
        }
        EhStitchButton {
            kind: 'wine'
            endIcon: 'next'
            enabled: root.enough
            text: qsTr('Use these coins')
            onClicked: {
                var list = []
                for (var k in root.chosen) list.push(k)
                if (root.finalizer) root.finalizer.ehCoins = list
                root.doAccept()
            }
        }
        EhStitchButton {
            kind: 'paper'
            icon: 'eh_undo.svg'
            text: qsTr('Choose by itself (normal)')
            onClicked: {
                if (root.finalizer) root.finalizer.ehCoins = []
                root.doAccept()
            }
        }
    }
}
