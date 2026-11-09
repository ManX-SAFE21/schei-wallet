import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

// Easy Heirs (schèi): information: logo, version, "few schei" note,
// credit to Electrum (MIT licence, as the licence requires).
Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Rectangle { anchors.fill: parent; color: '#faf7ef' }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight  // T9
        contentHeight: col.implicitHeight + 30
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 32
            x: 16
            spacing: 10
            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            Label {
                Layout.topMargin: -14
                text: '‹ ' + qsTr('Settings')
                color: '#5e1a33'; font.pixelSize: 17; font.bold: true
                TapHandler { margin: 10; onTapped: app.stack.pop() }
            }
            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 170
                Layout.preferredHeight: 170 * 345 / 756
                source: Qt.resolvedUrl('../../icons/eh_logo_wine.png')
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: 'Bitcoin Wallet · ' + qsTr('version %1').arg('1.0') + ' (Electrum ' + BUILD.electrum_version + ')'
                font.pixelSize: 14; color: '#6b5d55'
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: note.implicitHeight + 24
                radius: 16; color: '#fbf0d6'
                RowLayout {
                    id: note
                    anchors.fill: parent; anchors.margins: 12; spacing: 10
                    Image { Layout.alignment: Qt.AlignTop; source: Qt.resolvedUrl('../../icons/eh_wallet.svg'); sourceSize.width: 38; sourceSize.height: 38 }
                    Label {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; textFormat: Text.StyledText; font.pixelSize: 16
                        text: '<b>' + qsTr('Schèi is like the wallet in your pocket:') + '</b> ' + qsTr('keep only a few schei in it, the ones for spending. It is not a safe: for big savings use a safer system.')
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: cr.implicitHeight + 24
                radius: 16; color: '#ffffff'
                ColumnLayout {
                    id: cr
                    anchors.fill: parent; anchors.margins: 12; spacing: 6
                    Label {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; textFormat: Text.StyledText; font.pixelSize: 15
                        text: '<b>' + qsTr('Based on Electrum') + '</b>, ' + qsTr('the open source Bitcoin wallet created by Thomas Voegtlin and the Electrum developers.')
                    }
                    Label {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 13; color: '#6b5d55'
                        text: qsTr('MIT licence') + ' · Copyright © 2011-2024 The Electrum developers, Thomas Voegtlin.'
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: fr.implicitHeight + 24
                radius: 16; color: '#ffffff'
                Label {
                    id: fr
                    anchors.fill: parent; anchors.margins: 12; wrapMode: Text.WordWrap; font.pixelSize: 15
                    text: qsTr('The code of Schèi is free and public on GitHub. Nobody, not even who made the app, can see your 12 words or touch your money.')
                }
            }
        }
    }
}
