// Easy Heirs (schèi): "Scrivi le tue 12 parole" — restore from existing words.
// Two big choices (Electrum / other wallet = BIP39), the words shown one by one
// with their number, big suggestions, and our own on-screen keyboard: 7 keys
// per row in alphabetical order, no phone keyboard (it could remember or send
// what is typed). Replaces WCHaveSeed for a standard wallet (not cosigners).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "../controls"

WizardComponent {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'
    securePage: true
    valid: false
    property bool hideWizardButtons: true

    property string variant: 'electrum'     // 'electrum' or 'bip39'
    property string seedText: ''            // words separated by one space
    property string _seedType
    property bool _canPassphrase
    property bool checked: false            // validation ran on the current text
    property string hint: ''                // the words are right, but for the other choice

    readonly property var tokens: seedText === '' ? [] : seedText.replace(/ +$/, '').split(' ')
    readonly property bool typing: seedText !== '' && seedText.slice(-1) !== ' '
    readonly property string fragment: typing ? (tokens[tokens.length - 1] || '') : ''
    readonly property int doneWords: typing ? tokens.length - 1 : tokens.length
    readonly property var suggestions: fragment.length >= 1 ? bitcoin.mnemonicsFor(fragment).slice(0, 3) : []

    background: Rectangle { color: '#faf7ef' }
    topPadding: 0
    leftPadding: 16
    rightPadding: 16
    bottomPadding: 14 + app.navigationBarHeight

    function apply() {
        wizard_data['seed'] = seedText.trim()
        wizard_data['seed_variant'] = variant
        wizard_data['seed_type'] = _seedType
        // review 2026-11-11 (W4): Schèi never adds "extra words" to the 12 words: no stock page about it
        wizard_data['seed_extend'] = false
    }

    function setText(t) {
        seedText = t
        valid = false
        checked = false
        checkTimer.restart()
    }
    function key(ch) {
        if (doneWords >= 24 && !typing)
            return
        setText(seedText + ch)
    }
    function backspace() {
        if (seedText.length > 0)
            setText(seedText.slice(0, -1))
    }
    function pick(word) {
        var t = tokens.slice(0, doneWords)
        t.push(word)
        setText(t.join(' ') + ' ')
    }
    function isWord(w) {
        return bitcoin.mnemonicsFor(w).indexOf(w) >= 0
    }
    function checkValid() {
        var s = seedText.trim()
        var r = wiz.verifySeed(s, variant, wizard_data['wallet_type'])
        _seedType = r.type
        _canPassphrase = r.can_passphrase
        var ok = r.valid
        // review 2026-11-11 (W1): Electrum accepts ANY text as "another wallet" (BIP39) words and
        // opens an empty wallet. Schèi accepts them only if they are a real list: right number of
        // words, all from the list, and the last one matching the others (checksum).
        var n = s === '' ? 0 : s.split(/ +/).length
        if (variant === 'bip39')
            ok = ok && r.message === '' && [12, 15, 18, 21, 24].indexOf(n) >= 0
        hint = ''
        if (!ok && n >= 12) {
            var other = variant === 'bip39' ? 'electrum' : 'bip39'
            var r2 = wiz.verifySeed(s, other, wizard_data['wallet_type'])
            if (r2.valid && (other === 'electrum' || (r2.message === '' && [12, 15, 18, 21, 24].indexOf(n) >= 0)))
                hint = other === 'electrum'
                       ? qsTr('These words were made with Schèi or Electrum: choose "Made with Schèi or Electrum" above.')
                       : qsTr('These words were made with another wallet: choose "Made with another wallet" above.')
        }
        valid = ok
        checked = true
    }
    function goOn() {
        if (!valid)
            return
        if (root.last)
            wizard.pages.finish()
        else
            wizard.pages.next()
    }

    Timer {
        id: checkTimer
        interval: 250
        onTriggered: root.checkValid()
    }
    Bitcoin { id: bitcoin }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        EhPageTop {
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            title: qsTr('Write your 12 words')
        }

        // ---- where were the words made ----
        Repeater {
            model: [
                { v: 'electrum', t: qsTr('Made with Schèi or Electrum') },
                { v: 'bip39', t: qsTr('Made with another wallet') }
            ]
            delegate: Rectangle {
                id: ch
                required property var modelData
                readonly property bool on: root.variant === modelData.v
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 22
                color: on ? '#fbf3f5' : '#ffffff'
                border.width: on ? 3 : 2
                border.color: on ? '#5e1a33' : '#e2d7c1'
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    spacing: 10
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: 'transparent'
                        border.width: 3; border.color: '#5e1a33'
                        Rectangle { visible: ch.on; anchors.centerIn: parent; width: 12; height: 12; radius: 6; color: '#5e1a33' }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ch.modelData.t
                        color: '#2a2220'
                        font.pixelSize: 17
                        font.bold: true
                    }
                }
                TapHandler {
                    margin: 3
                    onTapped: { root.variant = ch.modelData.v; root.setText(root.seedText) }
                }
            }
        }

        // ---- the words, one by one with their number ----
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 56
            radius: 16
            color: '#ffffff'
            border.width: 2
            border.color: root.checked && root.doneWords >= 12 && !root.valid ? '#b0413e' : '#e2d7c1'
            Flickable {
                id: wordsFlick
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                contentHeight: wordsFlow.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
                Flow {
                    id: wordsFlow
                    width: parent.width
                    spacing: 5
                    Repeater {
                        model: root.tokens
                        delegate: Rectangle {
                            id: chip
                            required property string modelData
                            required property int index
                            readonly property bool current: root.typing && index === root.tokens.length - 1
                            readonly property bool bad: !current && !root.isWord(modelData)
                            width: chipRow.implicitWidth + 14
                            height: 28
                            radius: current ? 0 : 9
                            color: current ? 'transparent' : (bad ? '#f6dada' : '#f3ece0')
                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 3
                                Label { text: (chip.index + 1); color: '#6b5d55'; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                Label { text: chip.modelData; color: chip.bad ? '#8a1f1c' : '#2a2220'; font.pixelSize: 16; font.bold: true }
                            }
                            Rectangle { visible: chip.current; anchors.bottom: parent.bottom; width: parent.width; height: 3; color: '#5e1a33' }
                        }
                    }
                }
            }
            Label {
                visible: root.seedText === ''
                anchors.centerIn: parent
                width: parent.width - 20
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr('tap the letters, then the word')
                color: '#a89a8e'
                font.pixelSize: 16
            }
        }

        Label {
            visible: root.checked && root.doneWords >= 12 && !root.valid && !root.typing
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.hint !== '' ? root.hint : qsTr('These words are not right. Check them one by one.')
            color: '#8a1f1c'
            font.pixelSize: 15
            font.bold: true
        }

        // ---- big suggestions ----
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: 6
            Repeater {
                model: root.suggestions
                delegate: Rectangle {
                    id: sg
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 22
                    color: index === 0 ? (st.pressed ? '#3f0f21' : '#5e1a33') : (st.pressed ? '#f3ecdd' : '#ffffff')
                    border.width: index === 0 ? 0 : 2
                    border.color: '#5e1a33'
                    Label {
                        anchors.centerIn: parent
                        width: parent.width - 10
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: sg.modelData
                        color: sg.index === 0 ? '#ffffff' : '#3f0f21'
                        font.pixelSize: 18
                        font.bold: true
                    }
                    TapHandler { id: st; onTapped: root.pick(sg.modelData) }
                }
            }
            Item { visible: root.suggestions.length === 0; Layout.fillWidth: true; Layout.preferredHeight: 44 }
        }

        // ---- the keyboard: 7 keys per row, alphabetical ----
        Rectangle {
            id: kbd
            Layout.fillWidth: true
            readonly property real keyW: Math.floor((width - 6 - 6 * 4) / 7)
            readonly property real keyH: 46
            Layout.preferredHeight: 4 * keyH + 3 * 6 + 12
            radius: 16
            color: '#efe6d3'
            Column {
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: ['abcdefg', 'hijklmn', 'opqrstu', 'vwxyz']
                    delegate: Row {
                        id: krow
                        required property string modelData
                        required property int index
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        Repeater {
                            model: krow.modelData.split('')
                            delegate: Rectangle {
                                id: kk
                                required property string modelData
                                width: kbd.keyW
                                height: kbd.keyH
                                radius: 9
                                color: kt.pressed ? '#f3ecdd' : '#ffffff'
                                Rectangle { z: -1; anchors.fill: parent; anchors.topMargin: 2; anchors.bottomMargin: -2; radius: 9; color: '#d6c9b1' }
                                Label {
                                    anchors.centerIn: parent
                                    text: kk.modelData
                                    color: '#2a2220'
                                    font.pixelSize: 24
                                    font.bold: true
                                }
                                TapHandler { id: kt; onTapped: root.key(kk.modelData) }
                            }
                        }
                        // delete key on the last row
                        Rectangle {
                            visible: krow.index === 3
                            width: 2 * kbd.keyW + 4
                            height: kbd.keyH
                            radius: 9
                            color: bt.pressed ? '#d6c9b1' : '#e2d7c1'
                            EhBackspaceIcon { anchors.centerIn: parent; width: 38; height: 27 }
                            TapHandler { id: bt; onTapped: root.backspace(); onLongPressed: root.setText('') }
                        }
                    }
                }
            }
        }

        EhPillButton {
            enabled: root.valid && !root.typing
            opacity: enabled ? 1 : 0.45
            text: enabled ? qsTr('Next') : qsTr('Next (%1 of 12)').arg(Math.min(root.doneWords, 12))
            fontSize: 21
            color: '#5e1a33'
            textColor: '#ffffff'
            tileColor: '#d9b25a'
            outlined: false
            onClicked: root.goOn()
            Image {
                anchors.centerIn: parent
                source: Qt.resolvedUrl('../../../icons/eh_next.svg')
                sourceSize.width: 30
                sourceSize.height: 30
            }
        }
    }
}
