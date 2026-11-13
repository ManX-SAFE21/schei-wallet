// Easy Heirs (schȅi): "Scrivi le tue 12 parole" — restore from existing words.
// Two big choices (Electrum / other wallet = BIP39), the words shown one by one
// with their number, big suggestions, and our own on-screen keyboard: 7 keys
// per row in alphabetical order, no phone keyboard (it could remember or send
// what is typed). Replaces WCHaveSeed for a standard wallet (not cosigners).
// "Bottega" (WP6): the two choices as level tiles (wine leather = chosen), paper word tiles,
// paper suggestion keys, the letter keys with the EhKey look, "Next" in wine leather.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "../controls"
import "../controls/EhStyle.js" as S

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

    background: Rectangle { color: S.parch }
    topPadding: 0
    leftPadding: 16
    rightPadding: 16
    bottomPadding: 14   // the wizard (ElDialog) already leaves room for the Android keys

    function apply() {
        wizard_data['seed'] = seedText.trim()
        wizard_data['seed_variant'] = variant
        wizard_data['seed_type'] = _seedType
        // review 2026-11-11 (W4): Schȅi never adds "extra words" to the 12 words: no stock page about it
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
        // opens an empty wallet. Schȅi accepts them only if they are a real list: right number of
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
                       ? qsTr('These words were made with Schȅi or Electrum: choose "Made with Schȅi or Electrum" above.')
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

    // owner 12/11: the page scrolls when the phone is short (buttons never under the keys)
    Flickable {
        id: ehFlick
        anchors.fill: parent
        // over the side margins too, so the hills on top are not cut
        anchors.leftMargin: -16
        anchors.rightMargin: -16
        contentHeight: ehCol.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
    ColumnLayout {
        id: ehCol
        x: 16
        width: ehFlick.width - 32
        height: Math.max(implicitHeight, ehFlick.height)
        spacing: 8

        EhPageTop {
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            title: qsTr('Write your 12 words')
        }

        // ---- where were the words made ----
        // two tiles side by side, the chosen one in wine leather with stitching
        EhSegmented {
            look: 'level'
            readonly property var values: ['electrum', 'bip39']
            model: [qsTr('Made with Schȅi or Electrum'), qsTr('Made with another wallet')]
            currentIndex: root.variant === 'bip39' ? 1 : 0
            onActivated: (i) => { root.variant = values[i]; root.setText(root.seedText) }
        }

        // ---- the words, one by one with their number ----
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 56
            radius: 16
            color: S.paper
            border.width: 2
            border.color: root.checked && root.doneWords >= 12 && !root.valid ? S.wine : S.edge
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
                        // a word tile (number in brass, word in bold); the word being typed is
                        // underlined in wine; a word not in the list is rose with a wine border
                        delegate: Rectangle {
                            id: chip
                            required property string modelData
                            required property int index
                            readonly property bool current: root.typing && index === root.tokens.length - 1
                            readonly property bool bad: !current && !root.isWord(modelData)
                            width: chipRow.implicitWidth + 16
                            height: 34
                            radius: current ? 0 : 10
                            color: current ? 'transparent' : (bad ? S.dangerBg : S.parch)
                            border.width: current ? 0 : 1.5
                            border.color: bad ? S.wine : S.edge
                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 4
                                Label {
                                    text: (chip.index + 1)
                                    color: S.brassRing
                                    font.family: SerifFont ? SerifFont : font.family
                                    font.weight: Font.ExtraBold
                                    font.pixelSize: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Label {
                                    text: chip.modelData
                                    color: chip.bad ? S.wine : S.ink
                                    font.family: BodyFont ? BodyFont : font.family
                                    font.pixelSize: 17
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Rectangle { visible: chip.current; anchors.bottom: parent.bottom; width: parent.width; height: 3; color: S.wine }
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
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 17
            }
        }

        EhInfoBox {
            visible: root.checked && root.doneWords >= 12 && !root.valid && !root.typing
            kind: 'danger'
            text: '<b>' + (root.hint !== '' ? root.hint : qsTr('These words are not right. Check them one by one.')) + '</b>'
        }

        // ---- big suggestions ----
        // paper keys, 48 high; the first (best) one has a wine border
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 51
            spacing: 6
            Repeater {
                model: root.suggestions
                delegate: Item {
                    id: sg
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 51
                    Rectangle { visible: !st.pressed; y: 3; width: parent.width; height: parent.height - 3; radius: 16; color: S.edgeShadow }
                    Rectangle {
                        y: st.pressed ? 2 : 0
                        width: parent.width
                        height: parent.height - 3
                        radius: 16
                        color: st.pressed ? S.sand : S.paper
                        border.width: sg.index === 0 ? 2.5 : 1.5
                        border.color: sg.index === 0 ? S.wine : S.edge
                        Label {
                            anchors.centerIn: parent
                            width: parent.width - 10
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: sg.modelData
                            color: S.wineDark
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }
                    TapHandler { id: st; onTapped: root.pick(sg.modelData) }
                }
            }
            Item { visible: root.suggestions.length === 0; Layout.fillWidth: true; Layout.preferredHeight: 51 }
        }

        // ---- the keyboard: 7 keys per row, alphabetical ----
        // keys with the EhKey look (paper, hard shadow, letter Lexend bold), 48 high (with the shadow)
        Rectangle {
            id: kbd
            Layout.fillWidth: true
            readonly property real keyW: Math.floor((width - 6 - 6 * 4) / 7)
            readonly property real keyH: 48
            Layout.preferredHeight: 4 * keyH + 3 * 6 + 12
            radius: 16
            color: S.sand
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
                            delegate: EhKey {
                                id: kk
                                required property string modelData
                                width: kbd.keyW
                                height: kbd.keyH
                                letter: true
                                fontSize: 22
                                keyRadius: 10
                                text: kk.modelData
                                onActivated: root.key(kk.modelData)
                            }
                        }
                        // delete key on the last row (a long press clears everything)
                        Item {
                            visible: krow.index === 3
                            width: 2 * kbd.keyW + 4
                            height: kbd.keyH
                            Rectangle { visible: !bt.pressed; y: 3; width: parent.width; height: parent.height - 3; radius: 10; color: S.edgeShadow }
                            Rectangle {
                                id: delFace
                                y: bt.pressed ? 2 : 0
                                width: parent.width
                                height: parent.height - 3
                                radius: 10
                                color: bt.pressed ? Qt.darker(S.sandDel, 1.08) : S.sandDel
                                border.width: 1.5
                                border.color: S.edge
                                EhBackspaceIcon { anchors.centerIn: parent; width: 38; height: 27; ink: S.wine; fill: delFace.color }
                            }
                            TapHandler { id: bt; onTapped: root.backspace(); onLongPressed: root.setText('') }
                        }
                    }
                }
            }
        }

        EhStitchButton {
            enabled: root.valid && !root.typing
            kind: 'wine'
            text: enabled ? qsTr('Next') : qsTr('Next (%1 of 12)').arg(Math.min(root.doneWords, 12))
            endIcon: 'next'
            onClicked: root.goOn()
        }
    }
    }
}
