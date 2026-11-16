// Easy Heirs (schȅi): "Cancel the inheritance" (owner 15/11, point 7). Opened by the link at
// the bottom of the Status page. What it means (the envelope is cancelled on the network, a
// small fee as the renewal, it cannot be undone), then "Do you also want to delete the heirs?"
// (Yes / No, owner decision), the PIN, bal.cancelWill(deleteHeirs). When the wallet does not
// see the cancellation yet (not_synced) the heirs are deleted later (app.ehHeirDropHeirsLater).
// "Close" at the end also closes the Status page (there is no inheritance any more).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "controls"
import "controls/EhStyle.js" as S

EhBottomSheet {
    id: root
    readonly property var bal: AppController.plugin('bal')
    readonly property var st: bal ? bal.state : ({})
    property string stage: 'confirm'           // confirm | heirs | done | sent
    property bool deleteHeirs: false
    property string error: ''
    property bool _mine: false

    closable: !(bal && bal.busy && _mine)
    onClosed: {
        if ((stage === 'done' || stage === 'sent') && app.stack.currentItem && app.stack.currentItem.ehHeirStatus)
            app.stack.pop()
        destroy()
    }

    Connections {
        target: root.bal
        function onDone(op, result) {
            if (op !== 'cancelWill') return
            root._mine = false
            root.stage = 'done'
        }
        function onFailed(op, code, message) {
            if (op !== 'cancelWill' || code === 'busy') return
            root._mine = false
            if (code === 'not_synced') {
                // sent, the wallet does not see it yet: the heirs (if asked) go when it does
                if (root.deleteHeirs) app.ehHeirDropHeirsLater()
                root.stage = 'sent'
                return
            }
            root.error = app.ehHeirErrorText(code, message)
        }
    }

    function go(del) {
        deleteHeirs = del
        app.ehAskPin(qsTr('Type the PIN to cancel the inheritance'), function() {
            if (!root.bal) return
            root.error = ''
            root._mine = true
            root.bal.cancelWill(root.deleteHeirs)
        })
    }

    component Para: Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.StyledText
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: app.ehFsText
        lineHeight: 1.15
        color: S.ink
    }

    // ---- 1: what it means
    EhTitle {
        visible: root.stage === 'confirm'
        text: qsTr('Cancel the inheritance')
        fontSize: app.ehFsBox
        Layout.bottomMargin: 0
    }
    Para {
        visible: root.stage === 'confirm'
        text: qsTr('The envelope for the heirs is cancelled on the bitcoin network: a small operation that costs about <b>%1</b>.')
                .arg(app.ehHeirSats(root.st.fees ? (root.st.fees.cancelSats || root.st.fees.renewSats) : 0))
    }
    EhInfoBox {
        visible: root.stage === 'confirm'
        kind: 'danger'
        text: qsTr('It cannot be undone: to have an inheritance again you must make it again.')
    }
    EhStitchButton {
        visible: root.stage === 'confirm'
        kind: 'wine'
        icon: 'eh_undo_white.svg'
        text: qsTr('Yes, cancel it')
        onClicked: root.stage = 'heirs'
    }
    EhStitchButton {
        visible: root.stage === 'confirm'
        kind: 'paper'
        text: qsTr('Keep it')
        onClicked: root.close()
    }

    // ---- 2: the heirs too?
    EhTitle {
        visible: root.stage === 'heirs'
        text: qsTr('Do you also want to delete the heirs?')
        fontSize: app.ehFsBox
        Layout.bottomMargin: 0
    }
    Para {
        visible: root.stage === 'heirs'
        text: qsTr('If you keep them, you find them ready when you make the inheritance again.')
    }
    Label {
        visible: root.stage === 'heirs' && root.bal !== null && root.bal.busy && root._mine
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: app.ehFsText
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
        visible: root.stage === 'heirs'
        kind: 'wine'
        icon: 'eh_lock_white.svg'
        text: qsTr('Yes, delete them')
        enabled: !(root.bal && root.bal.busy)
        onClicked: root.go(true)
    }
    EhStitchButton {
        visible: root.stage === 'heirs'
        kind: 'paper'
        icon: 'eh_lock.svg'
        text: qsTr('No, keep them')
        enabled: !(root.bal && root.bal.busy)
        onClicked: root.go(false)
    }

    // ---- 3: done (or sent, the wallet will see it in a little while)
    Image {
        visible: root.stage === 'done'
        Layout.alignment: Qt.AlignHCenter
        source: Qt.resolvedUrl('../../icons/eh_check.svg')
        sourceSize.width: 52
        sourceSize.height: 52
    }
    EhIconRing {
        visible: root.stage === 'sent'
        Layout.alignment: Qt.AlignHCenter
        big: true
        icon: 'eh_wait_wine.svg'
    }
    EhTitle {
        visible: root.stage === 'done'
        text: qsTr('Inheritance cancelled')
        fontSize: app.ehFsBox
        Layout.bottomMargin: 0
    }
    Para {
        visible: root.stage === 'done'
        text: qsTr('The old envelope is no longer valid. Your money stays yours.')
              + (root.deleteHeirs ? '' : ' ' + qsTr('Your heirs are still saved, ready for a new inheritance.'))
    }
    Para {
        visible: root.stage === 'sent'
        text: qsTr('The cancellation has left. Schȅi will see it in a little while.')
              + (root.deleteHeirs ? ' ' + qsTr('I will delete the heirs as soon as it sees it.') : '')
    }
    EhStitchButton {
        visible: root.stage === 'done' || root.stage === 'sent'
        kind: 'olive'
        icon: 'eh_check_white.svg'
        text: qsTr('Close')
        onClicked: root.close()
    }
}
