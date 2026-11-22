// Easy Heirs (schȅi): the bubble of the inheritance dot on the home wallet (owner 22/11).
// Tap the dot: it says what the colour means and what to do; it stays open until a tap
// anywhere else (owner 22/11: 6 s were too short to read it and tap the link). Tap the logo instead: the inheritance opens (as before).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "controls"
import "controls/EhStyle.js" as S

Popup {
    id: root
    property string dot: ''              // ok | warn | bad
    property var st: ({})                // the inheritance state of the wallet open
    property Item anchorItem             // the logo + dot, the bubble points at it

    readonly property string phase: st.phase || ''
    readonly property string why: st.updateReason || ''
    readonly property string keepers: st.custodians ? (st.custodians.status || '') : ''
    readonly property bool canMore: phase === 'needs_update' && (why === 'received' || why === 'spent')

    parent: Overlay.overlay
    width: Math.min(parent ? parent.width - 32 : 300, 300)
    padding: 12
    modal: false
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
    onClosed: destroy()

    property real arrowX: width - 30
    property bool arrowDown: true        // the bubble above the logo (the wallet is low on the home)

    function title() {
        if (dot === 'ok') return qsTr('Inheritance in order')
        if (dot === 'bad') return qsTr('Inheritance not valid')
        return qsTr('Inheritance to look at')
    }
    function body() {
        if (dot === 'ok') return qsTr('It covers all your money. You have nothing to do.')
        if (phase === 'expired') return qsTr('It has expired. Tap the logo to make it again.')
        if (phase === 'needs_update' && why === 'spent')
            return qsTr('You made a payment: <b>the inheritance is no longer valid</b>. If you do not update, the heirs receive nothing.<br>Tap the logo and press <b>Update with the PIN</b>. It costs nothing.')
        if (keepers === 'none' || keepers === 'invalid') return qsTr('No keeper has the envelope. Tap the logo to fix it.')
        if (phase === 'needs_update' && why === 'received')
            return qsTr('New money arrived: the inheritance does not cover it yet.<br>Tap the logo and press <b>Update with the PIN</b>. It costs nothing.')
        if (phase === 'needs_update') return qsTr('It must be put in order: for example the heirs changed, or a keeper no longer has the envelope. Tap the logo to fix it.')
        if (phase === 'due') return qsTr('It is time to renew it. Tap the logo to renew it.')
        if (phase === 'unfinished') return qsTr('It is not finished. Tap the logo to finish it.')
        if (keepers === 'low') return qsTr('Few keepers have the envelope. Tap the logo to look at it.')
        return qsTr('Tap the logo to look at it.')
    }

    function place() {
        if (!anchorItem || !parent) return
        var p = anchorItem.mapToItem(parent, 0, 0)
        var cx = p.x + anchorItem.width / 2
        x = Math.max(16, Math.min(parent.width - width - 16, cx - width + 30))
        arrowX = Math.max(20, Math.min(width - 20, cx - x))
        var above = p.y - implicitHeight - 10
        arrowDown = above > 40
        y = arrowDown ? above : p.y + anchorItem.height + 10
    }
    onImplicitHeightChanged: place()
    Component.onCompleted: place()

    background: Item {
        Rectangle { anchors.fill: parent; radius: 14; color: S.paper; border.width: 1.5; border.color: S.edge }
        Rectangle {
            width: 16; height: 16; rotation: 45; color: S.paper
            border.width: 1.5; border.color: S.edge
            x: root.arrowX - 8
            y: root.arrowDown ? parent.height - 8 : -8
            z: -1
        }
        // hides the arrow's inner border lines
        Rectangle { x: root.arrowX - 10; width: 20; height: 3; color: S.paper; y: root.arrowDown ? parent.height - 3 : 0 }
    }
    contentItem: ColumnLayout {
        spacing: 4
        RowLayout {
            spacing: 8
            Rectangle {
                width: 14; height: 14; radius: 7
                color: root.dot === 'ok' ? '#a9c84f' : (root.dot === 'warn' ? '#f4c430' : '#e5533d')
            }
            Label {
                Layout.fillWidth: true
                text: root.title()
                color: root.dot === 'bad' ? S.wine : S.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsStrong
                font.bold: true
                wrapMode: Text.WordWrap
            }
        }
        Label {
            Layout.fillWidth: true
            text: root.body()
            textFormat: Text.StyledText
            color: S.ink
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: app.ehFsText
            wrapMode: Text.WordWrap
            lineHeight: 1.15
        }
        Label {
            visible: root.canMore
            Layout.topMargin: 2
            text: '<u>' + qsTr('More information') + '</u>'
            textFormat: Text.StyledText
            color: S.wine
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: app.ehFsText
            font.bold: true
            TapHandler { onTapped: { root.close(); app.ehShowHeirUpdateInfo() } }
        }
    }
}
