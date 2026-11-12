// Easy Heirs (schèi): PIN for big payments: on / off and the threshold. Opened with the
// PIN from Settings (level ESPERTO, T50); the other expert rows are in Settings.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#45541f'

    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    EhGlow { tone: 'wine'; x: -page.width * 0.3; y: 40; width: page.width * 1.6; height: 380; opacity: 0.7 }

    property bool ehProtected: true   // closes after a minute in the background (main.qml)
    // the PIN was typed to come in: no new PIN for the 12 words while here
    Component.onCompleted: app._ehPinOkUntil = Date.now() + 10 * 60 * 1000
    Component.onDestruction: app._ehPinOkUntil = 0

    component Nav: Rectangle {
        id: nv
        property string icon
        property string text
        signal clicked
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(56, nvRow.implicitHeight + 16)
        color: nvTap.pressed ? '#f7f2e8' : 'transparent'
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: '#f1ebdf' }
        RowLayout {
            id: nvRow
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12
            Image { source: Qt.resolvedUrl('../../icons/' + nv.icon); sourceSize.width: 24; sourceSize.height: 24 }
            Label { Layout.fillWidth: true; text: nv.text; font.pixelSize: 16; font.bold: true; wrapMode: Text.WordWrap }
            Label { text: '›'; font.pixelSize: 22; color: '#5e1a33' }
        }
        TapHandler { id: nvTap; onTapped: nv.clicked() }
    }

    component Sw: Rectangle {
        id: s
        property string text
        property string hint
        property string key
        property bool soon: false
        property bool invert: false     // the option stores the opposite (e.g. no_anim)
        property bool locked: false     // second review (S3): stays on, cannot be turned off
        property string lockedHint
        Component.onCompleted: if (locked && !app.ehOption(key)) app.ehSetOption(key, true)
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(60, swRow.implicitHeight + 16)
        color: 'transparent'
        opacity: soon ? 0.5 : 1
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: '#f1ebdf' }
        RowLayout {
            id: swRow
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: s.text; font.pixelSize: 16; font.bold: true; wrapMode: Text.WordWrap }
                Label { Layout.fillWidth: true; text: s.soon ? qsTr('coming soon') : (s.locked ? s.lockedHint : s.hint); font.pixelSize: 13; color: '#6b5d55'; wrapMode: Text.WordWrap }
            }
            Switch {
                enabled: !s.soon && !s.locked
                checked: s.invert ? !app.ehOption(s.key) : app.ehOption(s.key)
                onToggled: app.ehSetOption(s.key, s.invert ? !checked : checked)
            }
        }
    }
    component Group: Label {
        font.pixelSize: 13
        font.bold: true
        font.letterSpacing: 0.5
        color: '#45541f'
        Layout.leftMargin: 4
        Layout.topMargin: 2
    }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight  // T9: last button was under the Android keys
        contentHeight: col.implicitHeight + 30
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 32
            x: 16
            spacing: 8

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }

            Label {
                Layout.topMargin: -14
                text: '‹ ' + qsTr('Settings')
                color: '#5e1a33'
                font.pixelSize: 17
                font.bold: true
                TapHandler { margin: 10; onTapped: app.stack.pop() }
            }
            RowLayout {
                spacing: 10
                Image { source: Qt.resolvedUrl('../../icons/eh_lock.svg'); sourceSize.width: 30; sourceSize.height: 30 }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr('PIN for big payments')
                    color: '#3f0f21'
                    font.family: TitleFont ? TitleFont : font.family
                    font.weight: Font.Black
                    font.pixelSize: 28
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: g0.implicitHeight; radius: 18; color: Qt.rgba(1, 1, 1, 0.7); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.9); clip: true
                ColumnLayout { id: g0; width: parent.width; spacing: 0
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: 'transparent'
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: '#f1ebdf' }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label { Layout.fillWidth: true; text: qsTr('PIN for big payments'); font.pixelSize: 16; font.bold: true; wrapMode: Text.WordWrap }
                                Label { Layout.fillWidth: true; text: qsTr('like a contactless card: below the threshold the coin is enough'); font.pixelSize: 13; color: '#6b5d55'; wrapMode: Text.WordWrap }
                            }
                            Switch { checked: app.ehDoubleOn(); onToggled: app.ehSetOption('double', checked) }
                        }
                    }
                    ColumnLayout {
                        visible: app.ehDoubleOn()
                        Layout.fillWidth: true
                        Layout.margins: 12
                        spacing: 8
                        Label { text: qsTr('Ask the PIN from'); font.pixelSize: 14; font.bold: true; color: '#6b5d55' }
                        Label {
                            visible: app.ehBtcOnly()
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            textFormat: Text.StyledText
                            font.pixelSize: 15
                            text: qsTr('<b>20%</b> of the balance (with "Only bitcoin" there is no value in %1).').arg(app.ehCcyName())
                        }
                        Flow {
                            visible: !app.ehBtcOnly()
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: [50, 100, 200, 500].map(function(x) { return x * app.ehCcyMult() })
                                delegate: Rectangle {
                                    required property int modelData
                                    width: amtL.implicitWidth + 28
                                    height: 38
                                    radius: 19
                                    color: app.ehDoubleEur() === modelData ? '#5e1a33' : '#efe6d3'
                                    Label {
                                        id: amtL
                                        anchors.centerIn: parent
                                        text: app.ehGroup('' + modelData) + ' ' + app.ehSym()
                                        font.pixelSize: 15
                                        font.bold: true
                                        color: app.ehDoubleEur() === modelData ? '#ffffff' : '#6b5d55'
                                    }
                                    TapHandler { onTapped: app.ehSetDoubleEur(modelData) }
                                }
                            }
                            Rectangle {
                                width: 138      // fixed: the empty field has no width of its own
                                height: 38
                                radius: 19
                                color: [50, 100, 200, 500].map(function(x) { return x * app.ehCcyMult() }).indexOf(app.ehDoubleEur()) < 0 ? '#5e1a33' : '#efe6d3'
                                TextInput {
                                    id: otherF
                                    anchors.centerIn: parent
                                    width: 110
                                    horizontalAlignment: TextInput.AlignHCenter
                                    text: [50, 100, 200, 500].map(function(x) { return x * app.ehCcyMult() }).indexOf(app.ehDoubleEur()) < 0 ? '' + app.ehDoubleEur() : ''
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    validator: IntValidator { bottom: 1; top: 1000000 }
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: [50, 100, 200, 500].map(function(x) { return x * app.ehCcyMult() }).indexOf(app.ehDoubleEur()) < 0 ? '#ffffff' : '#2a2220'
                                    onEditingFinished: if (text !== '') app.ehSetDoubleEur(parseInt(text))
                                    Label {
                                        // our own hint: it stays in place and goes away while typing
                                        anchors.centerIn: parent
                                        visible: otherF.text === '' && !otherF.activeFocus
                                        text: qsTr('other amount…')
                                        font.pixelSize: 15
                                        font.bold: true
                                        color: '#6b5d55'
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }
    }
}
