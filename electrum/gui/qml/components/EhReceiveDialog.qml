// Easy Heirs (schèi): RICEVI. Big QR in a green frame, an address card that
// holds the address and its own Share / Copy buttons. When the payment shows
// up, the same screen changes to "Ti sono arrivati" with the waiting note.
// "Bottega": parchment page, olive title, the address on a paper sheet, stitched buttons.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"
import "controls/EhStyle.js" as S

ElDialog {
    id: dialog
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.wine
    font.family: BodyFont ? BodyFont : Qt.application.font.family

    property string key
    property bool arrived: false
    property var demoAmount: null
    readonly property var shownAmount: demoAmount ? demoAmount : paidTx.amount

    readonly property string _address: request.address
    readonly property string _qrtext: request.amount.isEmpty ? request.address : request.bip21

    // "i" next to the amount asked: the QR holds the amount too; show its text
    function showAmountInfo() {
        var money = app.ehMoney(request.amount).replace(/ /g, ' ')   // "€ 248,75" never split
        // the QR text is one long word: allow a line break every 4 characters
        function wrap(s) { return s.replace(/(.{4})/g, '$1​') }
        var btc = app.ehBtc(request.amount)
        var head = dialog._qrtext.split('?')[0]
        var tail = dialog._qrtext.indexOf('?') >= 0 ? dialog._qrtext.substring(dialog._qrtext.indexOf('?')) : ''
        app.ehInfoDialog.createObject(app, {
            pageTitle: qsTr('You are asking %1').arg(money),
            bodyText: qsTr('This QR code does not only hold your address: it also holds <b>the amount to pay in bitcoin</b>.')
                      + '<br><br>' + qsTr('Whoever scans it finds the amount already written: they only have to confirm.')
                      + '<br><br><b>' + qsTr('The text inside the QR code') + '</b><br>'
                      + '<font face="monospace">' + wrap(head) + '<font color="#45541f"><b>' + wrap(tail) + '</b></font></font>',
            tipText: app.ehEuro(request.amount) !== '' ? qsTr('%1 are %2 at today\'s price.').arg(btc).arg(money) : ''
        }).open()
    }

    signal requestPaid

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false

    background: Rectangle { color: S.parch }

    // address in groups of 4, last group highlighted, on two lines
    function groupedAddress(highlight) {
        var a = dialog._address || ''
        var n = Math.ceil(a.length / 4)
        var half = Math.ceil(n / 2)
        var out = ''
        for (var i = 0; i < a.length; i++) {
            if (highlight && i === a.length - 4) out += '<font color="#45541f"><u>'
            out += a[i]
            if (highlight && i === a.length - 1) out += '</u></font>'
            var left = a.length - 1 - i
            if (left > 0 && left % 4 === 0)
                out += (left === 4 * Math.floor(n / 2)) ? '<br>' : ' '
        }
        return out
    }

    // owner 12/11: the page scrolls, so the last row is never under the phone keys
    Flickable {
        id: flick
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.height + 16
        boundsBehavior: Flickable.StopAtBounds
        clip: true

    ColumnLayout {
        id: col
        x: S.margin
        width: flick.width - 2 * S.margin
        height: Math.max(implicitHeight, flick.height - 16)
        spacing: 10

        EhPageTop { title: '' }

        // back
        EhBackLink { onClicked: dialog.doClose() }

        // ---------- QR view ----------
        EhTitle {
            visible: !dialog.arrived
            text: qsTr('Receive')
            icon: 'eh_rx_olive.svg'
            color: S.oliveInk
        }

        // amount asked: up here, so it is never hidden under the phone keys
        Rectangle {
            visible: !dialog.arrived && !request.amount.isEmpty
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: col.width
            Layout.preferredHeight: 48
            Layout.preferredWidth: askRow.implicitWidth + 28
            radius: 24
            color: infoTap.pressed ? Qt.darker(S.tipBg, 1.06) : S.tipBg
            border.width: 2
            border.color: S.tipEdge
            RowLayout {
                id: askRow
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 28)
                spacing: 10
                Label {
                    Layout.fillWidth: true
                    text: qsTr('You are asking %1').arg(app.ehMoney(request.amount))
                    color: S.oliveInk
                    font.pixelSize: 17
                    font.bold: true
                    elide: Text.ElideRight
                }
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 15
                    color: infoTap.pressed ? '#5d6f2a' : S.olive
                    Label { anchors.centerIn: parent; text: 'i'; color: '#ffffff'; font.pixelSize: 18; font.bold: true; font.family: SerifFont ? SerifFont : 'serif' }
                }
            }
            TapHandler { id: infoTap; onTapped: dialog.showAmountInfo() }
        }

        Label {
            visible: !dialog.arrived
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 17
            color: S.ink
            text: qsTr('Have the person sending you bitcoin scan this QR code.')
        }

        // the QR stays on pure white (cameras read it well), green frame, hard green shadow
        Item {
            visible: !dialog.arrived
            Layout.alignment: Qt.AlignHCenter
            readonly property real side: Math.min(dialog.width - 36, 300, dialog.height * 0.36)
            Layout.preferredWidth: side
            Layout.preferredHeight: side + 4
            Rectangle {
                y: 4
                width: parent.width
                height: parent.height - 4
                radius: 20
                color: '#b9c48a'
            }
            Rectangle {
                width: parent.width
                height: parent.height - 4
                radius: 20
                color: '#ffffff'
                border.width: 3
                border.color: S.olive
                Item {
                    anchors.fill: parent
                    anchors.margins: 14
                    QRImage {
                        id: qr
                        anchors.centerIn: parent
                        qrdata: dialog._qrtext
                        scale: Math.min(parent.width / Math.max(1, width), parent.height / Math.max(1, height))
                    }
                }
            }
        }

        // address card with its own buttons
        EhSheet {
            visible: !dialog.arrived
            topPadding: 12
            bottomPadding: 14
            spacing: 8
            Label {
                Layout.fillWidth: true
                text: qsTr('YOUR BITCOIN ADDRESS')
                color: S.olive
                font.pixelSize: 16
                font.bold: true
                font.letterSpacing: 0.5
                wrapMode: Text.WordWrap
                TapHandler { onTapped: app.ehZoomAddress(dialog._address, true) }
            }
            EhDotLine { Layout.topMargin: -2 }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                text: app.ehAddressRich(dialog._address, S.wineDark, S.highlight)
                font.family: FixedFont
                font.bold: true
                font.pixelSize: 18
                color: S.ink
                lineHeight: 1.2
                TapHandler { onTapped: app.ehZoomAddress(dialog._address, true) }
            }
            // under the address (it was over it)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(32, zoomRow.implicitHeight)
                RowLayout {
                    id: zoomRow
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width)
                    spacing: 6
                    Image { source: Qt.resolvedUrl('../../icons/eh_zoom.svg'); sourceSize.width: 20; sourceSize.height: 20 }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr('tap the address to enlarge')
                        font.pixelSize: 16
                        font.bold: true
                        color: S.muted
                        wrapMode: Text.WordWrap
                    }
                }
                TapHandler { onTapped: app.ehZoomAddress(dialog._address, true) }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8
                EhStitchButton {
                    id: shareBtn
                    kind: 'paper'
                    icon: 'eh_share_wine.svg'
                    text: qsTr('Share')
                    onClicked: AppController.doShare(dialog._qrtext, qsTr('My bitcoin address'))
                }
                EhStitchButton {
                    id: copyBtn
                    kind: 'paper'
                    icon: 'eh_copy_wine.svg'
                    text: qsTr('Copy')
                    onClicked: {
                        AppController.textToClipboard(dialog._qrtext)
                        toaster.show(copyBtn, qsTr('Copied!'))
                    }
                }
            }
        }

        // second review (RN-1): expert option "Ask for an amount": the page "How much are you
        // asking for?" makes a new request with the amount; this page closes, the new one opens
        EhStitchButton {
            visible: !dialog.arrived && app.ehOption('request_amount') && request.amount.isEmpty
            Layout.topMargin: 4
            kind: 'paper'
            icon: 'eh_euro.svg'
            text: qsTr('Ask for an amount')
            onClicked: {
                var d = app.ehAskAmountDialog.createObject(app)
                d.accepted.connect(function() { dialog.close() })
                d.open()
            }
        }

        // T8: the addresses, only for who taps here (choose, copy, block an address)
        // owner 12/11: not in BASE, only in MEDIO and ESPERTO
        EhSheet {
            visible: !dialog.arrived && app.ehLevelNum() > 0
            Layout.topMargin: 4
            EhRow {
                icon: 'eh_list_olive.svg'
                iconColor: S.olive
                text: qsTr('Your addresses')
                hint: qsTr('choose, copy or block an address')
                last: true
                onClicked: {
                    dialog.close()
                    app.stack.push(Qt.resolvedUrl('EhAddressesPage.qml'))
                }
            }
        }


        // ---------- arrived view ----------
        ColumnLayout {
            visible: dialog.arrived
            Layout.fillWidth: true
            Layout.topMargin: 20
            spacing: 10
            Image {
                Layout.alignment: Qt.AlignHCenter
                source: Qt.resolvedUrl('../../icons/eh_check.svg')
                sourceSize.width: 110
                sourceSize.height: 110
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr('You received')
                font.family: SerifFont ? SerifFont : font.family
                font.weight: Font.ExtraBold
                font.pixelSize: 26
                color: S.oliveInk
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: col.width
                text: dialog.shownAmount.isEmpty ? '' : app.ehMoney(dialog.shownAmount)
                visible: text !== ''
                font.family: SerifFont ? SerifFont : font.family
                font.weight: Font.ExtraBold
                font.pixelSize: 44
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 24
                color: S.oliveInk
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: dialog.shownAmount.isEmpty || app.ehEuro(dialog.shownAmount) === '' ? '' : app.ehBtc(dialog.shownAmount)
                font.pixelSize: 16
                color: S.muted
            }
            EhInfoBox {
                id: waitText
                kind: 'warn'
                fontSize: 17
                text: ('<b>' + qsTr('Arriving.') + '</b> ' + qsTr('The payment has left. To be safe you need to wait for <b>at least one confirmation</b>: usually about ten minutes, sometimes more. Meanwhile have a chat or a glass of wine 🍷 in company.'))
                      .replace('🍷', '<img src="' + Qt.resolvedUrl('../../icons/eh_wine.svg') + '" width="18" height="25">')
            }
            EhStitchButton {
                kind: 'paper'
                icon: 'eh_info.svg'
                text: qsTr('More information')
                onClicked: app.ehShowConfirmationsInfo()
            }
        }

        Item { Layout.fillHeight: true }

        EhStitchButton {
            visible: dialog.arrived
            kind: 'olive'
            icon: 'eh_home_ivory.svg'
            text: qsTr('Back to home')
            onClicked: dialog.doAccept()
        }
    }
    }

    RequestDetails {
        id: request
        wallet: Daemon.currentWallet
        onStatusChanged: {
            if (status == RequestDetails.Paid || status == RequestDetails.Unconfirmed) {
                paidTx.txid = request.paidTxid
                dialog.arrived = true
                AppController.haptic()
                dialog.requestPaid()
            }
        }
    }

    TxDetails {
        id: paidTx
        wallet: Daemon.currentWallet
    }

    Toaster { id: toaster }

    Component.onCompleted: request.key = dialog.key
}
