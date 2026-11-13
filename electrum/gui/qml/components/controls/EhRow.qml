// Easy Heirs (schȅi), "Bottega": a row of a sheet (put it in an EhSheet).
// Icon ring on the left, text 17 bold, optional hint 16 muted and level tag; on the right:
// value + chevron, lock + chevron, a switch, or your own item (default property: children
// go on the right, before the chevron). Dotted line at the bottom unless last: true.
//   EhRow { icon: 'eh_globe.svg'; text: qsTr('Currency'); value: 'EUR'; onClicked: ... }
//   EhRow { icon: 'eh_anim.svg'; text: qsTr('Animations'); hint: ...; showSwitch: true
//           checked: app.ehOption('x'); onToggled: (on) => app.ehSetOption('x', on) }
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

Item {
    id: root
    property string icon: ''               // file name in gui/icons, or a full URL ('' = no ring)
    property color iconColor: S.wine       // ring colour: wine (out, settings) / olive (in)
    property string text
    property string hint: ''
    property string value: ''
    property bool lock: false              // asks the PIN: brass lock before the chevron
    property int tag: 0                    // 1 MEDIO, 2 ESPERTO: small tag under the text
    property bool chevron: !showSwitch     // the "›" on the right
    property bool last: false              // no dotted line under it
    property bool showSwitch: false
    property bool checked: false           // the switch (showSwitch: true)
    property bool switchEnabled: true
    property real minHeight: 64
    default property alias trailing: extra.data
    readonly property bool pressed: tap.pressed

    signal clicked
    signal toggled(bool on)

    Layout.fillWidth: true
    implicitHeight: Math.max(root.minHeight, line.implicitHeight + 16)
    Layout.preferredHeight: implicitHeight

    // pressed: sand at 40 %
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -6
        anchors.rightMargin: -6
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        radius: 10
        color: S.sand
        opacity: tap.pressed ? 0.4 : 0
    }

    RowLayout {
        id: line
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        EhIconRing {
            visible: root.icon !== ''
            icon: root.icon
            ringColor: root.iconColor
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: root.text
                color: S.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 17
                font.bold: true
                lineHeight: 1.1
                wrapMode: Text.WordWrap
            }
            EhLevelTag { level: root.tag }
            Label {
                Layout.fillWidth: true
                visible: root.hint !== ''
                text: root.hint
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
                lineHeight: 1.1
                wrapMode: Text.WordWrap
            }
        }
        Label {
            visible: root.value !== ''
            Layout.maximumWidth: root.width * 0.5
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            text: root.value
            color: S.muted
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 16
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Row {
            id: extra
            Layout.alignment: Qt.AlignVCenter
            visible: children.length > 0
            spacing: 8
        }
        Image {
            visible: root.lock
            source: Qt.resolvedUrl('../../../icons/eh_lock_brass.svg')
            sourceSize.width: 20
            sourceSize.height: 20
        }
        EhSwitch {
            visible: root.showSwitch
            Layout.rightMargin: -8          // its touch room, not its look
            checked: root.checked
            enabled: root.switchEnabled
            onToggled: root.toggled(checked)
        }
        Label {
            visible: root.chevron
            text: '›'
            color: S.wine
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 30
            font.bold: true
        }
    }

    EhDotLine {
        visible: !root.last
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: parent.width
    }

    TapHandler {
        id: tap
        enabled: !root.showSwitch
        onTapped: root.clicked()
    }
}
