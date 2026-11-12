// Easy Heirs (schèi): RICEVI. Big QR in a green frame, an address card that
// holds the address and its own Share / Copy buttons. When the payment shows
// up, the same screen changes to "Ti sono arrivati" with the waiting note.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"

ElDialog {
    id: dialog
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'

    property string key
    property bool arrived: false
    property var demoAmount: null
    readonly property var shownAmount: demoAmount ? demoAmount : paidTx.amount

    readonly property string _address: request.address
    readonly property string _qrtext: request.amount.isEmpty ? request.address : request.bip21

    // "i" next to the amount asked: the QR holds the amount too; show its text
    function showAmountInfo() {
        var money = app.ehMoney(request.amount).replace(/ /g, '\u00a0')   // "€ 248,75" never split
        // the QR text is one long word: allow a line break every 4 characters
        function wrap(s) { return s.replace(/(.{4})/g, '$1\u200b') }
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

    background: Rectangle {
        color: '#faf7ef'
        EhGlow { tone: 'green'; z: 0; x: -parent.width * 0.25; y: 30; width: parent.width * 1.5; height: 340 }
    }

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
        contentHeight: col.height + 18
        boundsBehavior: Flickable.StopAtBounds
        clip: true

    ColumnLayout {
        id: col
        x: 18
        width: flick.width - 36
        height: Math.max(implicitHeight, flick.height - 18)
        spacing: 10

        EhPageTop { title: '' ; Layout.bottomMargin: -14 }

        // back
        Label {
            text: '‹ ' + qsTr('Back')
            color: '#5e1a33'
            font.pixelSize: 17
            font.bold: true
            TapHandler { margin: 10; onTapped: dialog.doClose() }
        }

        // ---------- QR view ----------
        RowLayout {
            visible: !dialog.arrived
            spacing: 10
            Image {
                source: Qt.resolvedUrl('../../icons/eh_rx_olive.svg')
                sourceSize.width: 36
                sourceSize.height: 36
            }
            Label {
                text: qsTr('Receive')
                color: '#45541f'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 30
            }
        }

        // amount asked: up here, so it is never hidden under the phone keys
        Rectangle {
            visible: !dialog.arrived && !request.amount.isEmpty
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 44
            Layout.preferredWidth: askRow.implicitWidth + 28
            radius: 22
            color: '#e6ecc8'
            border.width: 2
            border.color: '#c9d39a'
            RowLayout {
                id: askRow
                anchors.centerIn: parent
                spacing: 10
                Label {
                    text: qsTr('You are asking %1').arg(app.ehMoney(request.amount))
                    color: '#2f3a12'
                    font.pixelSize: 17
                    font.bold: true
                }
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 15
                    color: infoTap.pressed ? '#5d6f2a' : '#45541f'
                    Label { anchors.centerIn: parent; text: 'i'; color: '#ffffff'; font.pixelSize: 18; font.bold: true; font.family: 'serif' }
                }
            }
            TapHandler { id: infoTap; onTapped: dialog.showAmountInfo() }
        }

        Label {
            visible: !dialog.arrived
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 17
            color: '#2a2220'
            text: qsTr('Have the person sending you bitcoin scan this QR code.')
        }

        Rectangle {
            visible: !dialog.arrived
            Layout.alignment: Qt.AlignHCenter
            readonly property real side: Math.min(dialog.width - 36, 300, dialog.height * 0.36)
            Layout.preferredWidth: side
            Layout.preferredHeight: side
            radius: 24
            color: '#ffffff'
            border.width: 3
            border.color: '#45541f'
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

        // address card with its own buttons
        Rectangle {
            visible: !dialog.arrived
            Layout.fillWidth: true
            Layout.preferredHeight: card.implicitHeight + 24
            radius: 20
            color: '#ffffff'
            border.width: 2
            border.color: '#e6e9cf'
            ColumnLayout {
                id: card
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                Label {
                    text: qsTr('YOUR BITCOIN ADDRESS')
                    color: '#45541f'
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 0.4
                    TapHandler { onTapped: app.ehZoomAddress(dialog._address, true) }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 5
                    Image { source: Qt.resolvedUrl('../../icons/eh_zoom.svg'); sourceSize.width: 16; sourceSize.height: 16 }
                    Label { text: qsTr('tap the address to enlarge'); font.pixelSize: 12; font.bold: true; color: '#45541f' }
                    TapHandler { onTapped: app.ehZoomAddress(dialog._address, true) }
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.RichText
                    text: app.ehAddressRich(dialog._address, '#45541f', '#e6e9cf')
                    font.family: FixedFont
                    font.bold: true
                    font.pixelSize: 16
                    color: '#2a2220'
                    lineHeight: 1.2
                    TapHandler { onTapped: app.ehZoomAddress(dialog._address, true) }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: [
                            { 'icon': 'eh_share.svg', 'text': qsTr('Share'), 'act': 'share' },
                            { 'icon': 'eh_copy.svg', 'text': qsTr('Copy'), 'act': 'copy' }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            radius: 24
                            color: btnTap.pressed ? '#e4e8cc' : '#f1f3e2'
                            border.width: 2
                            border.color: '#d5dbb0'
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Image {
                                    source: Qt.resolvedUrl('../../icons/' + modelData.icon)
                                    sourceSize.width: 22
                                    sourceSize.height: 22
                                }
                                Label {
                                    text: modelData.text
                                    color: '#2f3a12'
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                            }
                            TapHandler {
                                id: btnTap
                                onTapped: {
                                    if (modelData.act === 'copy') {
                                        AppController.textToClipboard(dialog._qrtext)
                                        toaster.show(parent, qsTr('Copied!'))
                                    } else {
                                        AppController.doShare(dialog._qrtext, qsTr('My bitcoin address'))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // second review (RN-1): expert option "Ask for an amount": the page "How much are you
        // asking for?" makes a new request with the amount; this page closes, the new one opens
        EhPillButton {
            visible: !dialog.arrived && app.ehOption('request_amount') && request.amount.isEmpty
            Layout.topMargin: 4
            text: qsTr('Ask for an amount')
            fontSize: 18
            color: '#ffffff'
            textColor: '#45541f'
            onClicked: {
                var d = app.ehAskAmountDialog.createObject(app)
                d.accepted.connect(function() { dialog.close() })
                d.open()
            }
                Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_euro.svg'); sourceSize.width: 28; sourceSize.height: 28 }
        }

        // T8: the addresses, only for who taps here (choose, copy, block an address)
        // owner 12/11: not in BASE, only in MEDIO and ESPERTO
        Rectangle {
            visible: !dialog.arrived && app.ehLevelNum() > 0
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: adRow.implicitHeight + 22
            radius: 16
            color: adMa.pressed ? '#f1f3e2' : '#ffffff'
            border.width: 1.5
            border.color: '#e3e6cc'
            RowLayout {
                id: adRow
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12
                Image { source: Qt.resolvedUrl('../../icons/eh_list_olive.svg'); sourceSize.width: 26; sourceSize.height: 26; Layout.preferredWidth: 26; Layout.preferredHeight: 26 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: qsTr('Your addresses'); font.pixelSize: 17; font.bold: true; color: '#2a2220' }
                    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: qsTr('choose, copy or block an address'); font.pixelSize: 13; color: '#6b5d55' }
                }
                Label { text: '›'; font.pixelSize: 24; font.bold: true; color: '#45541f' }
            }
            MouseArea {
                id: adMa
                anchors.fill: parent
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
                font.pixelSize: 22
                font.bold: true
                color: '#2a2220'
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: dialog.shownAmount.isEmpty ? '' : app.ehMoney(dialog.shownAmount)
                visible: text !== ''
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 44
                color: '#45541f'
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: dialog.shownAmount.isEmpty || app.ehEuro(dialog.shownAmount) === '' ? '' : app.ehBtc(dialog.shownAmount)
                font.pixelSize: 16
                color: '#6b5d55'
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: waitText.implicitHeight + 24
                radius: 16
                color: '#fbf0d6'
                Label {
                    id: waitText
                    anchors.fill: parent
                    anchors.margins: 12
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font.pixelSize: 18
                    lineHeight: 1.2
                    color: '#2a2220'
                    text: ('<b>' + qsTr('Arriving.') + '</b> ' + qsTr('The payment has left. To be safe you need to wait for <b>at least one confirmation</b>: usually about ten minutes, sometimes more. Meanwhile have a chat or a glass of wine 🍷 in company.'))
                          .replace('🍷', '<img src="' + Qt.resolvedUrl('../../icons/eh_wine.svg') + '" width="18" height="25">')
                }
            }
            EhMoreInfoButton {
                Layout.fillWidth: true
                onClicked: app.ehShowConfirmationsInfo()
            }
        }

        Item { Layout.fillHeight: true }

        EhPillButton {
            visible: dialog.arrived
            text: qsTr('Back to home')
            color: '#45541f'
            textColor: '#ffffff'
            tileColor: '#e6e9cf'
            outlined: false
            onClicked: dialog.doAccept()
            Image {
                anchors.centerIn: parent
                source: Qt.resolvedUrl('../../icons/eh_home.svg')
                sourceSize.width: 28
                sourceSize.height: 28
            }
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
