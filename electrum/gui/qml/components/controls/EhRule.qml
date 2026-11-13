// Easy Heirs (schèi), "Bottega": the double gold rule under titles (two 1 px lines, 1 px apart).
import QtQuick
import QtQuick.Layouts

import "EhStyle.js" as S

Item {
    property color color: S.gold
    Layout.fillWidth: true
    Layout.preferredHeight: 3
    implicitHeight: 3
    Rectangle { width: parent.width; height: 1; color: parent.color }
    Rectangle { y: 2; width: parent.width; height: 1; color: parent.color }
}
