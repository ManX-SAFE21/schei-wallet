// Easy Heirs (schèi): "Hai dimenticato il PIN?" (third review). The 12 words of THIS wallet
// prove who you are: if they match, a new PIN is chosen (EhChangePinDialog without the old PIN).
// Same words area and keyboard as the restore page (WCEasyHaveSeed.qml).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"

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
    background: Rectangle { color: '#faf7ef' }
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

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 14 + app.navigationBarHeight
        spacing: 8

        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
        Label {
            Layout.topMargin: -14
            text: '‹ ' + qsTr('Back')
            color: '#5e1a33'; font.pixelSize: 17; font.bold: true
            TapHandler { margin: 10; onTapped: root.doReject() }
        }
        Label {
            Layout.fillWidth: true
            text: qsTr('Forgot the PIN?')
            wrapMode: Text.WordWrap
            color: '#3f0f21'
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 26
        }
        Label {
            Layout.fillWidth: true
            text: qsTr('Write the <b>12 words</b> of this wallet, the ones on the paper. If they are right, you choose a new PIN.')
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            font.pixelSize: 15
        }

        // ---- the words, one by one with their number ----
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 56
            radius: 16
            color: '#ffffff'
            border.width: 2
            border.color: root.hint !== '' ? '#b0413e' : '#e2d7c1'
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
            visible: root.hint !== ''
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.hint
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
            enabled: root.ready
            opacity: enabled ? 1 : 0.45
            text: enabled ? qsTr('Next') : qsTr('Next (%1 of 12)').arg(Math.min(root.doneWords, 12))
            fontSize: 21
            color: '#5e1a33'
            textColor: '#ffffff'
            tileColor: '#d9b25a'
            outlined: false
            onClicked: root.check()
            Image {
                anchors.centerIn: parent
                source: Qt.resolvedUrl('../../icons/eh_next.svg')
                sourceSize.width: 30
                sourceSize.height: 30
            }
        }
    }
}
