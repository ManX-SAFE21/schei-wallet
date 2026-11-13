// Easy Heirs (schèi): INVIA step 1 - "A chi mandi?". Camera already on, or
// paste a bitcoin address. Found data goes to the usual Electrum resolver
// (piResolver -> invoiceParser), then our EhInvoiceDialog opens.
// "Bottega": parchment page, the pasted address on a paper sheet, stitched buttons.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"
import "controls/EhStyle.js" as S

ElDialog {
    id: root
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.wine
    font.family: BodyFont ? BodyFont : Qt.application.font.family

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
    background: Rectangle { color: S.parch }

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

    // viewfinder: green corners and a vibration for a moment, then the code is used as before
    property string _ehFound: ''
    function ehQrFound(data) {
        if (_ehFound !== '') return
        _ehFound = data
        AppController.haptic()
        ehFoundTimer.restart()
    }
    Timer {
        id: ehFoundTimer
        interval: 300
        onTriggered: { var d = root._ehFound; root._ehFound = ''; root.dispatch(d) }
    }

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

    // every page scrolls: nothing under the phone keys, also with the big phone font
    Flickable {
        id: flick
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: Math.max(height, col.implicitHeight + 16)
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height + 1
        clip: true

    ColumnLayout {
        id: col
        x: S.margin
        width: flick.width - 2 * S.margin
        height: Math.max(flick.height - 16, implicitHeight)
        spacing: 10

        EhPageTop { title: ''; steps: app.ehSendSteps(); stepNow: 1 }

        EhBackLink { onClicked: { app._ehDraft = null; root.doClose() } }   // given up: forget what was typed

        Label {
            text: qsTr('STEP %1 OF %2').arg(1).arg(3)
            visible: false   // the steps bar at the top says it now
            color: S.olive
            font.pixelSize: 16
            font.bold: true
        }

        EhTitle {
            text: qsTr('Who are you sending to?')
            icon: 'eh_tx_wine.svg'
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 18
            color: S.ink
            text: qsTr('Scan the bitcoin QR code of the person you have to pay.')
            visible: root.pasted === ''
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 200
            Layout.maximumHeight: 360
            visible: root.pasted === ''
            radius: 20
            color: '#1e1b1a'
            clip: true
            // camera only on the phone (the PC preview has no camera / QR library)
            Loader {
                id: camLoader
                anchors.fill: parent
                active: AppController.isAndroid()
                sourceComponent: QRScan {
                    hint: ''
                    onFoundText: (data) => root.ehQrFound(data)
                }
            }
            Label {
                visible: !camLoader.active
                anchors.centerIn: parent
                text: qsTr('the camera is already on')
                color: '#ffffff'
                font.pixelSize: 16
            }
            // owner 13/11: a viewfinder, so it is clear where to put the code and how to turn it
            Item {
                id: finder
                anchors.fill: parent
                readonly property bool found: root._ehFound !== ''
                readonly property real side: Math.max(60, Math.min(width - 60, height - 70))
                readonly property real fx: (width - side) / 2
                readonly property real fy: Math.max(12, (height - side) / 2 - 14)
                readonly property color ink: found ? '#9cc25a' : S.gold
                // darker outside the frame (one shape with a hole, with the box's round corners)
                Canvas {
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var c = getContext('2d')
                        c.reset()
                        c.fillStyle = 'rgba(0,0,0,0.55)'
                        c.fillRule = Qt.OddEvenFill
                        c.beginPath()
                        c.roundedRect(0, 0, width, height, 20, 20)
                        c.rect(finder.fx, finder.fy, finder.side, finder.side)
                        c.fill()
                    }
                }
                Item {
                    id: fbox
                    x: finder.fx
                    y: finder.fy
                    width: finder.side
                    height: finder.side
                    // the 3 squares of a QR code, transparent: how the code goes
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            readonly property real m: fbox.width * 0.09
                            width: fbox.width * 0.18
                            height: width
                            x: index === 1 ? fbox.width - width - m : m
                            y: index === 2 ? fbox.height - height - m : m
                            radius: 4
                            color: 'transparent'
                            border.width: Math.max(3, width * 0.16)
                            border.color: Qt.rgba(1, 1, 1, 0.35)
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * 0.4
                                height: width
                                radius: 2
                                color: Qt.rgba(1, 1, 1, 0.35)
                            }
                        }
                    }
                    // the gold corners
                    Repeater {
                        model: 4
                        Item {
                            required property int index
                            readonly property bool isRight: index % 2 === 1
                            readonly property bool isBottom: index >= 2
                            width: 40
                            height: 40
                            x: isRight ? fbox.width - width + 3 : -3
                            y: isBottom ? fbox.height - height + 3 : -3
                            Rectangle { width: 40; height: 6; radius: 3; y: parent.isBottom ? 34 : 0; color: finder.ink }
                            Rectangle { width: 6; height: 40; radius: 3; x: parent.isRight ? 34 : 0; color: finder.ink }
                        }
                    }
                    // a gold line going up and down: the camera is looking
                    Rectangle {
                        id: scanLine
                        visible: !finder.found
                        x: 14
                        width: fbox.width - 28
                        height: 3
                        radius: 1.5
                        y: fbox.height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.rgba(0.91, 0.78, 0.41, 0) }
                            GradientStop { position: 0.5; color: Qt.rgba(0.91, 0.78, 0.41, 1) }
                            GradientStop { position: 1.0; color: Qt.rgba(0.91, 0.78, 0.41, 0) }
                        }
                        SequentialAnimation on y {
                            loops: Animation.Infinite
                            running: !app.ehOption('no_anim') && !finder.found && fbox.height > 40
                            NumberAnimation { from: 14; to: fbox.height - 17; duration: 1600; easing.type: Easing.InOutSine }
                            NumberAnimation { from: fbox.height - 17; to: 14; duration: 1600; easing.type: Easing.InOutSine }
                        }
                    }
                }
                Label {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: qsTr('Put the QR code inside the frame')
                    color: '#ffffff'
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 16
                    font.bold: true
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                }
            }

            // the wine frame, over the camera picture
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: 'transparent'
                border.width: 3
                border.color: S.wine
            }
        }

        // ---- after "Paste": the address, big, to check it ----
        EhSheet {
            visible: root.pasted !== ''
            Layout.topMargin: 8
            topPadding: 12
            bottomPadding: 14
            spacing: 10
            Label {
                Layout.fillWidth: true
                text: qsTr('YOU PASTED THIS ADDRESS')
                color: S.wine
                font.pixelSize: 16
                font.bold: true
                font.letterSpacing: 0.5
                wrapMode: Text.WordWrap
            }
            EhDotLine { Layout.topMargin: -4 }
            Label {
                id: pAddr
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                text: app.ehAddressRich(root.addrOf(root.pasted), S.wineDark, S.highlight,
                                        Math.max(1, Math.floor((width + pFm.averageCharacterWidth) / (pFm.averageCharacterWidth * 5))))
                font.family: FixedFont
                font.bold: true
                font.pixelSize: 18
                lineHeight: 1.25
                color: S.ink
                FontMetrics { id: pFm; font: pAddr.font }
            }
            EhInfoBox {
                id: tipL
                kind: 'warn'
                readonly property var parts: app.ehAddressParts(root.addrOf(root.pasted))
                text: parts.prefix !== ''
                      ? qsTr('Check that after <b>%1</b> there is <b>%2</b> and that it ends with <b>%3</b>, like the one you were given.').arg(parts.prefix).arg(parts.first).arg(parts.last)
                      : qsTr('Check that it starts with <b>%1</b> and ends with <b>%2</b>, like the one you were given.').arg(parts.first).arg(parts.last)
            }
        }

        Item { visible: root.pasted !== ''; Layout.fillHeight: true }

        // T23: the same address as before (still in the clipboard)
        EhInfoBox {
            id: sameL
            visible: root.pasteSame && root.pasted !== ''
            kind: 'warn'
            text: qsTr('<b>It is the same address as before.</b> In the phone memory there is still that one: copy the new address and paste again.')
        }

        Label {
            visible: root.pasteError
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: qsTr('This is not a bitcoin address. Copy it again and retry.')
            color: S.red
            font.pixelSize: 16
            font.bold: true
        }

        EhStitchButton {
            visible: root.pasted !== ''
            kind: 'wine'
            endIcon: 'next'
            text: qsTr('Yes, it is right: next')
            onClicked: root.dispatch(root.pasted)
        }

        // T23: a wrong paste can be thrown away
        EhStitchButton {
            visible: root.pasted !== ''
            kind: 'paper'
            icon: 'eh_cross.svg'
            text: qsTr('Clear this address')
            onClicked: root.clearPasted()
        }

        EhStitchButton {
            id: pasteBtn
            kind: 'paper'
            icon: 'eh_paste.svg'
            text: root.pasted !== '' ? qsTr('Paste another one') : qsTr('Paste a bitcoin address')
            onClicked: {
                var cliptext = AppController.clipboardToText().trim()
                if (!cliptext) {
                    toaster.show(pasteBtn,qsTr('There is nothing to paste: copy the address first.'))
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
