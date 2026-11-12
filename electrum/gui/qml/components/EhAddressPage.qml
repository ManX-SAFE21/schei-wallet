// Easy Heirs (schèi): one address seen up close (T8): the whole address to read,
// copy and share, "Receive on this address", its note, its coins (each with its
// own switch) and the switch that blocks the whole address.
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

    property string address
    property var info: ({ 'address': '', 'kind': 'receive', 'label': '', 'sats': 0, 'held': false, 'coins': [] })
    function reload() { if (Daemon.currentWallet && page.address) page.info = Daemon.currentWallet.ehAddressInfo(page.address) }
    Component.onCompleted: reload()

    function satsAmount(s) { return Config.unitsToSats((s / 100000000).toFixed(8)) }
    function shortUtxo(outpoint) {
        var i = outpoint.indexOf(':')
        var txid = i > 0 ? outpoint.substring(0, i) : outpoint
        return txid.substring(0, 4) + '…' + txid.slice(-4) + (i > 0 ? outpoint.substring(i) : '')
    }
    function showBlockInfo() {
        app.ehInfoDialog.createObject(app, {
            pageTitle: qsTr('Blocking an address'),
            bodyText: qsTr('If you <b>block an address</b>, all the coins inside it are blocked: the app will not use them to pay. Also the coins that arrive <b>later</b> on that address are blocked.')
                      + '<br><br>' + qsTr('The coins stay yours: you still see them in the balance, as blocked. To use them again, unblock the address.')
                      + '<br><br>' + qsTr('To block only one coin, use its own switch in "Your gold coins".')
        }).open()
    }

    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    EhGlow { tone: 'gold'; x: -page.width * 0.3; y: 40; width: page.width * 1.6; height: 380 }

    component Card: Rectangle {
        Layout.fillWidth: true
        radius: 18
        color: Qt.rgba(1, 1, 1, 0.75)
        border.width: 1.5
        border.color: '#ece4d6'
    }
    component Head: Label { font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.6; color: '#6b5d55' }

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
                text: '‹ ' + qsTr('Your addresses')
                color: '#5e1a33'; font.pixelSize: 17; font.bold: true
                TapHandler { margin: 10; onTapped: app.ehPop() }
            }
            Label {
                Layout.fillWidth: true
                text: page.info.kind === 'change' ? qsTr('Change address') : qsTr('Address to receive')
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 26
                wrapMode: Text.WordWrap
            }

            // the whole address, copy and share
            Card {
                Layout.preferredHeight: adCol.implicitHeight + 24
                ColumnLayout {
                    id: adCol
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 10
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        font.family: FixedFont
                        font.pixelSize: 16
                        font.bold: true
                        lineHeight: 1.25
                        text: app.ehAddressRich(page.address)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Repeater {
                            model: [
                                { 'icon': 'eh_share.svg', 'text': qsTr('Share'), 'act': 'share' },
                                { 'icon': 'eh_copy.svg', 'text': qsTr('Copy'), 'act': 'copy' }
                            ]
                            Rectangle {
                                id: ab
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                radius: 23
                                color: abMa.pressed ? '#e4e8c8' : '#eef0dc'
                                border.width: 2
                                border.color: '#d6dcae'
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Image { source: Qt.resolvedUrl('../../icons/' + ab.modelData.icon); sourceSize.width: 20; sourceSize.height: 20 }
                                    Label { text: ab.modelData.text; color: '#45541f'; font.pixelSize: 16; font.bold: true }
                                }
                                MouseArea {
                                    id: abMa
                                    anchors.fill: parent
                                    onClicked: {
                                        if (ab.modelData.act === 'copy') {
                                            AppController.textToClipboard(page.address)
                                            toaster.show(ab, qsTr('Copied!'))
                                        } else {
                                            AppController.doShare(page.address, qsTr('My bitcoin address'))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // receive on this address (opens Receive with its QR)
            Rectangle {
                visible: page.info.kind !== 'change'
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                radius: 24
                color: rxMa.pressed ? '#3a4719' : '#45541f'
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    Image { source: Qt.resolvedUrl('../../icons/eh_rx_white.svg'); sourceSize.width: 26; sourceSize.height: 26; visible: status === Image.Ready }
                    Label { text: qsTr('Receive on this address'); color: '#ffffff'; font.pixelSize: 18; font.bold: true }
                }
                MouseArea {
                    id: rxMa
                    anchors.fill: parent
                    onClicked: {
                        app.stack.pop(null)   // back to the home: Receive opens there
                        Daemon.currentWallet.ehReceiveOn(page.address)
                    }
                }
            }

            // note
            Card {
                Layout.preferredHeight: noteCol.implicitHeight + 24
                border.color: noteIn.activeFocus ? '#5e1a33' : '#ecd49a'
                ColumnLayout {
                    id: noteCol
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 6
                    Head { text: qsTr('NOTE') }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 12
                        color: '#ffffff'
                        border.width: 2
                        border.color: '#e8dcc4'
                        Image { x: 10; anchors.verticalCenter: parent.verticalCenter; source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg'); sourceSize.width: 18; sourceSize.height: 18 }
                        TextInput {
                            id: noteIn
                            anchors.fill: parent
                            anchors.leftMargin: 36
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 16
                            clip: true
                            text: page.info.label
                            onEditingFinished: if (text !== page.info.label) Daemon.currentWallet.ehSetAddressNote(page.address, text)
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: noteIn.text === '' && !noteIn.activeFocus
                                text: qsTr('write a note…')
                                color: '#b3a894'
                                font.pixelSize: 16
                            }
                        }
                    }
                }
            }

            // its coins
            Head {
                Layout.topMargin: 4
                Layout.leftMargin: 4
                text: qsTr('ITS COINS (%1)').arg(page.info.coins.length)
            }
            Card {
                Layout.preferredHeight: coinsCol.implicitHeight
                clip: true
                ColumnLayout {
                    id: coinsCol
                    width: parent.width
                    spacing: 0
                    Label {
                        visible: page.info.coins.length === 0
                        Layout.fillWidth: true
                        Layout.margins: 14
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        color: '#6b5d55'
                        font.pixelSize: 15
                        text: qsTr('No coins on this address.')
                    }
                    Repeater {
                        model: page.info.coins
                        ColumnLayout {
                            id: cr
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 0
                            Rectangle { visible: cr.index > 0; Layout.fillWidth: true; Layout.preferredHeight: 1; color: '#efe7da' }
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 62
                                Layout.leftMargin: 10
                                Layout.rightMargin: 10
                                spacing: 10
                                opacity: page.info.held ? 0.6 : 1
                                Image { source: Qt.resolvedUrl('../../icons/eh_goldcoin_1.svg'); sourceSize.width: 32; sourceSize.height: 32; Layout.preferredWidth: 32; Layout.preferredHeight: 32 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Label { text: app.ehMoney(page.satsAmount(cr.modelData.sats)); font.pixelSize: 16; font.bold: true }
                                    Label {
                                        font.pixelSize: 12
                                        color: '#6b5d55'
                                        text: 'UTXO ' + page.shortUtxo(cr.modelData.outpoint) + ' · '
                                              + (page.info.held ? qsTr('blocked (with the address)')
                                                 : (cr.modelData.held ? qsTr('blocked') : (cr.modelData.height > 0 ? qsTr('confirmed') : qsTr('arriving'))))
                                    }
                                }
                                // one coin: only when the address is not blocked as a whole
                                EhSpendSwitch {
                                    visible: !page.info.held
                                    spendable: !cr.modelData.held
                                    onToggled: {
                                        Daemon.currentWallet.ehSetCoinFrozen(cr.modelData.outpoint, !spendable)
                                        page.reload()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // block the whole address
            Card {
                Layout.preferredHeight: blRow.implicitHeight + 24
                RowLayout {
                    id: blRow
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Label { text: page.info.held ? qsTr('Address blocked') : qsTr('Block the whole address'); font.pixelSize: 16; font.bold: true
                                color: page.info.held ? '#c0392b' : '#2a2220' }
                        Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 13; color: '#6b5d55'
                                text: qsTr('all its coins, also the ones that will arrive here') }
                    }
                    Rectangle {
                        Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                        color: '#45541f'
                        Label { anchors.centerIn: parent; text: 'i'; color: '#ffffff'; font.pixelSize: 15; font.bold: true; font.family: 'serif' }
                        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: page.showBlockInfo() }
                    }
                    EhSpendSwitch {
                        spendable: !page.info.held
                        blockedText: qsTr('blocked (address)')
                        onToggled: {
                            Daemon.currentWallet.ehSetAddressFrozen(page.address, !spendable)
                            page.reload()
                        }
                    }
                }
            }
        }
    }

    Toaster { id: toaster }
}
