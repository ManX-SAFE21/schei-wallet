// Easy Heirs (schèi): "Dove vedere i movimenti" (T32, owner 2026-11-11).
// The site opened by "Vedi sulla blockchain". Electrum's own setting
// (BLOCK_EXPLORER, or BLOCK_EXPLORER_CUSTOM for one's own node); default mempool.space.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"

Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: '#2a2220'

    readonly property var sites: Config.ehExplorers()
    readonly property var cur: Config.ehExplorer
    property bool mineOpen: cur.custom !== ''
    readonly property var hints: ({
        'mempool.space': qsTr('clear, it also shows the queue of payments'),
        'Blockstream.info': qsTr('simple and fast'),
        'Blockchair.com': qsTr('many details'),
        'mempool.emzy.de': qsTr('like mempool.space, on another server')
    })

    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    EhGlow { tone: 'gold'; x: -page.width * 0.3; y: 40; width: page.width * 1.6; height: 380 }

    component Radio: Rectangle {
        property bool on: false
        width: 24; height: 24; radius: 12
        color: 'transparent'
        border.width: 2.5
        border.color: on ? '#45541f' : '#b9ad95'
        Rectangle { visible: parent.on; anchors.centerIn: parent; width: 12; height: 12; radius: 6; color: '#45541f' }
    }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.implicitHeight + 24
        clip: true
        ColumnLayout {
            id: col
            x: 16
            width: parent.width - 32
            spacing: 10

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            Label {
                Layout.topMargin: -14
                text: '‹ ' + qsTr('Advanced')
                color: '#5e1a33'; font.pixelSize: 17; font.bold: true
                TapHandler { margin: 10; onTapped: app.stack.pop() }
            }
            Label {
                Layout.fillWidth: true
                text: qsTr('Where to see the movements')
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 28
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: lCol.implicitHeight
                radius: 18
                color: '#ffffff'
                border.width: 1.5
                border.color: '#ece4d6'
                clip: true
                ColumnLayout {
                    id: lCol
                    width: parent.width
                    spacing: 0
                    Repeater {
                        model: page.sites
                        Rectangle {
                            id: sr
                            required property var modelData
                            required property int index
                            readonly property bool on: page.cur.custom === '' && page.cur.name === modelData.name && !page.mineOpen
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(58, srRow.implicitHeight + 18)
                            color: sr.on ? '#f6f8ec' : (srMa.pressed ? '#f7f2e8' : 'transparent')
                            Rectangle { visible: sr.index > 0; width: parent.width; height: 1; color: '#f1ebdf' }
                            RowLayout {
                                id: srRow
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 12
                                spacing: 12
                                Radio { on: sr.on }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    RowLayout {
                                        spacing: 6
                                        Label { text: sr.modelData.name; font.pixelSize: 16; font.bold: true }
                                        Rectangle {
                                            visible: sr.modelData.name === 'mempool.space'
                                            Layout.preferredWidth: recL.implicitWidth + 12; Layout.preferredHeight: 18; radius: 8
                                            color: '#e6ecc8'
                                            Label { id: recL; anchors.centerIn: parent; text: qsTr('recommended'); font.pixelSize: 11; font.bold: true; color: '#2f3a12' }
                                        }
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: 13
                                        color: '#6b5d55'
                                        text: page.hints[sr.modelData.name] !== undefined ? page.hints[sr.modelData.name] : sr.modelData.url
                                    }
                                }
                            }
                            MouseArea { id: srMa; anchors.fill: parent; onClicked: { page.mineOpen = false; Config.ehSetExplorer(sr.modelData.name) } }
                        }
                    }
                    // "Il mio nodo": the address of one's own mempool
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: mCol.implicitHeight + 22
                        color: (page.mineOpen || page.cur.custom !== '') ? '#f6f8ec' : 'transparent'
                        Rectangle { width: parent.width; height: 1; color: '#f1ebdf' }
                        RowLayout {
                            x: 14; y: 11
                            width: parent.width - 26
                            spacing: 12
                            Radio { Layout.alignment: Qt.AlignTop; Layout.topMargin: 2; on: page.mineOpen || page.cur.custom !== '' }
                            ColumnLayout {
                                id: mCol
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: qsTr('My node'); font.pixelSize: 16; font.bold: true }
                                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 13; color: '#6b5d55'
                                        text: qsTr('for example Umbrel: write the address of your mempool') }
                                Rectangle {
                                    visible: page.mineOpen || page.cur.custom !== ''
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    radius: 12
                                    color: '#ffffff'
                                    border.width: 2
                                    border.color: urlIn.activeFocus ? '#45541f' : '#e8dcc4'
                                    TextInput {
                                        id: urlIn
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: FixedFont
                                        font.pixelSize: 15
                                        clip: true
                                        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                                        text: page.cur.custom
                                        Label {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: urlIn.text === '' && !urlIn.activeFocus
                                            text: 'http://umbrel.local:3006'
                                            color: '#b3a894'
                                            font.family: FixedFont
                                            font.pixelSize: 15
                                        }
                                    }
                                }
                                Label {
                                    id: urlErr
                                    visible: false
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: '#b3261e'
                                    text: qsTr('It must start with http:// or https://')
                                }
                                Rectangle {
                                    visible: page.mineOpen || page.cur.custom !== ''
                                    Layout.preferredWidth: useL.implicitWidth + 36
                                    Layout.preferredHeight: 42
                                    radius: 21
                                    color: useMa.pressed ? '#36431a' : '#45541f'
                                    Label { id: useL; anchors.centerIn: parent; text: qsTr('Use this address'); color: '#ffffff'; font.pixelSize: 15; font.bold: true }
                                    MouseArea {
                                        id: useMa
                                        anchors.fill: parent
                                        onClicked: {
                                            urlErr.visible = !Config.ehSetExplorerCustom(urlIn.text)
                                            if (!urlErr.visible) { urlIn.focus = false; toaster.show(parent, qsTr('Saved')) }
                                        }
                                    }
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            onClicked: { page.mineOpen = true; urlIn.forceActiveFocus() }
                        }
                    }
                }
            }

            // privacy (text approved by the owner, 2026-11-11)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: pvCol.implicitHeight + 22
                radius: 14
                color: '#fbf0d6'
                ColumnLayout {
                    id: pvCol
                    x: 12; y: 11
                    width: parent.width - 24
                    spacing: 6
                    Label {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; textFormat: Text.StyledText; font.pixelSize: 14
                        text: '<b>' + qsTr('Privacy.') + '</b> ' + qsTr('The site you open sees which movement you are looking at and where you connect from.')
                    }
                    Label {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; textFormat: Text.StyledText; font.pixelSize: 14
                        text: '• ' + qsTr('With <b>your node</b> nobody knows it: everything stays at your home.')
                    }
                    Label {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; textFormat: Text.StyledText; font.pixelSize: 14
                        text: '• ' + qsTr('With a public site you can protect yourself with a <b>VPN</b> or with <b>Tor</b> (Orbot or Tor Browser app): the site sees the movement, but does not know who you are.')
                    }
                }
            }
        }
    }

    Toaster { id: toaster }
}
