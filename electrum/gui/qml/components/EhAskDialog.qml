// Easy Heirs (schèi): small yes / no question in our colours
// (e.g. "Vuoi chiudere Schèi Wallet?"). Two big buttons: Sì on the left (beige), No on the right
// (wine): the safe answer is in the easy place, "Sì" must be chosen on purpose (owner 2026-11-11).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

Popup {
    id: root
    property string text
    property string detail: ''   // smaller explanation under the question

    signal accepted
    signal rejected

    modal: true
    dim: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: Overlay.overlay
    width: Math.min(parent ? parent.width - 48 : 320, 340)
    padding: 22
    topPadding: 24
    bottomPadding: 18
    Material.theme: Material.Light

    Overlay.modal: Rectangle { color: Qt.rgba(0.16, 0.13, 0.12, 0.45) }
    background: Rectangle { radius: 26; color: '#ffffff' }

    function answer(yes) {
        close()
        if (yes) accepted()
        else rejected()
    }

    contentItem: ColumnLayout {
        spacing: 20
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.text
            color: '#3f0f21'
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 23
        }
        Label {
            visible: root.detail !== ''
            Layout.fillWidth: true
            Layout.topMargin: -8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.detail
            color: '#4a4038'
            font.pixelSize: 16
            lineHeight: 1.15
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: [true, false]
                delegate: Rectangle {
                    id: b
                    required property bool modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 26
                    color: modelData ? (bt.pressed ? '#e2d7c1' : '#efe6d3') : (bt.pressed ? '#3f0f21' : '#5e1a33')
                    Label {
                        anchors.centerIn: parent
                        text: b.modelData ? qsTr('Yes') : qsTr('No')
                        color: b.modelData ? '#2a2220' : '#ffffff'
                        font.pixelSize: 19
                        font.bold: true
                    }
                    TapHandler { id: bt; onTapped: root.answer(b.modelData) }
                }
            }
        }
    }
    onClosed: destroy()
}
