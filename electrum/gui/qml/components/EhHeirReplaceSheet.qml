// Easy Heirs (schȅi): "Replace the ones that do not answer" (owner 15/11, points 4d, P6; preview
// anteprima/custode-spento/sostituisci.html). Opened by the Status page when too few keepers
// answer. bal.findKeeper() looks in the public list for as many keepers as do not answer
// (`need`), that answer and are not used yet (`picks`: the first ones of the public list, owner
// P5: never by price); the PIN once, then bal.replaceKeepers(picks) makes the envelope again
// ONCE and sends every new keeper its copy. Free; the delivery date does not change. Fewer
// found than needed: those found ("I found 1 new keeper out of 2"). None free: a short sheet.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "controls"
import "controls/EhStyle.js" as S

EhBottomSheet {
    id: root
    readonly property var bal: AppController.plugin('bal')
    readonly property var st: bal ? bal.state : ({})
    property string stage: 'find'              // find | pick | done | none | error
    property var candidates: []
    property var picks: []                     // urls of the new keepers chosen
    property int need: 1                       // how many do not answer (how many to find)
    property var result: ({})                  // replaceKeepers' answer
    property string error: ''
    property bool _mine: false

    closable: !(bal && bal.busy && _mine)
    // the keepers that do not answer now (the title while looking)
    readonly property int lostNow: st.custodians ? Math.max(0, (st.custodians.total || 0) - (st.custodians.ok || 0)) : 0
    onClosed: destroy()

    readonly property var fresh: {             // the keepers not used yet
        var r = []
        for (var i = 0; i < candidates.length; i++) if (!candidates[i].used) r.push(candidates[i])
        return r
    }
    readonly property var deadNames: {         // the keepers that do not answer
        var r = []
        for (var i = 0; i < candidates.length; i++)
            if (candidates[i].used && !candidates[i].ok) r.push(candidates[i].name)
        return r
    }
    readonly property var pickNames: {         // the new ones, in the order of the list
        var r = []
        for (var i = 0; i < candidates.length; i++)
            if (picks.indexOf(candidates[i].url) >= 0) r.push(candidates[i].name)
        return r
    }
    // "<b>A</b>", "<b>A</b> e <b>B</b>", "<b>A</b>, <b>B</b> e <b>C</b>"
    function names(list) {
        var b = []
        for (var i = 0; i < list.length; i++) b.push('<b>' + list[i] + '</b>')
        if (b.length <= 1) return b.join('')
        return qsTr('%1 and %2').arg(b.slice(0, -1).join(', ')).arg(b[b.length - 1])
    }
    // a tap on a free keeper that answers: in or out (at most `need`; when full, it takes the
    // place of the last one chosen)
    function toggle(url) {
        var p = picks.slice()
        var i = p.indexOf(url)
        if (i >= 0) { if (p.length > 1) p.splice(i, 1) }
        else if (p.length < need) p.push(url)
        else p[p.length - 1] = url
        picks = p
    }
    readonly property string firstUrl: {       // the first of the list that answers (P5)
        for (var i = 0; i < fresh.length; i++) if (fresh[i].ok) return fresh[i].url
        return ''
    }

    function find() {
        if (!bal) return
        error = ''
        stage = 'find'
        if (bal.busy) { waitIdle.start(); return }
        _mine = true
        bal.findKeeper()
    }
    Component.onCompleted: find()
    Timer {
        id: waitIdle
        interval: 300
        repeat: true
        onTriggered: if (root.bal && !root.bal.busy) { stop(); root._mine = true; root.bal.findKeeper() }
    }

    Connections {
        target: root.bal
        function onDone(op, result) {
            if (op === 'findKeeper') {
                root._mine = false
                root.candidates = result.candidates || []
                root.need = Math.max(1, result.need || 1)
                root.picks = result.picks || (result.pick ? [result.pick] : [])
                root.stage = 'pick'
            } else if (op === 'replaceKeepers') {
                root._mine = false
                root.result = result
                root.stage = 'done'
            }
        }
        function onFailed(op, code, message) {
            if (op !== 'findKeeper' && op !== 'replaceKeepers') return
            if (code === 'busy') return
            root._mine = false
            if (op === 'findKeeper' && code === 'custodians') { root.stage = 'none'; return }
            root.error = app.ehHeirErrorText(code, message)
            if (op === 'findKeeper') root.stage = 'error'
        }
    }

    component Para: Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.StyledText
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 16
        lineHeight: 1.15
        color: S.ink
    }
    // one keeper of the list: name, price (and why it is there), what it said
    component KeeperLine: Item {
        id: kl
        property var k
        property bool chosen: false
        property bool last: false
        signal tapped
        Layout.fillWidth: true
        implicitHeight: klRow.implicitHeight + 18
        Layout.preferredHeight: implicitHeight
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            radius: 10
            color: S.tipBg
            visible: kl.chosen
        }
        RowLayout {
            id: klRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    Layout.fillWidth: true
                    text: kl.k ? kl.k.name : ''
                    elide: Text.ElideRight
                    color: S.ink
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 16
                    font.bold: true
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: S.muted
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 14
                    text: !kl.k ? '' : kl.k.used ? (kl.k.ok ? qsTr('already yours') : qsTr('the one switched off'))
                        : app.ehHeirSats(kl.k.feeSats) + (kl.k.url === root.firstUrl ? ' · ' + qsTr('the first of the list') : '')
                }
            }
            Label {
                text: !kl.k ? '' : kl.k.used ? (kl.k.ok ? qsTr('already used') : '✕ ' + qsTr('does not answer'))
                    : !kl.k.ok ? '✕ ' + qsTr('does not answer') : '✓ ' + (kl.chosen ? qsTr('chosen') : qsTr('answers'))
                color: !kl.k ? S.ink : kl.k.used && kl.k.ok ? S.offInk : (kl.k.ok ? S.oliveInk : S.wine)
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 14
                font.bold: true
            }
        }
        EhDotLine {
            visible: !kl.last
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: parent.width
        }
        TapHandler { onTapped: kl.tapped() }
    }

    // ---- 1: looking in the public list
    EhTitle {
        visible: root.stage === 'find' || root.stage === 'error'
        text: root.lostNow > 1 ? qsTr('I look for %1 new keepers…').arg(root.lostNow) : qsTr('I look for a new keeper…')
        fontSize: 26
        Layout.bottomMargin: 0
    }
    Para {
        visible: root.stage === 'find' || root.stage === 'error'
        text: qsTr('I look at the public list of keepers and ask each one whether it is on.')
    }
    RowLayout {
        visible: root.stage === 'find'
        Layout.alignment: Qt.AlignHCenter
        spacing: 8
        BusyIndicator { Layout.preferredWidth: 28; Layout.preferredHeight: 28; running: parent.visible }
        Label {
            text: root.bal && root.bal.busy ? app.ehHeirStepText(root.bal.step) || qsTr('I ask the keepers…') : qsTr('I ask the keepers…')
            color: S.muted
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 16
            font.bold: true
        }
    }
    Label {
        visible: root.stage === 'find'
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 14
        color: S.muted
        text: qsTr('It takes a few seconds. I skip the .onion (Tor) addresses.')
    }

    // ---- 2: found, confirm with the PIN
    EhTitle {
        visible: root.stage === 'pick'
        text: root.picks.length < root.need
              ? (root.picks.length === 1 ? qsTr('I found 1 new keeper out of %1').arg(root.need)
                                         : qsTr('I found %1 new keepers out of %2').arg(root.picks.length).arg(root.need))
              : root.picks.length > 1 ? qsTr('I found %1 keepers').arg(root.picks.length) : qsTr('I found a keeper')
        fontSize: 26
        Layout.bottomMargin: 0
    }
    EhSheet {
        visible: root.stage === 'pick' && root.fresh.length > 0
        Repeater {
            model: root.fresh
            delegate: KeeperLine {
                required property var modelData
                required property int index
                k: modelData
                chosen: root.picks.indexOf(modelData.url) >= 0
                last: index === root.fresh.length - 1
                onTapped: if (modelData.ok && !(root.bal && root.bal.busy)) root.toggle(modelData.url)
            }
        }
    }
    Para {
        visible: root.stage === 'pick'
        text: (root.deadNames.length === 0
               ? qsTr('I add <b>%1</b> and send it its copy of the envelope. The delivery stays on <b>%2</b>.').arg(root.pickNames.join(', '))
               : root.pickNames.length > 1
               ? qsTr('Instead of %1 I put %2 and send each one its copy of the envelope. The delivery stays on <b>%3</b>.').arg(root.names(root.deadNames)).arg(root.names(root.pickNames))
               : qsTr('Instead of %1 I put %2 and send it its copy of the envelope. The delivery stays on <b>%3</b>.').arg(root.names(root.deadNames)).arg(root.names(root.pickNames)))
                  .arg(app.ehHeirDate(root.st.delivery))
              + ' <b>' + qsTr('Today you pay nothing.') + '</b>'
    }
    Label {
        visible: root.stage === 'pick' && root.bal !== null && root.bal.busy && root._mine
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 17
        font.bold: true
        color: S.wine
        text: root.bal ? app.ehHeirStepText(root.bal.step) : ''
    }
    EhInfoBox {
        visible: root.error !== '' && !(root.bal && root.bal.busy)
        kind: 'danger'
        text: root.error
    }
    EhStitchButton {
        visible: root.stage === 'pick'
        kind: 'wine'
        icon: 'eh_lock_white.svg'
        text: qsTr('Send the envelope with the PIN')
        enabled: root.picks.length > 0 && !(root.bal && root.bal.busy)
        onClicked: app.ehAskPin(root.picks.length > 1 ? qsTr('Type the PIN to send the envelope to the new keepers')
                                                      : qsTr('Type the PIN to send the envelope to the new keeper'), function() {
            if (!root.bal) return
            root.error = ''
            root._mine = true
            root.bal.replaceKeepers(root.picks)
        })
    }
    EhStitchButton {
        visible: root.stage === 'error'
        kind: 'paper'
        icon: 'eh_refresh.svg'
        text: qsTr('Try again')
        enabled: !(root.bal && root.bal.busy)
        onClicked: root.find()
    }
    EhStitchButton {
        visible: root.stage === 'pick' || root.stage === 'error' || root.stage === 'find'
        kind: 'paper'
        text: qsTr('Cancel')
        enabled: root.closable
        onClicked: root.close()
    }

    // ---- 3: done
    Image {
        visible: root.stage === 'done'
        Layout.alignment: Qt.AlignHCenter
        source: Qt.resolvedUrl('../../icons/eh_check.svg')
        sourceSize.width: 52
        sourceSize.height: 52
    }
    EhTitle {
        visible: root.stage === 'done'
        text: (root.result.added || 1) > 1 ? qsTr('Keepers replaced') : qsTr('Keeper replaced')
        fontSize: 26
        Layout.bottomMargin: 0
    }
    Para {
        visible: root.stage === 'done'
        horizontalAlignment: Text.AlignHCenter
        text: ((root.result.total || 0) === 1
               ? qsTr('The envelope is safe with <b>1 keeper</b>.')
               : qsTr('The envelope is safe with <b>%1 keepers out of %2</b>.').arg(root.result.ok || 0).arg(root.result.total || 0))
              + '<br>' + qsTr('Delivery on <b>%1</b>.').arg(app.ehHeirDate(root.result.delivery || root.st.delivery))
    }
    EhStitchButton {
        visible: root.stage === 'done'
        kind: 'olive'
        icon: 'eh_check_white.svg'
        text: qsTr('Close')
        onClicked: root.close()
    }

    // ---- 4: no free keeper
    EhTitle {
        visible: root.stage === 'none'
        text: qsTr('No free keeper')
        fontSize: 26
        Layout.bottomMargin: 0
    }
    Para {
        visible: root.stage === 'none'
        text: qsTr('In the public list there is no other keeper on now.')
    }
    EhInfoBox {
        visible: root.stage === 'none'
        kind: 'warn'
        readonly property int alive: root.st.custodians ? (root.st.custodians.ok || 0) : 0
        text: alive > 1 ? qsTr('The envelope stays with your <b>%1 keepers</b> that work: the inheritance is valid. Try again later.').arg(alive)
            : alive === 1 ? qsTr('The envelope stays with your <b>keeper</b> that works: the inheritance is valid. Try again later.')
            : qsTr('Try again later: if your keepers come back, the envelope arrives anyway.')
    }
    EhStitchButton {
        visible: root.stage === 'none'
        kind: 'paper'
        text: qsTr('OK (go ahead)')
        onClicked: root.close()
    }
}
