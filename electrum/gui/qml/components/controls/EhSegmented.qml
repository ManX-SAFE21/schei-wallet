// Easy Heirs (schèi), "Bottega": a choice of 2-4 side by side.
// look 'filter' (Movements Tutti/Ricevuti/Inviati, euro/BTC, Coins/Addresses, export period):
//   sand track 56 high, items 17 bold ink; the chosen one is a paper tab with wine text.
// look 'level' (Settings BASE/MEDIO/ESPERTO, the two seed choices): paper tiles >= 64 high with
//   label 17 bold + sub-label 16; the chosen one is wine leather with stitching.
// model: a list of strings, or of objects { text, sub, lock } (lock: a small lock after sub).
//   EhSegmented { model: [qsTr('All'), qsTr('Received'), qsTr('Sent')]; currentIndex: f; onActivated: (i) => f = i }
// A tap does NOT change currentIndex by itself (the page may refuse, e.g. ESPERTO asks the PIN):
// set it in onActivated, or bind it to the page state.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

Item {
    id: root
    property var model: []
    property int currentIndex: 0
    property string look: 'filter'
    signal activated(int index)

    readonly property bool level: look === 'level'
    Layout.fillWidth: true
    implicitHeight: level ? Math.max(64, items.implicitHeight) : 56
    Layout.preferredHeight: implicitHeight

    function _txt(m) { return (typeof m === 'string') ? m : (m.text || '') }
    function _sub(m) { return (typeof m === 'string') ? '' : (m.sub || '') }
    function _lock(m) { return (typeof m === 'string') ? false : !!m.lock }

    // filter look: the sand track
    Rectangle {
        visible: !root.level
        anchors.fill: parent
        radius: 18
        color: S.sand
        Rectangle {   // a little depth at the top edge
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 1
            height: 6
            radius: 17
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.08) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
            }
        }
    }

    RowLayout {
        id: items
        anchors.fill: parent
        anchors.margins: root.level ? 0 : 4
        spacing: root.level ? 6 : 4

        Repeater {
            model: root.model
            delegate: Item {
                id: it
                required property var modelData
                required property int index
                readonly property bool on: index === root.currentIndex
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1          // equal widths
                implicitHeight: root.level ? Math.max(64, lv.implicitHeight + 18) : 48

                // ---- filter look ----
                Rectangle {
                    visible: !root.level && it.on
                    x: 0; y: 2
                    width: parent.width; height: parent.height
                    radius: 14
                    color: S.edgeShadow
                }
                Rectangle {
                    visible: !root.level
                    anchors.fill: parent
                    radius: 14
                    color: it.on ? S.paper : (tap.pressed ? Qt.rgba(1, 1, 1, 0.35) : 'transparent')
                    border.width: it.on ? 1.5 : 0
                    border.color: S.edge
                }
                Label {
                    visible: !root.level
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root._txt(it.modelData)
                    color: it.on ? S.wine : S.ink
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 17
                    font.bold: true
                    elide: Text.ElideRight
                }

                // ---- level look ----
                Rectangle {
                    visible: root.level
                    anchors.fill: parent
                    radius: 14
                    border.width: it.on ? 0 : 2
                    border.color: S.edge
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: it.on ? S.leatherWine1 : (tap.pressed ? S.sand : S.paper) }
                        GradientStop { position: 0.7; color: it.on ? S.leatherWine2 : (tap.pressed ? S.sand : S.paper) }
                        GradientStop { position: 1.0; color: it.on ? S.leatherWine3 : (tap.pressed ? S.sand : S.paper) }
                    }
                }
                Loader {
                    // the stitching only on the chosen tile (one Canvas, not three)
                    active: root.level && it.on
                    anchors.fill: parent
                    sourceComponent: EhDashedBorder { inset: 3; radius: 11; lineWidth: 1.6; color: S.stitch }
                }
                ColumnLayout {
                    id: lv
                    visible: root.level
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 0
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root._txt(it.modelData)
                        color: it.on ? S.ivory : S.wineDark
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: 17
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        visible: root._sub(it.modelData) !== '' || root._lock(it.modelData)
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: lv.width
                        spacing: 3
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ''
                            horizontalAlignment: Text.AlignHCenter
                            text: root._sub(it.modelData)
                            color: it.on ? '#ffffff' : S.muted
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 16
                            elide: Text.ElideRight
                        }
                        Image {
                            visible: root._lock(it.modelData)
                            source: Qt.resolvedUrl(it.on ? '../../../icons/eh_lock_white.svg' : '../../../icons/eh_lock_brass.svg')
                            sourceSize.width: 15
                            sourceSize.height: 15
                        }
                    }
                }

                TapHandler {
                    id: tap
                    onTapped: root.activated(it.index)
                }
            }
        }
    }
}
