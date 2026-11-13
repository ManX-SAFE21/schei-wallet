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
import "EhStyle.js" as S

Item {
    id: pad

    property string euroInput: ''
    property int cents: 0
    property var counts: ({})
    readonly property bool animate: !app.ehOption('no_anim')
    // owner 13/11: big notes (3 in a row) at BASE and MEDIO, the page scrolls if needed;
    // false (ESPERTO) = notes may shrink into one row on short screens
    property bool bigNotes: true

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
    readonly property bool compact: !bigNotes && roomFull < 0.95 * (2 * noteH(3) + coinKFor(8) * maxC)
    readonly property real purseH: compact ? 150 : 176
    // owner 13/11: the purse grows with the rows of chips (none is cut any more)
    readonly property real purseRealH: Math.max(purseH, 46 + rightCol.implicitHeight + 10)
    readonly property real room: height - purseRealH - 4 * gap
    function noteH(cols) { return ((width - (cols - 1) * gap) / cols) * pad.maxH / pad.maxW }
    function coinKFor(cols) { return Math.min(2.45, ((width - (cols - 1) * gap) / cols) / (pad.maxC + 1)) }
    readonly property int noteCols: compact ? noteValues.length : 3
    readonly property int coinCols: Math.max(4, coinValues.length)
    readonly property real natNoteH: noteH(noteCols)
    readonly property real natCoinK: coinKFor(coinCols)
    readonly property real fit: bigNotes ? 1 : Math.max(0.6, Math.min(1, room / ((compact ? 1 : 2) * natNoteH + natCoinK * maxC)))
    readonly property int noteRows: Math.ceil(noteValues.length / noteCols)
    // the height it needs: big notes = all of it (the page scrolls), else the smallest
    implicitHeight: bigNotes ? purseRealH + noteRows * natNoteH + (noteRows - 1) * gap + natCoinK * maxC + 3 * gap
                             : purseRealH + 3 * gap + 0.6 * (noteH(noteValues.length) + coinKFor(coinCols) * maxC)
    readonly property real noteK: (natNoteH * fit) / pad.maxH  // pixels per mm, notes
    readonly property real coinK: natCoinK * fit             // pixels per mm, coins

    function isNote(c) { return noteValues.indexOf(c) >= 0 }

    function update() {
        var e = Math.floor(cents / 100), r = cents % 100
        euroInput = cents === 0 ? '' : (r === 0 ? '' + e : e + ',' + (r < 10 ? '0' : '') + r)
    }
    // owner 13/11: the pile always sits centred inside its box (it never goes out of it)
    function heapSpot(c) {
        var n = heapModel.count
        var W = heap.width, H = heap.height
        if (isNote(c)) {
            // the biggest note fits the box with room for the pile (16 px) and the tilt
            var wMax = Math.min(W - 22, (H - 30) * pad.maxW / pad.maxH)
            var w = Math.round(wMax * noteMm[c][0] / pad.maxW), h = Math.round(wMax * noteMm[c][1] / pad.maxW)
            var up = Math.min(n, 8) * 2
            return { x: (W - w) / 2 + ((n % 3) - 1) * 3, y: (H - h - 16) / 2 + 16 - up, w: w, h: h,
                     rot: (n % 2 ? -1 : 1) * (3 + n % 4) }
        }
        var k = 0
        for (var i = 0; i < heapModel.count; i++) if (!isNote(heapModel.get(i).c)) k++
        var s = Math.round(Math.min(coinMm[c] * 1.35, H * 0.5))
        var spots = [[0, 0], [-0.8, -0.7], [0.8, 0.6], [-0.7, 0.8], [0.75, -0.8], [0, -1], [0, 1], [-1, 0], [1, 0]]
        var sp = spots[k % spots.length]
        var dx = (W - s) / 2 - 6, dy = (H - s) / 2 - 4
        return { x: (W - s) / 2 + sp[0] * dx, y: (H - s) / 2 + sp[1] * dy, w: s, h: s, rot: 0 }
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
            Layout.preferredHeight: pad.purseRealH
            // "Bottega" (WP1): a paper sheet with a hard shadow (was a wine purse)
            radius: 18
            color: S.paper
            border.width: 1.5
            border.color: S.edge
            Rectangle { z: -1; y: 3; width: parent.width; height: parent.height; radius: parent.radius; color: S.edgeShadow }
            Label {
                x: 14; y: 8
                width: parent.width - 150      // up to the "Clear" button
                text: qsTr('Your little stash')
                color: S.olive
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
                font.bold: true
                elide: Text.ElideRight
            }
            Item {
                id: heap
                x: 12; y: 30
                width: 118; height: pad.purseH - 74   // WP1: room for a 16 px hint on two lines under it
                Rectangle { anchors.fill: parent; radius: 14; color: heapTap.pressed ? S.sand : S.parch; border.width: 1; border.color: S.edgeShadow }
                // owner 13/11: a tap ON the notes and coins works too: this sits above the pile
                Item {
                    z: 1000
                    anchors.fill: parent
                    anchors.margins: -6
                    TapHandler { id: heapTap; onTapped: pad.removeLast() }
                }
                Label {
                    visible: heapModel.count > 0
                    anchors.top: parent.bottom
                    anchors.topMargin: 2
                    anchors.left: parent.left
                    width: parent.width + 8
                    text: qsTr('tap: take the last one back')
                    color: S.muted
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 16
                    lineHeight: 0.95
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Label {
                    visible: heapModel.count === 0
                    anchors.fill: parent; anchors.margins: 8
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    text: qsTr('the money you put in lands here')
                    color: S.muted
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 16
                    lineHeight: 1.05
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
                id: rightCol
                anchors.left: heap.right; anchors.leftMargin: 10
                anchors.right: parent.right; anchors.rightMargin: 10
                anchors.top: parent.top; anchors.topMargin: 46
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    text: app.ehSym() + ' ' + app.ehGroup('' + Math.floor(pad.cents / 100)) + app.ehLocale().decimalPoint + ('0' + (pad.cents % 100)).slice(-2)
                    color: S.wineDark
                    font.family: SerifFont ? SerifFont : font.family
                    font.weight: Font.ExtraBold
                    font.pixelSize: 30
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 18
                }
                Label {
                    Layout.fillWidth: true
                    text: pad.cents > 0 ? qsTr('about %1').arg(app.ehBtc(Config.unitsToSats(((parseInt(Daemon.fx.satoshiValue((pad.cents / 100).toFixed(2), true)) || 0) / 100000000).toFixed(8))))
                                        : qsTr('tap notes and coins')
                    color: S.muted
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 16
                    elide: Text.ElideRight
                }
                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    implicitHeight: chips.implicitHeight
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
                                height: visible ? 30 : 0
                                radius: 15
                                color: chipTap.pressed ? S.sand : S.parch
                                border.width: 1
                                border.color: S.edge
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
                                    Label { anchors.verticalCenter: parent.verticalCenter; text: '×' + (pad.counts[chip.modelData] || 0); color: S.ink; font.family: BodyFont ? BodyFont : font.family; font.pixelSize: 16; font.bold: true }
                                    Label { anchors.verticalCenter: parent.verticalCenter; text: '−'; color: S.wine; font.family: BodyFont ? BodyFont : font.family; font.pixelSize: 16; font.bold: true }
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
                color: clrTap.pressed ? S.sand : S.paper
                border.width: 1.5
                border.color: S.edge
                scale: clrTap.pressed ? 0.96 : 1
                Row {
                    id: clrRow
                    anchors.centerIn: parent
                    spacing: 6
                    Image { anchors.verticalCenter: parent.verticalCenter; source: Qt.resolvedUrl('../../../icons/eh_undo.svg'); sourceSize.width: 18; sourceSize.height: 18 }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: qsTr('Clear'); color: S.wine; font.family: BodyFont ? BodyFont : font.family; font.pixelSize: 16; font.bold: true }
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
