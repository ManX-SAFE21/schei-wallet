// Easy Heirs (schȅi): "I tuoi schȅi", the balance as real money on a table.
// Every banknote is drawn (100, 50, 20, 10, 5), slightly overlapped, in real
// euro proportions; then the coins. Many 100s are grouped in bundles of
// 1,000 euro (10 notes with the paper strap). Still picture, no animations.
// Look: "Bottega" (parchment, the "table" is a paper sheet); the drawings are not changed.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls/EhMoney.js" as Money
import "controls/EhStyle.js" as S
import "controls"

Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: S.ink

    property int cents: 0
    property real demoEuro: -1      // previews only
    // T48: the notes and coins of the currency (euro or US dollar)
    readonly property string ccy: app.ehCcy()
    readonly property var noteMm: Money.table(ccy).noteMm
    readonly property var coinMm: Money.table(ccy).coinMm
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
        var notes = Money.table(page.ccy).notes
        for (var i = 0; i < notes.length; i++) {
            var n = Math.floor(rest / notes[i])
            if (n > 0) { out.push({ kind: 'note', value: notes[i], count: n }); rest -= n * notes[i] }
        }
        var coins = [], coinTot = 0, cv = Money.table(page.ccy).coins
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
        return app.ehSym() + ' ' + grp(Math.floor(c / 100)) + app.ehLocale().decimalPoint + ('0' + (c % 100)).slice(-2)
    }

    Rectangle { anchors.fill: parent; color: S.parch }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 14 + app.navigationBarHeight
        spacing: 8

        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
        EhBackLink { onClicked: app.stack.pop() }
        EhTitle { text: qsTr('Your money') }
        Flow {
            Layout.fillWidth: true
            spacing: 10
            Label {
                id: totalL
                text: page.euroText(page.cents)
                color: S.wineDark
                font.family: SerifFont ? SerifFont : font.family
                font.weight: Font.ExtraBold
                font.pixelSize: 36
            }
            Label {
                height: totalL.height - 6
                verticalAlignment: Text.AlignBottom
                text: Daemon.currentWallet ? qsTr('about %1').arg(app.ehBtc(Daemon.currentWallet.ehTotal)) : ''
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
            }
        }

        // ===== the table: a paper sheet =====
        Rectangle {
            id: table
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.bottomMargin: 3
            color: S.paper
            radius: 18
            border.width: 1.5
            border.color: S.edge
            // hard shadow
            Rectangle {
                z: -1
                y: 3
                width: parent.width
                height: parent.height
                radius: parent.radius
                color: S.edgeShadow
            }
            Flickable {
                anchors.fill: parent
                anchors.margins: 10
                clip: true
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
                                color: S.oliveInk
                                font.family: BodyFont ? BodyFont : font.family
                                font.pixelSize: 16
                                font.bold: true
                                text: gd.modelData.kind === 'bundle'
                                      ? qsTr('%1 × bundle of %2').arg(gd.modelData.count).arg('1.000 ' + app.ehSym()) + ' <font color="#5a4c44">' + qsTr('(10 notes of 100)') + '</font>'
                                      : gd.modelData.kind === 'note'
                                        ? gd.modelData.count + ' × ' + (gd.modelData.value / 100) + ' ' + app.ehSym() + ' <font color="#5a4c44">= ' + page.grp(gd.modelData.count * gd.modelData.value / 100) + ' ' + app.ehSym() + '</font>'
                                        : qsTr('Coins') + ' <font color="#5a4c44">= ' + page.euroText(gd.modelData.value).replace(app.ehSym() + ' ', '') + ' ' + app.ehSym() + '</font>'
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
                                                text: '1.000 ' + app.ehSym()
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
            text: qsTr('The value in %1 changes with the bitcoin price.').arg(app.ehCcyName())
            color: S.muted
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 16
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
