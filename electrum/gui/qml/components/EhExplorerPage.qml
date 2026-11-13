// Easy Heirs (schèi): "Dove vedere i movimenti" (T32, owner 2026-11-11).
// The site opened by "Vedi sulla blockchain": a tap chooses it, the pencil changes its
// name and address, "+ Aggiungi un sito" adds one. Electrum's own setting underneath
// (Config.ehExplorers / ehSelectExplorer / ehSaveExplorer / ehForgetExplorer).
// "Bottega" look (WP4): parchment, the sites on one paper sheet with radio rings,
// the editor with paper fields and stitched buttons (loaded only while open).
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

    Rectangle { anchors.fill: parent; color: S.parch }

    // radio ring: 28 px, wine ring, brass dot when chosen
    component Radio: Rectangle {
        property bool on: false
        Layout.preferredWidth: 28; Layout.preferredHeight: 28
        width: 28; height: 28; radius: 14
        color: S.paper
        border.width: 2.5
        border.color: S.wine
        Rectangle {
            visible: parent.on
            anchors.centerIn: parent
            width: 16; height: 16; radius: 8
            border.width: 1.5
            border.color: S.brassRing
            gradient: Gradient {
                GradientStop { position: 0.0; color: S.brassLight }
                GradientStop { position: 0.55; color: S.brass }
                GradientStop { position: 1.0; color: S.brassDark }
            }
        }
    }

    // the editor: name + address, save / cancel / original or delete
    component Editor: ColumnLayout {
        id: ed
        property var site: ({ 'id': '', 'name': '', 'url': '', 'builtin': false })
        spacing: 8
        EhCaption { text: qsTr('NAME'); Layout.topMargin: 4; Layout.bottomMargin: 0 }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: S.fieldH; radius: 16; color: S.paper
            border.width: nIn.activeFocus ? 2.5 : 2; border.color: nIn.activeFocus ? S.wine : S.edge
            TextInput {
                id: nIn
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 18
                color: S.ink
                selectionColor: S.highlight
                selectedTextColor: S.wineDark
                maximumLength: 30
                clip: true
                text: page.shownName(ed.site)
                Label { anchors.verticalCenter: parent.verticalCenter; visible: nIn.text === '' && !nIn.activeFocus
                        text: qsTr('for example: my Umbrel'); color: S.muted
                        font.family: BodyFont ? BodyFont : font.family; font.pixelSize: 17 }
            }
        }
        EhCaption { text: qsTr('ADDRESS'); Layout.topMargin: 4; Layout.bottomMargin: 0 }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: S.fieldH; radius: 16; color: S.paper
            border.width: uIn.activeFocus ? 2.5 : 2; border.color: uIn.activeFocus ? S.wine : S.edge
            TextInput {
                id: uIn
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                font.family: FixedFont
                font.pixelSize: 17
                color: S.ink
                selectionColor: S.highlight
                selectedTextColor: S.wineDark
                clip: true
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                text: ed.site.url
                Component.onCompleted: cursorPosition = 0      // show the start of a long address
                Label { anchors.verticalCenter: parent.verticalCenter; visible: uIn.text === '' && !uIn.activeFocus
                        text: 'http://umbrel.local:3006'; color: S.muted; font.family: FixedFont; font.pixelSize: 17 }
            }
        }
        EhInfoBox {
            id: err
            visible: false
            kind: 'danger'
            text: qsTr('It must start with http:// or https://')
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            EhStitchButton {
                kind: 'paper'
                text: qsTr('Cancel')
                onClicked: page.editId = '-'
            }
            EhStitchButton {
                kind: 'olive'
                text: qsTr('Save')
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
        // Electrum's site changed by hand: back to the original. Own site: delete.
        EhStitchButton {
            visible: ed.site.id !== '' && (ed.site.builtin ? (ed.site.edited === true) : true)
            kind: 'paper'
            icon: ed.site.builtin ? 'eh_undo.svg' : ''
            text: ed.site.builtin ? qsTr('Original') : qsTr('Delete')
            onClicked: { Config.ehForgetExplorer(ed.site.id); page.editId = '-'; page.rev++ }
        }
    }

    Flickable {
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
                text: '‹ ' + qsTr('Advanced')
                onClicked: app.stack.pop()
            }
            EhTitle { text: qsTr('Where to see the movements') }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
                lineHeight: 1.1
                color: S.muted
                text: qsTr('Tap a site to choose it. The pencil changes its name and address.')
            }

            EhSheet {
                topPadding: 4
                bottomPadding: 4
                Repeater {
                    model: page.sites
                    ColumnLayout {
                        id: sr
                        required property var modelData
                        required property int index
                        readonly property bool on: page.selId === modelData.id
                        readonly property bool editing: page.editId === modelData.id
                        readonly property bool last: index === page.sites.length - 1
                        Layout.fillWidth: true
                        spacing: 0
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(S.rowH, srRow.implicitHeight + 16)
                            // pressed: sand at 40 %
                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: -6; anchors.rightMargin: -6
                                anchors.topMargin: 2; anchors.bottomMargin: 2
                                radius: 10
                                color: S.sand
                                opacity: srMa.pressed ? 0.4 : 0
                            }
                            MouseArea { id: srMa; anchors.fill: parent; onClicked: page.choose(sr.modelData) }
                            RowLayout {
                                id: srRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                Radio { on: sr.on }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Label {
                                            width: Math.min(implicitWidth, parent.width)
                                            elide: Text.ElideRight
                                            text: page.shownName(sr.modelData)
                                            color: S.ink
                                            font.family: BodyFont ? BodyFont : font.family
                                            font.pixelSize: 17
                                            font.bold: true
                                        }
                                        Rectangle {
                                            visible: sr.modelData.id === 'mempool.space' && !sr.modelData.edited
                                            width: recL.implicitWidth + 12; height: recL.implicitHeight + 2
                                            radius: 6
                                            color: S.paper
                                            border.width: 1.5
                                            border.color: S.olive
                                            Label { id: recL; anchors.centerIn: parent; text: qsTr('recommended')
                                                    font.family: BodyFont ? BodyFont : font.family
                                                    font.pixelSize: 16; font.bold: true; color: S.oliveInk }
                                        }
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                        lineHeight: 1.05
                                        font.family: BodyFont ? BodyFont : font.family
                                        font.pixelSize: 16
                                        color: S.muted
                                        text: sr.modelData.id === 'mine' && sr.modelData.url === ''
                                              ? qsTr('for example Umbrel: write the address of your mempool')
                                              : (!sr.modelData.edited && page.hints[sr.modelData.id] !== undefined
                                                 ? page.hints[sr.modelData.id] : sr.modelData.url)
                                    }
                                }
                                // the pencil: change name and address
                                Rectangle {
                                    Layout.preferredWidth: 48; Layout.preferredHeight: 48; radius: 24
                                    color: sr.editing ? S.sand : (pMa.pressed ? Qt.rgba(0.902, 0.847, 0.714, 0.5) : 'transparent')
                                    border.width: sr.editing ? 1.5 : 0
                                    border.color: S.edge
                                    Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg'); sourceSize.width: 22; sourceSize.height: 22 }
                                    MouseArea { id: pMa; anchors.fill: parent; onClicked: page.editId = sr.editing ? '-' : sr.modelData.id }
                                }
                            }
                        }
                        // the editor is made only while it is open (its buttons are not list rows)
                        Loader {
                            active: sr.editing
                            visible: active
                            Layout.fillWidth: true
                            Layout.bottomMargin: active ? 14 : 0
                            sourceComponent: Editor { site: sr.modelData }
                        }
                        EhDotLine { visible: !sr.last }
                    }
                }
            }

            // add a site
            EhStitchButton {
                kind: 'paper'
                icon: 'eh_plus.svg'
                text: qsTr('Add a site')
                onClicked: page.editId = page.editId === '' ? '-' : ''
            }
            EhSheet {
                visible: page.editId === ''
                topPadding: 8
                bottomPadding: 14
                Loader {
                    active: page.editId === ''
                    Layout.fillWidth: true
                    sourceComponent: Editor { site: ({ 'id': '', 'name': '', 'url': '', 'builtin': false }) }
                }
            }

            // privacy (text approved by the owner, 2026-11-11)
            EhInfoBox {
                kind: 'warn'
                text: '<b>' + qsTr('Privacy.') + '</b> ' + qsTr('The site you open sees which movement you are looking at and where you connect from.')
                Label {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; textFormat: Text.StyledText
                    font.family: BodyFont ? BodyFont : font.family; font.pixelSize: 16; lineHeight: 1.15; color: S.ink
                    text: '• ' + qsTr('With <b>your node</b> nobody knows it: everything stays at your home.')
                }
                Label {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; textFormat: Text.StyledText
                    font.family: BodyFont ? BodyFont : font.family; font.pixelSize: 16; lineHeight: 1.15; color: S.ink
                    text: '• ' + qsTr('With a public site you can protect yourself with a <b>VPN</b> or with <b>Tor</b> (Orbot or Tor Browser app): the site sees the movement, but does not know who you are.')
                }
            }
        }
    }

    Toaster { id: toaster }
}
