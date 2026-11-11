// Easy Heirs (schèi): "Questo telefono non riconosce più la chiave" (second review W2).
// Shown instead of the PIN pad when the phone's safe cannot open the wallet any more
// (app moved to another phone, restored from a backup): the PIN is not the problem, the
// 12 words are the way back.
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

    property string name
    property string path
    signal restoreChosen
    signal retryChosen

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    allowClose: false
    closePolicy: Popup.NoAutoClose
    background: Rectangle { color: '#faf7ef' }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.implicitHeight + 30
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 36
            x: 18
            spacing: 14

            EhPageTop { title: '' }

            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -10
                source: Qt.resolvedUrl('../../icons/eh_key_wine.svg')
                sourceSize.width: 64
                sourceSize.height: 64
            }
            Label {
                Layout.fillWidth: true
                text: qsTr('This phone no longer recognises the key')
                wrapMode: Text.WordWrap
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 28
            }
            Label {
                Layout.fillWidth: true
                text: qsTr('It happens when the app is moved to another phone or copied back from a backup.')
                      + ' <b>' + qsTr('Your money is not lost') + '</b>: ' + qsTr('it is on the blockchain.')
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                font.pixelSize: 17
                lineHeight: 1.2
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: boxL.implicitHeight + 26
                radius: 16
                color: '#ffffff'
                border.width: 2
                border.color: '#e2d7c1'
                Label {
                    id: boxL
                    anchors.fill: parent
                    anchors.margins: 13
                    text: qsTr('To get it back you need <b>your 12 words</b>, the ones you wrote on the paper when you created the wallet.')
                    textFormat: Text.StyledText
                    wrapMode: Text.WordWrap
                    font.pixelSize: 16
                    lineHeight: 1.2
                }
            }
            Item { Layout.preferredHeight: 6 }
            EhPillButton {
                text: qsTr('Put back the 12 words')
                fontSize: 20
                color: '#5e1a33'
                textColor: '#ffffff'
                tileColor: '#d9b25a'
                outlined: false
                onClicked: { dialog.restoreChosen(); dialog.doAccept() }
                Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_paper.svg'); sourceSize.width: 28; sourceSize.height: 28 }
            }
            EhPillButton {
                text: qsTr('Try again')
                fontSize: 20
                color: '#ffffff'
                textColor: '#5e1a33'
                onClicked: { dialog.retryChosen(); dialog.doAccept() }
                Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_undo.svg'); sourceSize.width: 28; sourceSize.height: 28 }
            }
        }
    }
}
