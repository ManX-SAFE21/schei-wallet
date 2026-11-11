// Easy Heirs (schèi): ADVANCED SETTINGS, opened with the PIN (EhSettings).
// Security (12 words, PIN, PIN for big payments), money, wallets, and the
// "back to the initial settings" button. Inside, the PIN is not asked again.
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
    Material.accent: '#45541f'

    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    EhGlow { tone: 'wine'; x: -page.width * 0.3; y: 40; width: page.width * 1.6; height: 380; opacity: 0.7 }

    // the PIN was typed to come in: no new PIN for the 12 words while here
    Component.onCompleted: app._ehPinOkUntil = Date.now() + 10 * 60 * 1000
    Component.onDestruction: app._ehPinOkUntil = 0

    component Nav: Rectangle {
        id: nv
        property string icon
        property string text
        signal clicked
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(56, nvRow.implicitHeight + 16)
        color: nvTap.pressed ? '#f7f2e8' : 'transparent'
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: '#f1ebdf' }
        RowLayout {
            id: nvRow
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12
            Image { source: Qt.resolvedUrl('../../icons/' + nv.icon); sourceSize.width: 24; sourceSize.height: 24 }
            Label { Layout.fillWidth: true; text: nv.text; font.pixelSize: 16; font.bold: true; wrapMode: Text.WordWrap }
            Label { text: '›'; font.pixelSize: 22; color: '#5e1a33' }
        }
        TapHandler { id: nvTap; onTapped: nv.clicked() }
    }

    component Sw: Rectangle {
        id: s
        property string text
        property string hint
        property string key
        property bool soon: false
        property bool invert: false     // the option stores the opposite (e.g. no_anim)
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(60, swRow.implicitHeight + 16)
        color: 'transparent'
        opacity: soon ? 0.5 : 1
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: '#f1ebdf' }
        RowLayout {
            id: swRow
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: s.text; font.pixelSize: 16; font.bold: true; wrapMode: Text.WordWrap }
                Label { Layout.fillWidth: true; text: s.soon ? qsTr('coming soon') : s.hint; font.pixelSize: 13; color: '#6b5d55'; wrapMode: Text.WordWrap }
            }
            Switch {
                enabled: !s.soon
                checked: s.invert ? !app.ehOption(s.key) : app.ehOption(s.key)
                onToggled: app.ehSetOption(s.key, s.invert ? !checked : checked)
            }
        }
    }
    component Group: Label {
        font.pixelSize: 13
        font.bold: true
        font.letterSpacing: 0.5
        color: '#45541f'
        Layout.leftMargin: 4
        Layout.topMargin: 2
    }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight  // T9: last button was under the Android keys
        contentHeight: col.implicitHeight + 30
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 32
            x: 16
            spacing: 8

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }

            Label {
                Layout.topMargin: -14
                text: '‹ ' + qsTr('Settings')
                color: '#5e1a33'
                font.pixelSize: 17
                font.bold: true
                TapHandler { margin: 10; onTapped: app.stack.pop() }
            }
            RowLayout {
                spacing: 10
                Image { source: Qt.resolvedUrl('../../icons/eh_lock.svg'); sourceSize.width: 30; sourceSize.height: 30 }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr('Advanced settings')
                    color: '#3f0f21'
                    font.family: TitleFont ? TitleFont : font.family
                    font.weight: Font.Black
                    font.pixelSize: 28
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: nl.implicitHeight + 14
                radius: 14
                color: '#fbf0d6'
                Label { id: nl; anchors.fill: parent; anchors.margins: 7; anchors.leftMargin: 12; wrapMode: Text.WordWrap; font.pixelSize: 15; text: qsTr('Here are the things about money and safety. By default everything is off, except the PIN for big payments.') }
            }

            Group { text: '1 · ' + qsTr('SECURITY') }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: g0.implicitHeight; radius: 18; color: Qt.rgba(1, 1, 1, 0.7); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.9); clip: true
                ColumnLayout { id: g0; width: parent.width; spacing: 0
                    Nav { icon: 'eh_key_wine.svg'; text: qsTr('See the 12 words again'); onClicked: app.ehShowSeed() }
                    Nav { icon: 'eh_dots.svg'; text: qsTr('Change PIN'); onClicked: app.ehChangePin() }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: 'transparent'
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: '#f1ebdf' }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label { Layout.fillWidth: true; text: qsTr('PIN for big payments'); font.pixelSize: 16; font.bold: true; wrapMode: Text.WordWrap }
                                Label { Layout.fillWidth: true; text: qsTr('like a contactless card: below the threshold the coin is enough'); font.pixelSize: 13; color: '#6b5d55'; wrapMode: Text.WordWrap }
                            }
                            Switch { checked: app.ehDoubleOn(); onToggled: app.ehSetOption('double', checked) }
                        }
                    }
                    ColumnLayout {
                        visible: app.ehDoubleOn()
                        Layout.fillWidth: true
                        Layout.margins: 12
                        spacing: 8
                        Label { text: qsTr('Ask the PIN from'); font.pixelSize: 14; font.bold: true; color: '#6b5d55' }
                        Label {
                            visible: app.ehBtcOnly()
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            textFormat: Text.StyledText
                            font.pixelSize: 15
                            text: qsTr('<b>20%</b> of the balance (with "Only bitcoin" there is no euro value).')
                        }
                        Flow {
                            visible: !app.ehBtcOnly()
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: [50, 100, 200, 500]
                                delegate: Rectangle {
                                    required property int modelData
                                    width: amtL.implicitWidth + 28
                                    height: 38
                                    radius: 19
                                    color: app.ehDoubleEur() === modelData ? '#5e1a33' : '#efe6d3'
                                    Label {
                                        id: amtL
                                        anchors.centerIn: parent
                                        text: app.ehGroup('' + modelData) + ' €'
                                        font.pixelSize: 15
                                        font.bold: true
                                        color: app.ehDoubleEur() === modelData ? '#ffffff' : '#6b5d55'
                                    }
                                    TapHandler { onTapped: app.ehSetDoubleEur(modelData) }
                                }
                            }
                            Rectangle {
                                width: 138      // fixed: the empty field has no width of its own
                                height: 38
                                radius: 19
                                color: [50, 100, 200, 500].indexOf(app.ehDoubleEur()) < 0 ? '#5e1a33' : '#efe6d3'
                                TextInput {
                                    id: otherF
                                    anchors.centerIn: parent
                                    width: 110
                                    horizontalAlignment: TextInput.AlignHCenter
                                    text: [50, 100, 200, 500].indexOf(app.ehDoubleEur()) < 0 ? '' + app.ehDoubleEur() : ''
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    validator: IntValidator { bottom: 1; top: 1000000 }
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: [50, 100, 200, 500].indexOf(app.ehDoubleEur()) < 0 ? '#ffffff' : '#2a2220'
                                    onEditingFinished: if (text !== '') app.ehSetDoubleEur(parseInt(text))
                                    Label {
                                        // our own hint: it stays in place and goes away while typing
                                        anchors.centerIn: parent
                                        visible: otherF.text === '' && !otherF.activeFocus
                                        text: qsTr('other amount…')
                                        font.pixelSize: 15
                                        font.bold: true
                                        color: '#6b5d55'
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Group { text: '2 · ' + qsTr('AMOUNTS') }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: g1.implicitHeight; radius: 18; color: '#ffffff'; clip: true
                ColumnLayout { id: g1; width: parent.width; spacing: 0
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: 'transparent'
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: '#f1ebdf' }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label { Layout.fillWidth: true; text: qsTr('Only bitcoin (no euro)'); font.pixelSize: 16; font.bold: true; wrapMode: Text.WordWrap }
                                Label { Layout.fillWidth: true; text: qsTr('all amounts in BTC, no exchange rate is asked'); font.pixelSize: 13; color: '#6b5d55'; wrapMode: Text.WordWrap }
                            }
                            Switch { checked: app.ehBtcOnly(); onToggled: app.ehSetBtcOnly(checked) }
                        }
                    }
                    Sw { visible: !app.ehBtcOnly(); text: qsTr('Euro or Bitcoin'); hint: qsTr('write the amount in € or in BTC'); key: 'euro_btc' }
                    Sw { text: qsTr('"All the balance" button'); hint: qsTr('to empty the wallet'); key: 'max' }
                    Sw { text: qsTr('Ask for an amount'); hint: qsTr('in Receive, a QR with the amount'); key: 'request_amount' }
                }
            }
            Group { text: '3 · ' + qsTr('COINS AND PRIVACY') }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: gN.implicitHeight; radius: 18; color: Qt.rgba(1, 1, 1, 0.7); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.9); clip: true
                ColumnLayout { id: gN; width: parent.width; spacing: 0
                    Nav { icon: 'eh_goldcoin.svg'; text: qsTr('Your gold coins and addresses'); onClicked: app.stack.push(Qt.resolvedUrl('EhCoinsPage.qml')) }
                    // T20: pockets, origin of the coins, warnings (for advanced users, off by default)
                    Nav { icon: 'eh_privacy.svg'; text: qsTr('Advanced privacy') + ' · ' + (app.ehOption('privacy') ? qsTr('on (f)') : qsTr('off (f)')); onClicked: app.stack.push(Qt.resolvedUrl('EhPrivacyPage.qml')) }
                }
            }

            Group { text: '4 · ' + qsTr('WALLETS') }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: g2.implicitHeight; radius: 18; color: '#ffffff'; clip: true
                ColumnLayout { id: g2; width: parent.width; spacing: 0
                    Sw { text: qsTr('More wallets'); hint: qsTr('up to 7, each with its own colour'); key: 'multi' }
                    Sw { text: qsTr('Watch only'); hint: qsTr('see the balance without being able to spend'); key: 'watch' }
                    Sw { text: qsTr('Sign elsewhere'); hint: qsTr('sign the payment on another device'); key: 'sign_elsewhere'; soon: true }
                }
            }
            Group { text: '5 · ' + qsTr('NETWORK AND RECOVERY') + '  ' + qsTr('(for experts)') }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: g5.implicitHeight; radius: 18; color: Qt.rgba(1, 1, 1, 0.7); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.9); clip: true
                ColumnLayout { id: g5; width: parent.width; spacing: 0
                    Nav { icon: 'eh_onion.svg'; text: qsTr('Connection: your node and Tor'); onClicked: app.stack.push(Qt.resolvedUrl('EhConnectionPage.qml')) }
                    // look further than the usual 20 empty addresses (gap limit)
                    Nav {
                        icon: 'eh_zoom.svg'
                        text: qsTr('Look at more addresses') + ' · ' + qsTr('now: %1').arg(Daemon.currentWallet ? Daemon.currentWallet.ehGapLimit() : 20)
                        onClicked: app.stack.push(Qt.resolvedUrl('EhGapLimitPage.qml'))
                    }
                }
            }
            // back to the initial settings (also the PIN threshold, so it lives here)
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.preferredHeight: 52
                radius: 26
                color: resetTap.pressed ? '#fbeef2' : Qt.rgba(1, 1, 1, 0.7)
                border.width: 2
                border.color: '#e9cdd6'
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Image { source: Qt.resolvedUrl('../../icons/eh_undo.svg'); sourceSize.width: 22; sourceSize.height: 22 }
                    Label { text: qsTr('Back to the initial settings'); color: '#5e1a33'; font.pixelSize: 16; font.bold: true }
                }
                TapHandler {
                    id: resetTap
                    onTapped: {
                        var d = app.messageDialog.createObject(app, {
                            title: qsTr('Back to the initial settings?'),
                            text: qsTr('Your choices (expert mode, colours) will go back to how they were at the start.') + '\n\n'
                                  + qsTr('Your money, the 12 words and the PIN do not change.'),
                            yesno: true
                        })
                        d.accepted.connect(function() { app.ehResetSettings() })
                        d.open()
                    }
                }
            }
        }
    }
}
