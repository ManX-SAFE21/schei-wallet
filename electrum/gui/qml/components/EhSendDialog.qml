// Easy Heirs (schèi): INVIA step 1 - "A chi mandi?". Camera already on, or
// paste a bitcoin address. Found data goes to the usual Electrum resolver
// (piResolver -> invoiceParser), then our EhInvoiceDialog opens.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"

ElDialog {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'

    property var invoiceParser  // type: InvoiceParser
    property var piResolver  // type: PIResolver

    signal txFound(data: string)
    signal channelBackupFound(data: string)

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    background: Rectangle { color: '#faf7ef' }

    function restart() { if (camLoader.item) camLoader.item.restart() }

    // pasted address: shown big first, so a wrong paste is seen before going on
    property string pasted: ''
    property bool pasteError: false
    property bool pasteSame: false   // T23: pasted again the address already shown
    function clearPasted() {
        root.pasted = ''; root.pasteError = false; root.pasteSame = false
        if (camLoader.item) camLoader.item.start()
    }
    function addrOf(s) { return s.replace(/^bitcoin:/i, '').split('?')[0] }

    function dispatch(data) {
        data = data.trim()
        // review 2026-11-11: nobody listened to txFound / channelBackupFound, the QR was ignored.
        // Schèi does not use these codes: say it, instead of doing nothing.
        if (bitcoin.isRawTx(data) || Daemon.currentWallet.isValidChannelBackup(data)) {
            if (camLoader.item) camLoader.item.stop()
            var info = app.ehInfoDialog.createObject(app, {
                pageTitle: qsTr('This code is not an address'),
                bodyText: qsTr('This QR code holds a whole transaction or a backup, not a bitcoin address to pay. Schèi cannot use it.')
                          + '<br><br>' + qsTr('Ask the person you pay for their bitcoin address.')
            })
            // second review (F1): the camera starts again only when the page is closed, and with
            // restart(): start() alone kept the old code and never read another one
            info.closed.connect(root.restart)
            info.open()
        } else {
            piResolver.recipient = data
        }
    }

    function doClose() {
        if (camLoader.item) camLoader.item.stop()
        Qt.callLater(doReject)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.bottomMargin: 18 + app.navigationBarHeight
        spacing: 10

        EhPageTop { title: ''; steps: app.ehSendSteps(); stepNow: 1 }

        Label {
            Layout.topMargin: -14
            text: '‹ ' + qsTr('Back')
            color: '#5e1a33'
            font.pixelSize: 17
            font.bold: true
            TapHandler { margin: 10; onTapped: { app._ehDraft = null; root.doClose() } }   // given up: forget what was typed
        }

        Label {
            text: qsTr('STEP %1 OF %2').arg(1).arg(3)
            visible: false   // the steps bar at the top says it now
            color: '#5e1a33'
            font.pixelSize: 14
            font.bold: true
        }

        RowLayout {
            spacing: 10
            Image {
                source: Qt.resolvedUrl('../../icons/eh_tx_wine.svg')
                sourceSize.width: 36
                sourceSize.height: 36
            }
            Label {
                text: qsTr('Who are you sending to?')
                color: '#5e1a33'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 28
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 18
            color: '#2a2220'
            text: qsTr('Scan the bitcoin QR code of the person you have to pay.')
            visible: root.pasted === ''
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumHeight: 360
            visible: root.pasted === ''
            radius: 24
            color: '#1e1b1a'
            clip: true
            // camera only on the phone (the PC preview has no camera / QR library)
            Loader {
                id: camLoader
                anchors.fill: parent
                active: AppController.isAndroid()
                sourceComponent: QRScan {
                    hint: qsTr('the camera is already on')
                    onFoundText: (data) => root.dispatch(data)
                }
            }
            Label {
                visible: !camLoader.active
                anchors.centerIn: parent
                text: qsTr('the camera is already on')
                color: '#ffffff'
                font.pixelSize: 15
            }
        }

        // ---- after "Paste": the address, big, to check it ----
        Rectangle {
            visible: root.pasted !== ''
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.preferredHeight: pastedCol.implicitHeight + 32
            radius: 20
            color: '#ffffff'
            border.width: 2
            border.color: '#f0dbe2'
            ColumnLayout {
                id: pastedCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 10
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr('YOU PASTED THIS ADDRESS')
                    color: '#3f0f21'
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 0.6
                }
                Label {
                    id: pAddr
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                    text: app.ehAddressRich(root.addrOf(root.pasted), '#3f0f21', '#f7e3e8',
                                            Math.max(1, Math.floor((pastedCol.width + pFm.averageCharacterWidth) / (pFm.averageCharacterWidth * 5))))
                    font.family: FixedFont
                    font.bold: true
                    font.pixelSize: 20
                    lineHeight: 1.25
                    FontMetrics { id: pFm; font: pAddr.font }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: tipL.implicitHeight + 20
                    radius: 12
                    color: '#fbf0d6'
                    Label {
                        id: tipL
                        anchors.fill: parent
                        anchors.margins: 10
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        font.pixelSize: 16
                        color: '#2a2220'
                        readonly property var parts: app.ehAddressParts(root.addrOf(root.pasted))
                        text: parts.prefix !== ''
                              ? qsTr('Check that after <b>%1</b> there is <b>%2</b> and that it ends with <b>%3</b>, like the one you were given.').arg(parts.prefix).arg(parts.first).arg(parts.last)
                              : qsTr('Check that it starts with <b>%1</b> and ends with <b>%2</b>, like the one you were given.').arg(parts.first).arg(parts.last)
                    }
                }
            }
        }

        Item { visible: root.pasted !== ''; Layout.fillHeight: true }

        // T23: the same address as before (still in the clipboard)
        Rectangle {
            visible: root.pasteSame && root.pasted !== ''
            Layout.fillWidth: true
            Layout.preferredHeight: sameL.implicitHeight + 20
            radius: 14
            color: '#fdf1d4'
            border.width: 2
            border.color: '#e0a21a'
            Label {
                id: sameL
                x: 12; y: 10
                width: parent.width - 24
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                font.pixelSize: 15
                color: '#3f0f21'
                text: qsTr('<b>It is the same address as before.</b> In the phone memory there is still that one: copy the new address and paste again.')
            }
        }

        Label {
            visible: root.pasteError
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: qsTr('This is not a bitcoin address. Copy it again and retry.')
            color: '#b3261e'
            font.pixelSize: 16
            font.bold: true
        }

        EhNextButton {
            visible: root.pasted !== ''
            Layout.fillWidth: true
            text: qsTr('Yes, it is right: next')
            onClicked: root.dispatch(root.pasted)
        }

        // T23: a wrong paste can be thrown away
        Rectangle {
            visible: root.pasted !== ''
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 44
            Layout.preferredWidth: clRow.implicitWidth + 36
            radius: 22
            color: clMa.pressed ? '#f7e3e8' : '#ffffff'
            border.width: 2
            border.color: '#e6b9b3'
            RowLayout {
                id: clRow
                anchors.centerIn: parent
                spacing: 8
                Image { source: Qt.resolvedUrl('../../icons/eh_cross.svg'); sourceSize.width: 18; sourceSize.height: 18 }
                Label { text: qsTr('Clear this address'); color: '#b3261e'; font.pixelSize: 16; font.bold: true }
            }
            MouseArea { id: clMa; anchors.fill: parent; onClicked: root.clearPasted() }
        }

        EhPillButton {
            text: root.pasted !== '' ? qsTr('Paste another one') : qsTr('Paste a bitcoin address')
            color: '#ffffff'
            textColor: '#2a2220'
            tileColor: '#efe6d3'
            fontSize: 20
            onClicked: {
                var cliptext = AppController.clipboardToText().trim()
                if (!cliptext) {
                    toaster.show(this, qsTr('There is nothing to paste: copy the address first.'))
                    return
                }
                if (camLoader.item) camLoader.item.stop()
                if (bitcoin.isRawTx(cliptext) || Daemon.currentWallet.isValidChannelBackup(cliptext)) {
                    root.dispatch(cliptext)
                    return
                }
                if (!bitcoin.isAddress(root.addrOf(cliptext))) {
                    root.pasted = ''
                    root.pasteError = true
                    root.pasteSame = false
                    return
                }
                root.pasteError = false
                // T23: same address again: say it, so it does not look like nothing happened
                root.pasteSame = root.pasted !== '' && root.addrOf(cliptext) === root.addrOf(root.pasted)
                if (root.pasteSame) AppController.haptic()
                root.pasted = cliptext
            }
            Image {
                anchors.centerIn: parent
                source: Qt.resolvedUrl('../../icons/eh_paste.svg')
                sourceSize.width: 28
                sourceSize.height: 28
            }
        }
    }

    Bitcoin { id: bitcoin }
    Toaster { id: toaster }

    Binding {
        target: AppController
        property: 'secureWindow'
        value: true
        when: root.visible
    }
}
