// Easy Heirs (schèi): one gold coin seen up close: its full UTXO (serial
// number) to read, copy and share, the spend / block switch, where it arrived.
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
            spacing: 10

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            Label {
                Layout.topMargin: -14
                text: '‹ ' + qsTr('Your gold coins')
                color: '#5e1a33'; font.pixelSize: 17; font.bold: true
                TapHandler { margin: 10; onTapped: app.ehPop() }
            }
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
                Layout.alignment: Qt.AlignHCenter
                text: page.amount ? app.ehMoney(page.amount) : ''
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 36
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                visible: page.amount && app.ehEuro(page.amount) !== ''
                text: page.amount ? app.ehBtc(page.amount) : ''
                color: '#6b5d55'
                font.pixelSize: 15
            }

            // the coin's note: tap and write
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: noteCol.implicitHeight + 24
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.75)
                border.width: 2
                border.color: noteIn.activeFocus ? '#5e1a33' : '#ecd49a'
                ColumnLayout {
                    id: noteCol
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 6
                    Label { text: qsTr('NOTE'); font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.6; color: '#6b5d55' }
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
                            text: page.note
                            onEditingFinished: if (text !== page.note) { page.note = text; Daemon.currentWallet.ehSetCoinNote(page.outpoint, text) }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: noteIn.text === '' && !noteIn.activeFocus
                                text: qsTr('write a note…')
                                color: '#b3a894'
                                font.pixelSize: 16
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: 13
                        color: '#6b5d55'
                        text: qsTr('Tap to write or change it. Only you see it, it stays on the phone.')
                    }
                }
            }

            // the serial number, whole
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: utxoCol.implicitHeight + 24
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.7)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.9)
                ColumnLayout {
                    id: utxoCol
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 8
                    Label { text: qsTr('UTXO · SERIAL NUMBER'); font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.6; color: '#6b5d55' }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        font.family: FixedFont
                        font.pixelSize: 15
                        font.bold: true
                        lineHeight: 1.2
                        text: page.grouped(page.txPart) + '<font color="#8a5a12">' + page.nPart + '</font>'
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: 13
                        color: '#6b5d55'
                        text: qsTr('The long part is the transaction (the crucible) the coin came out of; "%1" is its order number: the first coin out is :0, the second :1.').arg(page.nPart)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Repeater {
                            model: [
                                { 'icon': 'eh_copy.svg', 'text': qsTr('Copy'), 'act': 'copy' },
                                { 'icon': 'eh_share.svg', 'text': qsTr('Share'), 'act': 'share' }
                            ]
                            Rectangle {
                                id: ab
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                radius: 23
                                color: abTap.pressed ? '#e4e8c8' : '#eef0dc'
                                border.width: 2
                                border.color: '#d6dcae'
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Image { source: Qt.resolvedUrl('../../icons/' + ab.modelData.icon); sourceSize.width: 20; sourceSize.height: 20 }
                                    Label { text: ab.modelData.text; color: '#45541f'; font.pixelSize: 16; font.bold: true }
                                }
                                TapHandler {
                                    id: abTap
                                    onTapped: {
                                        if (ab.modelData.act === 'copy') {
                                            AppController.textToClipboard(page.outpoint)
                                            toaster.show(ab, qsTr('Copied!'))
                                        } else {
                                            AppController.doShare(page.outpoint, 'UTXO')
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // spend / block
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: spRow.implicitHeight + 24
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.7)
                RowLayout {
                    id: spRow
                    x: 12; y: 12
                    width: parent.width - 24
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Label { text: page.held || page.addrHeld ? qsTr('Blocked') : qsTr('It can be spent'); font.pixelSize: 16; font.bold: true }
                        Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 13; color: '#6b5d55'
                                text: page.addrHeld ? qsTr('its whole address is blocked: unblock it from "Your addresses"')
                                      : (page.held ? qsTr('the app will not use this coin to pay') : qsTr('turn it off to block this coin')) }
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
            Rectangle {
                visible: app.ehOption('privacy')
                Layout.fillWidth: true
                Layout.preferredHeight: orCol.implicitHeight + 24
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.7)
                ColumnLayout {
                    id: orCol
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 8
                    Label { text: qsTr('WHERE IT COMES FROM'); font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.6; color: '#6b5d55' }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: app.ehCats().concat([app.ehCat('')])
                            Rectangle {
                                id: oc
                                required property var modelData
                                readonly property bool on: page.origin === modelData.id
                                width: ocRow.implicitWidth + 24; height: 40; radius: 20
                                color: on ? '#ffffff' : '#f4efe4'
                                border.width: 2
                                border.color: on ? modelData.color : 'transparent'
                                RowLayout {
                                    id: ocRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Rectangle { Layout.preferredWidth: 11; Layout.preferredHeight: 11; radius: 5.5; color: oc.modelData.color }
                                    Label { text: oc.modelData.name; font.pixelSize: 15; font.bold: true; color: oc.modelData.color }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { page.origin = oc.modelData.id; Daemon.currentWallet.ehSetOrigin([page.outpoint], oc.modelData.id) }
                                }
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: 13; color: '#6b5d55'
                        text: qsTr('It is only for you: the colour shows at a glance which coins come from the same place.')
                    }
                }
            }

            // where and when it arrived
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: arCol.implicitHeight + 24
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.7)
                ColumnLayout {
                    id: arCol
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 3
                    Label { text: qsTr('ARRIVED ON'); font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.6; color: '#6b5d55' }
                    Label {
                        readonly property var parts: app.ehAddressParts(page.address)
                        textFormat: Text.StyledText
                        font.family: FixedFont
                        font.pixelSize: 14
                        font.bold: true
                        text: (parts.prefix !== '' ? parts.prefix + ' ' : '') + '<u>' + parts.first + '</u> … <u>' + parts.last + '</u>'
                    }
                    Label {
                        font.pixelSize: 13
                        color: '#6b5d55'
                        text: page.arrived > 0 ? new Date(page.arrived * 1000).toLocaleDateString(app.ehLocale(), 'd MMMM yyyy')
                                               : qsTr('not confirmed yet')
                    }
                }
            }
        }
    }

    Toaster { id: toaster }
}
