// Easy Heirs (schȅi): "Cerca più indirizzi" (Electrum's gap limit, on the desktop
// only from the console: wallet.change_gap_limit). Electrum looks at the
// addresses in order and stops after 20 empty ones in a row; money beyond them
// is not seen. Here the person can look further: 50, 100, 200...
// "Bottega" look (WP4): explanations in info boxes, the choices as paper tabs
// (the chosen one in wine leather), the result in a green tip box.
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

    property int current: Daemon.currentWallet ? Daemon.currentWallet.ehGapLimit() : 20
    property string state_: ''          // '' | 'searching' | 'done' | 'too_low'
    property var balanceBefore
    property int minGap: 0

    function choose(n) {
        if (!Daemon.currentWallet || n === current) return
        balanceBefore = Config.unitsToSats((Daemon.currentWallet.totalBalance.satsInt / 100000000).toFixed(8))
        var ok = Daemon.currentWallet.ehSetGapLimit(n)
        if (!ok) {
            minGap = Daemon.currentWallet.ehMinGapLimit()
            state_ = 'too_low'
            return
        }
        current = n
        state_ = 'searching'
        searchStart = Date.now()
        doneTimer.restart()
    }
    // second review (RN-3): "Done" only when the wallet is connected and has really finished
    // looking (at least 4 seconds, so the person sees that something happened)
    property real searchStart: 0
    Timer {
        id: doneTimer
        interval: 1000
        repeat: true
        onTriggered: {
            var w = Daemon.currentWallet
            if (Date.now() - page.searchStart >= 4000 && Network.isConnected && w && !w.synchronizing) {
                stop()
                page.state_ = 'done'
            }
        }
    }

    Rectangle { anchors.fill: parent; color: S.parch }

    component Note: EhInfoBox {
        kind: 'warn'
    }

    // a choice: paper tab, the chosen one in wine leather
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
            EhTitle { text: qsTr('Look at more addresses') }

            Note {
                text: qsTr('<b>What it is for.</b> The wallet has a long row of addresses, always the same, born from the 12 words. To find your money Schȅi looks at them <b>one after the other</b>, and stops when it finds <b>%1 empty in a row</b>: it thinks there is nothing after.').arg(20)   // always explain the normal value
            }
            // the row of addresses: used, empty, and money hidden after many empty ones
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                spacing: 4
                Repeater {
                    model: 14
                    Rectangle {
                        required property int index
                        width: 20; height: 20; radius: 4
                        color: index < 3 ? S.olive : (index === 13 ? S.gold : S.switchOff)
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
                lineHeight: 1.1
                color: S.muted
                text: qsTr('green = used · grey = empty · gold = money that is <b>after</b> many empty ones')
            }
            Note {
                text: qsTr('<b>When it is needed.</b> If the 12 words were also used in another wallet that created many addresses without using them, the money can be after more than 20 empty addresses. Schȅi does not see it and the balance seems to be missing. Looking further finds it.')
            }

            EhCaption { text: qsTr('Look up to'); Layout.topMargin: 6; Layout.bottomMargin: 0 }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [20, 50, 100, 200]
                    Chip {
                        required property int modelData
                        on: page.current === modelData
                        text: modelData === 20 ? qsTr('20 (normal)') : '' + modelData
                        onPicked: page.choose(modelData)
                    }
                }
                Rectangle {
                    id: otherBox
                    width: 168
                    height: 48
                    radius: 14
                    readonly property bool other: [20, 50, 100, 200].indexOf(page.current) < 0
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
                        text: parent.other ? '' + page.current : ''
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 1; top: 5000 }
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: 17
                        font.bold: true
                        color: parent.other ? S.ivory : S.ink
                        onEditingFinished: if (text !== '') page.choose(parseInt(text))
                        Label {
                            anchors.centerIn: parent
                            visible: otherF.text === '' && !otherF.activeFocus
                            text: qsTr('other amount…')
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 17; color: S.muted
                        }
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                wrapMode: Text.WordWrap
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
                lineHeight: 1.1
                color: S.muted
                text: qsTr('It does not change your money and costs nothing. The further it looks, the more time it takes to update the balance. If it is not needed, leave 20.')
            }

            // result
            EhInfoBox {
                visible: page.state_ === 'searching' || page.state_ === 'done'
                kind: 'tip'
                title: page.state_ === 'searching' ? qsTr('Looking…') : qsTr('Done') + ' ✓'
                text: page.state_ === 'searching'
                      ? (Network.isConnected ? qsTr('I look at %1 addresses instead of 20').arg(page.current)
                                             : qsTr('Not connected to the internet: I start as soon as you are connected.'))
                      : (page.state_ === 'done' ? qsTr('Balance updated: <b>%1</b> (before %2)').arg(app.ehMoney(Daemon.currentWallet.totalBalance)).arg(page.balanceBefore ? app.ehMoney(page.balanceBefore) : '') : '')
            }
            Note {
                visible: page.state_ === 'done'
                text: qsTr('If the balance did not change, the money is not here: try with 100 or 200, or check that the 12 words and the kind of seed are right.')
            }
            Note {
                visible: page.state_ === 'too_low'
                text: qsTr('It cannot go below <b>%1</b>: your addresses already used need at least that many.').arg(page.minGap)
            }
        }
    }
}
