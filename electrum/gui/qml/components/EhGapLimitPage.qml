// Easy Heirs (schèi): "Cerca più indirizzi" (Electrum's gap limit, on the desktop
// only from the console: wallet.change_gap_limit). Electrum looks at the
// addresses in order and stops after 20 empty ones in a row; money beyond them
// is not seen. Here the person can look further: 50, 100, 200...
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

    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    EhGlow { tone: 'green'; x: -page.width * 0.3; y: 40; width: page.width * 1.6; height: 380; opacity: 0.6 }

    component Note: Rectangle {
        property alias text: nL.text
        Layout.fillWidth: true
        Layout.preferredHeight: nL.implicitHeight + 22
        radius: 14
        color: Qt.rgba(0.98, 0.94, 0.84, 0.92)
        Label {
            id: nL
            x: 11; y: 11
            width: parent.width - 22
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            font.pixelSize: 14
            lineHeight: 1.1
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
                text: qsTr('Look at more addresses')
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 26
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Note {
                text: qsTr('<b>What it is for.</b> The wallet has a long row of addresses, always the same, born from the 12 words. To find your money Schèi looks at them <b>one after the other</b>, and stops when it finds <b>%1 empty in a row</b>: it thinks there is nothing after.').arg(20)   // always explain the normal value
            }
            // the row of addresses: used, empty, and money hidden after many empty ones
            Flow {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: 14
                    Rectangle {
                        required property int index
                        width: 18; height: 18; radius: 4
                        color: index < 3 ? '#cfdca0' : (index === 13 ? '#f0c14a' : '#e3dccf')
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                font.pixelSize: 12
                color: '#6b5d55'
                text: qsTr('green = used · grey = empty · gold = money that is <b>after</b> many empty ones')
            }
            Note {
                text: qsTr('<b>When it is needed.</b> If the 12 words were also used in another wallet that created many addresses without using them, the money can be after more than 20 empty addresses. Schèi does not see it and the balance seems to be missing. Looking further finds it.')
            }

            Label { Layout.topMargin: 4; text: qsTr('Look up to'); font.pixelSize: 14; font.bold: true; color: '#6b5d55' }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [20, 50, 100, 200]
                    Rectangle {
                        required property int modelData
                        width: chL.implicitWidth + 26
                        height: 38
                        radius: 19
                        color: page.current === modelData ? '#5e1a33' : '#efe6d3'
                        Label {
                            id: chL
                            anchors.centerIn: parent
                            text: modelData === 20 ? qsTr('20 (normal)') : '' + modelData
                            font.pixelSize: 15; font.bold: true
                            color: page.current === modelData ? '#ffffff' : '#6b5d55'
                        }
                        TapHandler { onTapped: page.choose(modelData) }
                    }
                }
                Rectangle {
                    width: 138
                    height: 38
                    radius: 19
                    readonly property bool other: [20, 50, 100, 200].indexOf(page.current) < 0
                    color: other ? '#5e1a33' : '#efe6d3'
                    TextInput {
                        id: otherF
                        anchors.centerIn: parent
                        width: 110
                        horizontalAlignment: TextInput.AlignHCenter
                        text: parent.other ? '' + page.current : ''
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 1; top: 5000 }
                        font.pixelSize: 15
                        font.bold: true
                        color: parent.other ? '#ffffff' : '#2a2220'
                        onEditingFinished: if (text !== '') page.choose(parseInt(text))
                        Label {
                            anchors.centerIn: parent
                            visible: otherF.text === '' && !otherF.activeFocus
                            text: qsTr('other amount…')
                            font.pixelSize: 15; font.bold: true; color: '#6b5d55'
                        }
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 13
                color: '#6b5d55'
                text: qsTr('It does not change your money and costs nothing. The further it looks, the more time it takes to update the balance. If it is not needed, leave 20.')
            }

            // result
            Rectangle {
                visible: page.state_ === 'searching' || page.state_ === 'done'
                Layout.fillWidth: true
                Layout.preferredHeight: resCol.implicitHeight + 24
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0; color: '#53652a' }
                    GradientStop { position: 1; color: '#344016' }
                }
                ColumnLayout {
                    id: resCol
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 2
                    Label { color: '#ffffff'; font.pixelSize: 16; font.bold: true
                            text: page.state_ === 'searching' ? qsTr('Looking…') : qsTr('Done') + ' ✓' }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        color: '#ffffff'; opacity: 0.9; font.pixelSize: 13
                        text: page.state_ === 'searching'
                              ? (Network.isConnected ? qsTr('I look at %1 addresses instead of 20').arg(page.current)
                                                     : qsTr('Not connected to the internet: I start as soon as you are connected.'))
                              : qsTr('Balance updated: <b>%1</b> (before %2)').arg(app.ehMoney(Daemon.currentWallet.totalBalance)).arg(page.balanceBefore ? app.ehMoney(page.balanceBefore) : '')
                    }
                }
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
