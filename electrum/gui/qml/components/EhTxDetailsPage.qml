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

        Item { Layout.fillHeight: true }

        EhMoreInfoButton {
            Layout.fillWidth: true
            onClicked: app.ehShowConfirmationsInfo()
        }
    }
}
