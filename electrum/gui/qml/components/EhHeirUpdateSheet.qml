// Easy Heirs (schȅi): "update the inheritance" (inheritance, screen 8). Opened over the home
// by main.qml ehHeirDecide when the envelope no longer covers the coins: money received,
// a payment made (owner 9.1), or an inheritance left unfinished. The PIN, then bal.update():
// free, the delivery moves one day earlier (owner 9.2). It closes when the update is done.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "controls"
import "controls/EhStyle.js" as S

EhBottomSheet {
    id: root
    property string reason: 'received'         // received | spent | changed | unfinished
    readonly property var bal: AppController.plugin('bal')
    readonly property var st: app.ehHeirState(bal)   // M1: only the wallet open
    property string error: ''
    property bool _mine: false
    readonly property int bigText: Math.round(18 * app.ehFs)

    dimOpacity: 0.32
    closable: !(bal && bal.busy && _mine)

    onClosed: destroy()

    Connections {
        target: root.bal
        function onDone(op, result) {
            if (op !== 'update') return
            root._mine = false
            root.close()
        }
        function onFailed(op, code, message) {
            if (op !== 'update') return
            root._mine = false
            root.error = app.ehHeirErrorText(code, message)
        }
    }

    // owner 22/11: bigger, with a title; after a payment the risk said at once, in red
    EhTitle {
        text: qsTr('Update the inheritance')
        fontSize: app.ehFsTitle
        Layout.bottomMargin: 0
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        EhIconRing {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 56
            color: S.paper
            ringColor: root.reason === 'received' ? S.olive : S.wine
            iconSize: 32
            icon: root.reason === 'received' ? 'eh_rx_olive.svg'
                : root.reason === 'spent' ? 'eh_tx_wine.svg' : 'eh_will.svg'
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: root.reason === 'received' ? app.ehFsStrong : root.bigText
                lineHeight: 1.15
                color: S.ink
                text: root.reason === 'received' ? qsTr('You received')
                      : root.reason === 'unfinished' ? qsTr('The inheritance is not finished.')
                      : root.reason === 'changed' ? qsTr('The inheritance must be put in order: for example the heirs changed, or a keeper no longer has the envelope.')
                      : qsTr('You made a payment.')
            }
            Label {
                visible: root.reason === 'received'
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsTitle
                font.bold: true
                color: S.oliveInk
                text: app.ehHeirSats(root.st.uncoveredSats || 0)
            }
        }
    }
    Label {
        visible: root.reason !== 'spent'
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.StyledText
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: root.bigText
        lineHeight: 1.15
        color: S.ink
        text: root.reason === 'received' ? qsTr('Do I update the inheritance so it covers this money too?')
              : root.reason === 'unfinished' ? qsTr('Do I finish it now?')
              : qsTr('Do I fix it now?')
    }
    EhInfoBox {
        visible: root.reason === 'spent'
        kind: 'danger'
        showIcon: false
        fontSize: app.ehFsStrong
        text: qsTr('<b>The inheritance is no longer valid:</b> if you do not update, the heirs receive nothing.')
    }

    Label {
        visible: root.bal !== null && root.bal.busy && root._mine
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
        kind: 'wine'
        icon: 'eh_lock_white.svg'
        endIcon: 'next'
        text: qsTr('Update with the PIN')
        enabled: !(root.bal && root.bal.busy)
        onClicked: app.ehAskPin(qsTr('Type the PIN to update the inheritance'), function() {
            if (!root.bal) return
            root.error = ''
            root._mine = true
            root.bal.update()
        })
    }
    EhInfoBox {
        kind: 'tip'
        // each free update dates the envelope one day earlier (an unfinished one keeps its date);
        // owner 18/11: after a payment that spent the envelope's coins the old envelope is already
        // dead: the new one starts again from today, for the whole period (newDelivery)
        text: qsTr('It costs nothing. The delivery becomes <b>%1</b>.')
                .arg(app.ehHeirDate(root.reason === 'spent'
                                    // Opus review 18/11: a fixed-date will (no period) keeps its date
                                    ? ((root.st.newDelivery || 0) > 0 ? root.st.newDelivery : (root.st.delivery || 0))
                                    : (root.st.delivery || 0) - (root.reason === 'unfinished' ? 0 : 86400)))
        fontSize: app.ehFsStrong
    }
    Label {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 2
        text: '<u>' + qsTr('More information') + '</u>'
        textFormat: Text.StyledText
        color: S.wine
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: app.ehFsStrong
        font.bold: true
        TapHandler { onTapped: app.ehShowHeirUpdateInfo() }
    }
}
