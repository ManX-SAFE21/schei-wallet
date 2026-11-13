import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

// Easy Heirs (schȅi): the 12 words again (after the PIN).
// "Bottega" (WP6): same word tiles as the new-wallet page (paper, number in brass), the scam
// warning in the rose box; the page scrolls.
Item {
    id: page
    property bool ehHideHeader: true
    property bool ehProtected: true   // closes after a minute in the background (main.qml)
    property var words: Daemon.currentWallet.seed ? Daemon.currentWallet.seed.split(' ') : []
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Rectangle { anchors.fill: parent; color: S.parch }
    Binding { target: AppController; property: 'secureWindow'; value: true; when: page.visible }

    Flickable {
        id: ehFlick
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight   // nothing under the Android keys
        contentHeight: ehCol.implicitHeight + 16
        boundsBehavior: Flickable.StopAtBounds
        clip: true
    ColumnLayout {
        id: ehCol
        x: 16
        width: ehFlick.width - 32
        spacing: 10
        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
        EhBackLink {
            text: '‹ ' + qsTr('Advanced')   // it opens from the advanced settings
            onClicked: app.stack.pop()
        }
        EhTitle { text: qsTr('Your 12 words') }
        EhInfoBox {
            kind: 'danger'
            text: '<b>' + qsTr('Nobody will ever ask you for the 12 words. Whoever asks is a scammer.') + '</b>'
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2; rows: 6; flow: GridLayout.TopToBottom
            rowSpacing: 8; columnSpacing: 8
            Repeater {
                model: page.words
                delegate: Item {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 50
                    // paper tile with a hard 2 px shadow
                    Rectangle { y: 2; width: parent.width; height: 48; radius: 12; color: S.edgeShadow }
                    Rectangle {
                        width: parent.width; height: 48
                        radius: 12; color: S.paper; border.width: 1.5; border.color: S.edge
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                            Label {
                                Layout.preferredWidth: 24; horizontalAlignment: Text.AlignRight
                                text: index + 1; color: S.brassRing
                                font.family: SerifFont ? SerifFont : font.family
                                font.weight: Font.ExtraBold; font.pixelSize: 17
                            }
                            Label {
                                Layout.fillWidth: true; text: modelData; color: S.ink
                                font.family: FixedFont; font.bold: true; font.pixelSize: 21
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
        // the kind of seed: Electrum (segwit) or BIP39 (point 21)
        EhSeedTypeBox {
            visible: page.words.length > 0
            review: true
            kind: Daemon.currentWallet ? Daemon.currentWallet.ehSeedType(Daemon.currentWallet.seed) : 'segwit'
        }
    }
    }
}
