// Easy Heirs (schȅi): "Gestione privacy avanzata" (T20, owner 2026-11-09).
// For advanced users only, off by default: with the switch off the app shows
// no pockets, no origin colours and no privacy warnings.
// Step 1: the page and its switch. Next steps add the pockets with the
// "sacchetti" (step 2), the origin categories (step 3) and the warnings (step 4).
// "Bottega" look (WP4): paper sheets with rows and brass switches, info boxes,
// the category editor with a paper field and stitched buttons.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"
import "controls/EhStyle.js" as S

Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.olive

    readonly property bool on: app.ehOption('privacy')
    // the category being written: null = none, id '' = a new one
    property var edit: null
    // T26: show the editor where it can be seen, with the cursor in the name
    function showEditor() {
        var y = editCard.mapToItem(pfl.contentItem, 0, 0).y
        // the whole card in view, its bottom just above the screen edge
        var want = y + editCard.height + 16 - pfl.height
        if (want > pfl.contentY) pfl.contentY = Math.min(want, Math.max(0, pfl.contentHeight - pfl.height))
        nameIn.forceActiveFocus()
    }
    // wait for the card to be laid out before measuring where it is
    Timer { id: editTimer; interval: 120; onTriggered: page.showEditor() }
    onEditChanged: if (page.edit !== null) editTimer.restart()
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

    Rectangle { anchors.fill: parent; color: S.parch }

    // one origin category: its own colour dot, the name, the pencil
    component CatRow: Item {
        id: cr
        property color dot
        property string name
        property bool muted: false
        property string side: ''
        property bool pen: true
        property bool last: false
        signal clicked
        Layout.fillWidth: true
        Layout.preferredHeight: S.rowH
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -6; anchors.rightMargin: -6
            anchors.topMargin: 2; anchors.bottomMargin: 2
            radius: 10
            color: S.sand
            opacity: crMa.pressed ? 0.4 : 0
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 18; Layout.preferredHeight: 18; radius: 9
                color: cr.dot
                border.width: 1.5
                border.color: Qt.darker(cr.dot, 1.3)
            }
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: cr.name
                color: cr.muted ? S.muted : S.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 17
                font.bold: true
            }
            Label {
                visible: cr.side !== ''
                text: cr.side
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
            }
            Image {
                visible: cr.pen
                Layout.rightMargin: 4
                source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg')
                sourceSize.width: 22; sourceSize.height: 22
            }
        }
        EhDotLine {
            visible: !cr.last
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }
        MouseArea { id: crMa; anchors.fill: parent; enabled: cr.pen; onClicked: cr.clicked() }
    }

    Flickable {
        id: pfl
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.implicitHeight + 24
        clip: true
        ColumnLayout {
            id: col
            x: S.margin
            width: parent.width - 2 * S.margin
            spacing: S.gap

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            EhBackLink {
                text: '‹ ' + qsTr('Advanced settings')
                onClicked: app.stack.pop()
            }
            EhTitle { text: qsTr('Advanced privacy') }

            // the switch that turns everything on
            EhSheet {
                EhRow {
                    text: qsTr('Use the privacy management')
                    hint: qsTr('pockets, origin of the coins and warnings')
                    showSwitch: true
                    last: true
                    checked: page.on
                    onToggled: (on) => app.ehSetOption('privacy', on)
                }
            }

            // off: what it is for
            EhInfoBox {
                visible: !page.on
                kind: 'warn'
                text: qsTr('It is for those who want to choose <b>which coins to keep apart</b>, so that different payments are not linked to each other.')
                      + '<br><br>' + qsTr('With the switch off nothing changes: the app chooses the coins by itself, as always.')
            }

            // on: the pockets
            EhSheet {
                visible: page.on
                EhRow {
                    icon: 'eh_goldcoin.svg'
                    iconColor: S.brassRing
                    text: qsTr('Your coins in the pockets')
                    last: true
                    onClicked: app.stack.push(Qt.resolvedUrl('EhPocketsPage.qml'))
                }
            }
            EhInfoBox {
                visible: page.on
                kind: 'warn'
                text: qsTr('<b>"To spend"</b>: the coins the app can use to pay. <b>"Set aside"</b>: the blocked coins, which the app never uses.')
                      + '<br><br>' + qsTr('This does not make the coins anonymous: payments stay written in the public register. It helps not to link your coins to each other.')
            }

            // ---- where the coins come from ----
            EhCaption {
                visible: page.on
                Layout.topMargin: 6
                Layout.bottomMargin: -4
                text: qsTr('WHERE THE COINS COME FROM')
            }
            EhSheet {
                visible: page.on
                Repeater {
                    model: app.ehCats()
                    CatRow {
                        required property var modelData
                        dot: modelData.color
                        name: modelData.name
                        onClicked: page.startEdit(modelData)
                    }
                }
                CatRow {
                    dot: '#8a7d70'          // the colour of "I do not know" (main.qml)
                    name: qsTr('I do not know')
                    muted: true
                    side: qsTr('always there')
                    pen: false
                    last: true
                }
            }
            EhStitchButton {
                visible: page.on
                kind: 'paper'
                icon: 'eh_plus.svg'
                text: qsTr('Add a category')
                onClicked: page.startEdit(null)
            }
            // write one category: name, colour, save / delete
            EhSheet {
                id: editCard
                visible: page.on && page.edit !== null
                borderColor: S.wine
                topPadding: 14
                bottomPadding: 14
                spacing: 12
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: page.edit && page.edit.id === '' ? qsTr('New category') : qsTr('Change the category')
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 17; font.bold: true; color: S.wineDark
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: S.fieldH
                    radius: 16
                    color: S.paper
                    border.width: nameIn.activeFocus ? 2.5 : 2
                    border.color: nameIn.activeFocus ? S.wine : S.edge
                    TextInput {
                        id: nameIn
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: 18
                        color: S.ink
                        selectionColor: S.highlight
                        selectedTextColor: S.wineDark
                        maximumLength: 18
                        clip: true
                        text: page.edit ? page.edit.name : ''
                        Label { anchors.verticalCenter: parent.verticalCenter; visible: nameIn.text === '' && !nameIn.activeFocus
                                text: qsTr('name, for example: shop'); color: S.muted
                                font.family: BodyFont ? BodyFont : font.family; font.pixelSize: 17 }
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.topMargin: 4
                    spacing: 14
                    Repeater {
                        model: app.ehCatColors
                        Rectangle {
                            id: cd
                            required property string modelData
                            readonly property bool on: page.edit !== null && page.edit.color === modelData
                            width: 40; height: 40; radius: 20
                            color: modelData
                            border.width: on ? 4 : 0
                            border.color: S.paper
                            Rectangle { visible: cd.on; anchors.centerIn: parent; width: 50; height: 50; radius: 25; color: 'transparent'; border.width: 3; border.color: S.gold }
                            MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: { var e = page.edit; e.color = cd.modelData; e.name = nameIn.text; page.edit = e } }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8
                    EhStitchButton {
                        kind: 'paper'
                        text: qsTr('Cancel')
                        onClicked: page.edit = null
                    }
                    EhStitchButton {
                        kind: 'olive'
                        text: qsTr('Save')
                        enabled: nameIn.text.trim() !== ''
                        onClicked: page.saveEdit(nameIn.text)
                    }
                }
                EhStitchButton {
                    visible: page.edit !== null && page.edit.id !== ''
                    kind: 'paper'
                    text: qsTr('Delete')
                    onClicked: page.deleteEdit()
                }
                Label {
                    visible: page.edit !== null && page.edit.id !== ''
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 16; lineHeight: 1.1; color: S.muted
                    text: qsTr('If you delete it, its coins go back to "I do not know".')
                }
            }

            // the two warnings (on by default)
            EhCaption {
                visible: page.on
                Layout.topMargin: 6
                Layout.bottomMargin: -4
                text: qsTr('WARNINGS')
            }
            EhSheet {
                visible: page.on
                Repeater {
                    model: [ { 'k': 'warn_mix', 't': qsTr('When I mix origins'), 'h': qsTr('before sending') },
                             { 'k': 'warn_dust', 't': qsTr('Suspicious little coins'), 'h': qsTr('very small, from strangers') } ]
                    EhRow {
                        id: wr
                        required property var modelData
                        required property int index
                        text: wr.modelData.t
                        hint: wr.modelData.h
                        showSwitch: true
                        last: wr.index === 1
                        checked: app.ehPrivWarn(wr.modelData.k)
                        onToggled: (on) => app.ehSetPrivWarn(wr.modelData.k, on)
                    }
                }
            }

        }
    }
}
