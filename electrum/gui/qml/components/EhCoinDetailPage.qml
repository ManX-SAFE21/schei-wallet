// Easy Heirs (schèi): one gold coin seen up close: its full UTXO (serial
// number) to read, copy and share, the spend / block switch, where it arrived.
// "Bottega" (WP5): parchment page, paper sheets, stitched paper buttons.
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

    property string outpoint
    property string txid
    property string address
    property var amount
    property int blockHeight: 0      // 0 = not confirmed yet
    property bool held: false
    property bool addrHeld: false     // blocked because its whole address is blocked
    property string note: ''
    // advanced privacy: id of the origin category ('' = I do not know)
    property string origin: ''
    Component.onCompleted: if (Daemon.currentWallet && outpoint) origin = Daemon.currentWallet.ehCoinOrigin(outpoint)

    readonly property string txPart: outpoint.indexOf(':') > 0 ? outpoint.substring(0, outpoint.indexOf(':')) : outpoint
    readonly property string nPart: outpoint.indexOf(':') > 0 ? outpoint.substring(outpoint.indexOf(':')) : ''
    function grouped(s) { return (s.match(/.{1,4}/g) || []).join(' ') }
    readonly property int arrived: Daemon.currentWallet ? Daemon.currentWallet.ehTxTimestamp(txid) : 0
    // short address: prefix, first 4 … last 4, the two groups of 4 highlighted
    function shortAddrRich(a) {
        var p = app.ehAddressParts(a)
        var hl = function (s) { return '<span style="background-color:' + S.highlight + '"><font color="' + S.wineDark + '">' + s + '</font></span>' }
        return (p.prefix !== '' ? p.prefix + ' ' : '') + hl(p.first) + ' … ' + hl(p.last)
    }

    Rectangle { anchors.fill: parent; color: S.parch }

    component Caption: Label {
        Layout.fillWidth: true
        color: S.olive
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 16
        font.bold: true
        font.letterSpacing: 0.5
        wrapMode: Text.WordWrap
    }
    component Body: Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: S.muted
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 16
        lineHeight: 1.1
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
            EhBackLink { text: '‹ ' + qsTr('Your gold coins'); onClicked: app.ehPop() }
            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 130
                Layout.preferredHeight: 130
                source: Qt.resolvedUrl('../../icons/eh_goldcoin_' + (!page.amount ? 2 : (page.amount.satsInt < 100000 ? 1 : (page.amount.satsInt < 1000000 ? 2 : 3))) + '.svg')
                sourceSize.width: 260
                sourceSize.height: 260
                opacity: page.held || page.addrHeld ? 0.4 : 1
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: page.amount ? app.ehMoney(page.amount) : ''
                color: S.wineDark
                font.family: SerifFont ? SerifFont : font.family
                font.weight: Font.ExtraBold
                font.pixelSize: 42
                wrapMode: Text.WrapAnywhere
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -6
                visible: page.amount && app.ehEuro(page.amount) !== ''
                text: page.amount ? app.ehBtc(page.amount) : ''
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
            }

            // the coin's note: tap and write
            EhSheet {
                topPadding: 12
                bottomPadding: 14
                spacing: 8
                Caption { text: qsTr('NOTE') }
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
                        text: page.note
                        onEditingFinished: if (text !== page.note) { page.note = text; Daemon.currentWallet.ehSetCoinNote(page.outpoint, text) }
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
                Body { text: qsTr('Tap to write or change it. Only you see it, it stays on the phone.') }
            }

            // the serial number, whole
            EhSheet {
                topPadding: 12
                bottomPadding: 14
                spacing: 10
                Caption { text: qsTr('UTXO · SERIAL NUMBER') }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    textFormat: Text.RichText
                    font.family: FixedFont
                    font.pixelSize: 16
                    font.bold: true
                    color: S.ink
                    lineHeight: 1.2
                    text: page.grouped(page.txPart) + '<font color="' + S.waitInk + '">' + page.nPart + '</font>'
                }
                Body { text: qsTr('The long part is the transaction (the crucible) the coin came out of; "%1" is its order number: the first coin out is :0, the second :1.').arg(page.nPart) }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8
                    EhStitchButton {
                        id: copyB
                        kind: 'paper'
                        icon: 'eh_copy_wine.svg'
                        text: qsTr('Copy')
                        onClicked: {
                            AppController.textToClipboard(page.outpoint)
                            toaster.show(copyB, qsTr('Copied!'))
                        }
                    }
                    EhStitchButton {
                        kind: 'paper'
                        icon: 'eh_share_wine.svg'
                        text: qsTr('Share')
                        onClicked: AppController.doShare(page.outpoint, 'UTXO')
                    }
                }
            }

            // spend / block
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
                            text: page.held || page.addrHeld ? qsTr('Blocked') : qsTr('It can be spent')
                            color: page.held || page.addrHeld ? S.red : S.ink
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 17
                            font.bold: true
                        }
                        Body {
                            text: page.addrHeld ? qsTr('its whole address is blocked: unblock it from "Your addresses"')
                                  : (page.held ? qsTr('the app will not use this coin to pay') : qsTr('turn it off to block this coin'))
                        }
                    }
                    EhSpendSwitch {
                        enabled: !page.addrHeld
                        opacity: page.addrHeld ? 0.5 : 1
                        spendable: !page.held && !page.addrHeld
                        onToggled: {
                            page.held = !spendable
                            Daemon.currentWallet.ehSetCoinFrozen(page.outpoint, page.held)
                        }
                    }
                }
            }

            // where it comes from (only with the advanced privacy on)
            EhSheet {
                visible: app.ehOption('privacy')
                topPadding: 12
                bottomPadding: 14
                spacing: 10
                Caption { text: qsTr('WHERE IT COMES FROM') }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: app.ehCats().concat([app.ehCat('')])
                        Rectangle {
                            id: oc
                            required property var modelData
                            readonly property bool on: page.origin === modelData.id
                            width: ocRow.implicitWidth + 26; height: 48; radius: 16
                            color: on ? S.paper : S.parch
                            border.width: on ? 2.5 : 1.5
                            border.color: on ? modelData.color : S.edge
                            RowLayout {
                                id: ocRow
                                anchors.centerIn: parent
                                spacing: 7
                                Rectangle { Layout.preferredWidth: 12; Layout.preferredHeight: 12; radius: 6; color: oc.modelData.color }
                                Label { text: oc.modelData.name; font.family: BodyFont ? BodyFont : font.family; font.pixelSize: 16; font.bold: true; color: oc.modelData.color }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { page.origin = oc.modelData.id; Daemon.currentWallet.ehSetOrigin([page.outpoint], oc.modelData.id) }
                            }
                        }
                    }
                }
                Body { text: qsTr('It is only for you: the colour shows at a glance which coins come from the same place.') }
            }

            // where and when it arrived
            EhSheet {
                topPadding: 12
                bottomPadding: 14
                spacing: 4
                Caption { text: qsTr('ARRIVED ON') }
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    textFormat: Text.RichText
                    font.family: FixedFont
                    font.pixelSize: 17
                    font.bold: true
                    color: S.ink
                    wrapMode: Text.WordWrap
                    text: page.shortAddrRich(page.address)
                }
                Body {
                    text: page.arrived > 0 ? new Date(page.arrived * 1000).toLocaleDateString(app.ehLocale(), 'd MMMM yyyy')
                                           : qsTr('not confirmed yet')
                }
            }
        }
    }

    Toaster { id: toaster }
}
