// Easy Heirs (schȅi): full-screen explanation page ("Maggiori informazioni").
// "Bottega" (WP6): parchment page, back link, Fraunces title, green tip box.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

ElDialog {
    id: dialog
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'

    property string pageTitle
    property string bodyText      // rich text, paragraphs separated by <br><br>
    property string tipText       // rich text, green box at the end
    // owner 22/11 ("Se non aggiorni l'eredità"): optional titles of the boxes, a red box after the
    // green one and a closing line
    property string tipTitle: ''
    property string dangerTitle: ''
    property string dangerText: ''
    property string footText: ''
    property bool showBlocks: false
    // owner 13/11: an optional page to open at the bottom ("How the crucible works" ...)
    property string linkText: ''
    property url linkUrl

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    background: Rectangle { color: S.parch }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight   // nothing under the Android keys
        contentHeight: col.implicitHeight + 30
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 32
            x: 16
            spacing: 12

            EhPageTop { title: '' }

            EhBackLink { onClicked: dialog.doClose() }

            EhTitle { text: dialog.pageTitle }

            Label {
                Layout.fillWidth: true
                text: dialog.bodyText
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                lineHeight: 1.2
                color: S.ink
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
                        width: modelData === '›' ? 10 : Math.min(38, (col.width - 5 * 16) / 6)
                        height: 32
                        radius: 8
                        color: modelData === '›' ? 'transparent' : (index === 0 ? S.olive : S.sand)
                        Label {
                            anchors.centerIn: parent
                            text: modelData
                            font.family: BodyFont ? BodyFont : font.family
                            font.bold: true
                            font.pixelSize: app.ehFsText
                            color: index === 0 ? '#ffffff' : (modelData === '›' ? S.muted : S.ink)
                        }
                    }
                }
            }

            EhInfoBox {
                visible: dialog.tipText !== ''
                kind: 'tip'
                title: dialog.tipTitle
                text: dialog.tipText
                fontSize: app.ehFsText
            }

            EhInfoBox {
                visible: dialog.dangerText !== ''
                kind: 'danger'
                title: dialog.dangerTitle
                text: dialog.dangerText
                fontSize: app.ehFsText
            }

            Label {
                visible: dialog.footText !== ''
                Layout.fillWidth: true
                text: dialog.footText
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                lineHeight: 1.2
                color: S.ink
            }

            EhStitchButton {
                visible: dialog.linkText !== ''
                Layout.topMargin: 4
                kind: 'paper'
                icon: 'eh_goldcoin.svg'
                endIcon: 'next'
                text: dialog.linkText
                onClicked: app.ehOpenPage(dialog.linkUrl)
            }
        }
    }
}
