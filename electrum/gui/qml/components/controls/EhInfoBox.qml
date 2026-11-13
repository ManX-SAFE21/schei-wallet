// Easy Heirs (schȅi), "Bottega": a box with something to read.
// kind 'warn'   (to know / to do): ivory, gold border, brass info icon
// kind 'danger' (cannot be undone, scam, not enough money): rose, wine border, wine triangle
// kind 'tip'    (green advice at the end of info pages): pale green, olive text
// text is StyledText (<b>, <br>); more children (lists, buttons) go under the text.
//   EhInfoBox { kind: 'danger'; text: qsTr('It cannot be undone.') }
//   EhInfoBox { kind: 'warn'; title: qsTr('Good to know'); text: ...; showIcon: false }
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

Rectangle {
    id: root
    property string kind: 'warn'
    property string title: ''
    property string text: ''
    property string icon: kind === 'danger' ? 'eh_warn.svg' : (kind === 'tip' ? 'eh_info_olive.svg' : 'eh_info_brass.svg')
    property bool showIcon: true
    property real fontSize: 16
    property int horizontalAlignment: Text.AlignLeft
    default property alias content: extra.data
    readonly property color ink: kind === 'danger' ? S.wineDark : (kind === 'tip' ? S.oliveInk : S.ink)

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + 24
    Layout.preferredHeight: implicitHeight
    radius: 16
    color: kind === 'danger' ? S.dangerBg : (kind === 'tip' ? S.tipBg : S.ivory)
    border.width: 2
    border.color: kind === 'danger' ? S.wine : (kind === 'tip' ? S.tipEdge : S.gold)

    RowLayout {
        id: row
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 10
        Image {
            visible: root.showIcon && root.icon !== ''
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 1
            source: root.icon !== '' ? Qt.resolvedUrl(S.iconPath(root.icon)) : ''
            sourceSize.width: 24
            sourceSize.height: 24
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Label {
                Layout.fillWidth: true
                visible: root.title !== ''
                text: root.title
                color: root.kind === 'tip' ? S.oliveInk : S.wine
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 17
                font.bold: true
                horizontalAlignment: root.horizontalAlignment
                wrapMode: Text.WordWrap
            }
            Label {
                Layout.fillWidth: true
                visible: root.text !== ''
                text: root.text
                textFormat: Text.StyledText
                color: root.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: root.fontSize
                lineHeight: 1.15
                horizontalAlignment: root.horizontalAlignment
                wrapMode: Text.WordWrap
            }
            ColumnLayout {
                id: extra
                Layout.fillWidth: true
                visible: children.length > 0
                spacing: 6
            }
        }
    }
}
