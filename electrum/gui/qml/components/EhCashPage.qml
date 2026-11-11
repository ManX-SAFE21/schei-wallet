// Easy Heirs (schèi): "I tuoi schèi", the balance as real money on a table.
// Every banknote is drawn (100, 50, 20, 10, 5), slightly overlapped, in real
// euro proportions; then the coins. Many 100s are grouped in bundles of
// 1,000 euro (10 notes with the paper strap). Still picture, no animations.
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

    property int cents: 0
    property real demoEuro: -1      // previews only
    readonly property var noteMm: ({ 10000: [147, 77], 5000: [140, 77], 2000: [133, 72], 1000: [127, 67], 500: [120, 62] })
    readonly property var coinMm: ({ 200: 25.75, 100: 23.25, 50: 24.25, 20: 22.25, 10: 19.75, 5: 21.25, 2: 18.75, 1: 16.25 })
    readonly property real tableW: table.width - 20
    readonly property real k: tableW * 0.36 / 147      // pixels per mm, notes
    readonly property real ck: tableW / 200             // pixels per mm, coins

    // how the money is split: [{kind, value, count}]
    property var groups: []

    function grp(n) { return app.ehGroup('' + n) }
    function refresh() {
        if (demoEuro < 0 && (!Daemon.currentWallet || !Daemon.fx.enabled)) { cents = 0; groups = []; return }
        var v = demoEuro >= 0 ? demoEuro : Number(Daemon.fx.fiatValue(Daemon.currentWallet.ehTotal, true))
        cents = isNaN(v) ? 0 : Math.max(0, Math.round(v * 100))
        var rest = cents, out = []
        if (Math.floor(rest / 10000) > 20) {
            var b = Math.floor(rest / 100000)
            out.push({ kind: 'bundle', value: 100000, count: b })
            rest -= b * 100000
        }
        var notes = [10000, 5000, 2000, 1000, 500]
        for (var i = 0; i < notes.length; i++) {
            var n = Math.floor(rest / notes[i])
            if (n > 0) { out.push({ kind: 'note', value: notes[i], count: n }); rest -= n * notes[i] }
        }
        var coins = [], coinTot = 0, cv = [200, 100, 50, 20, 10, 5, 2, 1]
        for (var j = 0; j < cv.length; j++) {
            var m = Math.floor(rest / cv[j])
            for (var q = 0; q < m; q++) coins.push(cv[j])
            coinTot += m * cv[j]
            rest -= m * cv[j]
        }
        if (coins.length) out.push({ kind: 'coins', value: coinTot, list: coins })
        groups = out
    }
    function euroText(c) {
        return '€ ' + grp(Math.floor(c / 100)) + app.ehLocale().decimalPoint + ('0' + (c % 100)).slice(-2)
    }

    Rectangle {
        anchors.fill: parent
        color: '#faf7ef'
        EhGlow { tone: 'wine'; z: 0; x: -parent.width * 0.25; y: 30; width: parent.width * 1.5; height: 340; opacity: 0.8 }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 14 + app.navigationBarHeight
        spacing: 8

        EhPageTop { title: '' }
        Label {
            Layout.topMargin: -14
            text: '‹ ' + qsTr('Back')
            color: '#5e1a33'; font.pixelSize: 17; font.bold: true
            TapHandler { margin: 10; onTapped: app.stack.pop() }
        }
        Label {
            text: qsTr('Your money')
            color: '#5e1a33'
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 26
        }
        Flow {
            Layout.fillWidth: true
            spacing: 10
            Label {
                text: page.euroText(page.cents)
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 34
            }
            Label {
                height: 40
                verticalAlignment: Text.AlignBottom
                text: Daemon.currentWallet ? qsTr('about %1').arg(app.ehBtc(Daemon.currentWallet.ehTotal)) : ''
                color: '#6b5d55'
                font.pixelSize: 14
            }
        }

        // ===== the green table =====
        Rectangle {
            id: table
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: 'transparent'
            clip: true
            EhGlow { tone: 'green'; z: 0; anchors.fill: parent; anchors.margins: -4 }
            Flickable {
                anchors.fill: parent
                anchors.margins: 10
                contentHeight: groupsCol.implicitHeight + 6
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: groupsCol
                    width: parent.width
                    spacing: 12
                    Repeater {
                        model: page.groups
                        delegate: Column {
                            id: gd
                            required property var modelData
                            width: groupsCol.width
                            spacing: 6
                            Label {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                textFormat: Text.StyledText
                                color: '#2f3a12'
                                font.pixelSize: 15
                                font.bold: true
                                text: gd.modelData.kind === 'bundle'
                                      ? qsTr('%1 × bundle of %2').arg(gd.modelData.count).arg('1.000 €') + ' <font color="#6b5d55">' + qsTr('(10 notes of 100)') + '</font>'
                                      : gd.modelData.kind === 'note'
                                        ? gd.modelData.count + ' × ' + (gd.modelData.value / 100) + ' € <font color="#6b5d55">= ' + page.grp(gd.modelData.count * gd.modelData.value / 100) + ' €</font>'
                                        : qsTr('Coins') + ' <font color="#6b5d55">= ' + page.euroText(gd.modelData.value).replace('€ ', '') + ' €</font>'
                            }
                            // bundles of 1,000 euro
                            Flow {
                                visible: gd.modelData.kind === 'bundle'
                                width: parent.width
                                spacing: 10
                                Repeater {
                                    model: gd.modelData.kind === 'bundle' ? gd.modelData.count : 0
                                    delegate: Item {
                                        width: 147 * page.k + 6
                                        height: 77 * page.k + 6
                                        Repeater {
                                            model: 4
                                            delegate: EhNote {
                                                required property int index
                                                c: 10000
                                                x: index * 2; y: (3 - index) * 2
                                                width: 147 * page.k; height: 77 * page.k
                                            }
                                        }
                                        Rectangle {
                                            x: parent.width * 0.42; width: parent.width * 0.2; height: parent.height
                                            color: '#f4ecd8'; radius: 2
                                            border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.15)
                                            Label {
                                                anchors.centerIn: parent
                                                rotation: -90
                                                text: '1.000 €'
                                                color: '#3f0f21'
                                                font.family: TitleFont ? TitleFont : font.family
                                                font.weight: Font.Black
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                }
                            }
                            // banknotes in rows, overlapped so each one shows
                            Column {
                                id: rowsCol
                                visible: gd.modelData.kind === 'note'
                                spacing: 5
                                readonly property real nw: gd.modelData.kind === 'note' ? page.noteMm[gd.modelData.value][0] * page.k : 0
                                readonly property real nh: gd.modelData.kind === 'note' ? page.noteMm[gd.modelData.value][1] * page.k : 0
                                readonly property real step: nw * (gd.modelData.value >= 10000 ? 0.48 : 0.42)
                                readonly property int maxRow: Math.max(1, Math.floor((gd.width - nw) / Math.max(1, step)) + 1)
                                readonly property int n: gd.modelData.kind === 'note' ? gd.modelData.count : 0
                                readonly property int rows: Math.ceil(n / maxRow)
                                readonly property int perRow: rows > 0 ? Math.ceil(n / rows) : 0
                                Repeater {
                                    model: rowsCol.rows
                                    delegate: Item {
                                        id: rowItem
                                        required property int index
                                        readonly property int inRow: Math.min(rowsCol.perRow, rowsCol.n - index * rowsCol.perRow)
                                        width: rowsCol.nw + (inRow - 1) * rowsCol.step
                                        height: rowsCol.nh
                                        Repeater {
                                            model: rowItem.inRow
                                            delegate: EhNote {
                                                required property int index
                                                c: gd.modelData.value
                                                x: index * rowsCol.step
                                                width: rowsCol.nw; height: rowsCol.nh
                                            }
                                        }
                                    }
                                }
                            }
                            // coins, real proportions
                            Flow {
                                visible: gd.modelData.kind === 'coins'
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: gd.modelData.kind === 'coins' ? gd.modelData.list : []
                                    delegate: EhCoin {
                                        required property int modelData
                                        c: modelData
                                        width: page.coinMm[modelData] * page.ck
                                        height: width
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr('The euro value changes with the bitcoin price.')
            color: '#4a4038'
            font.pixelSize: 14
        }
    }

    Connections {
        target: Daemon.currentWallet
        function onBalanceChanged() { page.refresh() }
    }
    Connections {
        target: Daemon.fx
        function onQuotesUpdated() { page.refresh() }
    }
    Component.onCompleted: refresh()
}
