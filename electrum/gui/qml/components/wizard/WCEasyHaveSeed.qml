// Easy Heirs (schȅi): "Scrivi le tue parole" — restore from existing words.
// Owner 17/11: first "12 words" / "24 words" (15, 18, 21 from a small link); the words are judged
// only when all of them are written (before: a red box after the 12th word of a 24-word list, and
// 1 time in 16 the first 12 words of a 24-word list looked right and "Next" lit up).
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
    property int wantWords: 12              // how many words the person has (12, 15, 18, 21, 24)
    property bool otherCounts: false        // the small link "I have 15, 18 or 21 words" was used

    readonly property var tokens: seedText === '' ? [] : seedText.replace(/ +$/, '').split(' ')
    readonly property bool typing: seedText !== '' && seedText.slice(-1) !== ' '
    readonly property string fragment: typing ? (tokens[tokens.length - 1] || '') : ''
    readonly property int doneWords: typing ? tokens.length - 1 : tokens.length
    readonly property bool tooMany: doneWords > wantWords   // the number was changed after writing
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
        if (doneWords >= wantWords && !typing)
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
        ok = ok && n === wantWords
        if (variant === 'bip39')
            ok = ok && r.message === '' && [12, 15, 18, 21, 24].indexOf(n) >= 0
        hint = ''
        if (!ok && n === wantWords) {
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
        // phone 17/11: whether more pages follow depends on the choice above (another wallet: the
        // search page), so ask again now (before: decided when the page opened -> KeyError)
        checkIsLast()
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
            title: qsTr('Write your words (SEED)')
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

        // ---- how many words (owner 17/11) ----
        EhCaption { text: qsTr('HOW MANY WORDS DO YOU HAVE?'); Layout.topMargin: 2; Layout.bottomMargin: 0 }
        EhSegmented {
            look: 'filter'   // lower than the choice above: room for the words on short phones
            readonly property var values: root.otherCounts ? [12, 15, 18, 21, 24] : [12, 24]
            model: root.otherCounts ? ['12', '15', '18', '21', '24'] : [qsTr('12 words'), qsTr('24 words')]
            currentIndex: Math.max(0, values.indexOf(root.wantWords))
            onActivated: (i) => { root.wantWords = values[i]; root.setText(root.seedText) }
        }
        Label {
            visible: !root.otherCounts
            Layout.alignment: Qt.AlignHCenter
            text: '<u>' + qsTr('I have 15, 18 or 21 words') + '</u>'
            textFormat: Text.StyledText
            color: S.wine
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: app.ehFsSmall
            TapHandler { onTapped: root.otherCounts = true }
        }

        // ---- the words, one by one with their number ----
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 56
            radius: 16
            color: S.paper
            border.width: 2
            border.color: root.tooMany || (root.checked && root.doneWords === root.wantWords && !root.valid) ? S.wine : S.edge
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
                                    font.pixelSize: app.ehFsText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Label {
                                    text: chip.modelData
                                    color: chip.bad ? S.wine : S.ink
                                    font.family: BodyFont ? BodyFont : font.family
                                    font.pixelSize: app.ehFsText
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
                font.pixelSize: app.ehFsText
            }
        }

        EhInfoBox {
            visible: !root.typing && (root.tooMany || (root.checked && root.doneWords === root.wantWords && !root.valid))
            kind: 'danger'
            text: '<b>' + (root.tooMany ? qsTr('You wrote %1 words, but you chose %2. Delete the extra words or choose another number.').arg(root.doneWords).arg(root.wantWords)
                          : root.hint !== '' ? root.hint : qsTr('These words are not right. Check them one by one.')) + '</b>'
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
                            font.pixelSize: app.ehFsText
                            font.bold: true
                        }
                    }
                    TapHandler { id: st; onTapped: root.pick(sg.modelData) }
                }
            }
            Item { visible: root.suggestions.length === 0; Layout.fillWidth: true; Layout.preferredHeight: 51 }
        }

        // ---- the keyboard: QWERTY like the phone (owner 17/11), shared control ----
        EhLetterKeyboard {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            onLetter: (ch) => root.key(ch)
            onDeleteOne: root.backspace()
            onDeleteAll: root.setText('')
        }

        EhStitchButton {
            enabled: root.valid && !root.typing
            kind: 'wine'
            text: enabled ? qsTr('Next') : qsTr('Next (%1 of %2)').arg(Math.min(root.doneWords, root.wantWords)).arg(root.wantWords)
            endIcon: 'next'
            onClicked: root.goOn()
        }
    }
    }
}
