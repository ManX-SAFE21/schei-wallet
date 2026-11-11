// Easy Heirs (schèi): details of one movement: amount, personal note,
// date, sending cost (if sent), status with confirmations, address.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"

Item {
    id: page
    property bool ehHideHeader: true
    property string txid
    Material.theme: Material.Light
    Material.foreground: '#2a2220'

    readonly property bool incoming: tx.amount.satsInt >= 0
    readonly property string otherAddress: {
        var outs = tx.outputs
        for (var i = 0; i < outs.length; i++) {
            if (incoming ? outs[i].is_mine : !outs[i].is_mine) return outs[i].address
        }
        return outs.length ? outs[0].address : ''
    }

    function grouped(a) {
        var n = Math.ceil(a.length / 4), out = ''
        for (var i = 0; i < a.length; i++) {
            out += a[i]
            var left = a.length - 1 - i
            if (left > 0 && left % 4 === 0) out += (left === 4 * Math.floor(n / 2)) ? '\n' : ' '
        }
        return out
    }

    Rectangle {
        anchors.fill: parent
        color: '#faf7ef'
        EhGlow { tone: page.incoming ? 'green' : 'rose'; z: 0; x: -parent.width * 0.25; y: 30; width: parent.width * 1.5; height: 340 }
    }

    TxDetails {
        id: tx
        wallet: Daemon.currentWallet
        txid: page.txid
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16 + app.navigationBarHeight
        spacing: 10

        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }

        Label {
            Layout.topMargin: -14
            text: '‹ ' + qsTr('Movements')
            color: '#5e1a33'
            font.pixelSize: 17
            font.bold: true
            TapHandler { margin: 10; onTapped: app.stack.pop() }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            radius: 32
            color: page.incoming ? '#e6e9cf' : '#f3e3e8'
            Image {
                anchors.centerIn: parent
                source: Qt.resolvedUrl(page.incoming ? '../../icons/eh_rx_olive.svg' : '../../icons/eh_tx_wine.svg')
                sourceSize.width: 42
                sourceSize.height: 42
            }
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: app.ehTxAmount(tx.amount, tx.timestamp, true)
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 38
            color: page.incoming ? '#45541f' : '#5e1a33'
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: app.ehBtc(tx.amount).replace('-', '') + ' · ' + (page.incoming ? qsTr('received') : qsTr('sent'))
            font.pixelSize: 15
            color: '#6b5d55'
        }

        // personal note
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 16
            color: '#ffffff'
            border.width: 2
            border.color: '#e2d7c1'
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                Image { source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg'); sourceSize.width: 22; sourceSize.height: 22 }
                TextField {
                    id: noteField
                    Layout.fillWidth: true
                    text: tx.label
                    placeholderText: qsTr('Add a note…')
                    font.pixelSize: 16
                    font.bold: text !== ''
                    background: null
                    onEditingFinished: {
                        if (text !== tx.label) {
                            tx.setLabel(text)
                            Daemon.currentWallet.historyModel.updateTxLabel(page.txid, text)
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: kv.implicitHeight + 12
            radius: 18
            color: '#ffffff'
            ColumnLayout {
                id: kv
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 6
                spacing: 0
                component KV: RowLayout {
                    property string k
                    property string v
                    property string sub: ''      // small line under the value
                    property color vc: '#2a2220'
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    Label { text: k; font.pixelSize: 15; color: '#6b5d55' }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 0
                        Label { Layout.alignment: Qt.AlignRight; text: v; font.pixelSize: 15; font.bold: true; color: vc; horizontalAlignment: Text.AlignRight }
                        Label { visible: sub !== ''; Layout.alignment: Qt.AlignRight; text: sub; font.pixelSize: 13; color: '#6b5d55' }
                    }
                }
                KV { k: qsTr('When'); v: tx.timestamp ? new Date(tx.timestamp * 1000).toLocaleString(app.ehLocale(), 'd MMMM yyyy · HH:mm') : qsTr('not yet') }
                // one row only: the cost, and while unconfirmed the speed paid under it
                KV {
                    visible: !page.incoming && !tx.fee.isEmpty
                    k: qsTr('Sending cost')
                    v: app.ehEuro(tx.fee) !== '' ? app.ehEuro(tx.fee) : app.ehBtc(tx.fee)
                    sub: tx.confirmations < 1 ? app.ehFeeRate(tx.feeRateStr) : ''
                }
                KV {
                    k: qsTr('Status')
                    vc: tx.confirmations > 0 ? '#45541f' : '#7a4a12'
                    v: tx.confirmations > 0
                       ? '✓ ' + qsTr('Confirmed') + ' · ' + (tx.confirmations === 1 ? qsTr('1 confirmation') : qsTr('%1 confirmations').arg(tx.confirmations))
                       : '⏳ ' + qsTr('Unconfirmed')
                }
                KV {
                    // money coming in: no "Sending cost" row, so the speed has its own row
                    visible: page.incoming && tx.confirmations < 1 && app.ehFeeRate(tx.feeRateStr) !== ''
                    k: qsTr('Fee')
                    v: app.ehFeeRate(tx.feeRateStr)
                }
            }
        }

        Rectangle {
            visible: page.otherAddress !== ''
            Layout.fillWidth: true
            Layout.preferredHeight: adCol.implicitHeight + 16
            radius: 14
            color: '#ffffff'
            border.width: 2
            border.color: '#ece4d2'
            ColumnLayout {
                id: adCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: page.incoming ? qsTr('ON YOUR ADDRESS') : qsTr('TO THIS ADDRESS')
                    font.pixelSize: 12
                    color: '#6b5d55'
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: page.grouped(page.otherAddress)
                    font.family: FixedFont
                    font.bold: true
                    font.pixelSize: 14
                }
            }
        }

        // T32: the code of the movement (hash) and the way to see it on the blockchain
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: hCol.implicitHeight + 20
            radius: 16
            color: '#ffffff'
            border.width: 2
            border.color: '#ece4d2'
            ColumnLayout {
                id: hCol
                x: 10; y: 10
                width: parent.width - 20
                spacing: 8
                Label {
                    text: qsTr('CODE OF THE MOVEMENT (HASH)')
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 0.5
                    color: '#6b5d55'
                }
                // all in one piece: it is only copied and pasted, never typed
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft   // left: centred it looked like two different codes
                    wrapMode: Text.WrapAnywhere
                    text: page.txid
                    font.family: FixedFont
                    font.pixelSize: 13
                    color: '#3f0f21'
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: [
                            { 'icon': 'eh_copy.svg', 'text': qsTr('Copy'), 'act': 'copy' },
                            { 'icon': 'eh_share.svg', 'text': qsTr('Share'), 'act': 'share' }
                        ]
                        Rectangle {
                            id: hb
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            radius: 21
                            color: hbMa.pressed ? '#e4e8c8' : '#eef0dc'
                            border.width: 2
                            border.color: '#d6dcae'
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Image { source: Qt.resolvedUrl('../../icons/' + hb.modelData.icon); sourceSize.width: 18; sourceSize.height: 18 }
                                Label { text: hb.modelData.text; color: '#45541f'; font.pixelSize: 15; font.bold: true }
                            }
                            MouseArea {
                                id: hbMa
                                anchors.fill: parent
                                onClicked: {
                                    if (hb.modelData.act === 'copy') {
                                        AppController.textToClipboard(page.txid)
                                        hToast.show(hb, qsTr('Copied!'))
                                    } else {
                                        AppController.doShare(page.txid, qsTr('Code of the movement'))
                                    }
                                }
                            }
                        }
                    }
                }
                // the green button: opens the chosen site (Avanzate > Dove vedere i movimenti)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: 22
                    gradient: Gradient {
                        GradientStop { position: 0; color: chMa.pressed ? '#5c6a2f' : '#6f7d3b' }
                        GradientStop { position: 1; color: chMa.pressed ? '#36431a' : '#45541f' }
                    }
                    EhDashedBorder { anchors.fill: parent; inset: 5; radius: 17; lineWidth: 1.4; color: Qt.rgba(1, 0.94, 0.78, 0.55) }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        Image { source: Qt.resolvedUrl('../../icons/eh_blocks_white.svg'); sourceSize.width: 40; sourceSize.height: 24 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label { text: qsTr('See it on the blockchain'); color: '#ffffff'; font.pixelSize: 17; font.bold: true }
                            Label {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                color: '#ffffff'; opacity: 0.9; font.pixelSize: 13
                                text: qsTr('opens %1').arg(Config.ehExplorer.name ? Config.ehExplorer.name : qsTr('My node'))
                            }
                        }
                        Image { source: Qt.resolvedUrl('../../icons/eh_open_white.svg'); sourceSize.width: 20; sourceSize.height: 20 }
                    }
                    MouseArea {
                        id: chMa
                        anchors.fill: parent
                        onClicked: {
                            var u = Config.ehExplorerTxUrl(page.txid)
                            if (u !== '') Qt.openUrlExternally(u)
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        EhMoreInfoButton {
            Layout.fillWidth: true
            onClicked: app.ehShowConfirmationsInfo()
        }
    }

    Toaster { id: hToast }
}
