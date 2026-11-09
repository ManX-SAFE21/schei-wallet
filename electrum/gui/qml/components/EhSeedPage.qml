import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

// Easy Heirs (schèi): the 12 words again (after the PIN).
Item {
    id: page
    property bool ehHideHeader: true
    property var words: Daemon.currentWallet.seed ? Daemon.currentWallet.seed.split(' ') : []
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    Binding { target: AppController; property: 'secureWindow'; value: true; when: page.visible }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16; anchors.rightMargin: 16
        anchors.bottomMargin: 16 + app.navigationBarHeight
        spacing: 10
        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
        Label {
            Layout.topMargin: -14
            text: '‹ ' + qsTr('Advanced')   // it opens from the advanced settings
            color: '#5e1a33'; font.pixelSize: 17; font.bold: true
            TapHandler { margin: 10; onTapped: app.stack.pop() }
        }
        Label {
            text: qsTr('Your 12 words')
            color: '#3f0f21'; font.family: TitleFont ? TitleFont : font.family; font.weight: Font.Black; font.pixelSize: 28
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: w.implicitHeight + 18
            radius: 14; color: '#f7e3e8'
            Label {
                id: w
                anchors.fill: parent; anchors.margins: 9; anchors.leftMargin: 12
                wrapMode: Text.WordWrap; font.pixelSize: 15; font.bold: true; color: '#5e1a33'
                text: qsTr('Nobody will ever ask you for the 12 words. Whoever asks is a scammer.')
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2; rows: 6; flow: GridLayout.TopToBottom
            rowSpacing: 7; columnSpacing: 8
            Repeater {
                model: page.words
                delegate: Rectangle {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 44
                    radius: 12; color: '#ffffff'; border.width: 1; border.color: '#ece4d2'
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; spacing: 8
                        Label { Layout.preferredWidth: 22; horizontalAlignment: Text.AlignRight; text: index + 1; color: '#6b5d55'; font.pixelSize: 14 }
                        Label { Layout.fillWidth: true; text: modelData; font.family: FixedFont; font.bold: true; font.pixelSize: 21 }
                    }
                }
            }
        }
        // the kind of seed: Electrum (segwit) or BIP39 (point 21)
        EhSeedTypeBox {
            visible: page.words.length > 0
            review: true
            kind: Daemon.currentWallet ? Daemon.currentWallet.ehSeedType(Daemon.currentWallet.seed) : 'segwit'
        }
        Item { Layout.fillHeight: true }
    }
}
