// Easy Heirs (schèi): "Collegamento" (advanced settings). Automatic servers or
// only your own node, and "Passa da Tor" through the Orbot app. Electrum's own
// network settings (setServerParameters, proxy, probeTor): only the look is ours.
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
    Material.accent: '#5e1a33'

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

    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    EhGlow { tone: page.torOn ? 'wine' : 'green'; x: -page.width * 0.3; y: 40; width: page.width * 1.6; height: 380; opacity: 0.7 }

    component Opt: Rectangle {
        id: op
        property bool on: false
        property string title
        property string hint
        default property alias extra: opExtra.data
        signal picked
        Layout.fillWidth: true
        Layout.preferredHeight: opCol.implicitHeight + 24
        radius: 16
        color: Qt.rgba(1, 1, 1, on ? 0.88 : 0.66)
        border.width: 2
        border.color: on ? '#5e1a33' : Qt.rgba(1, 1, 1, 0.9)
        ColumnLayout {
            id: opCol
            x: 12; y: 12
            width: parent.width - 24
            spacing: 6
            RowLayout {
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 11
                    color: 'transparent'
                    border.width: 2.5
                    border.color: op.on ? '#5e1a33' : '#b3a894'
                    Rectangle { visible: op.on; anchors.fill: parent; anchors.margins: 4; radius: width / 2; color: '#5e1a33' }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: op.title; font.pixelSize: 16; font.bold: true }
                    Label { Layout.fillWidth: true; visible: op.hint !== ''; text: op.hint; font.pixelSize: 13; color: '#6b5d55'; wrapMode: Text.WordWrap }
                }
            }
            ColumnLayout { id: opExtra; Layout.fillWidth: true; spacing: 6 }
        }
        TapHandler { gesturePolicy: TapHandler.WithinBounds; onTapped: op.picked() }
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
                text: qsTr('Connection')
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 28
            }

            // state of the connection
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: stRow.implicitHeight + 24
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0; color: !Network.isConnected ? '#b3261e' : (page.torOn ? '#6b3fa0' : '#53652a') }
                    GradientStop { position: 1; color: !Network.isConnected ? '#78140f' : (page.torOn ? '#402468' : '#344016') }
                }
                RowLayout {
                    id: stRow
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 10
                    Image {
                        visible: page.torOn
                        source: Qt.resolvedUrl('../../icons/eh_onion.svg')
                        sourceSize.width: 26; sourceSize.height: 26
                    }
                    Rectangle {
                        visible: !page.torOn
                        Layout.preferredWidth: 12; Layout.preferredHeight: 12; radius: 6
                        color: Network.isConnected ? '#bfe07a' : '#ffb4a8'
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Label {
                            color: '#ffffff'; font.pixelSize: 16; font.bold: true
                            text: !Network.isConnected ? qsTr('Not connected')
                                : (page.torOn ? qsTr('Connected through Tor') : (page.myNode ? qsTr('Connected to your node') : qsTr('Connected')))
                        }
                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                            color: '#ffffff'; opacity: 0.9; font.pixelSize: 13
                            text: !Network.isConnected ? (page.torOn && page.torFound === 0 ? qsTr('Tor does not answer') : qsTr('trying to connect…'))
                                : Network.server + ' · ' + qsTr('block %1').arg(Network.height.toLocaleString(app.ehLocale(), 'f', 0))
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: whyL.implicitHeight + 20
                radius: 14
                color: Qt.rgba(0.98, 0.94, 0.84, 0.92)
                Label {
                    id: whyL
                    anchors.fill: parent; anchors.margins: 10
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font.pixelSize: 14
                    text: qsTr('Schèi connects by itself to the public Electrum servers, to know the balance and to send payments. If you have <b>your own node</b> (for example on Umbrel), you can connect only to that.')
                }
            }

            Opt {
                on: !page.chooseMyNode
                title: qsTr('Automatic') + '  (' + qsTr('recommended') + ')'
                hint: qsTr('chooses by itself a server that works')
                onPicked: page.chooseAutomatic()
            }
            Opt {
                on: page.chooseMyNode
                title: qsTr('Only my node')
                hint: qsTr('connects only to the server you write')
                onPicked: { page.chooseMyNode = true; if (nodeField.text === '') nodeField.text = page.myNode ? Network.server : '' }
                Label { visible: page.chooseMyNode; text: qsTr('SERVER ADDRESS'); font.pixelSize: 12; font.bold: true; color: '#6b5d55' }
                Rectangle {
                    visible: page.chooseMyNode
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 12
                    color: '#ffffff'
                    border.width: 2
                    border.color: page.nodeError !== '' ? '#b3261e' : '#e8dcc4'
                    TextInput {
                        id: nodeField
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: FixedFont
                        font.pixelSize: 14
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhUrlCharactersOnly
                        clip: true
                        text: page.myNode ? Network.server : ''
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: nodeField.text === '' && !nodeField.activeFocus
                            text: 'umbrel.local:50002:s'
                            color: '#b3a894'
                            font.family: FixedFont
                            font.pixelSize: 14
                        }
                    }
                }
                Label {
                    visible: page.nodeError !== ''
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: page.nodeError
                    color: '#b3261e'; font.pixelSize: 13; font.bold: true
                }
                Label {
                    visible: page.chooseMyNode
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font.pixelSize: 13
                    color: '#6b5d55'
                    text: qsTr('You find it in the "Electrs" or "Fulcrum" app of your node. ":s" means protected connection.')
                          + (page.torOn ? ' ' + qsTr('With Tor you can also write the <b>.onion</b> address of the node: so you connect to your home even from outside, without touching the router.') : '')
                }
                EhNextButton {
                    visible: page.chooseMyNode
                    Layout.fillWidth: true
                    text: qsTr('Try and connect')
                    onClicked: page.connectNode()
                }
            }

            // through Tor (Orbot)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: torRow.implicitHeight + 24
                radius: 16
                color: Qt.rgba(1, 1, 1, 0.75)
                border.width: 2
                border.color: page.torOn ? (page.torFound === 0 ? '#e2a49c' : '#b9a3dd') : Qt.rgba(1, 1, 1, 0.9)
                RowLayout {
                    id: torRow
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 10
                    Image { source: Qt.resolvedUrl('../../icons/eh_onion.svg'); sourceSize.width: 30; sourceSize.height: 30 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Label { text: qsTr('Go through Tor'); font.pixelSize: 16; font.bold: true }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.pixelSize: 13
                            font.bold: page.torOn && page.torFound >= 0
                            color: !page.torOn ? '#6b5d55' : (page.torFound === 1 ? '#45541f' : (page.torFound === 0 ? '#b3261e' : '#6b5d55'))
                            text: !page.torOn ? qsTr('more private · needs the Orbot app')
                                : (page.probing ? qsTr('looking for Orbot…')
                                : (page.torFound === 1 ? '✓ ' + qsTr('Orbot found') : (page.torFound === 0 ? qsTr('Orbot is not on') : qsTr('on'))))
                        }
                    }
                    Switch {
                        checked: page.torOn
                        onToggled: page.setTor(checked)
                    }
                }
            }
            Rectangle {
                visible: page.torOn
                Layout.fillWidth: true
                Layout.preferredHeight: torNote.implicitHeight + 20
                radius: 14
                color: Qt.rgba(0.98, 0.94, 0.84, 0.95)
                Label {
                    id: torNote
                    anchors.fill: parent; anchors.margins: 10
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font.pixelSize: 14
                    text: page.torFound === 0
                          ? qsTr('<b>What to do:</b> open the <b>Orbot</b> app and tap the big button to turn it on. Then come back here: Schèi connects by itself.') + '<br><br>'
                            + qsTr('If you do not have Orbot, turn off "Go through Tor" and Schèi connects normally again.')
                          : qsTr('With Tor the connection is a bit slower: a few seconds more when opening and to update the balance.')
                }
            }
        }
    }
}
