// Easy Heirs (schèi): small yes / no question in our colours
// (e.g. "Vuoi chiudere Schèi Wallet?"). Two big buttons: Sì on the left (paper), No on the right
// (wine leather): the safe answer is in the easy place, "Sì" must be chosen on purpose (owner 2026-11-11).
// "Bottega" (WP6): paper sheet, Fraunces title with the gold rule, stitched buttons.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

Popup {
    id: root
    property string text
    property string detail: ''   // smaller explanation under the question
    property string yesText: qsTr('Yes')
    property string noText: qsTr('No')

    signal accepted
    signal rejected

    modal: true
    dim: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: Overlay.overlay
    width: Math.min(parent ? parent.width - 40 : 320, 360)
    padding: 20
    topPadding: 22
    bottomPadding: 22
    Material.theme: Material.Light

    // "Bottega": a paper sheet with a hard shadow on the dimmed page
    // (S.dim is a CSS 'rgba()' string, which a QML color does not read: same colour here)
    Overlay.modal: Rectangle { color: Qt.rgba(0.16, 0.13, 0.12, 0.5) }
    background: Item {
        Rectangle {
            y: 4
            width: parent.width
            height: parent.height
            radius: 22
            color: S.edgeShadow
        }
        Rectangle {
            anchors.fill: parent
            radius: 22
            color: S.paper
            border.width: 1.5
            border.color: S.edge
        }
    }

    property bool _answered: false
    function answer(yes) {
        _answered = true
        close()
        if (yes) accepted()
        else rejected()
    }

    contentItem: ColumnLayout {
        spacing: 18
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.text
                color: S.wine
                font.family: SerifFont ? SerifFont : font.family
                font.weight: Font.ExtraBold
                font.pixelSize: 26
                lineHeight: 1.05
            }
            EhRule {}
        }
        Label {
            visible: root.detail !== ''
            Layout.fillWidth: true
            Layout.topMargin: -4
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.detail
            color: S.ink
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 17
            lineHeight: 1.15
        }
        // Yes on the left (paper), No on the right (wine leather): the safe answer is in the easy
        // place. One button only (noText ''): the yes button, in wine leather.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            EhStitchButton {
                kind: root.noText === '' ? 'wine' : 'paper'
                text: root.yesText
                onClicked: root.answer(true)
            }
            EhStitchButton {
                visible: root.noText !== ''
                kind: 'wine'
                text: root.noText
                onClicked: root.answer(false)
            }
        }
    }
    // owner 12/11: the Android Back key answers "No" to the open question (main.qml onClosing),
    // so pressing Back again and again does not stack more questions
    onOpened: app._ehAsks.push(root)
    onClosed: {
        var i = app._ehAsks.indexOf(root)
        if (i >= 0) app._ehAsks.splice(i, 1)
        if (!_answered) { _answered = true; rejected() }
        destroy()
    }
}
