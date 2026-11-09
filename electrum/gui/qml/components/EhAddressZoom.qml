// Easy Heirs (schèi): the address in big letters: first 4 (after bc1q) and
// last 4, spaced, to read them aloud and compare with the other person.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

ElDialog {
    id: dialog
    Material.theme: Material.Light
    Material.foreground: '#2a2220'

    property string address
    property bool mine: false     // true in Receive (my own address)

    readonly property var parts: app.ehAddressParts(address)

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    background: Rectangle { color: '#faf7ef' }

    function spaced(s) { return s.split('').join(' ') }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.bottomMargin: 18 + app.navigationBarHeight
        spacing: 12

        EhPageTop { title: '' }

        Label {
            Layout.topMargin: -10
            text: qsTr('Check the address')
            color: '#3f0f21'
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 28
        }

        Repeater {
            model: [
                { k: qsTr('Starts with (after %1)').arg(dialog.parts.prefix), v: dialog.parts.first, c: '#2a2220' },
                { k: qsTr('Ends with'), v: dialog.parts.last, c: '#3f0f21' }
            ]
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: col.implicitHeight + 20
                radius: 18
                color: '#ffffff'
                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.leftMargin: 14
                    spacing: 0
                    Label { text: modelData.k; font.pixelSize: 14; font.bold: true; color: '#6b5d55' }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: dialog.spaced(modelData.v)
                        font.family: FixedFont
                        font.bold: true
                        font.pixelSize: 46
                        color: modelData.c
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: full.implicitHeight + 20
            radius: 16
            color: '#ffffff'
            border.width: 2
            border.color: '#ece4d2'
            Label {
                id: full
                anchors.fill: parent
                anchors.margins: 10
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                text: app.ehAddressRich(dialog.address, '#3f0f21', '#f7e3e8')
                font.family: FixedFont
                font.bold: true
                font.pixelSize: 19
                lineHeight: 1.3
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: hintL.implicitHeight + 20
            radius: 14
            color: '#fbf0d6'
            Label {
                id: hintL
                anchors.fill: parent
                anchors.margins: 10
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                font.pixelSize: 16
                text: dialog.mine
                      ? qsTr('<b>Read them aloud</b> to the person sending you bitcoin, letter by letter.')
                      : qsTr('<b>Read them aloud</b> to the person receiving, letter by letter: they must be the same as theirs.')
            }
        }

        Item { Layout.fillHeight: true }

        EhPillButton {
            text: qsTr('Close')
            color: '#5e1a33'
            textColor: '#ffffff'
            tileColor: '#d9b25a'
            outlined: false
            onClicked: dialog.doClose()
            Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_check_wine.svg'); sourceSize.width: 30; sourceSize.height: 30 }
        }
    }
}
