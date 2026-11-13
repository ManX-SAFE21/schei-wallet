// Easy Heirs (schȅi): "Questo telefono non riconosce più la chiave" (second review W2).
// Shown instead of the PIN pad when the phone's safe cannot open the wallet any more
// (app moved to another phone, restored from a backup): the PIN is not the problem, the
// 12 words are the way back.
// "Bottega" (WP6): parchment page, Fraunces title, "your money is not lost" in the green box,
// the 12 words in the warning box, stitched buttons.
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
    background: Rectangle { color: S.parch }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.implicitHeight + 30
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 32
            x: 16
            spacing: 14

            EhPageTop { title: '' }

            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -10
                source: Qt.resolvedUrl('../../icons/eh_key_wine.svg')
                sourceSize.width: 64
                sourceSize.height: 64
            }
            EhTitle {
                text: qsTr('This phone no longer recognises the key')
            }
            Label {
                Layout.fillWidth: true
                text: qsTr('It happens when the app is moved to another phone or copied back from a backup.')
                wrapMode: Text.WordWrap
                color: S.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 17
                lineHeight: 1.2
            }
            EhInfoBox {
                kind: 'tip'
                text: '<b>' + qsTr('Your money is not lost') + '</b>: ' + qsTr('it is on the blockchain.')
                fontSize: 17
            }
            EhInfoBox {
                kind: 'warn'
                text: qsTr('To get it back you need <b>your 12 words</b>, the ones you wrote on the paper when you created the wallet.')
                fontSize: 17
            }
            Item { Layout.preferredHeight: 4 }
            EhStitchButton {
                kind: 'wine'
                text: qsTr('Put back the 12 words')
                icon: 'eh_pen_ivory.svg'
                endIcon: 'next'
                onClicked: { dialog.restoreChosen(); dialog.doAccept() }
            }
            EhStitchButton {
                kind: 'paper'
                text: qsTr('Try again')
                icon: 'eh_undo.svg'
                onClicked: { dialog.retryChosen(); dialog.doAccept() }
            }
        }
    }
}
