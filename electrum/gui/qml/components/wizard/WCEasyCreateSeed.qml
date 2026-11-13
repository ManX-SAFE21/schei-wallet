// Easy Heirs (schèi): "Le tue 12 parole" — shows the new seed, big and numbered.
// Replaces WCCreateSeed. No passphrase step (seed_extend = false).
// "Bottega" (WP6): parchment page, the hints in the warning box, paper word tiles with the
// number in brass, "I wrote them down" in wine leather with the pen and the arrow.
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
    valid: words.length === 12
    property bool hideWizardButtons: true

    property var words: []

    background: Rectangle { color: S.parch }
    topPadding: 0
    leftPadding: 22
    rightPadding: 22
    bottomPadding: 22   // the wizard (ElDialog) already leaves room for the Android keys

    function apply() {
        wizard_data['seed'] = words.join(' ')
        wizard_data['seed_variant'] = 'electrum'  // generated seed always electrum variant
        wizard_data['seed_extend'] = false        // Easy Heirs: no extra custom words
    }

    component Hint: RowLayout {
        property alias iconSource: hintIcon.source
        property alias text: hintLabel.text
        property color color: S.ink
        property bool strong: false
        Layout.fillWidth: true
        spacing: 10
        Image {
            id: hintIcon
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2
            sourceSize.width: 22
            sourceSize.height: 22
        }
        Label {
            id: hintLabel
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            color: parent.color
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 16
            font.bold: parent.strong
            lineHeight: 1.15
        }
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
            step: qsTr('STEP %1 OF %2').arg(1).arg(3)
            title: qsTr('Your 12 words')
        }

        EhInfoBox {
            kind: 'warn'
            showIcon: false
            ColumnLayout {
                id: hints
                Layout.fillWidth: true
                spacing: 6
                Hint {
                    iconSource: Qt.resolvedUrl('../../../icons/eh_paper.svg')
                    text: '<b>' + qsTr('Write them on paper in block capitals') + '</b>' + qsTr(', letter by letter, in order.')
                }
                Hint {
                    iconSource: Qt.resolvedUrl('../../../icons/eh_phone.svg')
                    text: qsTr('You need them to get your money back if you lose your phone.')
                }
                Hint {
                    iconSource: Qt.resolvedUrl('../../../icons/eh_shield.svg')
                    text: qsTr('Nobody will ever ask you for the 12 words. Whoever asks is a scammer.')
                    color: S.wine
                    strong: true
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8
            flow: GridLayout.TopToBottom
            rows: 6

            Repeater {
                model: root.words
                delegate: Item {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    // paper tile with a hard 2 px shadow
                    Rectangle { y: 2; width: parent.width; height: 48; radius: 12; color: S.edgeShadow }
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 12
                        color: S.paper
                        border.width: 1.5
                        border.color: S.edge
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            Label {
                                Layout.preferredWidth: 24
                                horizontalAlignment: Text.AlignRight
                                text: (index + 1)
                                color: S.brassRing
                                font.family: SerifFont ? SerifFont : font.family
                                font.weight: Font.ExtraBold
                                font.pixelSize: 17
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData
                                color: S.ink
                                font.family: FixedFont
                                font.bold: true
                                font.pixelSize: 21
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // the kind of seed, to write under the words (point 21)
        EhSeedTypeBox {
            visible: root.words.length > 0
            kind: wizard_data['seed_type'] === 'standard' ? 'standard' : 'segwit'
        }

        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: root.words.length === 0
            running: visible
        }

        Item { Layout.fillHeight: true }

        EhStitchButton {
            enabled: root.valid
            kind: 'wine'
            text: qsTr('I wrote them down')
            icon: 'eh_pen_ivory.svg'
            endIcon: 'next'
            onClicked: wizard.pages.next()
        }
    }
    }

    Component.onCompleted: {
        if (wizard_data['seed']) {
            root.words = wizard_data['seed'].split(' ')
        } else {
            bitcoin.generateSeed(wizard_data['seed_type'])
        }
    }

    Bitcoin {
        id: bitcoin
        onGeneratedSeedChanged: root.words = generatedSeed.split(' ')
    }
}
