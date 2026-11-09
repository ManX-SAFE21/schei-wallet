// Easy Heirs (schèi): "I tuoi indirizzi", opened from Receive (T8, owner 2026-11-09).
// Every address is a "pocket" of the wallet and can hold more coins (UTXO).
// The switch blocks the whole address (Electrum's "freeze address"): none of its
// coins is used to pay, also the ones that will arrive later.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"

Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: '#2a2220'

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
    function shortAddr(a) {
        var p = app.ehAddressParts(a)
        return (p.prefix !== '' ? p.prefix + ' ' : '') + '<u>' + p.first + '</u> … <u>' + p.last + '</u>'
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

    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    EhGlow { tone: 'gold'; x: -page.width * 0.3; y: 40; width: page.width * 1.6; height: 380 }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.implicitHeight + 24
        clip: true
        ColumnLayout {
            id: col
            x: 16
            width: parent.width - 32
            spacing: 8

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            Label {
                Layout.topMargin: -14
                text: '‹ ' + qsTr('Receive')
                color: '#5e1a33'; font.pixelSize: 17; font.bold: true
                TapHandler { margin: 10; onTapped: app.stack.pop() }
            }
            Label {
                Layout.fillWidth: true
                text: qsTr('Your addresses')
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 30
                wrapMode: Text.WordWrap
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: tipRow.implicitHeight + 20
                radius: 14
                color: '#fbf0d6'
                RowLayout {
                    id: tipRow
                    x: 12; y: 10
                    width: parent.width - 24
                    spacing: 8
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        font.pixelSize: 14
                        text: qsTr('Every address is a "pocket" of the wallet and can hold <b>more coins</b>. If you block an address, the app uses none of its coins.')
                    }
                    Rectangle {
                        Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                        Layout.alignment: Qt.AlignTop
                        color: '#45541f'
                        Label { anchors.centerIn: parent; text: 'i'; color: '#ffffff'; font.pixelSize: 15; font.bold: true; font.family: 'serif' }
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
                    spacing: 6
                    Label {
                        Layout.topMargin: 6
                        Layout.leftMargin: 4
                        text: grp.modelData.title
                        font.pixelSize: 13; font.bold: true; font.letterSpacing: 0.6
                        color: '#45541f'
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: rowsCol.implicitHeight
                        radius: 16
                        color: '#ffffff'
                        border.width: 1.5
                        border.color: '#ece4d6'
                        clip: true
                        ColumnLayout {
                            id: rowsCol
                            width: parent.width
                            spacing: 0
                            Repeater {
                                model: grp.rows
                                ColumnLayout {
                                    id: ad
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Rectangle { visible: ad.index > 0; Layout.fillWidth: true; Layout.preferredHeight: 1; color: '#efe7da' }
                                    // the address
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Math.max(60, aRow.implicitHeight + 16)
                                        color: aMa.pressed ? '#f6f1e6' : 'transparent'
                                        MouseArea {
                                            id: aMa
                                            z: -1
                                            anchors.fill: parent
                                            onClicked: app.stack.push(Qt.resolvedUrl('EhAddressPage.qml'), { address: ad.modelData.address })
                                        }
                                        RowLayout {
                                            id: aRow
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 10
                                            spacing: 8
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Label { textFormat: Text.StyledText; font.family: FixedFont; font.pixelSize: 14; font.bold: true; text: page.shortAddr(ad.modelData.address) }
                                                Label {
                                                    visible: ad.modelData.label !== ''
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                    text: ad.modelData.label
                                                    font.pixelSize: 13; font.italic: true; color: '#5e1a33'
                                                }
                                                Label {
                                                    font.pixelSize: 12
                                                    color: '#6b5d55'
                                                    text: ad.modelData['new'] ? qsTr('empty · new')
                                                          : (ad.modelData.coins.length === 0 ? qsTr('empty · used')
                                                             : (ad.modelData.coins.length === 1 ? qsTr('1 coin') : qsTr('%1 coins').arg(ad.modelData.coins.length)))
                                                }
                                            }
                                            Label {
                                                text: app.ehMoney(page.satsAmount(ad.modelData.sats))
                                                font.pixelSize: 15; font.bold: true
                                                color: ad.modelData.held ? '#c0392b' : '#2a2220'
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
                                    // its coins, a little indented
                                    Repeater {
                                        model: ad.modelData.coins
                                        Rectangle {
                                            id: cr
                                            required property var modelData
                                            readonly property bool blocked: cr.modelData.held || ad.modelData.held
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 46
                                            color: '#fffaec'
                                            opacity: blocked ? 0.65 : 1
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 28
                                                anchors.rightMargin: 12
                                                spacing: 8
                                                Image { source: Qt.resolvedUrl('../../icons/eh_goldcoin_1.svg'); sourceSize.width: 26; sourceSize.height: 26; Layout.preferredWidth: 26; Layout.preferredHeight: 26 }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 0
                                                    Label { text: app.ehMoney(page.satsAmount(cr.modelData.sats)); font.pixelSize: 14; font.bold: true }
                                                    Label {
                                                        font.pixelSize: 11
                                                        color: '#6b5d55'
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
            }
        }
    }
}
