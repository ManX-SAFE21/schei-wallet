// Easy Heirs (schèi): "Gestione privacy avanzata" (T20, owner 2026-11-09).
// For advanced users only, off by default: with the switch off the app shows
// no pockets, no origin colours and no privacy warnings.
// Step 1: the page and its switch. Next steps add the pockets with the
// "sacchetti" (step 2), the origin categories (step 3) and the warnings (step 4).
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
    Material.accent: '#45541f'

    readonly property bool on: app.ehOption('privacy')
    // the category being written: null = none, id '' = a new one
    property var edit: null
    function startEdit(c) { page.edit = c ? { 'id': c.id, 'name': c.name, 'color': c.color } : { 'id': '', 'name': '', 'color': app.ehCatColors[app.ehCats().length % app.ehCatColors.length] } }
    function saveEdit(name) {
        name = name.trim()
        if (name === '') return
        var l = app.ehCats(), e = page.edit, found = false
        for (var i = 0; i < l.length; i++) if (l[i].id === e.id) { l[i].name = name; l[i].color = e.color; found = true }
        if (!found) l.push({ 'id': 'c' + Date.now(), 'name': name, 'color': e.color })
        app.ehSetCats(l)
        page.edit = null
    }
    function deleteEdit() {
        var id = page.edit.id
        app.ehSetCats(app.ehCats().filter(function (c) { return c.id !== id }))
        if (Daemon.currentWallet) Daemon.currentWallet.ehForgetOrigin(id)
        page.edit = null
    }

    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    EhGlow { tone: 'gold'; x: -page.width * 0.3; y: 40; width: page.width * 1.6; height: 380 }

    component Card: Rectangle {
        Layout.fillWidth: true
        radius: 18
        color: Qt.rgba(1, 1, 1, 0.8)
        border.width: 1.5
        border.color: '#ece4d6'
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
                text: '‹ ' + qsTr('Advanced settings')
                color: '#5e1a33'; font.pixelSize: 17; font.bold: true
                TapHandler { margin: 10; onTapped: app.stack.pop() }
            }
            Label {
                Layout.fillWidth: true
                text: qsTr('Advanced privacy')
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 28
                wrapMode: Text.WordWrap
            }

            // the switch that turns everything on
            Card {
                Layout.preferredHeight: swRow.implicitHeight + 24
                RowLayout {
                    id: swRow
                    x: 12; y: 12
                    width: parent.width - 20
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label { Layout.fillWidth: true; text: qsTr('Use the privacy management'); font.pixelSize: 17; font.bold: true; wrapMode: Text.WordWrap }
                        Label { Layout.fillWidth: true; text: qsTr('pockets, origin of the coins and warnings'); font.pixelSize: 13; color: '#6b5d55'; wrapMode: Text.WordWrap }
                    }
                    Switch {
                        checked: page.on
                        onToggled: app.ehSetOption('privacy', checked)
                    }
                }
            }

            // off: what it is for
            Rectangle {
                visible: !page.on
                Layout.fillWidth: true
                Layout.preferredHeight: offL.implicitHeight + 24
                radius: 14
                color: '#fbf0d6'
                Label {
                    id: offL
                    x: 12; y: 12
                    width: parent.width - 24
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font.pixelSize: 15
                    lineHeight: 1.15
                    text: qsTr('It is for those who want to choose <b>which coins to keep apart</b>, so that different payments are not linked to each other.')
                          + '<br><br>' + qsTr('With the switch off nothing changes: the app chooses the coins by itself, as always.')
                }
            }

            // on: the pockets
            Card {
                visible: page.on
                Layout.preferredHeight: 62
                color: pkMa.pressed ? '#f7f2e8' : Qt.rgba(1, 1, 1, 0.8)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12
                    Image { source: Qt.resolvedUrl('../../icons/eh_goldcoin.svg'); sourceSize.width: 30; sourceSize.height: 30 }
                    Label { Layout.fillWidth: true; text: qsTr('Your coins in the pockets'); font.pixelSize: 17; font.bold: true; wrapMode: Text.WordWrap }
                    Label { text: '›'; font.pixelSize: 24; font.bold: true; color: '#5e1a33' }
                }
                MouseArea {
                    id: pkMa
                    anchors.fill: parent
                    onClicked: app.stack.push(Qt.resolvedUrl('EhPocketsPage.qml'))
                }
            }
            Rectangle {
                visible: page.on
                Layout.fillWidth: true
                Layout.preferredHeight: onL.implicitHeight + 24
                radius: 14
                color: '#fbf0d6'
                Label {
                    id: onL
                    x: 12; y: 12
                    width: parent.width - 24
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font.pixelSize: 14
                    lineHeight: 1.15
                    text: qsTr('<b>"To spend"</b>: the coins the app can use to pay. <b>"Set aside"</b>: the blocked coins, which the app never uses.')
                          + '<br><br>' + qsTr('This does not make the coins anonymous: payments stay written in the public register. It helps not to link your coins to each other.')
                }
            }

            // ---- where the coins come from ----
            Label {
                visible: page.on
                Layout.topMargin: 6
                Layout.leftMargin: 4
                text: qsTr('WHERE THE COINS COME FROM')
                font.pixelSize: 13; font.bold: true; font.letterSpacing: 0.6; color: '#45541f'
            }
            Card {
                visible: page.on
                Layout.preferredHeight: catCol.implicitHeight
                clip: true
                ColumnLayout {
                    id: catCol
                    width: parent.width
                    spacing: 0
                    Repeater {
                        model: app.ehCats()
                        Rectangle {
                            id: cr
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            color: crMa.pressed ? '#f7f2e8' : 'transparent'
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: '#efe7da' }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 12
                                spacing: 12
                                Rectangle { Layout.preferredWidth: 16; Layout.preferredHeight: 16; radius: 8; color: cr.modelData.color }
                                Label { Layout.fillWidth: true; elide: Text.ElideRight; text: cr.modelData.name; font.pixelSize: 17; font.bold: true }
                                Image { source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg'); sourceSize.width: 18; sourceSize.height: 18 }
                            }
                            MouseArea { id: crMa; anchors.fill: parent; onClicked: page.startEdit(cr.modelData) }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        color: 'transparent'
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: '#efe7da' }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 12
                            Rectangle { Layout.preferredWidth: 16; Layout.preferredHeight: 16; radius: 8; color: '#8a7d70' }
                            Label { Layout.fillWidth: true; text: qsTr('I do not know'); font.pixelSize: 17; font.bold: true; color: '#6b5d55' }
                            Label { text: qsTr('always there'); font.pixelSize: 12; color: '#8a7d70' }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        color: addMa.pressed ? '#f1f3e2' : 'transparent'
                        Label { anchors.verticalCenter: parent.verticalCenter; x: 14; text: '+ ' + qsTr('Add a category'); font.pixelSize: 16; font.bold: true; color: '#45541f' }
                        MouseArea { id: addMa; anchors.fill: parent; onClicked: page.startEdit(null) }
                    }
                }
            }
            // the two warnings (on by default)
            Label {
                visible: page.on
                Layout.topMargin: 6
                Layout.leftMargin: 4
                text: qsTr('WARNINGS')
                font.pixelSize: 13; font.bold: true; font.letterSpacing: 0.6; color: '#45541f'
            }
            Card {
                visible: page.on
                Layout.preferredHeight: wCol.implicitHeight
                clip: true
                ColumnLayout {
                    id: wCol
                    width: parent.width
                    spacing: 0
                    Repeater {
                        model: [ { 'k': 'warn_mix', 't': qsTr('When I mix origins'), 'h': qsTr('before sending') },
                                 { 'k': 'warn_dust', 't': qsTr('Suspicious little coins'), 'h': qsTr('very small, from strangers') } ]
                        Rectangle {
                            id: wr
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(60, wRow.implicitHeight + 16)
                            color: 'transparent'
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: '#efe7da' }
                            RowLayout {
                                id: wRow
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 8
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Label { Layout.fillWidth: true; text: wr.modelData.t; font.pixelSize: 16; font.bold: true; wrapMode: Text.WordWrap }
                                    Label { Layout.fillWidth: true; text: wr.modelData.h; font.pixelSize: 13; color: '#6b5d55'; wrapMode: Text.WordWrap }
                                }
                                Switch { checked: app.ehPrivWarn(wr.modelData.k); onToggled: app.ehSetPrivWarn(wr.modelData.k, checked) }
                            }
                        }
                    }
                }
            }

            // write one category: name, colour, save / delete
            Card {
                visible: page.on && page.edit !== null
                Layout.preferredHeight: edCol.implicitHeight + 24
                border.width: 2
                border.color: '#5e1a33'
                ColumnLayout {
                    id: edCol
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 10
                    Label { text: page.edit && page.edit.id === '' ? qsTr('New category') : qsTr('Change the category'); font.pixelSize: 16; font.bold: true; color: '#3f0f21' }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: 12
                        color: '#ffffff'
                        border.width: 2
                        border.color: nameIn.activeFocus ? '#5e1a33' : '#e8dcc4'
                        TextInput {
                            id: nameIn
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 17
                            maximumLength: 18
                            clip: true
                            text: page.edit ? page.edit.name : ''
                            Label { anchors.verticalCenter: parent.verticalCenter; visible: nameIn.text === '' && !nameIn.activeFocus
                                    text: qsTr('name, for example: shop'); color: '#b3a894'; font.pixelSize: 16 }
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 10
                        Repeater {
                            model: app.ehCatColors
                            Rectangle {
                                id: cd
                                required property string modelData
                                readonly property bool on: page.edit !== null && page.edit.color === modelData
                                width: 36; height: 36; radius: 18
                                color: modelData
                                border.width: on ? 4 : 0
                                border.color: '#ffffff'
                                Rectangle { visible: cd.on; anchors.centerIn: parent; width: 44; height: 44; radius: 22; color: 'transparent'; border.width: 2; border.color: cd.modelData }
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: { var e = page.edit; e.color = cd.modelData; e.name = nameIn.text; page.edit = e } }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            visible: page.edit !== null && page.edit.id !== ''
                            Layout.preferredWidth: 104; Layout.preferredHeight: 48; radius: 20
                            color: '#ffffff'; border.width: 2; border.color: '#e6b9b3'
                            Label { anchors.centerIn: parent; text: qsTr('Delete'); color: '#c0392b'; font.pixelSize: 15; font.bold: true }
                            MouseArea { anchors.fill: parent; onClicked: page.deleteEdit() }
                        }
                        Rectangle {
                            Layout.preferredWidth: 96; Layout.preferredHeight: 48; radius: 20
                            color: '#ffffff'; border.width: 2; border.color: '#e3d9c6'
                            Label { anchors.centerIn: parent; text: qsTr('Cancel'); color: '#3f0f21'; font.pixelSize: 15; font.bold: true }
                            MouseArea { anchors.fill: parent; onClicked: page.edit = null }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 20
                            color: '#45541f'
                            opacity: nameIn.text.trim() === '' ? 0.5 : 1
                            Label { anchors.centerIn: parent; text: qsTr('Save'); color: '#ffffff'; font.pixelSize: 16; font.bold: true }
                            MouseArea { anchors.fill: parent; onClicked: page.saveEdit(nameIn.text) }
                        }
                    }
                    Label {
                        visible: page.edit !== null && page.edit.id !== ''
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12; color: '#6b5d55'
                        text: qsTr('If you delete it, its coins go back to "I do not know".')
                    }
                }
            }
        }
    }
}
