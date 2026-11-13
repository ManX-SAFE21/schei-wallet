// Easy Heirs (schȅi): "Collegamento" (advanced settings). Automatic servers or
// only your own node, and "Passa da Tor" through the Orbot app. Electrum's own
// network settings (setServerParameters, proxy, probeTor): only the look is ours.
// "Bottega" look (WP4): status line on a paper sheet, the two choices as radio rows,
// Tor with the brass switch.
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
    Material.accent: S.wine

    readonly property bool myNode: Network.oneServer && !Network.autoConnect
    property bool chooseMyNode: myNode
    readonly property bool torOn: Network.proxy && Network.proxy.enabled === true
    property bool probing: false
    property int torFound: -1          // -1 unknown, 0 not found, 1 found
    property string nodeError: ''

    function setTor(on) {
        if (on) {
            probing = true
            torFound = -1
            Network.probeTor()
        } else {
            Network.proxy = { 'enabled': false, 'mode': 'socks5', 'host': '', 'port': '', 'user': '', 'password': '' }
            torFound = -1
        }
    }
    function connectNode() {
        var s = nodeField.text.trim()
        if (!Network.isValidServerAddress(s)) {
            nodeError = qsTr('This address is not right. Example: umbrel.local:50002:s')
            return
        }
        nodeError = ''
        Network.setServerParameters(s, false, true)
    }
    function chooseAutomatic() {
        chooseMyNode = false
        Network.setServerParameters('', true, false)
    }

    Connections {
        target: Network
        function onTorProbeFinished(host, port) {
            page.probing = false
            var found = !!(host && port)
            page.torFound = found ? 1 : 0
            // with Tor on, the app never connects outside Tor: even when Orbot is
            // not found, the proxy stays on (Orbot's usual address)
            Network.proxy = { 'enabled': true, 'mode': 'socks5',
                              'host': found ? host : '127.0.0.1', 'port': found ? '' + port : '9050',
                              'user': '', 'password': '' }
        }
    }

    Rectangle { anchors.fill: parent; color: S.parch }

    // a choice row: 28 px radio ring (wine, brass dot when chosen), title 17 bold, hint 16
    component Opt: Item {
        id: op
        property bool on: false
        property string title
        property string hint
        property bool last: false
        signal picked
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(S.rowH, opRow.implicitHeight + 16)
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -6; anchors.rightMargin: -6
            anchors.topMargin: 2; anchors.bottomMargin: 2
            radius: 10
            color: S.sand
            opacity: opTap.pressed ? 0.4 : 0
        }
        RowLayout {
            id: opRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                color: S.paper
                border.width: 2.5
                border.color: S.wine
                Rectangle {
                    visible: op.on
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
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { Layout.fillWidth: true; text: op.title; color: S.ink; wrapMode: Text.WordWrap
                        font.family: BodyFont ? BodyFont : font.family; font.pixelSize: 17; font.bold: true }
                Label { Layout.fillWidth: true; visible: op.hint !== ''; text: op.hint; color: S.muted; wrapMode: Text.WordWrap
                        font.family: BodyFont ? BodyFont : font.family; font.pixelSize: 16; lineHeight: 1.05 }
            }
        }
        EhDotLine {
            visible: !op.last
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }
        TapHandler { id: opTap; gesturePolicy: TapHandler.WithinBounds; onTapped: op.picked() }
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
            EhTitle { text: qsTr('Connection') }

            // state of the connection
            EhSheet {
                topPadding: 12
                bottomPadding: 12
                RowLayout {
                    id: stRow
                    Layout.fillWidth: true
                    spacing: 12
                    Item {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter
                        Image {
                            visible: page.torOn
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl('../../icons/eh_onion.svg')
                            sourceSize.width: 28; sourceSize.height: 28
                        }
                        Rectangle {
                            visible: !page.torOn
                            anchors.centerIn: parent
                            width: 16; height: 16; radius: 8
                            color: Network.isConnected ? S.olive : S.waitInk
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: Network.isConnected ? S.oliveInk : S.waitInk
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 17; font.bold: true
                            text: !Network.isConnected ? qsTr('Not connected')
                                : (page.torOn ? qsTr('Connected through Tor') : (page.myNode ? qsTr('Connected to your node') : qsTr('Connected')))
                        }
                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                            color: S.muted
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 16
                            text: !Network.isConnected ? (page.torOn && page.torFound === 0 ? qsTr('Tor does not answer') : qsTr('trying to connect…'))
                                : Network.server + ' · ' + qsTr('block %1').arg(Network.height.toLocaleString(app.ehLocale(), 'f', 0))
                        }
                    }
                }
            }

            EhInfoBox {
                kind: 'warn'
                text: qsTr('Schȅi connects by itself to the public Electrum servers, to know the balance and to send payments. If you have <b>your own node</b> (for example on Umbrel), you can connect only to that.')
            }

            // automatic or only my node
            EhSheet {
                bottomPadding: page.chooseMyNode ? 14 : 0
                Opt {
                    on: !page.chooseMyNode
                    title: qsTr('Automatic') + '  (' + qsTr('recommended') + ')'
                    hint: qsTr('chooses by itself a server that works')
                    onPicked: page.chooseAutomatic()
                }
                Opt {
                    on: page.chooseMyNode
                    last: !page.chooseMyNode
                    title: qsTr('Only my node')
                    hint: qsTr('connects only to the server you write')
                    onPicked: { page.chooseMyNode = true; if (nodeField.text === '') nodeField.text = page.myNode ? Network.server : '' }
                }
                ColumnLayout {
                    visible: page.chooseMyNode
                    Layout.fillWidth: true
                    spacing: 8
                    EhCaption { text: qsTr('SERVER ADDRESS'); Layout.topMargin: 6; Layout.bottomMargin: 0 }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: S.fieldH
                        radius: 16
                        color: S.paper
                        border.width: (nodeField.activeFocus || page.nodeError !== '') ? 2.5 : 2
                        border.color: page.nodeError !== '' ? S.red : (nodeField.activeFocus ? S.wine : S.edge)
                        TextInput {
                            id: nodeField
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: FixedFont
                            font.pixelSize: 17
                            color: S.ink
                            selectionColor: S.highlight
                            selectedTextColor: S.wineDark
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhUrlCharactersOnly
                            clip: true
                            text: page.myNode ? Network.server : ''
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: nodeField.text === '' && !nodeField.activeFocus
                                text: 'umbrel.local:50002:s'
                                color: S.muted
                                font.family: FixedFont
                                font.pixelSize: 17
                            }
                        }
                    }
                    EhInfoBox {
                        visible: page.nodeError !== ''
                        kind: 'danger'
                        text: page.nodeError
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: 16
                        lineHeight: 1.1
                        color: S.muted
                        text: qsTr('You find it in the "Electrs" or "Fulcrum" app of your node. ":s" means protected connection.')
                              + (page.torOn ? ' ' + qsTr('With Tor you can also write the <b>.onion</b> address of the node: so you connect to your home even from outside, without touching the router.') : '')
                    }
                    EhStitchButton {
                        Layout.topMargin: 4
                        kind: 'wine'
                        endIcon: 'next'
                        text: qsTr('Try and connect')
                        onClicked: page.connectNode()
                    }
                }
            }

            // through Tor (Orbot)
            EhSheet {
                borderColor: page.torOn && page.torFound === 0 ? S.wine : S.edge
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(S.rowH, torRow.implicitHeight + 16)
                    RowLayout {
                        id: torRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        EhIconRing { icon: 'eh_onion.svg'; iconSize: 26 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label { Layout.fillWidth: true; text: qsTr('Go through Tor'); color: S.ink; wrapMode: Text.WordWrap
                                    font.family: BodyFont ? BodyFont : font.family; font.pixelSize: 17; font.bold: true }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                font.family: BodyFont ? BodyFont : font.family
                                font.pixelSize: 16
                                lineHeight: 1.05
                                font.bold: page.torOn && page.torFound >= 0
                                color: !page.torOn ? S.muted : (page.torFound === 1 ? S.oliveInk : (page.torFound === 0 ? S.red : S.muted))
                                text: !page.torOn ? qsTr('more private · needs the Orbot app')
                                    : (page.probing ? qsTr('looking for Orbot…')
                                    : (page.torFound === 1 ? '✓ ' + qsTr('Orbot found') : (page.torFound === 0 ? qsTr('Orbot is not on') : qsTr('on'))))
                            }
                        }
                        EhSwitch {
                            Layout.rightMargin: -8          // its touch room, not its look
                            checked: page.torOn
                            onToggled: page.setTor(checked)
                        }
                    }
                }
            }
            EhInfoBox {
                visible: page.torOn
                kind: 'warn'
                text: page.torFound === 0
                      ? qsTr('<b>What to do:</b> open the <b>Orbot</b> app and tap the big button to turn it on. Then come back here: Schȅi connects by itself.') + '<br><br>'
                        + qsTr('If you do not have Orbot, turn off "Go through Tor" and Schȅi connects normally again.')
                      : qsTr('With Tor the connection is a bit slower: a few seconds more when opening and to update the balance.')
            }
        }
    }
}
