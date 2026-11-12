// Easy Heirs (schèi): "Benvenuto" screen, first step of the new wallet wizard.
// Two big choices only; wallet name, wallet type and seed type are set
// automatically (see QENewWalletWizard.eh_welcome_accept).
// Style "Colline del vino": hills on top, wine title, pill buttons.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "../controls"

WizardComponent {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'
    valid: false
    // the big buttons go forward by themselves: hide the wizard bars
    property bool hideWizardButtons: true

    property string choice: ''

    readonly property color cBg: '#faf7ef'
    readonly property color cWine: '#5e1a33'
    readonly property color cWineDark: '#3f0f21'
    readonly property color cGold: '#d9b25a'

    background: Rectangle { color: root.cBg }
    padding: 0
    leftPadding: 0
    rightPadding: 0

    function apply() {
        if (choice)
            wizard_data['keystore_type'] = choice
    }

    function go(keystoreType) {
        choice = keystoreType
        valid = true
        wizard.pages.next()
    }

    Item {
        anchors.fill: parent

        EhHills {
            id: hills
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.round(parent.height * 0.33)
        }

        // owner 12/11: the page scrolls when the phone is short (buttons never under the keys)
        Flickable {
            id: ehFlick
            anchors.top: hills.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 2
            anchors.bottomMargin: 26   // the wizard (ElDialog) already leaves room for the Android keys
            contentHeight: ehCol.height
            boundsBehavior: Flickable.StopAtBounds
            clip: true
        ColumnLayout {
            id: ehCol
            x: 22
            width: ehFlick.width - 44
            height: Math.max(implicitHeight, ehFlick.height)
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: qsTr('Welcome')
                color: root.cWineDark
                font.family: TitleFont ? TitleFont : font.family
                font.pixelSize: 40
                font.weight: Font.Black
                wrapMode: Text.WordWrap
            }

            Label {
                Layout.fillWidth: true
                text: qsTr('This is your Bitcoin wallet.')
                color: '#3e3430'
                font.pixelSize: 22
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            EhPillButton {
                text: qsTr('Create a new wallet')
                color: root.cWine
                textColor: '#ffffff'
                tileColor: root.cGold
                outlined: false
                onClicked: root.go('createseed')
                Image {
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl('../../../icons/eh_plus.svg')
                    sourceSize.width: 34
                    sourceSize.height: 34
                }
            }

            Item { Layout.preferredHeight: 6 }

            EhPillButton {
                visible: app.ehOption('watch') && Daemon.availableWallets.rowCount() > 0
                text: qsTr('Watch only')
                color: '#fffaf0'
                textColor: '#7a4a12'
                tileColor: '#fbf0d6'
                onClicked: root.go('masterkey')
                Image {
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl('../../../icons/eh_eye.svg')
                    sourceSize.width: 34
                    sourceSize.height: 34
                }
            }

            EhPillButton {
                text: qsTr('I already have the 12 words')
                color: '#ffffff'
                textColor: '#2a2220'
                tileColor: '#efe6d3'
                onClicked: root.go('haveseed')
                Image {
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl('../../../icons/eh_key.svg')
                    sourceSize.width: 34
                    sourceSize.height: 34
                }
            }
        }
        }
    }
}
