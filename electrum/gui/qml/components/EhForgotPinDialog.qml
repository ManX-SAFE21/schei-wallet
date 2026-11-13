// Easy Heirs (schèi): "Hai dimenticato il PIN?" (third review). The 12 words of THIS wallet
// prove who you are: if they match, a new PIN is chosen (EhChangePinDialog without the old PIN).
// Same words area and keyboard as the restore page (WCEasyHaveSeed.qml).
// "Bottega" (WP6): parchment page, back link, Fraunces title, the same tiles and keys as there;
// the page scrolls when the phone is short.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"
import "controls/EhStyle.js" as S

ElDialog {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'
    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    background: Rectangle { color: S.parch }
    Binding { target: AppController; property: 'secureWindow'; value: true; when: root.visible }

    property string seedText: ''
    property string hint: ''
    readonly property var tokens: seedText === '' ? [] : seedText.replace(/ +$/, '').split(' ')
    readonly property bool typing: seedText !== '' && seedText.slice(-1) !== ' '
    readonly property string fragment: typing ? (tokens[tokens.length - 1] || '') : ''
    readonly property int doneWords: typing ? tokens.length - 1 : tokens.length
    readonly property var suggestions: fragment.length >= 1 ? bitcoin.mnemonicsFor(fragment).slice(0, 3) : []
    readonly property bool ready: !typing && [12, 15, 18, 21, 24].indexOf(doneWords) >= 0

    function setText(t) { seedText = t; hint = '' }
    function key(ch) { if (doneWords >= 24 && !typing) return; setText(seedText + ch) }
    function backspace() { if (seedText.length > 0) setText(seedText.slice(0, -1)) }
    function pick(word) { var t = tokens.slice(0, doneWords); t.push(word); setText(t.join(' ') + ' ') }
    function isWord(w) { return bitcoin.mnemonicsFor(w).indexOf(w) >= 0 }
    function check() {
        if (Daemon.currentWallet.ehSeedMatches(seedText.trim())) {
            Config.ehSet('pin_fails', 0)
            Config.ehSet('pin_lock_mono', 0)
            app.ehChangePinDialog.createObject(app, { phase: 'new' }).open()
            root.doAccept()
        } else {
            hint = qsTr('These words are not the ones of this wallet. Check them one by one.')
            AppController.haptic()
        }
    }
    Bitcoin { id: bitcoin }

    Flickable {
        id: ehFlick
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight   // nothing under the Android keys
        contentHeight: ehCol.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
    ColumnLayout {
        id: ehCol
        x: 16
        width: ehFlick.width - 32
        height: Math.max(implicitHeight, ehFlick.height)
        spacing: 8

        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
        EhBackLink { onClicked: root.doReject() }
        EhTitle { text: qsTr('Forgot the PIN?') }
        Label {
            Layout.fillWidth: true
            text: qsTr('Write the <b>12 words</b> of this wallet, the ones on the paper. If they are right, you choose a new PIN.')
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            color: S.ink
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 17
            lineHeight: 1.15
        }

        // ---- the words, one by one with their number ----
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 56
            radius: 16
            color: S.paper
            border.width: 2
            border.color: root.hint !== '' ? S.wine : S.edge
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
            visible: root.hint !== ''
            kind: 'danger'
            text: '<b>' + root.hint + '</b>'
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
            Layout.bottomMargin: 14
            enabled: root.ready
            kind: 'wine'
            text: enabled ? qsTr('Next') : qsTr('Next (%1 of 12)').arg(Math.min(root.doneWords, 12))
            endIcon: 'next'
            onClicked: root.check()
        }
    }
    }
}
