// Easy Heirs (schèi): the two pockets of the advanced privacy (T20 step 2).
// "Da spendere" = coins the app may use; "Da parte" = blocked coins (frozen).
// Coins that sit on the same address are kept together in a dashed "sacchetto":
// moving the whole sacchetto aside blocks the ADDRESS (Electrum's freeze address).
// Tap = tick, then the button at the bottom; or press, hold and drag to the other
// pocket. More than 8 coins: compact look (3 per row, blocked addresses folded).
// All the wallet work is done by QEWallet.ehAddresses / ehPocketMove.
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

    // demo: fake coins for the PC previews (no wallet call is made)
    property bool demo: false
    property var items: []          // addresses, as QEWallet.ehAddresses()
    property int rev: 0             // bumped when items / folds change
    property var sel: ({})          // outpoint -> true
    property int selRev: 0
    property var fold: ({ 'spend': false, 'aside': false })
    property var openAddr: ({})     // blocked addresses opened by hand (compact look)
    property string filter: '*'     // '*' = all, '' = "I do not know", else the id of a category
    property bool choosing: false   // the origin chooser for the ticked coins is open

    readonly property var coins: { page.rev; return page.flat() }
    readonly property bool compact: coins.length > 8
    readonly property var spendData: { page.rev; return page.build('spend') }
    readonly property var asideData: { page.rev; return page.build('aside') }
    readonly property var picked: { page.selRev; page.rev; return page.coins.filter(function (c) { return page.sel[c.outpoint] === true }) }

    function reload() {
        if (!page.demo) page.items = Daemon.currentWallet ? Daemon.currentWallet.ehAddresses() : []
        page.sel = ({}); page.selRev++
        page.choosing = false
        page.rev++
    }
    Component.onCompleted: reload()
    StackView.onActivated: if (!page.demo) reload()   // back from a coin's page

    function flat() {
        var out = []
        for (var i = 0; i < page.items.length; i++) {
            var a = page.items[i]
            for (var j = 0; j < a.coins.length; j++) {
                var c = a.coins[j]
                out.push({ 'outpoint': c.outpoint, 'txid': c.txid, 'sats': c.sats, 'height': c.height, 'label': c.label, 'origin': c.origin || '',
                           'held': c.held, 'address': a.address, 'af': a.held, 'n': a.coins.length, 'kind': a.kind,
                           'pocket': (c.held || a.held) ? 'aside' : 'spend' })
            }
        }
        return out
    }
    // one pocket: first the "sacchetti" (addresses with more coins), then the single coins
    function build(p) {
        var here = page.coins.filter(function (c) { return c.pocket === p })
        var groups = [], seen = {}, singles = [], sats = 0
        for (var i = 0; i < here.length; i++) {
            var c = here[i]
            sats += c.sats
            if (page.filter !== '*' && page.catId(c.origin) !== page.filter) continue
            if (c.n < 2) { singles.push(c); continue }
            if (seen[c.address] === undefined) {
                seen[c.address] = groups.length
                groups.push({ 'address': c.address, 'coins': [], 'n': c.n, 'sats': 0, 'blocked': p === 'aside' && c.af })
            }
            var g = groups[seen[c.address]]
            g.coins.push(c); g.sats += c.sats
        }
        return { 'groups': groups, 'singles': singles, 'count': here.length, 'sats': sats }
    }
    function isSel(o) { page.selRev; return page.sel[o] === true }
    // T20 step 4: tiny coins received (not change) that the app can spend and the
    // user did not say he knows: they can be sent on purpose to follow your payments
    readonly property int dustSats: 1000
    readonly property var dust: {
        page.rev
        if (!app.ehPrivWarn('warn_dust')) return []
        var ok = app.ehDustOk()
        return page.coins.filter(function (c) { return c.sats < page.dustSats && c.kind !== 'change' && c.pocket === 'spend' && ok.indexOf(c.outpoint) < 0 })
    }
    // a coin whose category was deleted counts as "I do not know"
    function catId(origin) { return app.ehCat(origin).id }
    function setOrigin(list, id) {
        var ids = list.map(function (c) { return c.outpoint })
        if (page.demo) {
            var its = page.items
            its.forEach(function (a) { a.coins.forEach(function (c) { if (ids.indexOf(c.outpoint) >= 0) c.origin = id }) })
            page.items = its
        } else Daemon.currentWallet.ehSetOrigin(ids, id)
        page.choosing = false
        page.reload()
    }
    function selPocket() { return page.picked.length > 0 ? page.picked[0].pocket : '' }
    function toggle(list) {
        if (list.length === 0) return
        var s = page.sel
        if (page.picked.length > 0 && page.selPocket() !== list[0].pocket) s = ({})   // ticks in one pocket at a time
        var allOn = list.every(function (c) { return s[c.outpoint] === true })
        for (var i = 0; i < list.length; i++) { if (allOn) delete s[list[i].outpoint]; else s[list[i].outpoint] = true }
        page.sel = s; page.selRev++
    }
    // how many whole addresses (with more coins) are among the given coins
    function wholeAddresses(list) {
        var cnt = {}, n = {}, k = 0
        for (var i = 0; i < list.length; i++) { cnt[list[i].address] = (cnt[list[i].address] || 0) + 1; n[list[i].address] = list[i].n }
        for (var a in cnt) if (n[a] > 1 && cnt[a] === n[a]) k++
        return k
    }
    function move(list, toAside) {
        if (list.length === 0) return
        var ids = list.map(function (c) { return c.outpoint })
        if (page.demo) page.demoMove(ids, toAside)
        else Daemon.currentWallet.ehPocketMove(ids, toAside)
        page.reload()
    }
    // the same rules as qewallet.eh_pocket_move, on the fake coins
    function demoMove(ids, toAside) {
        var its = page.items
        for (var i = 0; i < its.length; i++) {
            var a = its[i]
            var chosen = a.coins.filter(function (c) { return ids.indexOf(c.outpoint) >= 0 })
            if (chosen.length === 0) continue
            var rest = a.coins.filter(function (c) { return ids.indexOf(c.outpoint) < 0 })
            if (toAside) {
                if (a.coins.length > 1 && rest.length === 0) a.held = true
                else chosen.forEach(function (c) { c.held = true })
            } else {
                if (a.held) { a.held = false; rest.forEach(function (c) { c.held = true }) }
                chosen.forEach(function (c) { c.held = false })
            }
        }
        page.items = its
    }

    function satsAmount(s) { return Config.unitsToSats((s / 100000000).toFixed(8)) }
    function money(s) { return app.ehMoney(page.satsAmount(s)) }
    function shortUtxo(outpoint) {
        var i = outpoint.indexOf(':')
        var txid = i > 0 ? outpoint.substring(0, i) : outpoint
        return txid.substring(0, 4) + '…' + txid.slice(-4) + (i > 0 ? outpoint.substring(i) : '')
    }
    function shortAddr(a) {
        var p = app.ehAddressParts(a)
        return (p.prefix !== '' ? p.prefix + ' ' : '') + p.first + ' … ' + p.last
    }
    function coinIcon(sats) { return Qt.resolvedUrl('../../icons/eh_goldcoin_' + (sats < 100000 ? 1 : (sats < 1000000 ? 2 : 3)) + '.svg') }
    function coinSize(sats) {
        var l = Math.log(Math.max(1000, sats)) / Math.LN10
        return Math.round((page.compact ? 20 : 24) + (page.compact ? 12 : 16) * Math.min(1, (l - 3) / 5))
    }
    function showHelp() {
        app.ehInfoDialog.createObject(app, {
            pageTitle: qsTr('The two pockets'),
            bodyText: qsTr('<b>"To spend"</b>: the coins the app can use to pay. <b>"Set aside"</b>: the blocked coins, which the app never uses.')
                      + '<br><br>' + qsTr('The dashed frame is a <b>little bag</b>: coins that arrived on the <b>same address</b>. In the public register they are already linked, so it is better to move them together.')
                      + '<br><br>' + qsTr('If you set a whole little bag aside, the <b>address</b> is blocked: also the coins that arrive there later. If you move one coin only, only that one is blocked.')
                      + '<br><br>' + qsTr('To move: tap the coins and then the button at the bottom, or keep a coin pressed and drag it to the other pocket.')
        }).open()
    }

    // ---- press, hold and drag ----
    property var dragList: []
    property bool dragging: false
    property string dragOver: ''
    function pocketAt(pt) {
        var ps = [['spend', pkSpend], ['aside', pkAside]]
        for (var i = 0; i < ps.length; i++) {
            var o = ps[i][1].mapToItem(page, 0, 0)
            if (pt.y >= o.y && pt.y <= o.y + ps[i][1].height) return ps[i][0]
        }
        return ''
    }
    function startDrag(list, pt) {
        // a ticked coin drags all the ticked ones; another coin goes alone
        var on = list.length === 1 && page.isSel(list[0].outpoint)
        page.dragList = on ? page.picked : list
        page.dragging = true
        page.moveDrag(pt)
        AppController.haptic()
    }
    function moveDrag(pt) {
        ghost.x = pt.x - ghost.width / 2
        ghost.y = pt.y - ghost.height - 14
        page.dragOver = page.pocketAt(pt)
    }
    function endDrag(pt) {
        if (!page.dragging) return
        var to = page.pocketAt(pt), list = page.dragList
        page.dragging = false; page.dragOver = ''; page.dragList = []
        if (to !== '' && list.length > 0 && to !== list[0].pocket) page.move(list, to === 'aside')
    }

    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    EhGlow { tone: 'gold'; x: -page.width * 0.3; y: 40; width: page.width * 1.6; height: 380 }

    // ---------- one coin ----------
    component Tile: Rectangle {
        id: tl
        property var coin
        property bool inGroup: false
        readonly property bool on: page.isSel(coin.outpoint)
        readonly property int cols: page.compact ? 3 : 2
        readonly property var cat: app.ehCat(coin.origin)
        width: Math.floor((parent.width - (cols - 1) * 7) / cols)
        height: page.compact ? 60 : 56
        radius: 12
        color: on ? '#fff8e3' : Qt.rgba(1, 1, 1, 0.93)
        border.width: 2.5
        border.color: on ? '#e0a21a' : 'transparent'
        opacity: page.dragging && page.dragList.indexOf(coin) >= 0 ? 0.4 : 1

        // comfortable: coin on the left, amount and note on the right
        RowLayout {
            visible: !page.compact
            anchors.fill: parent
            anchors.leftMargin: 7
            anchors.rightMargin: 6
            spacing: 6
            Item {
                Layout.preferredWidth: 40; Layout.preferredHeight: 40
                Image { anchors.centerIn: parent; readonly property int s: page.coinSize(tl.coin.sats); width: s; height: s
                        source: page.coinIcon(tl.coin.sats); sourceSize.width: 96; sourceSize.height: 96 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: page.money(tl.coin.sats); font.pixelSize: 15; font.bold: true
                        fontSizeMode: Text.HorizontalFit; minimumPixelSize: 10 }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Rectangle { visible: tl.cat.id !== ''; Layout.preferredWidth: 9; Layout.preferredHeight: 9; radius: 4.5; color: tl.cat.color }
                    Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 11
                            font.bold: tl.cat.id !== ''
                            font.italic: tl.cat.id === '' && tl.coin.label !== ''
                            color: tl.cat.id !== '' ? tl.cat.color : (tl.coin.label !== '' ? '#5e1a33' : '#6b5d55')
                            text: tl.cat.id !== '' ? tl.cat.name : (tl.coin.label !== '' ? tl.coin.label : page.shortUtxo(tl.coin.outpoint)) }
                }
            }
        }
        // compact: coin above, amount below
        ColumnLayout {
            visible: page.compact
            anchors.fill: parent
            anchors.margins: 4
            spacing: 0
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                Image { anchors.centerIn: parent; readonly property int s: page.coinSize(tl.coin.sats); width: s; height: s
                        source: page.coinIcon(tl.coin.sats); sourceSize.width: 96; sourceSize.height: 96 }
            }
            Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: page.money(tl.coin.sats); font.pixelSize: 13; font.bold: true
                    fontSizeMode: Text.HorizontalFit; minimumPixelSize: 9 }
        }
        Rectangle {
            visible: page.compact && tl.cat.id !== ''
            x: 6; y: 6; width: 10; height: 10; radius: 5
            color: tl.cat.color
        }
        // a single coin whose address is blocked too
        Image {
            visible: tl.coin.af && !tl.inGroup
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 4
            source: Qt.resolvedUrl('../../icons/eh_lock.svg'); sourceSize.width: 12; sourceSize.height: 12
        }
        Rectangle {
            visible: tl.on
            anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: -6; anchors.topMargin: -6
            width: 20; height: 20; radius: 10; color: '#e0a21a'
            Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_check_white.svg'); sourceSize.width: 12; sourceSize.height: 12 }
        }
        MouseArea {
            anchors.fill: parent
            pressAndHoldInterval: 350
            property bool held: false
            onClicked: if (!held) page.toggle([tl.coin])
            onPressed: held = false
            onPressAndHold: (mouse) => { held = true; preventStealing = true; page.startDrag([tl.coin], mapToItem(page, mouse.x, mouse.y)) }
            onPositionChanged: (mouse) => { if (held) page.moveDrag(mapToItem(page, mouse.x, mouse.y)) }
            onReleased: (mouse) => { preventStealing = false; if (held) page.endDrag(mapToItem(page, mouse.x, mouse.y)) }
            onCanceled: { preventStealing = false; page.dragging = false; page.dragOver = ''; page.dragList = [] }
        }
    }

    // ---------- one pocket ----------
    component Pocket: Rectangle {
        id: pk
        property string which
        property var d: ({ 'groups': [], 'singles': [], 'count': 0, 'sats': 0 })
        readonly property bool folded: { page.rev; return page.fold[which] === true }
        Layout.fillWidth: true
        Layout.preferredHeight: pkCol.implicitHeight + 26
        radius: 18
        gradient: Gradient {
            GradientStop { position: 0; color: pk.which === 'spend' ? '#76853f' : '#8a3a58' }
            GradientStop { position: 1; color: pk.which === 'spend' ? '#45541f' : '#5e1a33' }
        }
        border.width: page.dragOver === which ? 4 : 0
        border.color: '#e0a21a'
        EhDashedBorder { anchors.fill: parent; inset: 5; radius: 14; lineWidth: 1.6; color: Qt.rgba(1, 0.91, 0.77, 0.6) }
        ColumnLayout {
            id: pkCol
            x: 13; y: 13
            width: parent.width - 26
            spacing: 7
            // title: tap to fold / unfold
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    anchors.rightMargin: 5
                    spacing: 6
                    Label { text: pk.folded ? '▸' : '▾'; color: '#ffffff'; font.pixelSize: 13 }
                    Image { visible: pk.which === 'aside'; source: Qt.resolvedUrl('../../icons/eh_lock_white.svg'); sourceSize.width: 15; sourceSize.height: 15 }
                    Label { text: pk.which === 'spend' ? qsTr('To spend') : qsTr('Set aside'); color: '#ffffff'; font.pixelSize: 17; font.bold: true }
                    Label { Layout.fillWidth: true; text: pk.d.count === 1 ? qsTr('1 coin') : qsTr('%1 coins').arg(pk.d.count); color: '#ffffff'; opacity: 0.9; font.pixelSize: 13 }
                    Label { text: page.money(pk.d.sats); color: '#ffffff'; font.family: TitleFont ? TitleFont : font.family; font.weight: Font.Black; font.pixelSize: 18 }
                }
                MouseArea { anchors.fill: parent; onClicked: { var f = page.fold; f[pk.which] = !f[pk.which]; page.fold = f; page.rev++ } }
            }
            Label {
                visible: !pk.folded && pk.d.count === 0
                Layout.fillWidth: true
                Layout.topMargin: 8; Layout.bottomMargin: 8
                horizontalAlignment: Text.AlignHCenter
                text: qsTr('no coins here')
                color: '#ffffff'; opacity: 0.8; font.pixelSize: 14
            }
            // the "sacchetti"
            Repeater {
                model: pk.folded ? [] : pk.d.groups
                Rectangle {
                    id: gr
                    required property var modelData
                    readonly property bool shut: { page.rev; return page.compact && modelData.blocked && page.openAddr[modelData.address] !== true }
                    readonly property bool allOn: { page.selRev; return modelData.coins.every(function (c) { return page.sel[c.outpoint] === true }) }
                    Layout.fillWidth: true
                    Layout.preferredHeight: grCol.implicitHeight + 12
                    radius: 13
                    color: Qt.rgba(1, 1, 1, 0.12)
                    EhDashedBorder { anchors.fill: parent; inset: 1; radius: 13; lineWidth: 2; color: Qt.rgba(1, 1, 1, 0.75) }
                    ColumnLayout {
                        id: grCol
                        x: 6; y: 6
                        width: parent.width - 12
                        spacing: 5
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 3
                                anchors.rightMargin: 2
                                spacing: 6
                                Image { visible: gr.modelData.blocked; source: Qt.resolvedUrl('../../icons/eh_lock_white.svg'); sourceSize.width: 13; sourceSize.height: 13 }
                                Label { Layout.fillWidth: true; elide: Text.ElideRight; text: page.shortAddr(gr.modelData.address)
                                        color: '#ffffff'; font.family: FixedFont; font.pixelSize: 12; font.bold: true }
                                Label { color: '#ffffff'; opacity: 0.92; font.pixelSize: 11
                                        text: (gr.modelData.coins.length === gr.modelData.n ? gr.modelData.n : qsTr('%1 of %2').arg(gr.modelData.coins.length).arg(gr.modelData.n))
                                              + ' · ' + page.money(gr.modelData.sats) }
                                Rectangle {
                                    Layout.preferredWidth: 21; Layout.preferredHeight: 21; radius: 10.5
                                    color: gr.allOn ? '#e0a21a' : 'transparent'
                                    border.width: 2
                                    border.color: gr.allOn ? '#e0a21a' : '#ffffff'
                                    Image { visible: gr.allOn; anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_check_white.svg'); sourceSize.width: 12; sourceSize.height: 12 }
                                }
                                Item { visible: page.compact && gr.modelData.blocked; Layout.preferredWidth: 20; Layout.preferredHeight: 24 }
                            }
                            // the name of the address: tick all its coins; hold: drag the whole little bag
                            MouseArea {
                                anchors.fill: parent
                                pressAndHoldInterval: 350
                                property bool held: false
                                onClicked: if (!held) page.toggle(gr.modelData.coins)
                                onPressed: held = false
                                onPressAndHold: (mouse) => { held = true; preventStealing = true; page.startDrag(gr.modelData.coins, mapToItem(page, mouse.x, mouse.y)) }
                                onPositionChanged: (mouse) => { if (held) page.moveDrag(mapToItem(page, mouse.x, mouse.y)) }
                                onReleased: (mouse) => { preventStealing = false; if (held) page.endDrag(mapToItem(page, mouse.x, mouse.y)) }
                                onCanceled: { preventStealing = false; page.dragging = false; page.dragOver = ''; page.dragList = [] }
                            }
                            // compact: open / close a blocked address
                            Label {
                                visible: page.compact && gr.modelData.blocked
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                width: 22; horizontalAlignment: Text.AlignHCenter
                                text: gr.shut ? '▸' : '▾'; color: '#ffffff'; font.pixelSize: 15
                                MouseArea { anchors.fill: parent; anchors.margins: -8
                                            onClicked: { var o = page.openAddr; o[gr.modelData.address] = !(o[gr.modelData.address] === true); page.openAddr = o; page.rev++ } }
                            }
                        }
                        Flow {
                            visible: !gr.shut
                            Layout.fillWidth: true
                            spacing: 7
                            Repeater { model: gr.shut ? [] : gr.modelData.coins; Tile { required property var modelData; coin: modelData; inGroup: true } }
                        }
                        Label {
                            visible: gr.modelData.blocked && !gr.shut
                            Layout.fillWidth: true
                            Layout.leftMargin: 3
                            wrapMode: Text.WordWrap
                            text: qsTr('address blocked: also the coins that will arrive here')
                            color: '#ffffff'; opacity: 0.9; font.pixelSize: 11
                        }
                    }
                }
            }
            // the single coins
            Flow {
                visible: !pk.folded && pk.d.singles.length > 0
                Layout.fillWidth: true
                spacing: 7
                Repeater { model: pk.folded ? [] : pk.d.singles; Tile { required property var modelData; coin: modelData } }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 10 + app.navigationBarHeight
        spacing: 6

        EhPageTop { title: ''; Layout.leftMargin: 8; Layout.rightMargin: 8 }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: -14
            Label {
                Layout.fillWidth: true
                text: '‹ ' + qsTr('Advanced privacy')
                color: '#5e1a33'; font.pixelSize: 17; font.bold: true
                TapHandler { margin: 10; onTapped: app.stack.pop() }
            }
            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                color: '#45541f'
                Label { anchors.centerIn: parent; text: 'i'; color: '#ffffff'; font.pixelSize: 16; font.bold: true; font.family: 'serif' }
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: page.showHelp() }
            }
        }
        Label {
            Layout.fillWidth: true
            text: qsTr('Your gold coins')
            color: '#3f0f21'
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 26
            wrapMode: Text.WordWrap
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            font.pixelSize: 13
            color: '#6b5d55'
            text: {
                page.rev
                var aside = page.coins.filter(function (c) { return c.pocket === 'aside' }).length
                var fr = page.items.filter(function (a) { return a.held && a.coins.length > 0 }).length
                return qsTr('Coins: <b>%1</b> · set aside: <b>%2</b> · addresses blocked: <b>%3</b>').arg(page.coins.length).arg(aside).arg(fr)
            }
        }

        // filter by origin: only when the coins are many
        Flickable {
            visible: page.compact
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            contentWidth: fRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            clip: true
            Row {
                id: fRow
                spacing: 6
                Repeater {
                    model: {
                        page.rev
                        var l = [{ 'id': '*', 'name': qsTr('All (coins)'), 'color': '#3f0f21', 'n': -1 }]
                        var cats = app.ehCats().concat([app.ehCat('')])
                        for (var i = 0; i < cats.length; i++) {
                            var n = page.coins.filter(function (c) { return page.catId(c.origin) === cats[i].id }).length
                            if (n > 0) l.push({ 'id': cats[i].id, 'name': cats[i].name, 'color': cats[i].color, 'n': n })
                        }
                        return l
                    }
                    Rectangle {
                        id: fc
                        required property var modelData
                        readonly property bool on: page.filter === modelData.id
                        width: fcRow.implicitWidth + 20; height: 30; radius: 15
                        color: on ? '#ffffff' : '#f1eadc'
                        border.width: 2
                        border.color: on ? modelData.color : 'transparent'
                        RowLayout {
                            id: fcRow
                            anchors.centerIn: parent
                            spacing: 5
                            Rectangle { visible: fc.modelData.id !== '*'; Layout.preferredWidth: 9; Layout.preferredHeight: 9; radius: 4.5; color: fc.modelData.color }
                            Label { text: fc.modelData.name + (fc.modelData.n >= 0 ? ' ' + fc.modelData.n : ''); font.pixelSize: 13; font.bold: true; color: fc.modelData.color }
                        }
                        MouseArea { anchors.fill: parent; onClicked: { page.filter = fc.modelData.id; page.sel = ({}); page.selRev++; page.rev++ } }
                    }
                }
            }
        }

        Flickable {
            id: fl
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: pkWrap.implicitHeight + 8
            clip: true
            interactive: !page.dragging
            ColumnLayout {
                id: pkWrap
                width: fl.width
                spacing: 10
                Label {
                    visible: page.coins.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 30
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: '#6b5d55'; font.pixelSize: 16
                    text: qsTr('No coins yet: they arrive when someone sends you bitcoin.')
                }
                Rectangle {
                    visible: page.dust.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: duCol.implicitHeight + 22
                    radius: 16
                    color: '#fdf1d4'
                    border.width: 2
                    border.color: '#e0a21a'
                    ColumnLayout {
                        id: duCol
                        x: 11; y: 11
                        width: parent.width - 22
                        spacing: 8
                        Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: qsTr('A strange little coin arrived'); font.pixelSize: 16; font.bold: true; color: '#7a4d00' }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            textFormat: Text.StyledText
                            font.pixelSize: 14
                            text: page.dust.length === 0 ? '' :
                                  qsTr('<b>%1</b>, very small. Sometimes they are sent on purpose to follow your payments. If you did not expect it, set it aside: so the app never uses it.').arg(page.money(page.dust[0].sats))
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 18
                                color: '#5e1a33'
                                Label { anchors.centerIn: parent; text: qsTr('Put aside'); color: '#ffffff'; font.pixelSize: 15; font.bold: true }
                                MouseArea { anchors.fill: parent; onClicked: page.move([page.dust[0]], true) }
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 18
                                color: '#ffffff'; border.width: 2; border.color: '#e3d9c6'
                                Label { anchors.centerIn: parent; text: qsTr('I know it, leave it'); color: '#3f0f21'; font.pixelSize: 15; font.bold: true
                                        width: parent.width - 12; horizontalAlignment: Text.AlignHCenter; fontSizeMode: Text.HorizontalFit; minimumPixelSize: 11 }
                                MouseArea { anchors.fill: parent; onClicked: { app.ehSetDustOk(page.dust[0].outpoint); page.rev++ } }
                            }
                        }
                    }
                }
                Pocket { id: pkSpend; visible: page.coins.length > 0; which: 'spend'; d: page.spendData }
                Pocket { id: pkAside; visible: page.coins.length > 0; which: 'aside'; d: page.asideData }
            }
        }

        // where the ticked coins come from: one tap gives them all the same origin
        Rectangle {
            visible: page.choosing && page.picked.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: chCol.implicitHeight + 20
            radius: 16
            color: '#ffffff'
            border.width: 2
            border.color: '#e0a21a'
            ColumnLayout {
                id: chCol
                x: 10; y: 10
                width: parent.width - 20
                spacing: 6
                Label { text: qsTr('Where do they come from?'); font.pixelSize: 14; font.bold: true; color: '#3f0f21' }
                Flow {
                    Layout.fillWidth: true
                    spacing: 7
                    Repeater {
                        model: app.ehCats().concat([app.ehCat('')])
                        Rectangle {
                            id: cc
                            required property var modelData
                            width: ccRow.implicitWidth + 22; height: 38; radius: 19
                            color: '#f4efe4'
                            RowLayout {
                                id: ccRow
                                anchors.centerIn: parent
                                spacing: 6
                                Rectangle { Layout.preferredWidth: 11; Layout.preferredHeight: 11; radius: 5.5; color: cc.modelData.color }
                                Label { text: cc.modelData.name; font.pixelSize: 15; font.bold: true; color: cc.modelData.color }
                            }
                            MouseArea { anchors.fill: parent; onClicked: page.setOrigin(page.picked, cc.modelData.id) }
                        }
                    }
                }
            }
        }
        // the button: appears when something is ticked
        RowLayout {
            visible: page.picked.length > 0
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: 20
                color: page.choosing ? '#fff8e3' : '#ffffff'
                border.width: 2
                border.color: page.choosing ? '#e0a21a' : '#e3d9c6'
                // three dots of colour = "where it comes from"
                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Repeater { model: ['#1f6fb2', '#b4690e', '#6a4c93']; Rectangle { required property string modelData; width: 10; height: 10; radius: 5; color: modelData } }
                }
                MouseArea { anchors.fill: parent; onClicked: page.choosing = !page.choosing }
            }
            Rectangle {
                visible: page.picked.length === 1
                Layout.preferredWidth: 84
                Layout.preferredHeight: 56
                radius: 20
                color: dtMa.pressed ? '#f1ebdf' : '#ffffff'
                border.width: 2
                border.color: '#e3d9c6'
                Label { anchors.centerIn: parent; text: qsTr('Details'); color: '#3f0f21'; font.pixelSize: 15; font.bold: true }
                MouseArea {
                    id: dtMa
                    anchors.fill: parent
                    onClicked: {
                        var c = page.picked[0]
                        if (page.demo) return
                        app.stack.push(Qt.resolvedUrl('EhCoinDetailPage.qml'), {
                            outpoint: c.outpoint, txid: c.txid, address: c.address, amount: page.satsAmount(c.sats),
                            blockHeight: c.height, held: c.held, note: c.label })
                    }
                }
            }
            Rectangle {
                id: bar
                readonly property bool toAside: page.selPocket() === 'spend'
                readonly property int whole: page.wholeAddresses(page.picked)
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 20
                color: toAside ? (barMa.pressed ? '#4a1428' : '#5e1a33') : (barMa.pressed ? '#3a4719' : '#45541f')
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 7
                        Image { source: Qt.resolvedUrl('../../icons/' + (bar.toAside ? 'eh_lock_white.svg' : 'eh_check_white.svg')); sourceSize.width: 17; sourceSize.height: 17 }
                        Label { Layout.maximumWidth: bar.width - 44; text: bar.toAside ? qsTr('Put aside') : qsTr('Back to spend'); color: '#ffffff'; font.pixelSize: 18; font.bold: true
                                fontSizeMode: Text.HorizontalFit; minimumPixelSize: 12 }
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        color: '#ffffff'; opacity: 0.92; font.pixelSize: 12
                        text: {
                            var s = 0
                            for (var i = 0; i < page.picked.length; i++) s += page.picked[i].sats
                            return page.picked.length + ' · ' + page.money(s)
                                   + (bar.whole === 1 ? ' · ' + qsTr('whole address') : (bar.whole > 1 ? ' · ' + qsTr('%1 whole addresses').arg(bar.whole) : ''))
                        }
                    }
                }
                MouseArea { id: barMa; anchors.fill: parent; onClicked: page.move(page.picked, bar.toAside) }
            }
        }
    }

    // what follows the finger while dragging
    Rectangle {
        id: ghost
        visible: page.dragging
        z: 50
        width: 62; height: 62; radius: 31
        color: Qt.rgba(1, 1, 1, 0.92)
        border.width: 3
        border.color: '#e0a21a'
        Image { anchors.centerIn: parent; width: 40; height: 40; source: Qt.resolvedUrl('../../icons/eh_goldcoin_2.svg'); sourceSize.width: 96; sourceSize.height: 96 }
        Rectangle {
            visible: page.dragList.length > 1
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: -4
            width: 24; height: 24; radius: 12; color: '#5e1a33'
            Label { anchors.centerIn: parent; text: page.dragList.length; color: '#ffffff'; font.pixelSize: 13; font.bold: true }
        }
    }
}
