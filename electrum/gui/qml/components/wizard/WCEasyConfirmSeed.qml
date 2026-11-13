// Easy Heirs (schèi): "Controlliamo" — the 12 words are shown shuffled as big
// buttons; the user taps them in the order written on paper. Checks every word
// and the order, without any keyboard. Replaces WCConfirmSeed.
// "Bottega" (WP6): parchment page, messages in info boxes, paper word keys (mono), slots on
// paper with the number in brass, "Next" in wine leather.
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
    valid: done
    property bool hideWizardButtons: true

    property var seedWords: (wizard_data['seed'] || '').split(' ')
    property var shuffled: []        // [{word, used}]
    property int position: 0         // how many words placed so far
    property bool done: seedWords.length > 0 && position === seedWords.length
    property int wrongIndex: -1      // button just tapped wrongly
    property string wrongWord: ''

    background: Rectangle { color: S.parch }
    topPadding: 0
    leftPadding: 22
    rightPadding: 22
    bottomPadding: 22   // the wizard (ElDialog) already leaves room for the Android keys

    function shuffle() {
        var list = seedWords.map(function(w) { return { word: w, used: false } })
        for (var i = list.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1))
            var t = list[i]; list[i] = list[j]; list[j] = t
        }
        // avoid showing them already in the right order
        var same = list.every(function(e, k) { return e.word === seedWords[k] })
        if (same && list.length > 1) { var t2 = list[0]; list[0] = list[1]; list[1] = t2 }
        shuffled = list
        position = 0
        wrongIndex = -1
    }

    function tap(i) {
        if (done || shuffled[i].used)
            return
        if (shuffled[i].word === seedWords[position]) {
            var copy = shuffled.slice()
            copy[i] = { word: copy[i].word, used: true }
            shuffled = copy
            position = position + 1
            wrongIndex = -1
        } else {
            wrongIndex = i
            wrongWord = shuffled[i].word
            AppController.haptic()
            shake.restart()
        }
    }

    function goOn() {
        if (root.last)
            wizard.pages.finish()
        else
            wizard.pages.next()
    }

    // owner 12/11: the page scrolls when the phone is short (buttons never under the keys)
    Flickable {
        id: ehFlick
        anchors.fill: parent
        // over the side margins too, so the hills on top are not cut
        anchors.leftMargin: -22
        anchors.rightMargin: -22
        contentHeight: ehCol.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
    ColumnLayout {
        id: ehCol
        x: 22
        width: ehFlick.width - 44
        height: Math.max(implicitHeight, ehFlick.height)
        spacing: 8

        EhPageTop {
            step: qsTr('STEP %1 OF %2').arg(2).arg(3)
            title: qsTr("Let's check")
        }

        // message: instructions / wrong tap (rose box) / all correct (green box)
        Label {
            visible: !root.done && root.wrongIndex < 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 17
            lineHeight: 1.15
            color: S.ink
            text: qsTr('Look at your paper and tap the words in the right order: first number 1, then number 2…')
        }
        EhInfoBox {
            visible: root.done || root.wrongIndex >= 0
            kind: root.done ? 'tip' : 'danger'
            icon: root.done ? 'eh_check.svg' : 'eh_cross.svg'
            fontSize: 17
            text: root.done
                ? qsTr('Perfect! Your paper is correct: all 12 words, in the right order.')
                : qsTr('Number %1 is not "%2". Look carefully at your paper.').arg(root.position + 1).arg(root.wrongWord)
        }

        // the 12 numbered slots
        GridLayout {
            Layout.fillWidth: true
            // 3 per row (was 4): with 16 px text an 8-letter word still fits on a 360 px phone
            columns: 3
            rowSpacing: 4
            columnSpacing: 5
            Repeater {
                model: root.seedWords.length
                delegate: Rectangle {
                    required property int index
                    readonly property bool filled: index < root.position
                    readonly property bool current: index === root.position && !root.done
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 9
                    // placed = green, the next one = paper with the gold ring, later = sand
                    color: filled ? S.tipBg : (current ? S.paper : S.sand)
                    border.width: current ? 2.5 : (filled ? 1.5 : 0)
                    border.color: current ? S.gold : S.tipEdge
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 4
                        spacing: 4
                        Label {
                            text: index + 1
                            font.family: SerifFont ? SerifFont : font.family
                            font.weight: Font.ExtraBold
                            font.pixelSize: 16
                            color: S.brassRing
                        }
                        Label {
                            Layout.fillWidth: true
                            text: filled ? root.seedWords[index] : (current ? '?' : '')
                            font.family: FixedFont
                            font.bold: true
                            font.pixelSize: 16
                            color: filled ? S.oliveInk : S.ink
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // shuffled word buttons
        GridLayout {
            id: buttons
            visible: !root.done
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 6
            columnSpacing: 8
            Repeater {
                model: root.shuffled
                // a paper key (EhKey look) with the word in mono; wrong = rose with wine border
                delegate: Item {
                    id: wb
                    required property int index
                    required property var modelData
                    readonly property bool bad: index === root.wrongIndex
                    readonly property bool down: tapw.pressed
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    opacity: modelData.used ? 0.25 : 1
                    Rectangle {
                        visible: !wb.down
                        y: 3
                        width: parent.width
                        height: parent.height - 3
                        radius: 16
                        color: S.edgeShadow
                    }
                    Rectangle {
                        y: wb.down ? 2 : 0
                        width: parent.width
                        height: parent.height - 3
                        radius: 16
                        color: wb.bad ? S.dangerBg : (wb.down ? S.sand : S.paper)
                        border.width: wb.bad ? 2.5 : 1.5
                        border.color: wb.bad ? S.wine : S.edge
                        Label {
                            anchors.centerIn: parent
                            text: wb.modelData.word
                            font.family: FixedFont
                            font.bold: true
                            font.pixelSize: 19
                            color: S.wineDark
                        }
                    }
                    TapHandler {
                        id: tapw
                        enabled: !wb.modelData.used
                        onTapped: root.tap(wb.index)
                    }
                }
            }
            transform: Translate { id: shakeX; x: 0 }
        }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: shakeX; property: 'x'; to: -10; duration: 50 }
            NumberAnimation { target: shakeX; property: 'x'; to: 10; duration: 80 }
            NumberAnimation { target: shakeX; property: 'x'; to: -6; duration: 70 }
            NumberAnimation { target: shakeX; property: 'x'; to: 0; duration: 60 }
        }

        // a text link (17 bold wine, underlined), 48 px high to touch
        Label {
            visible: !root.done
            Layout.fillWidth: true
            Layout.minimumHeight: 48
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            color: S.wine
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 17
            font.bold: true
            text: qsTr("Can't find the word?") + ' <u>' + qsTr('Review the 12 words') + '</u>'
            opacity: revTap.pressed ? 0.6 : 1
            TapHandler { id: revTap; onTapped: wizard.pages.prev() }
        }

        EhStitchButton {
            visible: root.done
            kind: 'wine'
            text: qsTr('Next')
            endIcon: 'next'
            onClicked: root.goOn()
        }
    }
    }

    Component.onCompleted: shuffle()
}
