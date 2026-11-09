// Easy Heirs (schèi): "Maggiori informazioni" outlined pill button.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root
    signal clicked
    implicitHeight: 48
    Layout.preferredHeight: 48
    radius: 24
    color: tap.pressed ? '#f3ecdd' : '#ffffff'
    border.width: 2
    border.color: '#e2d7c1'
    RowLayout {
        anchors.centerIn: parent
        spacing: 8
        Image {
            source: Qt.resolvedUrl('../../../icons/eh_info.svg')
            sourceSize.width: 22
            sourceSize.height: 22
        }
        Label {
            text: qsTr('More information')
            color: '#5e1a33'
            font.pixelSize: 16
            font.bold: true
        }
    }
    TapHandler { id: tap; onTapped: root.clicked() }
}
