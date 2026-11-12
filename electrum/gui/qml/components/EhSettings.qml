// Easy Heirs (schèi): settings in three levels BASE / MEDIO / ESPERTO (owner 12/11, T50).
// The choice at the top shows the rows of the level and turns on its preset (main.qml
// ehSetLevel); every switch can then be changed by hand. ESPERTO asks the PIN, and its
// delicate rows (PIN threshold, node, more addresses, reset) ask it again.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'

    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    // "luce colorata": soft lights behind the cards
    EhGlow { tone: 'green'; x: -page.width * 0.3; y: 60; width: page.width * 1.6; height: 380 }
    EhGlow { tone: 'wine'; x: -page.width * 0.2; y: page.height - 360; width: page.width * 1.4; height: 360; opacity: 0.6 }

    // a row that opens something
    component Row1: Rectangle {
        id: r
        property string icon
        property string text
        property string value
        property bool lock: false        // asks the PIN: a small lock icon
        property int tag: 0              // 1 MEDIO, 2 ESPERTO: a small label
        signal clicked
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(56, r1.implicitHeight + 16)
        color: rt.pressed ? Qt.rgba(1, 1, 1, 0.5) : 'transparent'
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0.16, 0.13, 0.13, 0.07) }
        RowLayout {
            id: r1
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                color: Qt.rgba(0.94, 0.90, 0.83, 0.9)
                Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/' + r.icon); sourceSize.width: 22; sourceSize.height: 22 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { Layout.fillWidth: true; text: r.text; font.pixelSize: 17; font.bold: true; wrapMode: Text.WordWrap }
                LevelTag { level: r.tag }
            }
            Label { text: r.value; font.pixelSize: 14; color: '#6b5d55' }
            Image { visible: r.lock; source: Qt.resolvedUrl('../../icons/eh_lock.svg'); sourceSize.width: 18; sourceSize.height: 18 }
            Label { text: '›'; font.pixelSize: 22; color: '#5e1a33' }
        }
        TapHandler { id: rt; onTapped: r.clicked() }
    }
    // a row with a switch (an option of the app)
    component RowSw: Rectangle {
        id: s
        property string icon
        property string text
        property string hint
        property string key
        property bool invert: false     // the option stores the opposite (no_anim)
        property bool locked: false     // stays on, cannot be turned off (more wallets with 2+)
        property string lockedHint
        property int tag: 0              // 1 MEDIO, 2 ESPERTO: a small label
        Component.onCompleted: if (locked && !app.ehOption(key)) app.ehSetOption(key, true)
        signal toggled(bool on)
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(60, sRow.implicitHeight + 16)
        color: 'transparent'
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0.16, 0.13, 0.13, 0.07) }
        RowLayout {
            id: sRow
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                color: Qt.rgba(0.94, 0.90, 0.83, 0.9)
                Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/' + s.icon); sourceSize.width: 22; sourceSize.height: 22 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: s.text; font.pixelSize: 17; font.bold: true; wrapMode: Text.WordWrap }
                LevelTag { level: s.tag }
                Label { Layout.fillWidth: true; visible: text !== ''; text: s.locked ? s.lockedHint : s.hint; font.pixelSize: 13; color: '#6b5d55'; wrapMode: Text.WordWrap }
            }
            Switch {
                enabled: !s.locked
                checked: s.invert ? !app.ehOption(s.key) : app.ehOption(s.key)
                onToggled: { app.ehSetOption(s.key, s.invert ? !checked : checked); s.toggled(s.invert ? !checked : checked) }
            }
        }
    }
    component LevelTag: Rectangle {
        property int level: 0
        visible: level > 0
        implicitWidth: tagL.implicitWidth + 10
        implicitHeight: tagL.implicitHeight + 2
        radius: 5
        color: level === 2 ? '#f3dde5' : '#e6e9cf'
        Label {
            id: tagL
            anchors.centerIn: parent
            text: parent.level === 2 ? qsTr('EXPERT') : qsTr('MEDIUM')
            font.pixelSize: 10
            font.bold: true
            color: parent.level === 2 ? '#5e1a33' : '#45541f'
        }
    }
    component Group: Label {
        font.pixelSize: 13
        font.bold: true
        font.letterSpacing: 0.6
        color: '#6b5d55'
        Layout.leftMargin: 4
        Layout.topMargin: 4
    }
    // translucent card, as on the home
    component Card: Rectangle {
        default property alias content: cardCol.data
        Layout.fillWidth: true
        Layout.preferredHeight: cardCol.implicitHeight
        radius: 18
        color: Qt.rgba(1, 1, 1, 0.66)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.9)
        clip: true
        ColumnLayout { id: cardCol; width: parent.width; spacing: 0 }
    }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.implicitHeight + 24
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 32
            x: 16
            spacing: 8

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }

            Label {
                Layout.topMargin: -14
                text: '‹ ' + qsTr('Back')
                color: '#5e1a33'
                font.pixelSize: 17
                font.bold: true
                TapHandler { margin: 10; onTapped: app.stack.pop() }
            }

            RowLayout {
                spacing: 10
                Image { source: Qt.resolvedUrl('../../icons/eh_gear.svg'); sourceSize.width: 32; sourceSize.height: 32 }
                Label {
                    text: qsTr('Settings')
                    color: '#3f0f21'
                    font.family: TitleFont ? TitleFont : font.family
                    font.weight: Font.Black
                    font.pixelSize: 28
                }
            }

            // T50: the level, at the top (BASE / MEDIO / ESPERTO)
            readonly property int lv: app.ehLevelNum()
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: lvCol.implicitHeight + 16
                radius: 18
                gradient: Gradient {
                    GradientStop { position: 0.0; color: '#efe6d3' }
                    GradientStop { position: 1.0; color: '#f7f0e1' }
                }
                border.width: 2
                border.color: '#d9b25a'
                ColumnLayout {
                    id: lvCol
                    x: 8; y: 8
                    width: parent.width - 16
                    spacing: 6
                    Label { Layout.leftMargin: 4; text: qsTr('LEVEL'); font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.6; color: '#45541f' }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: [ { k: 'base', t: qsTr('BASE'), s: qsTr('simple') },
                                     { k: 'medio', t: qsTr('MEDIUM'), s: qsTr('more choices') },
                                     { k: 'esperto', t: qsTr('EXPERT'), s: qsTr('with PIN') } ]
                            delegate: Rectangle {
                                id: lvB
                                required property var modelData
                                required property int index
                                readonly property bool sel: col.lv === index
                                Layout.fillWidth: true
                                Layout.preferredHeight: lvBc.implicitHeight + 14
                                radius: 12
                                color: sel ? '#5e1a33' : (lvT.pressed ? '#f3ecdd' : '#ffffff')
                                border.width: 2
                                border.color: sel ? '#3f0f21' : 'transparent'
                                ColumnLayout {
                                    id: lvBc
                                    anchors.centerIn: parent
                                    width: parent.width - 6
                                    spacing: 0
                                    Label { Layout.alignment: Qt.AlignHCenter; text: lvB.modelData.t; font.pixelSize: 15; font.bold: true; color: lvB.sel ? '#ffffff' : '#3f0f21' }
                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 3
                                        Image { visible: lvB.index === 2; source: Qt.resolvedUrl('../../icons/eh_lock.svg'); sourceSize.width: 11; sourceSize.height: 11 }
                                        Label { text: lvB.modelData.s; font.pixelSize: 11; color: lvB.sel ? '#f3dde5' : '#6b5d55' }
                                    }
                                }
                                TapHandler { id: lvT; onTapped: app.ehChooseLevel(lvB.modelData.k) }
                            }
                        }
                    }
                }
            }

            Group { text: qsTr('YOUR WALLET') }
            Card {
                Row1 { icon: 'eh_palette.svg'; text: qsTr('Name and colour'); onClicked: app.stack.push(Qt.resolvedUrl('EhNamePage.qml')) }
                RowSw { visible: col.lv >= 1; tag: 1; icon: 'eh_wallet.svg'; text: qsTr('Manage more wallets'); hint: qsTr('up to 7, each with its own colour'); key: 'multi'
                        locked: Daemon.availableWallets.rowCount() > 1
                        lockedHint: qsTr('you have %1 wallets: it stays on, so you see them all').arg(Daemon.availableWallets.rowCount()) }
                RowSw { visible: col.lv >= 1; tag: 1; icon: 'eh_eye.svg'; text: qsTr('View and receive only'); hint: qsTr('a wallet without the 12 words: see the balance and receive, no spending'); key: 'watch' }
            }

            Group { text: qsTr('HOW YOU SEE THE APP') }
            Card {
                Row1 {
                    icon: 'eh_globe.svg'; text: qsTr('Language')
                    value: Config.language === 'vec_IT' ? 'Veneto' : (Config.language === 'en_UK' ? 'English' : 'Italiano')
                    onClicked: app.ehChangeLanguage()
                }
                // T48: the reference currency (euro, dollar, ...)
                Row1 {
                    icon: 'eh_euro.svg'; text: qsTr('Currency')
                    value: app.ehSym() + ' · ' + app.ehCcy()
                    onClicked: app.stack.push(Qt.resolvedUrl('EhCurrencyPage.qml'))
                }
                RowSw {
                    icon: 'eh_textsize.svg'; text: qsTr('Bigger text'); hint: qsTr('to read better'); key: 'bigtext'
                    onToggled: {
                        var m = app.messageDialog.createObject(app, { text: qsTr('Close and reopen Schèi to see the new text size.') })
                        m.open()
                    }
                }
                RowSw { visible: !app.ehBtcOnly() && app.ehHasCash(); icon: 'eh_euro.svg'; text: qsTr('Banknotes and coins'); hint: qsTr('as when you use cash'); key: 'coins' }
                RowSw { visible: col.lv >= 1; tag: 1; icon: 'eh_anim.svg'; text: qsTr('Animations'); hint: qsTr('turn them off if the phone is slow'); key: 'no_anim'; invert: true }
                // T32: the site for "See it on the blockchain"
                Row1 { visible: col.lv >= 1; tag: 1; icon: 'eh_blocks_wine.svg'; text: qsTr('Where to see the movements')
                       value: Config.ehExplorer.name ? Config.ehExplorer.name : qsTr('My node')
                       onClicked: app.stack.push(Qt.resolvedUrl('EhExplorerPage.qml')) }
            }

            Group { visible: col.lv >= 1; text: qsTr('HOW YOU PAY AND RECEIVE') }
            Card {
                visible: col.lv >= 1
                RowSw { tag: 1; icon: 'eh_list.svg'; text: qsTr('Buttons instead of the bar'); hint: qsTr('for those who find it hard to drag'); key: 'buttons' }
                // only bitcoin: its own switch (it also turns off the exchange rates)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(60, boRow.implicitHeight + 16)
                    color: 'transparent'
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0.16, 0.13, 0.13, 0.07) }
                    RowLayout {
                        id: boRow
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
                            color: Qt.rgba(0.94, 0.90, 0.83, 0.9)
                            Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_bitcoin_logo.svg'); sourceSize.width: 22; sourceSize.height: 22 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label { Layout.fillWidth: true; text: qsTr('Amounts only in bitcoin (no %1)').arg(app.ehCcyName()); font.pixelSize: 17; font.bold: true; wrapMode: Text.WordWrap }
                            LevelTag { level: 1 }
                            Label { Layout.fillWidth: true; text: qsTr('all amounts in BTC, no exchange rate is asked'); font.pixelSize: 13; color: '#6b5d55'; wrapMode: Text.WordWrap }
                        }
                        Switch { checked: app.ehBtcOnly(); onToggled: app.ehSetBtcOnly(checked) }
                    }
                }
                RowSw { visible: !app.ehBtcOnly(); tag: 1; icon: 'eh_euro.svg'; text: qsTr('Amounts in %1 and bitcoin').arg(app.ehCcyName()); hint: qsTr('write the amount in %1 or in BTC').arg(app.ehSym()); key: 'euro_btc' }
                RowSw { tag: 1; icon: 'eh_rx_olive.svg'; text: qsTr('Ask a precise amount'); hint: qsTr('in Receive, a QR with the amount'); key: 'request_amount' }
                RowSw { tag: 1; icon: 'eh_send_qr.svg'; text: qsTr('Button: Send all the balance'); hint: qsTr('to empty the wallet · it always asks the PIN'); key: 'max' }
            }

            Group { visible: col.lv >= 1; text: qsTr('COINS AND PRIVACY') }
            Card {
                visible: col.lv >= 1
                // owner 12/11: the coins are used IN the wallet (payment "Coins used", "blocked ›"
                // on the card); the crucible is the "i" there
                RowSw { tag: 1; icon: 'eh_goldcoin.svg'; text: qsTr('Gold coins (UTXO)'); key: 'utxo'
                        hint: app.ehOption('utxo') ? qsTr('you find them in the payment ("Coins used") and in "blocked ›" on the wallet card')
                                                   : qsTr('choose which coins to spend, block coins and addresses') }
                RowSw { visible: app.ehOption('utxo'); tag: 1; icon: 'eh_privacy.svg'; text: qsTr('Advanced privacy'); hint: qsTr('pockets, origin of the coins and warnings'); key: 'privacy' }
                Row1 { visible: app.ehOption('utxo') && app.ehOption('privacy'); icon: 'eh_privacy.svg'; text: qsTr('Pockets, origin and warnings')
                       onClicked: app.stack.push(Qt.resolvedUrl('EhPrivacyPage.qml')) }
            }

            Group { visible: col.lv >= 1; text: qsTr('NETWORK') }
            Card {
                visible: col.lv >= 1
                Row1 { tag: 1; icon: 'eh_onion.svg'; text: qsTr('Connection: your node and Tor'); lock: true
                       onClicked: app.ehAskPin(qsTr('Type the PIN to change the connection'),
                                               function() { app.stack.push(Qt.resolvedUrl('EhConnectionPage.qml')) }) }
            }

            Group { text: qsTr('SECURITY') }
            Card {
                Row1 { icon: 'eh_key_wine.svg'; text: qsTr('See the 12 words again'); lock: true; onClicked: app.ehShowSeed() }
                Row1 { icon: 'eh_dots.svg'; text: qsTr('Change PIN'); lock: true; onClicked: app.ehChangePin() }
            }

            // ESPERTO: the rows for experts are here; the delicate ones ask the PIN again
            Group { visible: col.lv >= 2; text: qsTr('FOR EXPERTS') }
            Card {
                visible: col.lv >= 2
                Row1 { tag: 2; icon: 'eh_shield.svg'; text: qsTr('PIN for big payments'); lock: true
                       value: app.ehDoubleOn() ? (app.ehBtcOnly() || !Daemon.fx.enabled ? '20%' : app.ehBigLimitText()) : qsTr('off (m)')
                       onClicked: app.ehAskPin(qsTr('Type the PIN to change the PIN for big payments'),
                                               function() { app.stack.push(Qt.resolvedUrl('EhExpertPage.qml')) }) }
                RowSw { tag: 2; icon: 'eh_pen_wine.svg'; text: qsTr('Tip written by hand'); hint: qsTr('in the sending cost, you write the sat/vB (for those who know)'); key: 'manual_fee' }
                // look further than the usual 20 empty addresses (gap limit)
                Row1 { tag: 2; icon: 'eh_zoom.svg'; text: qsTr('Search on more receiving addresses'); lock: true
                       value: '' + (Daemon.currentWallet ? Daemon.currentWallet.ehGapLimit() : 20)
                       onClicked: app.ehAskPin(qsTr('Type the PIN to search on more addresses'),
                                               function() { app.stack.push(Qt.resolvedUrl('EhGapLimitPage.qml')) }) }
                Row1 { tag: 2; icon: 'eh_phone.svg'; text: qsTr('Sign on another device'); value: qsTr('coming soon'); opacity: 0.5 }
                Row1 { icon: 'eh_undo.svg'; text: qsTr('Back to the initial settings'); lock: true
                       onClicked: app.ehAskPin(qsTr('Type the PIN to go back to the initial settings'), function() {
                           // T27: our own yes / no window (Electrum's one was see-through on the phone)
                           var d = Qt.createComponent(Qt.resolvedUrl('EhAskDialog.qml')).createObject(app, {
                               text: qsTr('Are you sure?'),
                               detail: qsTr('All the settings go back to the standard ones and the level goes back to BASE.') + '\n\n'
                                       + qsTr('Your money, the wallets, the 12 words, the PIN, the name and the language do not change.')
                           })
                           d.accepted.connect(function() { app.ehResetAndCheck() })
                           d.open()
                       }) }
            }

            // information (support, licence, Electrum) at the bottom, on its own
            Card {
                Layout.topMargin: 6
                Row1 { icon: 'eh_info.svg'; text: qsTr('Information and help'); onClicked: app.stack.push(Qt.resolvedUrl('EhAboutPage.qml')) }
            }
        }
    }
}
