// Easy Heirs (schèi): full-screen explanation page ("Maggiori informazioni").
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

ElDialog {
    id: dialog
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'

    property string pageTitle
    property string bodyText      // rich text, paragraphs separated by <br><br>
    property string tipText       // rich text, green box at the end
    property bool showBlocks: false

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    background: Rectangle { color: '#faf7ef' }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 30
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 36
            x: 18
            spacing: 12

            EhPageTop { title: '' }

            Label {
                text: '‹ ' + qsTr('Back')
                color: '#5e1a33'
                font.pixelSize: 17
                font.bold: true
                Layout.topMargin: -14
                TapHandler { margin: 10; onTapped: dialog.doClose() }
            }

            Label {
                Layout.fillWidth: true
                text: dialog.pageTitle
                wrapMode: Text.WordWrap
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 28
            }

            Label {
                Layout.fillWidth: true
                text: dialog.bodyText
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                font.pixelSize: 17
                lineHeight: 1.2
                color: '#2a2220'
            }

            Row {
                visible: dialog.showBlocks
                Layout.alignment: Qt.AlignHCenter
                spacing: 3
                Repeater {
                    // all 6 confirmations, smaller boxes
                    model: ['1', '›', '2', '›', '3', '›', '4', '›', '5', '›', '6']
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        width: modelData === '›' ? 9 : Math.min(38, (col.width - 5 * 15) / 6)
                        height: 32
                        radius: 8
                        color: modelData === '›' ? 'transparent' : (index === 0 ? '#45541f' : '#e2d7c1')
                        Label {
                            anchors.centerIn: parent
                            text: modelData
                            font.bold: true
                            font.pixelSize: 13
                            color: index === 0 ? '#ffffff' : '#6b5d55'
                        }
                    }
                }
            }

            Rectangle {
                visible: dialog.tipText !== ''
                Layout.fillWidth: true
                Layout.preferredHeight: tip.implicitHeight + 26
                radius: 16
                color: '#e9eed9'
                Label {
                    id: tip
                    anchors.fill: parent
                    anchors.margins: 13
                    text: dialog.tipText
                    textFormat: Text.StyledText
                    wrapMode: Text.WordWrap
                    font.pixelSize: 17
                    lineHeight: 1.2
                    color: '#2f3a12'
                }
            }
        }
    }
}
