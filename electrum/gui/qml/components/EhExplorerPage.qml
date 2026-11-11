// Easy Heirs (schèi): "Dove vedere i movimenti" (T32, owner 2026-11-11).
// The site opened by "Vedi sulla blockchain": a tap chooses it, the pencil changes its
// name and address, "+ Aggiungi un sito" adds one. Electrum's own setting underneath
// (Config.ehExplorers / ehSelectExplorer / ehSaveExplorer / ehForgetExplorer).
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

    property int rev: 0
    readonly property var sites: { page.rev; Config.ehExplorer; return Config.ehExplorers() }
    readonly property string selId: { page.rev; return Config.ehExplorer.id }
    property string editId: '-'          // '-' = no editor open, '' = a new site
    readonly property var hints: ({
        'mempool.space': qsTr('clear, it also shows the queue of payments'),
        'Blockstream.info': qsTr('simple and fast'),
        'Blockchair.com': qsTr('many details'),
        'mempool.emzy.de': qsTr('like mempool.space, on another server')
    })
    function shownName(s) { return s.id === 'mine' && s.name === '' ? qsTr('My node') : s.name }
    function choose(s) {
        if (s.url === '') { page.editId = s.id; return }       // "Il mio nodo" without address: write it first
        Config.ehSelectExplorer(s.id)
        page.editId = '-'
        page.rev++
    }

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

    // the editor: name + address, save / cancel / original or delete
    component Editor: ColumnLayout {
        id: ed
        property var site: ({ 'id': '', 'name': '', 'url': '', 'builtin': false })
        spacing: 6
        Label { text: qsTr('NAME'); font.pixelSize: 11; font.bold: true; font.letterSpacing: 0.5; color: '#6b5d55' }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 12; color: '#ffffff'
            border.width: 2; border.color: nIn.activeFocus ? '#45541f' : '#e8dcc4'
            TextInput {
                id: nIn
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 16
                maximumLength: 30
                clip: true
                text: page.shownName(ed.site)
                Label { anchors.verticalCenter: parent.verticalCenter; visible: nIn.text === '' && !nIn.activeFocus
                        text: qsTr('for example: my Umbrel'); color: '#b3a894'; font.pixelSize: 15 }
            }
        }
        Label { text: qsTr('ADDRESS'); font.pixelSize: 11; font.bold: true; font.letterSpacing: 0.5; color: '#6b5d55' }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 12; color: '#ffffff'
            border.width: 2; border.color: uIn.activeFocus ? '#45541f' : '#e8dcc4'
            TextInput {
                id: uIn
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                font.family: FixedFont
                font.pixelSize: 14
                clip: true
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                text: ed.site.url
                Label { anchors.verticalCenter: parent.verticalCenter; visible: uIn.text === '' && !uIn.activeFocus
                        text: 'http://umbrel.local:3006'; color: '#b3a894'; font.family: FixedFont; font.pixelSize: 14 }
            }
        }
        Label {
            id: err
            visible: false
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 13; font.bold: true; color: '#b3261e'
            text: qsTr('It must start with http:// or https://')
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8
            // Electrum's site changed by hand: back to the original. Own site: delete.
            Rectangle {
                visible: ed.site.id !== '' && (ed.site.builtin ? (ed.site.edited === true) : true)
                Layout.preferredHeight: 42; Layout.preferredWidth: fgL.implicitWidth + 24; radius: 18
                color: '#ffffff'; border.width: 2; border.color: ed.site.builtin ? '#e3d9c6' : '#e6b9b3'
                Label { id: fgL; anchors.centerIn: parent; font.pixelSize: 14; font.bold: true
                        color: ed.site.builtin ? '#3f0f21' : '#c0392b'
                        text: ed.site.builtin ? qsTr('Original') : qsTr('Delete') }
                MouseArea { anchors.fill: parent; onClicked: { Config.ehForgetExplorer(ed.site.id); page.editId = '-'; page.rev++ } }
            }
            Rectangle {
                Layout.preferredHeight: 42; Layout.preferredWidth: caL.implicitWidth + 24; radius: 18
                color: '#ffffff'; border.width: 2; border.color: '#e3d9c6'
                Label { id: caL; anchors.centerIn: parent; text: qsTr('Cancel'); font.pixelSize: 14; font.bold: true; color: '#3f0f21' }
                MouseArea { anchors.fill: parent; onClicked: page.editId = '-' }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 18
                color: svMa.pressed ? '#36431a' : '#45541f'
                Label { anchors.centerIn: parent; text: qsTr('Save'); color: '#ffffff'; font.pixelSize: 15; font.bold: true }
                MouseArea {
                    id: svMa
                    anchors.fill: parent
                    onClicked: {
                        var nm = nIn.text.trim()
                        if (ed.site.id === 'mine' && nm === qsTr('My node')) nm = ''
                        var id = Config.ehSaveExplorer(ed.site.id, nm, uIn.text)
                        err.visible = id === ''
                        if (id === '') return
                        if (ed.site.id === '' || ed.site.id === 'mine' || page.selId === id) Config.ehSelectExplorer(id)
                        page.editId = '-'
                        page.rev++
                        toaster.show(page, qsTr('Saved'))
                    }
                }
            }
        }
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
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                color: '#6b5d55'
                text: qsTr('Tap a site to choose it. The pencil changes its name and address.')
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
                        ColumnLayout {
                            id: sr
                            required property var modelData
                            required property int index
                            readonly property bool on: page.selId === modelData.id
                            readonly property bool editing: page.editId === modelData.id
                            Layout.fillWidth: true
                            spacing: 0
                            Rectangle { visible: sr.index > 0; Layout.fillWidth: true; Layout.preferredHeight: 1; color: '#f1ebdf' }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(60, srRow.implicitHeight + 18)
                                color: sr.on ? '#f6f8ec' : (srMa.pressed ? '#f7f2e8' : 'transparent')
                                MouseArea { id: srMa; anchors.fill: parent; onClicked: page.choose(sr.modelData) }
                                RowLayout {
                                    id: srRow
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 6
                                    spacing: 12
                                    Radio { on: sr.on }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Label { Layout.maximumWidth: srRow.width - 150; elide: Text.ElideRight; text: page.shownName(sr.modelData); font.pixelSize: 16; font.bold: true }
                                            Rectangle {
                                                visible: sr.modelData.id === 'mempool.space' && !sr.modelData.edited
                                                Layout.preferredWidth: recL.implicitWidth + 12; Layout.preferredHeight: 18; radius: 8
                                                color: '#e6ecc8'
                                                Label { id: recL; anchors.centerIn: parent; text: qsTr('recommended'); font.pixelSize: 11; font.bold: true; color: '#2f3a12' }
                                            }
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            font.pixelSize: 13
                                            color: '#6b5d55'
                                            text: sr.modelData.id === 'mine' && sr.modelData.url === ''
                                                  ? qsTr('for example Umbrel: write the address of your mempool')
                                                  : (!sr.modelData.edited && page.hints[sr.modelData.id] !== undefined
                                                     ? page.hints[sr.modelData.id] : sr.modelData.url)
                                        }
                                    }
                                    // the pencil: change name and address
                                    Rectangle {
                                        Layout.preferredWidth: 44; Layout.preferredHeight: 44; radius: 22
                                        color: sr.editing ? '#f7e3e8' : (pMa.pressed ? '#f1ebdf' : 'transparent')
                                        Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg'); sourceSize.width: 20; sourceSize.height: 20 }
                                        MouseArea { id: pMa; anchors.fill: parent; onClicked: page.editId = sr.editing ? '-' : sr.modelData.id }
                                    }
                                }
                            }
                            Editor {
                                visible: sr.editing
                                Layout.fillWidth: true
                                Layout.leftMargin: 14
                                Layout.rightMargin: 14
                                Layout.bottomMargin: 14
                                site: sr.modelData
                            }
                        }
                    }
                    // add a site
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: '#f1ebdf' }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        color: addMa.pressed ? '#f1f3e2' : 'transparent'
                        Label { anchors.verticalCenter: parent.verticalCenter; x: 14; text: '+ ' + qsTr('Add a site'); font.pixelSize: 16; font.bold: true; color: '#45541f' }
                        MouseArea { id: addMa; anchors.fill: parent; onClicked: page.editId = page.editId === '' ? '-' : '' }
                    }
                    Editor {
                        visible: page.editId === ''
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.bottomMargin: 14
                        site: ({ 'id': '', 'name': '', 'url': '', 'builtin': false })
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
