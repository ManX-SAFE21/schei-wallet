// Easy Heirs (schèi): settings in three levels BASE / MEDIO / ESPERTO (owner 12/11, T50).
// The choice at the top shows the rows of the level and turns on its preset (main.qml
// ehSetLevel); every switch can then be changed by hand. ESPERTO asks the PIN, and its
// delicate rows (PIN threshold, node, more addresses, reset) ask it again.
// Look: "Bottega" (paper sheets on parchment, EhRow rows, EhSwitch, level tiles).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: S.ink

    Rectangle { anchors.fill: parent; color: S.parch }

    // a row with a switch (an option of the app)
    component RowSw: EhRow {
        id: s
        property string key
        property bool invert: false     // the option stores the opposite (no_anim)
        property bool locked: false     // stays on, cannot be turned off (more wallets with 2+)
        property string lockedHint
        property string note            // the hint under the label
        signal optionSet(bool on)       // after the option is saved (the value of the option)
        Component.onCompleted: if (locked && !app.ehOption(key)) app.ehSetOption(key, true)
        showSwitch: true
        hint: s.locked ? s.lockedHint : s.note
        switchEnabled: !s.locked
        checked: s.invert ? !app.ehOption(s.key) : app.ehOption(s.key)
        onToggled: (on) => { app.ehSetOption(s.key, s.invert ? !on : on); s.optionSet(s.invert ? !on : on) }
    }
    // section caption between the sheets (16 visible px over it, 6 under it)
    component Group: EhCaption {
        Layout.topMargin: 8
        Layout.bottomMargin: -2
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

            EhBackLink { onClicked: app.stack.pop() }

            EhTitle { text: qsTr('Settings'); icon: 'eh_gear.svg' }

            // T50: the level, at the top (BASE / MEDIO / ESPERTO)
            readonly property int lv: app.ehLevelNum()
            readonly property var levelKeys: ['base', 'medio', 'esperto']
            EhSheet {
                padding: 8
                topPadding: 4
                bottomPadding: 10
                EhCaption { text: qsTr('LEVEL'); Layout.topMargin: 4; Layout.bottomMargin: 6 }
                EhSegmented {
                    look: 'level'
                    model: [ { text: qsTr('BASE'), sub: qsTr('simple') },
                             { text: qsTr('MEDIUM'), sub: qsTr('more choices') },
                             { text: qsTr('EXPERT'), sub: qsTr('with PIN'), lock: true } ]
                    currentIndex: col.lv
                    onActivated: (i) => app.ehChooseLevel(col.levelKeys[i])
                }
            }

            Group { text: qsTr('YOUR WALLET') }
            EhSheet {
                EhRow { icon: 'eh_palette.svg'; text: qsTr('Name and colour'); last: col.lv < 1
                        onClicked: app.stack.push(Qt.resolvedUrl('EhNamePage.qml')) }
                RowSw { visible: col.lv >= 1; tag: 1; icon: 'eh_wallet.svg'; text: qsTr('Manage more wallets'); note: qsTr('up to 7, each with its own colour'); key: 'multi'
                        locked: Daemon.availableWallets.rowCount() > 1
                        lockedHint: qsTr('you have %1 wallets: it stays on, so you see them all').arg(Daemon.availableWallets.rowCount()) }
                RowSw { visible: col.lv >= 1; tag: 1; icon: 'eh_eye.svg'; text: qsTr('View and receive only'); note: qsTr('a wallet without the 12 words: see the balance and receive, no spending'); key: 'watch'
                        last: true }
            }

            Group { text: qsTr('HOW YOU SEE THE APP') }
            EhSheet {
                id: seeSheet
                readonly property bool cashRow: !app.ehBtcOnly() && app.ehHasCash()
                EhRow {
                    icon: 'eh_globe.svg'; text: qsTr('Language')
                    value: Config.language === 'vec_IT' ? 'Veneto' : (Config.language === 'en_UK' ? 'English' : 'Italiano')
                    onClicked: app.ehChangeLanguage()
                }
                // T48: the reference currency (euro, dollar, ...)
                EhRow {
                    icon: 'eh_euro.svg'; text: qsTr('Currency')
                    value: app.ehSym() + ' · ' + app.ehCcy()
                    onClicked: app.stack.push(Qt.resolvedUrl('EhCurrencyPage.qml'))
                }
                RowSw {
                    icon: 'eh_textsize.svg'; text: qsTr('Bigger text'); note: qsTr('to read better'); key: 'bigtext'
                    last: col.lv < 1 && !seeSheet.cashRow
                    onOptionSet: {
                        var m = app.messageDialog.createObject(app, { text: qsTr('Close and reopen Schèi to see the new text size.') })
                        m.open()
                    }
                }
                RowSw { visible: seeSheet.cashRow; icon: 'eh_euro.svg'; text: qsTr('Banknotes and coins'); note: qsTr('as when you use cash'); key: 'coins'
                        last: col.lv < 1 }
                RowSw { visible: col.lv >= 1; tag: 1; icon: 'eh_anim.svg'; text: qsTr('Animations'); note: qsTr('turn them off if the phone is slow'); key: 'no_anim'; invert: true }
                // T32: the site for "See it on the blockchain"
                EhRow { visible: col.lv >= 1; tag: 1; icon: 'eh_blocks_wine.svg'; text: qsTr('Where to see the movements')
                        value: Config.ehExplorer.name ? Config.ehExplorer.name : qsTr('My node')
                        last: true
                        onClicked: app.stack.push(Qt.resolvedUrl('EhExplorerPage.qml')) }
            }

            Group { visible: col.lv >= 1; text: qsTr('HOW YOU PAY AND RECEIVE') }
            EhSheet {
                visible: col.lv >= 1
                RowSw { tag: 1; icon: 'eh_list.svg'; text: qsTr('Buttons instead of the bar'); note: qsTr('for those who find it hard to drag'); key: 'buttons' }
                // only bitcoin: its own switch (it also turns off the exchange rates)
                EhRow {
                    tag: 1; icon: 'eh_bitcoin_logo.svg'
                    text: qsTr('Amounts only in bitcoin (no %1)').arg(app.ehCcyName())
                    hint: qsTr('all amounts in BTC, no exchange rate is asked')
                    showSwitch: true
                    checked: app.ehBtcOnly()
                    onToggled: (on) => app.ehSetBtcOnly(on)
                }
                RowSw { visible: !app.ehBtcOnly(); tag: 1; icon: 'eh_euro.svg'; text: qsTr('Amounts in %1 and bitcoin').arg(app.ehCcyName()); note: qsTr('write the amount in %1 or in BTC').arg(app.ehSym()); key: 'euro_btc' }
                RowSw { tag: 1; icon: 'eh_rx_olive.svg'; text: qsTr('Ask a precise amount'); note: qsTr('in Receive, a QR with the amount'); key: 'request_amount' }
                RowSw { tag: 1; icon: 'eh_send_qr.svg'; text: qsTr('Button: Send all the balance'); note: qsTr('to empty the wallet · it always asks the PIN'); key: 'max'; last: true }
            }

            Group { visible: col.lv >= 1; text: qsTr('COINS AND PRIVACY') }
            EhSheet {
                visible: col.lv >= 1
                // owner 12/11: the coins are used IN the wallet (payment "Coins used", "blocked ›"
                // on the card); the crucible is the "i" there
                RowSw { tag: 1; icon: 'eh_goldcoin.svg'; text: qsTr('Gold coins (UTXO)'); key: 'utxo'
                        last: !app.ehOption('utxo')
                        note: app.ehOption('utxo') ? qsTr('you find them in the payment ("Coins used") and in "blocked ›" on the wallet card')
                                                   : qsTr('choose which coins to spend, block coins and addresses') }
                RowSw { visible: app.ehOption('utxo'); tag: 1; icon: 'eh_privacy.svg'; text: qsTr('Advanced privacy'); note: qsTr('pockets, origin of the coins and warnings'); key: 'privacy'
                        last: !app.ehOption('privacy') }
                EhRow { visible: app.ehOption('utxo') && app.ehOption('privacy'); icon: 'eh_privacy.svg'; text: qsTr('Pockets, origin and warnings')
                        last: true
                        onClicked: app.stack.push(Qt.resolvedUrl('EhPrivacyPage.qml')) }
            }

            Group { visible: col.lv >= 1; text: qsTr('NETWORK') }
            EhSheet {
                visible: col.lv >= 1
                EhRow { tag: 1; icon: 'eh_onion.svg'; text: qsTr('Connection: your node and Tor'); lock: true; last: true
                        onClicked: app.ehAskPin(qsTr('Type the PIN to change the connection'),
                                                function() { app.stack.push(Qt.resolvedUrl('EhConnectionPage.qml')) }) }
            }

            Group { text: qsTr('SECURITY') }
            EhSheet {
                EhRow { icon: 'eh_key_wine.svg'; text: qsTr('See the 12 words again'); lock: true; onClicked: app.ehShowSeed() }
                EhRow { icon: 'eh_dots.svg'; text: qsTr('Change PIN'); lock: true; last: true; onClicked: app.ehChangePin() }
            }

            // ESPERTO: the rows for experts are here; the delicate ones ask the PIN again
            Group { visible: col.lv >= 2; text: qsTr('FOR EXPERTS') }
            EhSheet {
                visible: col.lv >= 2
                EhRow { tag: 2; icon: 'eh_shield.svg'; text: qsTr('PIN for big payments'); lock: true
                        value: app.ehDoubleOn() ? (app.ehBtcOnly() || !Daemon.fx.enabled ? '20%' : app.ehBigLimitText()) : qsTr('off (m)')
                        onClicked: app.ehAskPin(qsTr('Type the PIN to change the PIN for big payments'),
                                                function() { app.stack.push(Qt.resolvedUrl('EhExpertPage.qml')) }) }
                RowSw { tag: 2; icon: 'eh_pen_wine.svg'; text: qsTr('Tip written by hand'); note: qsTr('in the sending cost, you write the sat/vB (for those who know)'); key: 'manual_fee' }
                // look further than the usual 20 empty addresses (gap limit)
                EhRow { tag: 2; icon: 'eh_zoom.svg'; text: qsTr('Search on more receiving addresses'); lock: true
                        value: '' + (Daemon.currentWallet ? Daemon.currentWallet.ehGapLimit() : 20)
                        onClicked: app.ehAskPin(qsTr('Type the PIN to search on more addresses'),
                                                function() { app.stack.push(Qt.resolvedUrl('EhGapLimitPage.qml')) }) }
                EhRow { tag: 2; icon: 'eh_phone.svg'; text: qsTr('Sign on another device'); value: qsTr('coming soon'); opacity: 0.5; last: true }
            }

            // owner 12/11: "back to the initial settings" in every level, at the bottom, with the PIN
            EhSheet {
                Layout.topMargin: 14
                EhRow { icon: 'eh_undo.svg'; text: qsTr('Back to the initial settings'); lock: true; last: true
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
            EhSheet {
                Layout.topMargin: 8
                EhRow { icon: 'eh_info.svg'; text: qsTr('Information and help'); last: true; onClicked: app.stack.push(Qt.resolvedUrl('EhAboutPage.qml')) }
            }
        }
    }
}
