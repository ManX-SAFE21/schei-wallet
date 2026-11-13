// Easy Heirs (schèi): "Le tue monete d'oro". Every coin of the wallet (UTXO) is
// a gold coin of variable value: bigger value, bigger coin. Each one can be
// blocked (frozen: the app will not spend it). Second tab: the addresses.
// Uses Electrum's own addressCoinModel; only the look is ours.
// "Bottega" (WP5): parchment page, the list is one paper sheet (the delegates draw
// its sides, the header and the footer its rounded top and bottom: no Canvas per row).
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
    property bool showAddresses: false
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.wine

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
    // short address: prefix, first 4 … last 4, the two groups of 4 highlighted
    function shortAddrRich(a) {
        var p = app.ehAddressParts(a)
        var hl = function (s) { return '<span style="background-color:' + S.highlight + '"><font color="' + S.wineDark + '">' + s + '</font></span>' }
        return (p.prefix !== '' ? p.prefix + ' ' : '') + hl(p.first) + ' … ' + hl(p.last)
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
            linkText: qsTr('How the crucible works'),
            linkUrl: Qt.resolvedUrl('EhCoinsHowPage.qml'),
            bodyText: qsTr('<b>UTXO</b> is the <b>serial number</b> engraved on the rim of the coin, like the one on a banknote: it tells which payment it comes from. It is not secret and it is not needed to spend the coin.')
                      + '<br><br>' + qsTr('Your coins are protected by the 12 words.')
        }).open()
    }

    Rectangle { anchors.fill: parent; color: S.parch }

    // the paper of the sheet behind one list item: paper with the two side edges
    component SheetSide: Item {
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: S.paper }
        Rectangle { x: 0; width: 1.5; height: parent.height; color: S.edge }
        Rectangle { x: parent.width - 1.5; width: 1.5; height: parent.height; color: S.edge }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 12 + app.navigationBarHeight
        spacing: 10

        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
        EhBackLink { onClicked: app.ehPop() }
        EhTitle { Layout.topMargin: -6; text: qsTr('Your gold coins') }

        // two tabs: coins / addresses
        EhSegmented {
            model: [qsTr('Coins'), qsTr('Addresses')]
            currentIndex: page.showAddresses ? 1 : 0
            onActivated: (i) => page.showAddresses = (i === 1)
        }

        EhInfoBox {
            visible: !page.showAddresses
            kind: 'tip'
            text: qsTr('Your balance is made of several <b>gold coins</b>: each one is a payment you received, and it is worth what is inside. You can <b>block</b> one: the app will not use it to pay.')
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            model: page.filterModel
            // rounded top of the sheet
            header: Item {
                width: list.width
                height: list.count > 0 ? 14 : 0
                visible: list.count > 0
                clip: true
                Rectangle {
                    width: parent.width
                    height: 40
                    radius: 18
                    color: S.paper
                    border.width: 1.5
                    border.color: S.edge
                }
            }
            // T22: section.property must NOT change while the list is alive (Qt crashed
            // switching to the Addresses tab): always 'type', headers hidden for coins
            section.property: 'type'
            section.criteria: ViewSection.FullString
            // the ListView drives the visibility of section items itself: wrap the label
            section.delegate: Item {
                id: sec
                required property string section
                width: ListView.view.width
                height: page.showAddresses ? secCol.implicitHeight + 10 : 0
                clip: true
                SheetSide { visible: page.showAddresses }
                ColumnLayout {
                    id: secCol
                    visible: page.showAddresses
                    x: 12
                    y: 8
                    width: parent.width - 24
                    spacing: 4
                    Label {
                        Layout.fillWidth: true
                        text: sec.section === 'receive' ? qsTr('TO RECEIVE') : (sec.section === 'change' ? qsTr('CHANGE') : sec.section.toUpperCase())
                        color: S.olive
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: 16
                        font.bold: true
                        font.letterSpacing: 0.5
                        wrapMode: Text.WordWrap
                    }
                    EhRule {}
                }
            }
            delegate: Loader {
                id: ld
                required property var model
                required property int index
                readonly property bool lastOne: ld.index === list.count - 1
                width: ListView.view.width
                sourceComponent: ld.model.outpoint ? coinRow : addrRow

                Component {
                    id: coinRow
                    Item {
                        readonly property bool blocked: ld.model.held || ld.model.addr_held
                        width: ld.width
                        height: Math.max(76, cRow.implicitHeight + 20)
                        SheetSide {}
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 6; anchors.rightMargin: 6
                            anchors.topMargin: 2; anchors.bottomMargin: 2
                            radius: 10
                            color: S.sand
                            opacity: cTap.pressed ? 0.4 : 0
                        }
                        EhDotLine {
                            visible: !ld.lastOne
                            x: 12
                            width: parent.width - 24
                            anchors.bottom: parent.bottom
                        }
                        RowLayout {
                            id: cRow
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 8
                            Item {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 52
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property int s: page.coinSize(ld.model.amount.satsInt)
                                    width: Math.min(46, s); height: width
                                    source: page.coinIcon(ld.model.amount.satsInt)
                                    sourceSize.width: 120
                                    sourceSize.height: 120
                                    opacity: (ld.model.held || ld.model.addr_held) ? 0.4 : 1
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    Layout.fillWidth: true
                                    text: app.ehMoney(ld.model.amount)
                                    font.family: SerifFont ? SerifFont : font.family
                                    font.weight: Font.ExtraBold
                                    font.pixelSize: 21
                                    color: (ld.model.held || ld.model.addr_held) ? S.muted : S.wineDark
                                    wrapMode: Text.WrapAnywhere
                                }
                                // T11: real pen icon (the phone font had no ✎ and drew a dark block)
                                RowLayout {
                                    visible: ld.model.label !== undefined && ld.model.label !== ''
                                    Layout.fillWidth: true
                                    spacing: 5
                                    Image {
                                        source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg')
                                        sourceSize.width: 16; sourceSize.height: 16
                                        Layout.preferredWidth: 16; Layout.preferredHeight: 16
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: ld.model.label
                                        font.family: BodyFont ? BodyFont : font.family
                                        font.pixelSize: 16
                                        font.italic: true
                                        color: S.wine
                                    }
                                }
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Label {
                                        height: 28
                                        verticalAlignment: Text.AlignVCenter
                                        text: 'UTXO'
                                        font.family: BodyFont ? BodyFont : font.family
                                        font.pixelSize: 16
                                        color: S.muted
                                    }
                                    Label {
                                        height: 28
                                        verticalAlignment: Text.AlignVCenter
                                        text: page.shortUtxo(ld.model.outpoint)
                                        font.family: FixedFont
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: S.ink
                                    }
                                    // the "i": 28 px, 48 px to the finger
                                    Rectangle {
                                        width: 28; height: 28; radius: 14
                                        color: 'transparent'
                                        border.width: 2.5
                                        border.color: S.olive
                                        Label { anchors.centerIn: parent; text: 'i'; color: S.olive; font.pixelSize: 18; font.bold: true; font.family: 'serif' }
                                        MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: page.showUtxoInfo() }
                                    }
                                }
                                // the state, as text (no small pill)
                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    font.family: BodyFont ? BodyFont : font.family
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: (ld.model.held || ld.model.addr_held) ? S.muted : (ld.model.height > 0 ? S.olive : S.waitInk)
                                    text: ld.model.addr_held ? qsTr('blocked (with the address)')
                                          : (ld.model.held ? qsTr('blocked')
                                             : (ld.model.height > 0 ? '✓ ' + qsTr('confirmed') : qsTr('arriving')))
                                }
                            }
                            EhSpendSwitch {
                                spendable: !ld.model.held && !ld.model.addr_held
                                enabled: !ld.model.addr_held   // unblock it from its address
                                opacity: ld.model.addr_held ? 0.5 : 1
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
                    Item {
                        width: ld.width
                        height: Math.max(64, aRow.implicitHeight + 18)
                        SheetSide {}
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 6; anchors.rightMargin: 6
                            anchors.topMargin: 2; anchors.bottomMargin: 2
                            radius: 10
                            color: S.sand
                            opacity: aTap.pressed ? 0.4 : 0
                        }
                        EhDotLine {
                            visible: !ld.lastOne
                            x: 12
                            width: parent.width - 24
                            anchors.bottom: parent.bottom
                        }
                        RowLayout {
                            id: aRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Label {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    font.family: FixedFont
                                    font.pixelSize: 17
                                    font.bold: true
                                    color: S.ink
                                    wrapMode: Text.WordWrap
                                    text: page.shortAddrRich(ld.model.address)
                                }
                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    font.family: BodyFont ? BodyFont : font.family
                                    font.pixelSize: 16
                                    color: S.muted
                                    text: (ld.model.numtx > 0 ? (ld.model.numtx === 1 ? qsTr('1 movement') : qsTr('%1 movements').arg(ld.model.numtx)) : qsTr('no movements'))
                                          + (ld.model.balance && ld.model.balance.satsInt > 0 ? ' · ' + app.ehMoney(ld.model.balance) : '')
                                }
                            }
                            // used / new: text, not a small pill
                            Label {
                                Layout.alignment: Qt.AlignVCenter
                                font.family: BodyFont ? BodyFont : font.family
                                font.pixelSize: 16
                                font.bold: true
                                color: ld.model.numtx > 0 ? S.olive : S.wine
                                text: ld.model.numtx > 0 ? qsTr('used') : qsTr('new')
                            }
                        }
                        TapHandler { id: aTap; onTapped: app.ehZoomAddress(ld.model.address, true) }
                    }
                }
            }
            footer: Item {
                width: list.width
                height: botCap.height + (page.showAddresses ? chNote.implicitHeight + 12 : 0) + howSheet.implicitHeight + 22
                // rounded bottom of the sheet, with its hard shadow
                Item {
                    id: botCap
                    width: parent.width
                    height: list.count > 0 ? 17 : 0
                    visible: list.count > 0
                    clip: true
                    Rectangle { y: -23; width: parent.width; height: 40; radius: 18; color: S.edgeShadow }
                    Rectangle { y: -26; width: parent.width; height: 40; radius: 18; color: S.paper; border.width: 1.5; border.color: S.edge }
                }
                Label {
                    id: chNote
                    visible: page.showAddresses
                    x: 4; y: botCap.height + 12
                    width: parent.width - 8
                    wrapMode: Text.WordWrap
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 16
                    color: S.muted
                    text: qsTr('"Change": when you pay, what is left over from a coin comes back to you on a new address, like the change at the shop.')
                }
                // owner 13/11: the same row in the Addresses tab too
                EhSheet {
                    id: howSheet
                    y: botCap.height + 14 + (page.showAddresses ? chNote.implicitHeight + 12 : 0)
                    width: parent.width
                    EhRow {
                        icon: 'eh_goldcoin.svg'
                        iconColor: S.brassRing
                        text: qsTr('How do the gold coins of digital gold (bitcoin) work?')
                        last: true
                        onClicked: app.ehPush(Qt.resolvedUrl('EhCoinsHowPage.qml'))
                    }
                }
            }
            Label {
                anchors.centerIn: parent
                visible: list.count === 0
                width: parent.width - 30
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 17
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
