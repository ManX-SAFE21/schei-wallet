// Easy Heirs (schèi): "I tuoi indirizzi", opened from Receive (T8, owner 2026-11-09).
// Every address is a "pocket" of the wallet and can hold more coins (UTXO).
// The switch blocks the whole address (Electrum's "freeze address"): none of its
// coins is used to pay, also the ones that will arrive later.
// "Bottega" (WP5): parchment page, one paper sheet per group, dotted lines between rows.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"
import "controls/EhStyle.js" as S

Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: S.ink

    property var items: []
    function reload() { page.items = Daemon.currentWallet ? Daemon.currentWallet.ehAddresses() : [] }
    Component.onCompleted: reload()
    // coming back from one address: its note or block may have changed
    StackView.onActivated: reload()

    function satsAmount(s) { return Config.unitsToSats((s / 100000000).toFixed(8)) }
    function shortUtxo(outpoint) {
        var i = outpoint.indexOf(':')
        var txid = i > 0 ? outpoint.substring(0, i) : outpoint
        return txid.substring(0, 4) + '…' + txid.slice(-4) + (i > 0 ? outpoint.substring(i) : '')
    }
    // short address: prefix, first 4 … last 4, the two groups of 4 highlighted
    function shortAddr(a) {
        var p = app.ehAddressParts(a)
        var hl = function (s) { return '<span style="background-color:' + S.highlight + '"><font color="' + S.wineDark + '">' + s + '</font></span>' }
        return (p.prefix !== '' ? p.prefix + ' ' : '') + hl(p.first) + ' … ' + hl(p.last)
    }
    function showBlockInfo() {
        app.ehInfoDialog.createObject(app, {
            pageTitle: qsTr('Blocking an address'),
            bodyText: qsTr('Every address is like a <b>pocket</b> of your wallet: it can hold <b>more coins</b>.')
                      + '<br><br>' + qsTr('If you <b>block an address</b>, all the coins inside it are blocked: the app will not use them to pay. Also the coins that arrive <b>later</b> on that address are blocked.')
                      + '<br><br>' + qsTr('The coins stay yours: you still see them in the balance, as blocked. To use them again, unblock the address.')
                      + '<br><br>' + qsTr('To block only one coin, use its own switch in "Your gold coins".')
        }).open()
    }

    Rectangle { anchors.fill: parent; color: S.parch }

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
            EhBackLink { text: '‹ ' + qsTr('Receive'); onClicked: app.stack.pop() }
            EhTitle { Layout.topMargin: -6; text: qsTr('Your addresses') }

            // what an address is: the "i" opens the long explanation
            EhInfoBox {
                kind: 'warn'
                showIcon: false
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        color: S.ink
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: 16
                        lineHeight: 1.15
                        text: qsTr('Every address is a "pocket" of the wallet and can hold <b>more coins</b>. If you block an address, the app uses none of its coins.')
                    }
                    Rectangle {
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                        Layout.alignment: Qt.AlignTop
                        color: 'transparent'
                        border.width: 2.5
                        border.color: S.brassRing
                        Label { anchors.centerIn: parent; text: 'i'; color: S.brassRing; font.pixelSize: 20; font.bold: true; font.family: 'serif' }
                        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: page.showBlockInfo() }
                    }
                }
            }

            Repeater {
                model: [ { 'kind': 'receive', 'title': qsTr('TO RECEIVE') }, { 'kind': 'change', 'title': qsTr('CHANGE') } ]
                ColumnLayout {
                    id: grp
                    required property var modelData
                    readonly property var rows: page.items.filter(function (it) { return it.kind === grp.modelData.kind })
                    visible: rows.length > 0
                    Layout.fillWidth: true
                    spacing: 0
                    EhCaption { Layout.topMargin: 8; text: grp.modelData.title }
                    EhSheet {
                        bottomPadding: 4
                        Repeater {
                            model: grp.rows
                            ColumnLayout {
                                id: ad
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: 0
                                EhDotLine { visible: ad.index > 0 }
                                // the address
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.max(64, aRow.implicitHeight + 18)
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: -6; anchors.rightMargin: -6
                                        anchors.topMargin: 2; anchors.bottomMargin: 2
                                        radius: 10
                                        color: S.sand
                                        opacity: aMa.pressed ? 0.4 : 0
                                    }
                                    MouseArea {
                                        id: aMa
                                        z: -1
                                        anchors.fill: parent
                                        onClicked: app.stack.push(Qt.resolvedUrl('EhAddressPage.qml'), { address: ad.modelData.address })
                                    }
                                    RowLayout {
                                        id: aRow
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Label {
                                                Layout.fillWidth: true
                                                wrapMode: Text.WordWrap
                                                textFormat: Text.RichText
                                                font.family: FixedFont
                                                font.pixelSize: 17
                                                font.bold: true
                                                color: S.ink
                                                text: page.shortAddr(ad.modelData.address)
                                            }
                                            Label {
                                                Layout.fillWidth: true
                                                text: app.ehMoney(page.satsAmount(ad.modelData.sats))
                                                font.family: SerifFont ? SerifFont : font.family
                                                font.weight: Font.ExtraBold
                                                font.pixelSize: 21
                                                color: ad.modelData.held ? S.red : S.wineDark
                                                wrapMode: Text.WrapAnywhere
                                            }
                                            Label {
                                                visible: ad.modelData.label !== ''
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                text: ad.modelData.label
                                                font.family: BodyFont ? BodyFont : font.family
                                                font.pixelSize: 16; font.italic: true; color: S.wine
                                            }
                                            Label {
                                                Layout.fillWidth: true
                                                wrapMode: Text.WordWrap
                                                font.family: BodyFont ? BodyFont : font.family
                                                font.pixelSize: 16
                                                color: S.muted
                                                text: ad.modelData['new'] ? qsTr('empty · new')
                                                      : (ad.modelData.coins.length === 0 ? qsTr('empty · used')
                                                         : (ad.modelData.coins.length === 1 ? qsTr('1 coin') : qsTr('%1 coins').arg(ad.modelData.coins.length)))
                                            }
                                        }
                                        EhSpendSwitch {
                                            visible: !ad.modelData['new']
                                            blockedText: qsTr('blocked (address)')
                                            spendable: !ad.modelData.held
                                            onToggled: {
                                                Daemon.currentWallet.ehSetAddressFrozen(ad.modelData.address, !spendable)
                                                page.reload()
                                            }
                                        }
                                    }
                                }
                                // its coins, INSIDE their address (owner 13/11): indented under the
                                // address text, joined to it by a wine "tree" line with a tick per coin,
                                // on a tinted strip that belongs to this address block only
                                Repeater {
                                    model: ad.modelData.coins
                                    Item {
                                        id: cr
                                        required property var modelData
                                        required property int index
                                        readonly property bool blocked: cr.modelData.held || ad.modelData.held
                                        readonly property bool lastCoin: cr.index === ad.modelData.coins.length - 1
                                        Layout.fillWidth: true
                                        Layout.topMargin: cr.index === 0 ? -8 : 0
                                        Layout.preferredHeight: Math.max(54, crRow.implicitHeight + 12) + (cr.lastCoin ? 10 : 0)
                                        // the tree: down from under the address, a tick to each coin
                                        Rectangle {
                                            x: 6; y: 0
                                            width: 2
                                            height: cr.lastCoin ? crBox.y + crBox.height / 2 + 1 : parent.height
                                            color: S.wine
                                        }
                                        Rectangle {
                                            x: 6; y: crBox.y + crBox.height / 2 - 1
                                            width: 14; height: 2
                                            color: S.wine
                                        }
                                        // tinted strip: top and bottom rounded only at the first / last coin
                                        Rectangle {
                                            id: crBox
                                            x: 20; y: 0
                                            width: parent.width - 20
                                            height: parent.height - (cr.lastCoin ? 10 : 0)
                                            radius: 10
                                            color: S.parch
                                            Rectangle { visible: !cr.lastCoin; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 10; color: S.parch }
                                            Rectangle { visible: cr.index > 0; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 10; color: S.parch }
                                        }
                                        RowLayout {
                                            id: crRow
                                            anchors.left: crBox.left
                                            anchors.right: crBox.right
                                            anchors.verticalCenter: crBox.verticalCenter
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            opacity: cr.blocked ? 0.65 : 1
                                            Image { source: Qt.resolvedUrl('../../icons/eh_goldcoin_1.svg'); sourceSize.width: 26; sourceSize.height: 26; Layout.preferredWidth: 26; Layout.preferredHeight: 26 }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Label {
                                                    Layout.fillWidth: true
                                                    text: app.ehMoney(page.satsAmount(cr.modelData.sats))
                                                    font.family: BodyFont ? BodyFont : font.family
                                                    font.pixelSize: 17; font.bold: true; color: S.ink
                                                    wrapMode: Text.WrapAnywhere
                                                }
                                                Label {
                                                    Layout.fillWidth: true
                                                    wrapMode: Text.WordWrap
                                                    font.family: BodyFont ? BodyFont : font.family
                                                    font.pixelSize: 16
                                                    color: S.muted
                                                    text: ad.modelData.held ? qsTr('blocked (with the address)')
                                                          : (cr.modelData.held ? qsTr('blocked') : 'UTXO ' + page.shortUtxo(cr.modelData.outpoint))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // owner 13/11: how the coins work, under the addresses and their coins
            EhSheet {
                Layout.topMargin: 8
                EhRow {
                    icon: 'eh_goldcoin.svg'
                    iconColor: S.brassRing
                    text: qsTr('How do the gold coins of digital gold (bitcoin) work?')
                    last: true
                    onClicked: app.ehPush(Qt.resolvedUrl('EhCoinsHowPage.qml'))
                }
            }
        }
    }
}
