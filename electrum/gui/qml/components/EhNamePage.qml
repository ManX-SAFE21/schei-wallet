import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

// Easy Heirs (schȅi): name and colour of the wallet (shown on the balance card).
// Look: "Bottega"; the page scrolls (the keyboard opens here).
Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.wine          // the text cursor
    readonly property var colors: ['#5e1a33', '#45541f', '#1f4f6e', '#7a4a12', '#3e3a6e', '#2d5c4f', '#6b3a2a']
    property string chosen: app.ehWalletColor()
    Rectangle { anchors.fill: parent; color: S.parch }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.height + 16
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: col
            x: 16
            width: flick.width - 32
            height: Math.max(implicitHeight, flick.height - 16)
            spacing: 10
            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            EhBackLink { text: '‹ ' + qsTr('Settings'); onClicked: app.stack.pop() }
            EhTitle { text: qsTr('Name and colour') }

            EhCaption { text: qsTr('Name'); Layout.topMargin: 4; Layout.bottomMargin: -4 }
            // the field: paper, wine border while writing, pen on the left
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 63
                Rectangle {      // hard shadow
                    y: 3
                    width: nameBox.width
                    height: nameBox.height
                    radius: nameBox.radius
                    color: S.edgeShadow
                }
                Rectangle {
                    id: nameBox
                    width: parent.width
                    height: 60
                    radius: 16
                    color: S.paper
                    border.width: nameField.activeFocus ? 2.5 : 2
                    border.color: nameField.activeFocus ? S.wine : S.edge
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        Image { source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg'); sourceSize.width: 24; sourceSize.height: 24 }
                        TextField {
                            id: nameField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: app.ehWalletName()
                            topPadding: 0
                            bottomPadding: 0
                            leftPadding: 0
                            rightPadding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            background: null
                            color: S.ink
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 18
                            font.bold: true
                            maximumLength: 24
                        }
                    }
                }
            }

            EhCaption { text: qsTr('Colour'); Layout.topMargin: 6; Layout.bottomMargin: -4 }
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                spacing: 10
                Repeater {
                    model: page.colors
                    delegate: Item {
                        id: sw
                        required property string modelData
                        readonly property bool on: page.chosen === modelData
                        width: 58; height: 58
                        // chosen: gold ring with a brass outline
                        Rectangle {
                            visible: sw.on
                            anchors.fill: parent
                            radius: width / 2
                            color: 'transparent'
                            border.width: 1.5
                            border.color: S.brassRing
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1.5
                                radius: width / 2
                                color: 'transparent'
                                border.width: 3
                                border.color: S.gold
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 48; height: 48; radius: 24
                            color: sw.modelData
                        }
                        TapHandler { onTapped: page.chosen = sw.modelData }
                    }
                }
            }
            // preview
            EhBalanceCard {
                Layout.fillWidth: true
                Layout.topMargin: 8
                previewName: nameField.text
                previewColor: page.chosen
            }
            Item { Layout.fillHeight: true; Layout.minimumHeight: 6 }
            EhStitchButton {
                Layout.bottomMargin: 6
                kind: 'olive'
                icon: 'eh_check_white.svg'
                text: qsTr('Save')
                onClicked: { app.ehSetWalletLook(nameField.text, page.chosen); app.stack.pop() }
            }
        }
    }
}
