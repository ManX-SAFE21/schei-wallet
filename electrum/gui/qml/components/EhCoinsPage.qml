// Easy Heirs (schèi): "Le tue monete d'oro". Every coin of the wallet (UTXO) is
// a gold coin of variable value: bigger value, bigger coin. Each one can be
// blocked (frozen: the app will not spend it). Second tab: the addresses.
// Uses Electrum's own addressCoinModel; only the look is ours.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"

Item {
    id: page
    property bool ehHideHeader: true
    property bool showAddresses: false
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'

    readonly property var filterModel: Daemon.currentWallet ? Daemon.currentWallet.addressCoinModel.filterModel : null
    function applyFilter() {
        if (!filterModel) return
        filterModel.showUsed = true
        filterModel.showAddressesCoins = page.showAddresses ? 1 : 2
    }
    onShowAddressesChanged: applyFilter()

    function shortUtxo(outpoint) {
        var i = outpoint.indexOf(':')
        var txid = i > 0 ? outpoint.substring(0, i) : outpoint
        return txid.substring(0, 4) + '…' + txid.slice(-4) + (i > 0 ? outpoint.substring(i) : '')
    }
    // coin size from its value: 1 000 sat -> 26 px ... 1 BTC -> 52 px
    function coinSize(sats) {
        var l = Math.log(Math.max(1000, sats)) / Math.LN10
        return Math.round(26 + 26 * Math.min(1, (l - 3) / 5))
    }
    // thicker coin for bigger value: < 100 000 sat thin, < 1 000 000 medium, else thick
    function coinIcon(sats) {
        return Qt.resolvedUrl('../../icons/eh_goldcoin_' + (sats < 100000 ? 1 : (sats < 1000000 ? 2 : 3)) + '.svg')
    }
    function showUtxoInfo() {
        app.ehInfoDialog.createObject(app, {
            pageTitle: 'UTXO',
            bodyText: qsTr('<b>UTXO</b> is the <b>serial number</b> engraved on the rim of the coin, like the one on a banknote: it tells which payment it comes from. It is not secret and it is not needed to spend the coin.')
                      + '<br><br>' + qsTr('Your coins are protected by the 12 words.')
        }).open()
    }

    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    EhGlow { tone: 'gold'; x: -page.width * 0.3; y: 40; width: page.width * 1.6; height: 380 }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 12 + app.navigationBarHeight
        spacing: 8

        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
        Label {
            Layout.topMargin: -14
            text: '‹ ' + qsTr('Back')
            color: '#5e1a33'; font.pixelSize: 17; font.bold: true
            TapHandler { margin: 10; onTapped: app.ehPop() }
        }
        Label {
            Layout.fillWidth: true
            text: qsTr('Your gold coins')
            color: '#3f0f21'
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 28
            wrapMode: Text.WordWrap
        }

        // two tabs: coins / addresses
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 23
            color: Qt.rgba(0.94, 0.90, 0.83, 0.9)
            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4
                Repeater {
                    model: [qsTr('Coins'), qsTr('Addresses')]
                    Rectangle {
                        required property string modelData
                        required property int index
                        readonly property bool on: (index === 1) === page.showAddresses
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: height / 2
                        color: on ? '#ffffff' : 'transparent'
                        Label { anchors.centerIn: parent; text: modelData; font.pixelSize: 16; font.bold: true; color: parent.on ? '#3f0f21' : '#6b5d55' }
                        TapHandler { onTapped: page.showAddresses = (index === 1) }
                    }
                }
            }
        }

        Rectangle {
            visible: !page.showAddresses
            Layout.fillWidth: true
            Layout.preferredHeight: noteL.implicitHeight + 20
            radius: 14
            color: Qt.rgba(0.98, 0.94, 0.84, 0.92)
            Label {
                id: noteL
                anchors.fill: parent; anchors.margins: 10
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                font.pixelSize: 14
                text: qsTr('Your balance is made of several <b>gold coins</b>: each one is a payment you received, and it is worth what is inside. You can <b>block</b> one: the app will not use it to pay.')
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            model: page.filterModel
            // T22: section.property must NOT change while the list is alive (Qt crashed
            // switching to the Addresses tab): always 'type', headers hidden for coins
            section.property: 'type'
            section.criteria: ViewSection.FullString
            // the ListView drives the visibility of section items itself: wrap the label
            section.delegate: Item {
                required property string section
                width: ListView.view.width
                height: page.showAddresses ? 34 : 0
                clip: true
                Label {
                    visible: page.showAddresses
                    anchors.fill: parent
                    topPadding: 10
                    bottomPadding: 4
                    leftPadding: 4
                    text: parent.section === 'receive' ? qsTr('TO RECEIVE') : (parent.section === 'change' ? qsTr('CHANGE') : parent.section.toUpperCase())
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 0.6
                    color: '#6b5d55'
                }
            }
            delegate: Loader {
                id: ld
                required property var model
                width: ListView.view.width
                sourceComponent: ld.model.outpoint ? coinRow : addrRow

                Component {
                    id: coinRow
                    Rectangle {
                        width: ld.width
                        height: Math.max(66, cRow.implicitHeight + 16)
                        color: cTap.pressed ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.66)
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0.16, 0.13, 0.13, 0.07) }
                        RowLayout {
                            id: cRow
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 10
                            spacing: 10
                            Item {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 44
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    readonly property int s: page.coinSize(ld.model.amount.satsInt)
                                    width: s; height: s
                                    source: page.coinIcon(ld.model.amount.satsInt)
                                    sourceSize.width: 120
                                    sourceSize.height: 120
                                    opacity: (ld.model.held || ld.model.addr_held) ? 0.4 : 1
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label {
                                    text: app.ehMoney(ld.model.amount)
                                    font.pixelSize: 17
                                    font.bold: true
                                    color: (ld.model.held || ld.model.addr_held) ? '#8a7d70' : '#2a2220'
                                }
                                // T11: real pen icon (the phone font had no ✎ and drew a dark block)
                                RowLayout {
                                    visible: ld.model.label !== undefined && ld.model.label !== ''
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Image {
                                        source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg')
                                        sourceSize.width: 14; sourceSize.height: 14
                                        Layout.preferredWidth: 14; Layout.preferredHeight: 14
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: ld.model.label
                                        font.pixelSize: 13
                                        font.italic: true
                                        color: '#5e1a33'
                                    }
                                }
                                RowLayout {
                                    spacing: 5
                                    Label { text: 'UTXO'; font.pixelSize: 12; color: '#6b5d55' }
                                    Label { text: page.shortUtxo(ld.model.outpoint); font.family: FixedFont; font.pixelSize: 12; font.bold: true; color: '#2a2220' }
                                    Rectangle {
                                        Layout.preferredWidth: 18; Layout.preferredHeight: 18; radius: 9
                                        color: '#45541f'
                                        Label { anchors.centerIn: parent; text: 'i'; color: '#ffffff'; font.pixelSize: 12; font.bold: true; font.family: 'serif' }
                                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: page.showUtxoInfo() }
                                    }
                                }
                                Rectangle {
                                    Layout.preferredHeight: 20
                                    Layout.preferredWidth: stL.implicitWidth + 14
                                    radius: 10
                                    color: (ld.model.held || ld.model.addr_held) ? '#ece6db' : (ld.model.height > 0 ? '#e6ecc8' : '#fbf0d6')
                                    Label {
                                        id: stL
                                        anchors.centerIn: parent
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: (ld.model.held || ld.model.addr_held) ? '#6b5d55' : (ld.model.height > 0 ? '#2f3a12' : '#8a5a12')
                                        text: ld.model.addr_held ? qsTr('blocked (with the address)') : (ld.model.held ? qsTr('blocked') : (ld.model.height > 0 ? qsTr('confirmed') : qsTr('arriving')))
                                    }
                                }
                            }
                            EhSpendSwitch {
                                spendable: !ld.model.held && !ld.model.addr_held
                                enabled: !ld.model.addr_held   // unblock it from its address
                                onToggled: Daemon.currentWallet.ehSetCoinFrozen(ld.model.outpoint, !spendable)  // T10: freeze = not spendable
                            }
                        }
                        // T10: a MouseArea under the row content, so the switch and the
                        // "i" (MouseAreas on top) get their own taps instead of opening the details
                        MouseArea {
                            id: cTap
                            z: -1
                            anchors.fill: parent
                            onClicked: app.ehPush(Qt.resolvedUrl('EhCoinDetailPage.qml'), {
                                outpoint: ld.model.outpoint, txid: ld.model.txid, address: ld.model.address,
                                amount: ld.model.amount, blockHeight: ld.model.height, held: ld.model.held, addrHeld: ld.model.addr_held === true,
                                note: ld.model.label || ''
                            })
                        }
                    }
                }

                Component {
                    id: addrRow
                    Rectangle {
                        width: ld.width
                        height: Math.max(56, aCol.implicitHeight + 16)
                        color: aTap.pressed ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.66)
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0.16, 0.13, 0.13, 0.07) }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            ColumnLayout {
                                id: aCol
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    readonly property var parts: app.ehAddressParts(ld.model.address)
                                    textFormat: Text.StyledText
                                    font.family: FixedFont
                                    font.pixelSize: 14
                                    font.bold: true
                                    text: (parts.prefix !== '' ? parts.prefix + ' ' : '') + '<u>' + parts.first + '</u> … <u>' + parts.last + '</u>'
                                }
                                Label {
                                    font.pixelSize: 12
                                    color: '#6b5d55'
                                    text: (ld.model.numtx > 0 ? (ld.model.numtx === 1 ? qsTr('1 movement') : qsTr('%1 movements').arg(ld.model.numtx)) : qsTr('no movements'))
                                          + (ld.model.balance && ld.model.balance.satsInt > 0 ? ' · ' + app.ehMoney(ld.model.balance) : '')
                                }
                            }
                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: uL.implicitWidth + 16
                                radius: 11
                                color: ld.model.numtx > 0 ? '#e6ecc8' : '#f3e3e8'
                                Label { id: uL; anchors.centerIn: parent; font.pixelSize: 12; font.bold: true
                                        color: ld.model.numtx > 0 ? '#2f3a12' : '#5e1a33'
                                        text: ld.model.numtx > 0 ? qsTr('used') : qsTr('new') }
                            }
                        }
                        TapHandler { id: aTap; onTapped: app.ehZoomAddress(ld.model.address, true) }
                    }
                }
            }
            footer: Item {
                width: list.width
                height: page.showAddresses ? chNote.implicitHeight + 24 : howBtn.height + 20
                Label {
                    id: chNote
                    visible: page.showAddresses
                    x: 4; y: 12
                    width: parent.width - 8
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13
                    color: '#6b5d55'
                    text: qsTr('"Change": when you pay, what is left over from a coin comes back to you on a new address, like the change at the shop.')
                }
                Rectangle {
                    id: howBtn
                    visible: !page.showAddresses
                    y: 12
                    width: parent.width
                    height: howRow.implicitHeight + 24
                    radius: 16
                    color: howTap.pressed ? '#ffffff' : Qt.rgba(1, 1, 1, 0.7)
                    border.width: 2
                    border.color: '#ecd49a'
                    RowLayout {
                        id: howRow
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        Image { source: Qt.resolvedUrl('../../icons/eh_goldcoin.svg'); sourceSize.width: 40; sourceSize.height: 40 }
                        Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 15; font.bold: true
                                text: qsTr('How do the gold coins of digital gold (bitcoin) work?') }
                        Label { text: '›'; font.pixelSize: 22; color: '#5e1a33' }
                    }
                    TapHandler { id: howTap; onTapped: app.ehPush(Qt.resolvedUrl('EhCoinsHowPage.qml')) }
                }
            }
            Label {
                anchors.centerIn: parent
                visible: list.count === 0
                width: parent.width - 30
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: '#6b5d55'
                font.pixelSize: 15
                text: page.showAddresses ? '' : qsTr('No coins yet: they arrive when someone sends you bitcoin.')
            }
        }
    }

    Connections {
        target: Daemon.currentWallet
        function onBalanceChanged() { Daemon.currentWallet.addressCoinModel.setDirty(); Daemon.currentWallet.addressCoinModel.initModel() }
    }
    Component.onCompleted: {
        Daemon.currentWallet.addressCoinModel.initModel(true)
        applyFilter()
    }
}
