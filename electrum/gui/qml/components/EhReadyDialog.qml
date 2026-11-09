// Easy Heirs (schèi): "Il tuo portafoglio è pronto" — shown once, after a new
// wallet is created, with the "few schei, it is not a safe" notice.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

ElDialog {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    allowClose: false
    closePolicy: Popup.NoAutoClose

    background: Rectangle { color: '#faf7ef' }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.bottomMargin: 22 + app.navigationBarHeight
        spacing: 12

        EhPageTop {
            title: qsTr('Your wallet is ready')
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: okRow.implicitHeight + 24
            radius: 16
            color: '#e9eed9'
            RowLayout {
                id: okRow
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Image {
                    source: Qt.resolvedUrl('../../icons/eh_check.svg')
                    sourceSize.width: 32
                    sourceSize.height: 32
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: 19
                    color: '#2f3a12'
                    text: qsTr('Done! Now you can receive and send bitcoin.')
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: noteRow.implicitHeight + 28
            radius: 18
            color: '#fbf0d6'
            RowLayout {
                id: noteRow
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12
                Image {
                    Layout.alignment: Qt.AlignTop
                    source: Qt.resolvedUrl('../../icons/eh_wallet.svg')
                    sourceSize.width: 44
                    sourceSize.height: 44
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font.pixelSize: 18
                    lineHeight: 1.2
                    color: '#2a2220'
                    text: '<b>' + qsTr('Schèi is like the wallet in your pocket:') + '</b> '
                        + qsTr('keep only a few schei in it, the ones for spending. It is not a safe: for big savings use a safer system.')
                }
            }
        }

        Item { Layout.fillHeight: true }

        EhPillButton {
            text: qsTr('Open the wallet')
            color: '#5e1a33'
            textColor: '#ffffff'
            tileColor: '#d9b25a'
            outlined: false
            onClicked: root.doAccept()
            Image {
                anchors.centerIn: parent
                source: Qt.resolvedUrl('../../icons/eh_next.svg')
                sourceSize.width: 30
                sourceSize.height: 30
            }
        }
    }
}
