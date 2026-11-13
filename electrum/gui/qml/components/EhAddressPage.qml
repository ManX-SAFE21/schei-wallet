// Easy Heirs (schèi): one address seen up close (T8): the whole address to read,
// copy and share, "Receive on this address", its note, its coins (each with its
// own switch) and the switch that blocks the whole address.
// "Bottega" (WP5): parchment page, paper sheets, stitched buttons (olive leather for
// "Receive on this address", paper for Share / Copy).
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

    Rectangle { anchors.fill: parent; color: S.parch }

    component Head: Label {
        Layout.fillWidth: true
        color: S.olive
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 16
        font.bold: true
        font.letterSpacing: 0.5
        wrapMode: Text.WordWrap
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
            spacing: 12

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            EhBackLink { text: '‹ ' + qsTr('Your addresses'); onClicked: app.ehPop() }
            EhTitle {
                Layout.topMargin: -6
                text: page.info.kind === 'change' ? qsTr('Change address') : qsTr('Address to receive')
            }

            // the whole address, copy and share
            EhSheet {
                topPadding: 14
                bottomPadding: 14
                spacing: 12
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                    font.family: FixedFont
                    font.pixelSize: 18
                    font.bold: true
                    color: S.ink
                    lineHeight: 1.25
                    text: app.ehAddressRich(page.address, S.wineDark, S.highlight)
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    EhStitchButton {
                        kind: 'paper'
                        icon: 'eh_share_wine.svg'
                        text: qsTr('Share')
                        onClicked: AppController.doShare(page.address, qsTr('My bitcoin address'))
                    }
                    EhStitchButton {
                        id: copyB
                        kind: 'paper'
                        icon: 'eh_copy_wine.svg'
                        text: qsTr('Copy')
                        onClicked: {
                            AppController.textToClipboard(page.address)
                            toaster.show(copyB, qsTr('Copied!'))
                        }
                    }
                }
            }

            // receive on this address (opens Receive with its QR)
            EhStitchButton {
                visible: page.info.kind !== 'change'
                kind: 'olive'
                icon: 'eh_rx_white.svg'
                text: qsTr('Receive on this address')
                onClicked: {
                    app.stack.pop(null)   // back to the home: Receive opens there
                    Daemon.currentWallet.ehReceiveOn(page.address)
                }
            }

            // note
            EhSheet {
                topPadding: 12
                bottomPadding: 14
                spacing: 8
                Head { text: qsTr('NOTE') }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: 16
                    color: S.paper
                    border.width: noteIn.activeFocus ? 2.5 : 2
                    border.color: noteIn.activeFocus ? S.wine : S.edge
                    Image { x: 14; anchors.verticalCenter: parent.verticalCenter; source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg'); sourceSize.width: 24; sourceSize.height: 24 }
                    TextInput {
                        id: noteIn
                        anchors.fill: parent
                        anchors.leftMargin: 48
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: 18
                        color: S.ink
                        clip: true
                        text: page.info.label
                        onEditingFinished: if (text !== page.info.label) Daemon.currentWallet.ehSetAddressNote(page.address, text)
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: noteIn.text === '' && !noteIn.activeFocus
                            text: qsTr('write a note…')
                            color: S.muted
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 17
                        }
                    }
                }
            }

            // its coins
            EhCaption {
                Layout.topMargin: 4
                Layout.bottomMargin: -6
                text: qsTr('ITS COINS (%1)').arg(page.info.coins.length)
            }
            EhSheet {
                Label {
                    visible: page.info.coins.length === 0
                    Layout.fillWidth: true
                    Layout.margins: 14
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    color: S.muted
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 17
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
                        EhDotLine { visible: cr.index > 0 }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(72, crCol.implicitHeight + 18)
                            spacing: 10
                            opacity: page.info.held ? 0.6 : 1
                            Image { source: Qt.resolvedUrl('../../icons/eh_goldcoin_1.svg'); sourceSize.width: 32; sourceSize.height: 32; Layout.preferredWidth: 32; Layout.preferredHeight: 32 }
                            ColumnLayout {
                                id: crCol
                                Layout.fillWidth: true
                                spacing: 1
                                Label {
                                    Layout.fillWidth: true
                                    text: app.ehMoney(page.satsAmount(cr.modelData.sats))
                                    color: S.wineDark
                                    font.family: SerifFont ? SerifFont : font.family
                                    font.weight: Font.ExtraBold
                                    font.pixelSize: 21
                                    wrapMode: Text.WrapAnywhere
                                }
                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    font.family: BodyFont ? BodyFont : font.family
                                    font.pixelSize: 16
                                    color: S.muted
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

            // block the whole address
            EhSheet {
                topPadding: 12
                bottomPadding: 12
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: page.info.held ? qsTr('Address blocked') : qsTr('Block the whole address')
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 17; font.bold: true
                            color: page.info.held ? S.red : S.ink
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 16
                            color: S.muted
                            text: qsTr('all its coins, also the ones that will arrive here')
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                        color: 'transparent'
                        border.width: 2.5
                        border.color: S.olive
                        Label { anchors.centerIn: parent; text: 'i'; color: S.olive; font.pixelSize: 20; font.bold: true; font.family: 'serif' }
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
