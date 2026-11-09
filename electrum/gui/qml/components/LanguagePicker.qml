// Easy Heirs (schèi): first screen, choose the language (Italiano, Veneto, English).
// Shown only at first start. The choice is applied at once, so every
// following screen is already in the chosen language, without a restart.
// Style "Colline del vino": hills on top, logo, pill buttons.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

ElDialog {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    allowClose: false
    closePolicy: Popup.NoAutoClose
    needsSystemBarPadding: false

    readonly property color cBg: '#faf7ef'
    readonly property color cMuted: '#6b5d55'
    readonly property color cGold: '#c8961e'

    background: Rectangle { color: root.cBg }

    function choose(code) {
        Config.language = code
        root.doAccept()
    }

    EhHills {
        id: hills
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.round(root.height * 0.27)
    }

    ColumnLayout {
        anchors.top: hills.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: -6
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.bottomMargin: 26 + app.navigationBarHeight
        spacing: 14

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 190
            Layout.preferredHeight: 190 * 345 / 756
            source: Qt.resolvedUrl('../../icons/eh_logo_wine.png')
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: root.cMuted
            font.pixelSize: 20
            lineHeight: 1.3
            // each line in its own language, never translated
            text: 'Scegli la lingua\nSielzi la lengua\nChoose your language'
        }

        Item { Layout.fillHeight: true }

        Repeater {
            model: Config.languagesAvailable
            delegate: Item {
                id: entry
                required property var modelData
                readonly property bool isPhone: modelData.value === Config.phoneLanguage
                Layout.fillWidth: true
                Layout.preferredHeight: 92

                // gold ring around the phone language
                Rectangle {
                    visible: entry.isPhone
                    anchors.fill: parent
                    anchors.margins: -6
                    radius: height / 2
                    color: 'transparent'
                    border.width: 4
                    border.color: root.cGold
                }

                EhPillButton {
                    anchors.fill: parent
                    text: entry.modelData.text
                    fontSize: 28
                    onClicked: root.choose(entry.modelData.value)

                    // flag inside the round tile
                    Rectangle {
                        anchors.centerIn: parent
                        width: 42; height: 30
                        radius: 6
                        color: '#2a2220'
                        Item {
                            anchors.fill: parent
                            anchors.margins: 1.5
                            clip: true
                            Row {  // Italia
                                visible: entry.modelData.value === 'it_IT'
                                anchors.fill: parent
                                Rectangle { width: parent.width / 3; height: parent.height; color: '#009246' }
                                Rectangle { width: parent.width / 3; height: parent.height; color: '#ffffff' }
                                Rectangle { width: parent.width / 3; height: parent.height; color: '#ce2b37' }
                            }
                            Rectangle {  // Veneto
                                visible: entry.modelData.value === 'vec_IT'
                                anchors.fill: parent
                                color: '#8a1f2b'
                                Label {
                                    anchors.centerIn: parent
                                    text: '\u{1F981}'  // lion
                                    font.pixelSize: 18
                                }
                            }
                            Image {  // English
                                visible: entry.modelData.value === 'en_UK'
                                anchors.fill: parent
                                source: Qt.resolvedUrl('../../icons/flag_en.svg')
                                sourceSize.width: 84
                                sourceSize.height: 60
                            }
                        }
                    }
                }
            }
        }
    }
}
