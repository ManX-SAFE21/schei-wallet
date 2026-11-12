// Easy Heirs (schèi): amount with banknotes and coins (euro or US dollar, owner 12/11).
// Tapping a note or a coin makes it fly onto the heap in the purse
// ("gruzzoletto"); the total and how many of each kind are shown beside it.
// Notes and coins keep the real euro proportions (the 50 is the biggest note,
// the 1 cent the smallest coin). With "Animations" off they land at once.
// Output: euroInput, the same text the number keypad makes ("57" or "57,50").
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "EhMoney.js" as Money

Item {
    id: pad

    property string euroInput: ''
    property int cents: 0
    property var counts: ({})
    readonly property bool animate: !app.ehOption('no_anim')

    // owner 12/11: the notes and coins of the chosen currency (euro or US dollar), EhMoney.js
    readonly property string ccy: app.ehCcy()
    readonly property var noteValues: Money.table(ccy).notes
    readonly property var coinValues: Money.table(ccy).coins
    readonly property var noteMm: Money.table(ccy).noteMm
    readonly property var coinMm: Money.table(ccy).coinMm
    readonly property real maxW: Money.maxNoteW(ccy)
    readonly property real maxH: Money.maxNoteH(ccy)
    readonly property real maxC: Money.maxCoinMm(ccy)

    // ---------- sizes (shrink everything together on short screens) ----------
    // roomy: notes 2 x 2, coins 4 x 2.  Short screen: notes 4 in a row, coins 8 in a row.
    readonly property real gap: 8
    // short screen (e.g. "Bigger text"): notes in one row and a lower purse
    readonly property real roomFull: height - 176 - 4 * gap
    readonly property bool compact: roomFull < 0.95 * (2 * noteH(3) + coinKFor(8) * maxC)
    readonly property real purseH: compact ? 150 : 176
    readonly property real room: height - purseH - 4 * gap
    function noteH(cols) { return ((width - (cols - 1) * gap) / cols) * pad.maxH / pad.maxW }
    function coinKFor(cols) { return Math.min(2.45, ((width - (cols - 1) * gap) / cols) / (pad.maxC + 1)) }
    readonly property int noteCols: compact ? noteValues.length : 3
    readonly property int coinCols: Math.max(4, coinValues.length)
    readonly property real natNoteH: noteH(noteCols)
    readonly property real natCoinK: coinKFor(coinCols)
    readonly property real fit: Math.max(0.6, Math.min(1, room / ((compact ? 1 : 2) * natNoteH + natCoinK * maxC)))
    readonly property real noteK: (natNoteH * fit) / pad.maxH  // pixels per mm, notes
    readonly property real coinK: natCoinK * fit             // pixels per mm, coins

    function isNote(c) { return noteValues.indexOf(c) >= 0 }

    function update() {
        var e = Math.floor(cents / 100), r = cents % 100
        euroInput = cents === 0 ? '' : (r === 0 ? '' + e : e + ',' + (r < 10 ? '0' : '') + r)
    }
    function heapSpot(c) {
        var n = heapModel.count
        if (isNote(c)) {
            var w = Math.round(96 * noteMm[c][0] / pad.maxW), h = Math.round(96 * noteMm[c][1] / pad.maxW)
            return { x: 10 + (96 - w) / 2 + (n % 3) * 3, y: 54 - Math.min(n, 10) * 3, w: w, h: h, rot: (n % 2 ? -1 : 1) * (4 + n % 5) }
        }
        var k = 0
        for (var i = 0; i < heapModel.count; i++) if (!isNote(heapModel.get(i).c)) k++
        var s = Math.round(coinMm[c] * 1.35)
        return { x: 10 + (k * 37) % 74, y: 12 + (k * 23) % 60, w: s, h: s, rot: 0 }
    }
    function add(c, src) {
        if (cents + c > 9999999) return
        var cc = Object.assign({}, counts); cc[c] = (cc[c] || 0) + 1; counts = cc
        cents += c
        var s = heapSpot(c)
        var p = src.mapToItem(heap, 0, 0)
        heapModel.append({ c: c, tx: s.x, ty: s.y, tw: s.w, th: s.h, trot: s.rot,
                           fx: p.x, fy: p.y, fw: src.width, fh: src.height, fly: animate, going: false })
        update()
    }
    // T28 (owner): taking a note or coin back is animated too: it flies back to its place
    function removeOne(c) {
        var found = -1
        for (var i = heapModel.count - 1; i >= 0; i--) {
            var e = heapModel.get(i)
            if (e.c === c && !e.going) { found = i; break }
        }
        if (found < 0) return
        var cc = Object.assign({}, counts); cc[c] = Math.max(0, (cc[c] || 0) - 1); counts = cc
        cents = Math.max(0, cents - c)
        update()
        var item = heapRep.itemAt(found)
        if (animate && item) {
            heapModel.setProperty(found, 'going', true)
            item.flyBack()
        } else {
            heapModel.remove(found)
        }
    }
    function removeLast() {
        for (var i = heapModel.count - 1; i >= 0; i--)
            if (!heapModel.get(i).going) { removeOne(heapModel.get(i).c); return }
    }
    function clear() {
        heapModel.clear()
        counts = ({})
        cents = 0
        update()
    }

    ListModel { id: heapModel }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: pad.gap

        // ===== the purse =====
        Rectangle {
            id: purse
            z: 5
            Layout.fillWidth: true
            Layout.preferredHeight: pad.purseH
            radius: 22
            gradient: Gradient {
                GradientStop { position: 0; color: '#7a2645' }
                GradientStop { position: 1; color: '#3f0f21' }
            }
            Label {
                x: 14; y: 10
                text: qsTr('Your little stash')
                color: Qt.rgba(1, 1, 1, 0.85)
                font.pixelSize: 13
            }
            Item {
                id: heap
                x: 12; y: 30
                width: 118; height: pad.purseH - 56
                Rectangle { anchors.fill: parent; radius: 16; color: heapTap.pressed ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08) }
                TapHandler { id: heapTap; onTapped: pad.removeLast() }
                Label {
                    visible: heapModel.count > 0
                    anchors.top: parent.bottom
                    anchors.topMargin: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr('tap: take the last one back')
                    color: Qt.rgba(1, 1, 1, 0.85)
                    font.pixelSize: 11
                    font.bold: true
                }
                Label {
                    visible: heapModel.count === 0
                    anchors.fill: parent; anchors.margins: 8
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    text: qsTr('the money you put in lands here')
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: 12
                }
                Repeater {
                    id: heapRep
                    model: heapModel
                    delegate: Item {
                        id: hi
                        required property int index
                        required property int c
                        required property real tx
                        required property real ty
                        required property real tw
                        required property real th
                        required property real trot
                        required property real fx
                        required property real fy
                        required property real fw
                        required property real fh
                        required property bool fly
                        z: index + 1
                        Loader {
                            anchors.fill: parent
                            sourceComponent: pad.isNote(hi.c) ? noteC : coinC
                        }
                        Component { id: noteC; EhNote { c: hi.c; ccy: pad.ccy } }
                        Component { id: coinC; EhCoin { c: hi.c; ccy: pad.ccy } }
                        ParallelAnimation {
                            id: flyAnim
                            NumberAnimation { target: hi; property: 'x'; to: hi.tx; duration: 460; easing.type: Easing.OutCubic }
                            NumberAnimation { target: hi; property: 'y'; to: hi.ty; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
                            NumberAnimation { target: hi; property: 'width'; to: hi.tw; duration: 460; easing.type: Easing.OutCubic }
                            NumberAnimation { target: hi; property: 'height'; to: hi.th; duration: 460; easing.type: Easing.OutCubic }
                            NumberAnimation { target: hi; property: 'rotation'; to: hi.trot; duration: 460 }
                        }
                        // T28: back to where it came from, then it leaves the heap
                        function flyBack() { flyAnim.stop(); backAnim.start() }
                        SequentialAnimation {
                            id: backAnim
                            ParallelAnimation {
                                NumberAnimation { target: hi; property: 'x'; to: hi.fx; duration: 380; easing.type: Easing.InOutCubic }
                                NumberAnimation { target: hi; property: 'y'; to: hi.fy; duration: 380; easing.type: Easing.InOutCubic }
                                NumberAnimation { target: hi; property: 'width'; to: hi.fw; duration: 380 }
                                NumberAnimation { target: hi; property: 'height'; to: hi.fh; duration: 380 }
                                NumberAnimation { target: hi; property: 'rotation'; to: 0; duration: 380 }
                            }
                            NumberAnimation { target: hi; property: 'opacity'; to: 0; duration: 120 }
                            ScriptAction { script: heapModel.remove(hi.index) }
                        }
                        Component.onCompleted: {
                            if (fly) {
                                x = fx; y = fy; width = fw; height = fh; rotation = 0
                                flyAnim.start()
                            } else {
                                x = tx; y = ty; width = tw; height = th; rotation = trot
                            }
                        }
                    }
                }
            }
            ColumnLayout {
                anchors.left: heap.right; anchors.leftMargin: 10
                anchors.right: parent.right; anchors.rightMargin: 10
                anchors.top: parent.top; anchors.topMargin: 46
                anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    text: app.ehSym() + ' ' + app.ehGroup('' + Math.floor(pad.cents / 100)) + app.ehLocale().decimalPoint + ('0' + (pad.cents % 100)).slice(-2)
                    color: '#ffffff'
                    font.family: TitleFont ? TitleFont : font.family
                    font.weight: Font.Black
                    font.pixelSize: 30
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 18
                }
                Label {
                    Layout.fillWidth: true
                    text: pad.cents > 0 ? qsTr('about %1').arg(app.ehBtc(Config.unitsToSats(((parseInt(Daemon.fx.satoshiValue((pad.cents / 100).toFixed(2), true)) || 0) / 100000000).toFixed(8))))
                                        : qsTr('tap notes and coins')
                    color: Qt.rgba(1, 1, 1, 0.8)
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: chips.implicitHeight
                    clip: true
                    Flow {
                        id: chips
                        width: parent.width
                        spacing: 5
                        Repeater {
                            model: pad.noteValues.concat(pad.coinValues)
                            delegate: Rectangle {
                                id: chip
                                required property int modelData
                                visible: (pad.counts[modelData] || 0) > 0
                                width: visible ? chipRow.implicitWidth + 12 : 0
                                height: visible ? 26 : 0
                                radius: 13
                                color: chipTap.pressed ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.14)
                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Loader {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: pad.isNote(chip.modelData) ? 26 : 18
                                        height: pad.isNote(chip.modelData) ? 15 : 18
                                        sourceComponent: pad.isNote(chip.modelData) ? miniNote : miniCoin
                                        Component { id: miniNote; EhNote { c: chip.modelData; ccy: pad.ccy } }
                                        Component { id: miniCoin; EhCoin { c: chip.modelData; ccy: pad.ccy } }
                                    }
                                    Label { anchors.verticalCenter: parent.verticalCenter; text: '×' + (pad.counts[chip.modelData] || 0); color: '#ffffff'; font.pixelSize: 13; font.bold: true }
                                    Label { anchors.verticalCenter: parent.verticalCenter; text: '−'; color: Qt.rgba(1, 1, 1, 0.7); font.pixelSize: 15; font.bold: true }
                                }
                                TapHandler { id: chipTap; margin: 3; onTapped: pad.removeOne(chip.modelData) }
                            }
                        }
                    }
                }
            }
            // "Azzera": big enough to hit, above every text
            Rectangle {
                z: 10
                anchors.right: parent.right; anchors.rightMargin: 8
                anchors.top: parent.top; anchors.topMargin: 6
                width: clrRow.implicitWidth + 26
                height: 40
                radius: 20
                color: clrTap.pressed ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(1, 1, 1, 0.22)
                border.width: 1.5
                border.color: Qt.rgba(1, 1, 1, 0.45)
                scale: clrTap.pressed ? 0.96 : 1
                Row {
                    id: clrRow
                    anchors.centerIn: parent
                    spacing: 6
                    Image { anchors.verticalCenter: parent.verticalCenter; source: Qt.resolvedUrl('../../../icons/eh_undo_white.svg'); sourceSize.width: 18; sourceSize.height: 18 }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: qsTr('Clear'); color: '#ffffff'; font.pixelSize: 15; font.bold: true }
                }
                TapHandler { id: clrTap; margin: 8; onTapped: pad.clear() }
            }
        }

        // ===== banknotes, real proportions =====
        GridLayout {
            Layout.fillWidth: true
            columns: pad.noteCols
            rowSpacing: pad.gap
            columnSpacing: pad.gap
            Repeater {
                model: pad.noteValues
                delegate: Item {
                    id: nCell
                    required property int modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: pad.maxH * pad.noteK
                    EhNote {
                        id: nItem
                        c: nCell.modelData
                        anchors.centerIn: parent
                        width: pad.noteMm[nCell.modelData][0] * pad.noteK
                        height: pad.noteMm[nCell.modelData][1] * pad.noteK
                        scale: nTap.pressed ? 0.96 : 1
                        TapHandler { id: nTap; onTapped: pad.add(nCell.modelData, nItem) }
                    }
                }
            }
        }

        // ===== coins, real proportions =====
        GridLayout {
            Layout.fillWidth: true
            columns: pad.coinCols
            rowSpacing: pad.gap
            columnSpacing: pad.gap
            Repeater {
                model: pad.coinValues
                delegate: Item {
                    id: cCell
                    required property int modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: pad.maxC * pad.coinK
                    EhCoin {
                        id: cItem
                        c: cCell.modelData
                        anchors.centerIn: parent
                        width: pad.coinMm[cCell.modelData] * pad.coinK
                        height: width
                        scale: cTap.pressed ? 0.92 : 1
                        TapHandler { id: cTap; margin: 4; onTapped: pad.add(cCell.modelData, cItem) }
                    }
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
