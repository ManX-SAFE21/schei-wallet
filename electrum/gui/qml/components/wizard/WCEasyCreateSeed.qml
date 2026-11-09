// Easy Heirs (schèi): "Le tue 12 parole" — shows the new seed, big and numbered.
// Replaces WCCreateSeed. No passphrase step (seed_extend = false).
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
    valid: words.length === 12
    property bool hideWizardButtons: true

    property var words: []

    background: Rectangle { color: '#faf7ef' }
    topPadding: 0
    leftPadding: 22
    rightPadding: 22
    bottomPadding: 22 + app.navigationBarHeight

    function apply() {
        wizard_data['seed'] = words.join(' ')
        wizard_data['seed_variant'] = 'electrum'  // generated seed always electrum variant
        wizard_data['seed_extend'] = false        // Easy Heirs: no extra custom words
    }

    component Hint: RowLayout {
        property alias iconSource: hintIcon.source
        property alias text: hintLabel.text
        property color color: '#2a2220'
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
            font.pixelSize: 16
            font.bold: parent.strong
            lineHeight: 1.15
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        EhPageTop {
            step: qsTr('STEP %1 OF %2').arg(1).arg(3)
            title: qsTr('Your 12 words')
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: hints.implicitHeight + 22
            radius: 16
            color: '#fbf0d6'
            ColumnLayout {
                id: hints
                anchors.fill: parent
                anchors.margins: 11
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
                    color: '#5e1a33'
                    strong: true
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 7
            columnSpacing: 8
            flow: GridLayout.TopToBottom
            rows: 6

            Repeater {
                model: root.words
                delegate: Rectangle {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 12
                    color: '#ffffff'
                    border.width: 1
                    border.color: '#ece4d2'
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8
                        Label {
                            Layout.preferredWidth: 22
                            horizontalAlignment: Text.AlignRight
                            text: (index + 1)
                            color: '#6b5d55'
                            font.pixelSize: 14
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData
                            color: '#2a2220'
                            font.family: FixedFont
                            font.bold: true
                            font.pixelSize: 21
                            elide: Text.ElideRight
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

        EhPillButton {
            enabled: root.valid
            opacity: enabled ? 1 : 0.4
            text: qsTr('I wrote them down')
            color: '#5e1a33'
            textColor: '#ffffff'
            tileColor: '#d9b25a'
            outlined: false
            onClicked: wizard.pages.next()
            Image {
                anchors.centerIn: parent
                source: Qt.resolvedUrl('../../../icons/eh_pen.svg')
                sourceSize.width: 32
                sourceSize.height: 32
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
