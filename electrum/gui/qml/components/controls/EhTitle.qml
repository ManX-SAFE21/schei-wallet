// Easy Heirs (schȅi), "Bottega": page title. Fraunces 30 wine, optional icon (32 px) on the
// left, the double gold rule under it. For the pages that draw their own title after
// EhPageTop { title: '' } (Settings, Movements, Receive, ...).
//   EhTitle { text: qsTr('Settings'); icon: 'eh_gear.svg' }
//   EhTitle { text: qsTr('Receive'); icon: 'eh_rx_olive.svg'; color: S.oliveInk }
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

ColumnLayout {
    id: root
    property string text
    property string icon: ''          // file name in gui/icons, or a full URL
    property color color: S.wine
    property real fontSize: 30

    Layout.fillWidth: true
    Layout.bottomMargin: 4
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Image {
            visible: root.icon !== ''
            Layout.alignment: Qt.AlignVCenter
            source: root.icon !== '' ? Qt.resolvedUrl(S.iconPath(root.icon)) : ''
            sourceSize.width: 32
            sourceSize.height: 32
        }
        Label {
            Layout.fillWidth: true
            text: root.text
            color: root.color
            font.family: SerifFont ? SerifFont : font.family
            font.weight: Font.ExtraBold
            font.pixelSize: root.fontSize
            lineHeight: 1.05
            wrapMode: Text.WordWrap
        }
    }
    EhRule {}
}
