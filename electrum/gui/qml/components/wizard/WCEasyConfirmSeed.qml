// Easy Heirs (schèi): "Controlliamo" — the 12 words are shown shuffled as big
// buttons; the user taps them in the order written on paper. Checks every word
// and the order, without any keyboard. Replaces WCConfirmSeed.
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
    valid: done
    property bool hideWizardButtons: true

    property var seedWords: (wizard_data['seed'] || '').split(' ')
    property var shuffled: []        // [{word, used}]
    property int position: 0         // how many words placed so far
    property bool done: seedWords.length > 0 && position === seedWords.length
    property int wrongIndex: -1      // button just tapped wrongly
    property string wrongWord: ''

    background: Rectangle { color: '#faf7ef' }
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
        spacing: 10

        EhPageTop {
            step: qsTr('STEP %1 OF %2').arg(2).arg(3)
            title: qsTr("Let's check")
        }

        // message: instructions / wrong tap / all correct
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: msg.implicitHeight + 24
            radius: 16
            color: root.done ? '#e9eed9' : (root.wrongIndex >= 0 ? '#f7e3e8' : 'transparent')
            RowLayout {
                id: msg
                anchors.fill: parent
                anchors.margins: root.done || root.wrongIndex >= 0 ? 12 : 0
                spacing: 10
                Image {
                    visible: root.done || root.wrongIndex >= 0
                    source: Qt.resolvedUrl(root.done ? '../../../icons/eh_check.svg' : '../../../icons/eh_cross.svg')
                    sourceSize.width: 32
                    sourceSize.height: 32
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: 19
                    lineHeight: 1.2
                    color: root.done ? '#2f3a12' : (root.wrongIndex >= 0 ? '#3f0f21' : '#2a2220')
                    text: root.done
                        ? qsTr('Perfect! Your paper is correct: all 12 words, in the right order.')
                        : (root.wrongIndex >= 0
                            ? qsTr('Number %1 is not "%2". Look carefully at your paper.').arg(root.position + 1).arg(root.wrongWord)
                            : qsTr('Look at your paper and tap the words in the right order: first number 1, then number 2…'))
                }
            }
        }

        // the 12 numbered slots
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 5
            columnSpacing: 5
            Repeater {
                model: root.seedWords.length
                delegate: Rectangle {
                    required property int index
                    readonly property bool filled: index < root.position
                    readonly property bool current: index === root.position && !root.done
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8
                    color: filled ? '#e9eed9' : (current ? '#ffffff' : '#efe6d3')
                    border.width: current ? 2.5 : 0
                    border.color: '#c8961e'
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 5
                        anchors.rightMargin: 3
                        spacing: 3
                        Label {
                            text: index + 1
                            font.pixelSize: 11
                            color: '#6b5d55'
                        }
                        Label {
                            Layout.fillWidth: true
                            text: filled ? root.seedWords[index] : (current ? '?' : '')
                            font.family: FixedFont
                            font.bold: true
                            font.pixelSize: 13
                            color: '#2a2220'
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
            rowSpacing: 8
            columnSpacing: 8
            Repeater {
                model: root.shuffled
                delegate: Rectangle {
                    id: wb
                    required property int index
                    required property var modelData
                    readonly property bool bad: index === root.wrongIndex
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    radius: height / 2
                    opacity: modelData.used ? 0.25 : 1
                    color: bad ? '#f7e3e8' : (tapw.pressed ? '#f3ecdd' : '#ffffff')
                    border.width: bad ? 3 : 2
                    border.color: bad ? '#5e1a33' : '#e2d7c1'
                    Label {
                        anchors.centerIn: parent
                        text: wb.modelData.word
                        font.family: FixedFont
                        font.bold: true
                        font.pixelSize: 21
                        color: wb.bad ? '#3f0f21' : '#2a2220'
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

        Label {
            visible: !root.done
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.StyledText
            color: '#5e1a33'
            font.pixelSize: 16
            text: qsTr("Can't find the word?") + ' <u>' + qsTr('Review the 12 words') + '</u>'
            TapHandler { onTapped: wizard.pages.prev() }
        }

        EhPillButton {
            visible: root.done
            text: qsTr('Next')
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

    Component.onCompleted: shuffle()
}
