// Easy Heirs (schèi), "Bottega": THE button of the app (owner rule 2026-11-13): a rounded
// rectangle with dashed stitching inside, icon on the left, the text, an optional small icon on
// the right. Three kinds:
//   'wine'  wine leather, gold stitching, ivory text   (main action: send, confirm, next)
//   'olive' olive leather, gold stitching, ivory text  (main action on the receive side, save)
//   'paper' paper, wine stitching, wine text           (every other button)
// Height 60 (68 with a second line `sub`, 48 when compact: true, inside a field or a row).
// At most one leather button per page; never put it in a list delegate (one Canvas each).
//   EhStitchButton { kind: 'wine'; text: qsTr('Next'); endIcon: 'next'; onClicked: ... }
//   EhStitchButton { kind: 'paper'; text: qsTr('Copy'); icon: 'eh_copy.svg' }
//   EhStitchButton { kind: 'olive'; text: ...; sub: ...; icon: 'eh_blocks_white.svg'; endIcon: 'open' }
// icon: a file name in gui/icons (or a full URL): on leather use a light one (*_white / *_ivory),
// on paper a wine one. Children are put in the icon place (24x24) too.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

Item {
    id: root

    property string kind: 'wine'
    property string text
    property string sub: ''
    property string icon: ''
    property string endIcon: ''              // 'next' | 'open' | '' (or a file name)
    property bool compact: false
    property real iconSize: 24
    default property alias iconContent: userSlot.data
    readonly property bool leather: kind !== 'paper'
    readonly property bool pressed: tap.pressed
    readonly property color ink: leather ? S.ivory : S.wine

    signal clicked

    implicitHeight: compact ? S.buttonCompactH : (sub !== '' ? S.buttonTallH : S.buttonH)
    implicitWidth: content.implicitWidth + 32
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    opacity: enabled ? 1 : 0.4

    readonly property bool _hasIcon: icon !== '' || userSlot.children.length > 0
    readonly property string _endSrc: endIcon === 'next' ? (leather ? 'eh_arrow_ivory.svg' : 'eh_arrow_wine.svg')
                                    : endIcon === 'open' ? (leather ? 'eh_open_ivory.svg' : 'eh_open_wine.svg')
                                    : endIcon

    // leather: soft shadow (a few transparent layers); paper: hard 3 px shadow
    Repeater {
        model: root.leather ? 3 : 0
        Rectangle {
            required property int index
            anchors.fill: body
            anchors.margins: -index * 2
            anchors.topMargin: -index * 2 + 4 + index
            radius: body.radius + index * 2
            color: root.kind === 'olive' ? '#2f3a12' : S.wineDark
            opacity: 0.10 - index * 0.025
        }
    }
    Rectangle {
        visible: !root.leather
        x: body.x
        y: body.y + 3
        width: body.width
        height: body.height
        radius: body.radius
        color: S.edgeShadow
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: root.compact ? 16 : 20
        border.width: root.leather ? 0 : 1.5
        border.color: S.edge
        readonly property real k: root.pressed ? 1.2 : 1.0
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.kind === 'wine' ? Qt.darker(S.leatherWine1, body.k)
                                               : root.kind === 'olive' ? Qt.darker(S.leatherOlive1, body.k)
                                               : (root.pressed ? S.sand : S.paper) }
            GradientStop { position: 0.7; color: root.kind === 'wine' ? Qt.darker(S.leatherWine2, body.k)
                                               : root.kind === 'olive' ? Qt.darker('#44521f', body.k)
                                               : (root.pressed ? S.sand : S.paper) }
            GradientStop { position: 1.0; color: root.kind === 'wine' ? Qt.darker(S.leatherWine3, body.k)
                                               : root.kind === 'olive' ? Qt.darker(S.leatherOlive2, body.k)
                                               : (root.pressed ? S.sand : S.paper) }
        }
    }

    EhDashedBorder {
        anchors.fill: body
        inset: root.compact ? 4 : 5
        radius: body.radius - inset
        lineWidth: 1.6
        color: root.leather ? S.stitch : S.wine
    }

    RowLayout {
        id: content
        anchors.fill: body
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 10

        Item {
            id: iconSlot
            visible: root._hasIcon
            Layout.preferredWidth: root.iconSize
            Layout.preferredHeight: root.iconSize
            Layout.alignment: Qt.AlignVCenter
            Image {
                anchors.centerIn: parent
                visible: root.icon !== ''
                source: root.icon !== '' ? Qt.resolvedUrl(S.iconPath(root.icon)) : ''
                sourceSize.width: root.iconSize
                sourceSize.height: root.iconSize
            }
            Item { id: userSlot; anchors.fill: parent }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1
            Label {
                Layout.fillWidth: true
                text: root.text
                color: root.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 18
                font.bold: true
                lineHeight: 1.05
                horizontalAlignment: (!root._hasIcon && root._endSrc === '') ? Text.AlignHCenter : Text.AlignLeft
                wrapMode: Text.WordWrap
                maximumLineCount: (root.sub !== '' || root.compact) ? 1 : 2
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                visible: root.sub !== ''
                text: root.sub
                color: root.leather ? '#ffffff' : S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
                horizontalAlignment: (!root._hasIcon && root._endSrc === '') ? Text.AlignHCenter : Text.AlignLeft
                elide: Text.ElideRight
            }
        }
        Image {
            visible: root._endSrc !== ''
            Layout.alignment: Qt.AlignVCenter
            source: root._endSrc !== '' ? Qt.resolvedUrl(S.iconPath(root._endSrc)) : ''
            sourceSize.width: 22
            sourceSize.height: 22
        }
    }

    TapHandler {
        id: tap
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
