// Easy Heirs (schèi): first screen, choose the language (Italiano, Veneto, English).
// Shown only at first start. The choice is applied at once, so every
// following screen is already in the chosen language, without a restart.
// Style "Bottega" (owner 13/11, preview pulsanti-grandi-rimasti.html): the B landscape on top as
// on the Welcome page, the logo, the three-language subtitle, three paper stitched buttons with
// the flag on the left; the phone's language has a gold outline. The flags are drawn (SVG): the
// Venetian lion emoji showed as an empty box on the phone.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

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

    background: Rectangle { color: S.parch }

    function choose(code) {
        Config.language = code
        root.doAccept()
    }

    function flagFor(code) {
        return code === 'it_IT' ? 'eh_flag_it.svg' : code === 'vec_IT' ? 'eh_flag_vec.svg' : 'flag_en.svg'
    }

    Item {
        anchors.fill: parent

        // sky, then the B landscape at its own proportions at the bottom of it (as WCEasyWelcome)
        Rectangle {
            id: hills
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.max(Math.round(parent.height * 0.27), app.statusBarHeight + land.height + 40)
            color: '#f8eed6'
            EhHills {
                id: land
                art: 'eh_hills_bottega.svg'
                band: true
                fade: false
                rays: true
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.round(width * 136 / 393)
                sunSize: 56
                sunTop: 8
                sunRight: 40
            }
        }

        // the page scrolls when the phone is short (buttons never under the keys)
        Flickable {
            id: flick
            anchors.top: hills.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottomMargin: 16 + app.navigationBarHeight
            contentHeight: col.height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: col
                x: 22
                width: flick.width - 44
                height: Math.max(implicitHeight, flick.height)
                spacing: 14

                Image {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    Layout.preferredWidth: 170
                    Layout.preferredHeight: 170 * 345 / 756
                    source: Qt.resolvedUrl('../../icons/eh_logo_wine.png')
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: S.muted
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 18
                    lineHeight: 1.3
                    // each line in its own language, never translated
                    text: 'Scegli la lingua\nSielzi la lengua\nChoose your language'
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: 12 }

                Repeater {
                    model: Config.languagesAvailable
                    delegate: Item {
                        id: entry
                        required property var modelData
                        readonly property bool isPhone: modelData.value === Config.phoneLanguage
                        Layout.fillWidth: true
                        Layout.preferredHeight: S.buttonH
                        Layout.topMargin: 4
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4

                        // gold outline round the phone's language
                        Rectangle {
                            visible: entry.isPhone
                            anchors.fill: parent
                            anchors.margins: -5
                            anchors.bottomMargin: -7    // round the paper shadow too
                            radius: 25
                            color: 'transparent'
                            border.width: 3
                            border.color: S.gold
                        }

                        EhStitchButton {
                            anchors.fill: parent
                            kind: 'paper'
                            text: entry.modelData.text
                            iconSize: 34
                            onClicked: root.choose(entry.modelData.value)

                            // the flag, drawn, with a thin frame
                            Rectangle {
                                anchors.centerIn: parent
                                width: 34; height: 24
                                radius: 3
                                color: '#2a2220'
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: Qt.resolvedUrl('../../icons/' + root.flagFor(entry.modelData.value))
                                    sourceSize.width: 96
                                    sourceSize.height: 64
                                    smooth: true
                                }
                            }
                        }
                    }
                }
                // room for the gold outline under the last button (the Flickable clips)
                Item { Layout.preferredHeight: 4 }
            }
        }
    }
}
