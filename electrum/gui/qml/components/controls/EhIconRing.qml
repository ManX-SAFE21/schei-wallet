// Easy Heirs (schèi), "Bottega": icon in a ring (rows, movements, detail page).
// 40x40 transparent circle, 2.5 border (wine = money out / settings, olive = money in),
// icon 23 inside. big: true = the 60x60 ring of a detail page (border 3, paper fill, icon 36).
import QtQuick
import QtQuick.Layouts

import "EhStyle.js" as S

Rectangle {
    id: root
    property string icon: ''          // file name in gui/icons, or a full URL
    property color ringColor: S.wine
    property bool big: false
    property real iconSize: big ? 36 : 23

    implicitWidth: big ? 60 : 40
    implicitHeight: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    width: implicitWidth
    height: implicitHeight
    radius: width / 2
    color: big ? S.paper : 'transparent'
    border.width: big ? 3 : 2.5
    border.color: ringColor

    Image {
        anchors.centerIn: parent
        visible: root.icon !== ''
        source: root.icon !== '' ? Qt.resolvedUrl(S.iconPath(root.icon)) : ''
        sourceSize.width: root.iconSize
        sourceSize.height: root.iconSize
    }
}
