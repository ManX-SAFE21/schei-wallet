// Easy Heirs (schȅi): "Replace the keeper" (owner 15/11, point 4d; preview
// anteprima/custode-spento/sostituisci.html). Opened by the Status page when a keeper does not
// answer. bal.findKeeper() looks in the public list for a keeper that answers and is not used
// yet (the cheapest is picked); the PIN, then bal.replaceKeeper(url) sends the new keeper its
// copy of the envelope. Free; the delivery date does not change. None free: a short sheet.
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
    property string pick: ''                   // url of the keeper chosen
    property var result: ({})                  // replaceKeeper's answer
    property string error: ''
    property bool _mine: false

    closable: !(bal && bal.busy && _mine)
    onClosed: destroy()

    readonly property var fresh: {             // the keepers not used yet
        var r = []
        for (var i = 0; i < candidates.length; i++) if (!candidates[i].used) r.push(candidates[i])
        return r
    }
    readonly property string deadName: {       // the keeper that does not answer
        for (var i = 0; i < candidates.length; i++)
            if (candidates[i].used && !candidates[i].ok) return candidates[i].name
        return ''
    }
    readonly property string pickName: {
        for (var i = 0; i < candidates.length; i++) if (candidates[i].url === pick) return candidates[i].name
        return ''
    }
    readonly property int cheapest: {
        var m = -1
        for (var i = 0; i < fresh.length; i++)
            if (fresh[i].ok && (m < 0 || fresh[i].feeSats < m)) m = fresh[i].feeSats
        return m
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
                root.pick = result.pick || ''
                root.stage = 'pick'
            } else if (op === 'replaceKeeper') {
                root._mine = false
                root.result = result
                root.stage = 'done'
            }
        }
        function onFailed(op, code, message) {
            if (op !== 'findKeeper' && op !== 'replaceKeeper') return
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
                        : app.ehHeirSats(kl.k.feeSats) + (kl.k.ok && kl.k.feeSats === root.cheapest ? ' · ' + qsTr('the cheapest') : '')
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
        text: qsTr('I look for a new keeper…')
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
        text: qsTr('I found a keeper')
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
                chosen: modelData.url === root.pick
                last: index === root.fresh.length - 1
                onTapped: if (modelData.ok && !(root.bal && root.bal.busy)) root.pick = modelData.url
            }
        }
    }
    Para {
        visible: root.stage === 'pick'
        text: (root.deadName !== ''
               ? qsTr('Instead of <b>%1</b> I put <b>%2</b> and send it its copy of the envelope. The delivery stays on <b>%3</b>.').arg(root.deadName).arg(root.pickName)
               : qsTr('I add <b>%1</b> and send it its copy of the envelope. The delivery stays on <b>%2</b>.').arg(root.pickName))
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
        enabled: root.pick !== '' && !(root.bal && root.bal.busy)
        onClicked: app.ehAskPin(qsTr('Type the PIN to send the envelope to the new keeper'), function() {
            if (!root.bal) return
            root.error = ''
            root._mine = true
            root.bal.replaceKeeper(root.pick)
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
        text: qsTr('Keeper replaced')
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
