// Easy Heirs (schȅi): "Sei ancora qui?" (inheritance, screen 7). From the day of the
// reminder (phase due) and after the delivery date (phase expired) it opens over the home once
// per opening of the app (main.qml ehHeirDecide); the Status page opens it with "Renew now".
// "Yes, renew" asks the PIN, then bal.renew(); "Later" just closes.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "controls"
import "controls/EhStyle.js" as S

EhBottomSheet {
    id: root
    readonly property var bal: AppController.plugin('bal')
    readonly property var st: bal ? bal.state : ({})
    property string error: ''
    property bool _mine: false                 // the job running is ours (renew)

    closable: !(bal && bal.busy && _mine)

    onClosed: destroy()

    Connections {
        target: root.bal
        function onDone(op, result) {
            if (op !== 'renew') return
            root._mine = false
            root.close()
        }
        function onFailed(op, code, message) {
            if (op !== 'renew') return
            root._mine = false
            root.error = app.ehHeirErrorText(code, message)
        }
    }

    EhTitle {
        text: qsTr('Are you still here?')
        fontSize: 28
        Layout.bottomMargin: 0
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.StyledText
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 16
        lineHeight: 1.15
        color: S.ink
        text: qsTr('<b>%1 months</b> to the delivery. If you renew, the inheritance starts again from today for %2: delivery on <b>%3</b>.')
                .arg(root.st.monthsToDelivery || 0)
                .arg(app.ehHeirYears(root.st.months || 0))
                .arg(app.ehHeirDate(root.st.newDelivery))
    }
    EhInfoBox {
        kind: 'warn'
        text: qsTr('The renewal makes a small operation on the bitcoin network: it costs about <b>%1</b>.')
                .arg(app.ehHeirSats(root.st.fees ? root.st.fees.renewSats : 0))
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 16
            lineHeight: 1.15
            color: S.ink
            text: qsTr('When you renew, Schȅi joins all the coins into one.')
        }
    }

    // while it works: one line with the step; a failure: the reason
    Label {
        visible: root.bal !== null && root.bal.busy && root._mine
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
        kind: 'olive'
        icon: 'eh_check_white.svg'
        text: qsTr('Yes, renew')
        enabled: !(root.bal && root.bal.busy)
        onClicked: app.ehAskPin(qsTr('Type the PIN to renew the inheritance'), function() {
            if (!root.bal) return
            root.error = ''
            root._mine = true
            root.bal.renew()
        })
    }
    EhStitchButton {
        kind: 'paper'
        icon: 'eh_pen_wine.svg'
        text: qsTr('Change heirs or period')
        enabled: !(root.bal && root.bal.busy)
        onClicked: {
            root.close()
            app.stack.push(Qt.resolvedUrl('EhHeirWhoPage.qml'))
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        visible: root.closable
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            Label {
                id: later
                anchors.centerIn: parent
                text: qsTr('Later')
                color: S.wine
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 17
                font.bold: true
                opacity: laterTap.pressed ? 0.6 : 1
            }
            Rectangle {
                x: later.x
                y: later.y + later.height + 1
                width: later.width
                height: 2
                color: S.wine
                opacity: later.opacity
            }
            TapHandler { id: laterTap; margin: 8; onTapped: root.close() }
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 15
            color: S.muted
            text: qsTr('I ask you again next time you open Schȅi')
        }
    }
}
