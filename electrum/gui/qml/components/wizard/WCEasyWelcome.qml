// Easy Heirs (schèi): "Benvenuto" screen, first step of the new wallet wizard.
// Two big choices only; wallet name, wallet type and seed type are set
// automatically (see QENewWalletWizard.eh_welcome_accept).
// Style "Bottega" (WP6): the home's B landscape on top (bell tower, cypresses, bitcoin sun with
// rays), parchment page, Fraunces title, stitched buttons (the new wallet in wine leather).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "../controls"
import "../controls/EhStyle.js" as S

WizardComponent {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'
    valid: false
    // the big buttons go forward by themselves: hide the wizard bars
    property bool hideWizardButtons: true

    property string choice: ''

    background: Rectangle { color: S.parch }
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

        // sky, then the B landscape at its own proportions at the bottom of it; the sun and its
        // rays stay in the sky, well under the status bar / test band
        Rectangle {
            id: hills
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.max(Math.round(parent.height * 0.33), app.statusBarHeight + land.height + 50)
            color: '#f8eed6'
            EhHills {
                id: land
                art: 'eh_hills_bottega.svg'
                band: true
                fade: false
                rays: true
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.round(width * 136 / 393)
                sunSize: 56
                sunTop: 8
                sunRight: 40
            }
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
                color: S.wine
                font.family: SerifFont ? SerifFont : font.family
                font.pixelSize: 34
                font.weight: Font.ExtraBold
                wrapMode: Text.WordWrap
            }
            EhRule {}

            Label {
                Layout.fillWidth: true
                Layout.topMargin: 4
                text: qsTr('This is your Bitcoin wallet.')
                color: S.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 22
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true; Layout.minimumHeight: 12 }

            EhStitchButton {
                kind: 'wine'
                text: qsTr('Create a new wallet')
                endIcon: 'next'
                onClicked: root.go('createseed')
                // a "+" in ivory (there is no ivory plus icon)
                Rectangle { anchors.centerIn: parent; width: 20; height: 3.5; radius: 2; color: S.ivory }
                Rectangle { anchors.centerIn: parent; width: 3.5; height: 20; radius: 2; color: S.ivory }
            }

            Item { Layout.preferredHeight: 4 }

            EhStitchButton {
                visible: app.ehOption('watch') && Daemon.availableWallets.rowCount() > 0
                kind: 'paper'
                text: qsTr('Watch only')
                icon: 'eh_eye.svg'
                onClicked: root.go('masterkey')
            }

            EhStitchButton {
                kind: 'paper'
                text: qsTr('I already have the 12 words')
                icon: 'eh_key_wine.svg'
                onClicked: root.go('haveseed')
            }
        }
        }
    }
}
