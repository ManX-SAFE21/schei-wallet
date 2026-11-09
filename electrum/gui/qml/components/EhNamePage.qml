import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

// Easy Heirs (schèi): name and colour of the wallet (shown on the balance card).
Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'
    readonly property var colors: ['#5e1a33', '#45541f', '#1f4f6e', '#7a4a12', '#3e3a6e', '#2d5c4f', '#6b3a2a']
    property string chosen: app.ehWalletColor()
    Rectangle { anchors.fill: parent; color: '#faf7ef' }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16; anchors.rightMargin: 16
        anchors.bottomMargin: 16 + app.navigationBarHeight
        spacing: 10
        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
        Label {
            Layout.topMargin: -14
            text: '‹ ' + qsTr('Settings')
            color: '#5e1a33'; font.pixelSize: 17; font.bold: true
            TapHandler { margin: 10; onTapped: app.stack.pop() }
        }
        Label {
            text: qsTr('Name and colour')
            color: '#3f0f21'; font.family: TitleFont ? TitleFont : font.family; font.weight: Font.Black; font.pixelSize: 28
        }
        Label { text: qsTr('Name'); font.pixelSize: 14; font.bold: true; color: '#6b5d55' }
        TextField {
            id: nameField
            Layout.fillWidth: true
            text: app.ehWalletName()
            font.pixelSize: 20
            font.bold: true
            maximumLength: 24
        }
        Label { text: qsTr('Colour'); font.pixelSize: 14; font.bold: true; color: '#6b5d55' }
        Flow {
            Layout.fillWidth: true
            spacing: 12
            Repeater {
                model: page.colors
                delegate: Rectangle {
                    required property string modelData
                    width: 40; height: 40; radius: 20
                    color: modelData
                    border.width: page.chosen === modelData ? 4 : 0
                    border.color: '#2a2220'
                    TapHandler { onTapped: page.chosen = modelData }
                }
            }
        }
        // preview
        EhBalanceCard {
            Layout.fillWidth: true
            Layout.topMargin: 8
            previewName: nameField.text
            previewColor: page.chosen
        }
        Item { Layout.fillHeight: true }
        EhPillButton {
            text: qsTr('Save')
            color: '#45541f'; textColor: '#ffffff'; tileColor: '#e6e9cf'; outlined: false
            onClicked: { app.ehSetWalletLook(nameField.text, page.chosen); app.stack.pop() }
            Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_check.svg'); sourceSize.width: 30; sourceSize.height: 30 }
        }
    }
}
