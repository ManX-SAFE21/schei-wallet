// Easy Heirs (schèi): PIN for big payments: on / off and the threshold. Opened with the
// PIN from Settings (level ESPERTO, T50); the other expert rows are in Settings.
// "Bottega" look (WP4): one paper sheet, brass switch, amount choices as tabs
// (the chosen one in wine leather), the "other amount" field on paper.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.olive

    Rectangle { anchors.fill: parent; color: S.parch }

    property bool ehProtected: true   // closes after a minute in the background (main.qml)
    // the PIN was typed to come in: no new PIN for the 12 words while here
    Component.onCompleted: app._ehPinOkUntil = Date.now() + 10 * 60 * 1000
    Component.onDestruction: app._ehPinOkUntil = 0

    // (the old local Nav / Sw / Group components were not used any more: the other
    // expert rows live in Settings; rows here are EhRow, captions EhCaption)

    // a choice of the threshold: paper tab, the chosen one in wine leather
    component Chip: Rectangle {
        id: ch
        property bool on: false
        property alias text: chL.text
        signal picked
        width: Math.max(64, chL.implicitWidth + 32)
        height: 48
        radius: 14
        border.width: on ? 0 : 1.5
        border.color: S.edge
        gradient: Gradient {
            GradientStop { position: 0.0; color: ch.on ? S.leatherWine1 : (chTap.pressed ? S.sand : S.paper) }
            GradientStop { position: 0.7; color: ch.on ? S.leatherWine2 : (chTap.pressed ? S.sand : S.paper) }
            GradientStop { position: 1.0; color: ch.on ? S.leatherWine3 : (chTap.pressed ? S.sand : S.paper) }
        }
        Label {
            id: chL
            anchors.centerIn: parent
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 17
            font.bold: true
            color: ch.on ? S.ivory : S.ink
        }
        TapHandler { id: chTap; onTapped: ch.picked() }
    }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight  // T9: last button was under the Android keys
        contentHeight: col.implicitHeight + 30
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 2 * S.margin
            x: S.margin
            spacing: S.gap

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }

            EhBackLink {
                text: '‹ ' + qsTr('Settings')
                onClicked: app.stack.pop()
            }
            EhTitle {
                text: qsTr('PIN for big payments')
                icon: 'eh_lock.svg'
            }
            EhSheet {
                bottomPadding: app.ehDoubleOn() ? 14 : 0
                EhRow {
                    text: qsTr('PIN for big payments')
                    hint: qsTr('like a contactless card: below the threshold the coin is enough')
                    showSwitch: true
                    last: !app.ehDoubleOn()
                    checked: app.ehDoubleOn()
                    onToggled: (on) => app.ehSetOption('double', on)
                }
                ColumnLayout {
                    visible: app.ehDoubleOn()
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 10
                    EhCaption { text: qsTr('Ask the PIN from'); Layout.topMargin: 8; Layout.bottomMargin: 0 }
                    Label {
                        visible: app.ehBtcOnly()
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: 17
                        lineHeight: 1.1
                        color: S.ink
                        text: qsTr('<b>20%</b> of the balance (with "Only bitcoin" there is no value in %1).').arg(app.ehCcyName())
                    }
                    Flow {
                        visible: !app.ehBtcOnly()
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: [50, 100, 200, 500].map(function(x) { return x * app.ehCcyMult() })
                            delegate: Chip {
                                required property int modelData
                                on: app.ehDoubleEur() === modelData
                                text: app.ehGroup('' + modelData) + ' ' + app.ehSym()
                                onPicked: app.ehSetDoubleEur(modelData)
                            }
                        }
                        Rectangle {
                            id: otherBox
                            readonly property bool other: [50, 100, 200, 500].map(function(x) { return x * app.ehCcyMult() }).indexOf(app.ehDoubleEur()) < 0
                            width: 168      // fixed: the empty field has no width of its own
                            height: 48
                            radius: 14
                            border.width: other ? 0 : (otherF.activeFocus ? 2.5 : 2)
                            border.color: otherF.activeFocus ? S.wine : S.edge
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: otherBox.other ? S.leatherWine1 : S.paper }
                                GradientStop { position: 0.7; color: otherBox.other ? S.leatherWine2 : S.paper }
                                GradientStop { position: 1.0; color: otherBox.other ? S.leatherWine3 : S.paper }
                            }
                            TextInput {
                                id: otherF
                                anchors.centerIn: parent
                                width: 150
                                horizontalAlignment: TextInput.AlignHCenter
                                text: [50, 100, 200, 500].map(function(x) { return x * app.ehCcyMult() }).indexOf(app.ehDoubleEur()) < 0 ? '' + app.ehDoubleEur() : ''
                                inputMethodHints: Qt.ImhDigitsOnly
                                validator: IntValidator { bottom: 1; top: 1000000 }
                                font.family: BodyFont ? BodyFont : font.family
                                font.pixelSize: 17
                                font.bold: true
                                color: otherBox.other ? S.ivory : S.ink
                                onEditingFinished: if (text !== '') app.ehSetDoubleEur(parseInt(text))
                                Label {
                                    // our own hint: it stays in place and goes away while typing
                                    anchors.centerIn: parent
                                    visible: otherF.text === '' && !otherF.activeFocus
                                    text: qsTr('other amount…')
                                    font.family: BodyFont ? BodyFont : font.family
                                    font.pixelSize: 17
                                    color: S.muted
                                }
                            }
                        }
                    }
                }
            }

        }
    }
}
