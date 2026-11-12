// Easy Heirs (schèi): "Quanto chiedi?" (expert option "Ask for an amount").
// Euro keypad; "Inserisci l'importo" makes a new receive request with it.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

ElDialog {
    id: dialog
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    property string euroInput: ''
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

    readonly property bool btc: app.ehBtcOnly()
    property bool coinsMode: app.ehOption('coins') && !btc && app.ehHasCash()
    function sats() {
        var plain = (euroInput === '' ? '0' : euroInput).replace(',', '.')
        if (btc) { var b = Number(plain); return isNaN(b) ? 0 : Math.round(b * 100000000) }
        var n = parseInt(Daemon.fx.satoshiValue(plain, true))
        return isNaN(n) ? 0 : n
    }
    function amount() { return Config.unitsToSats((sats() / 100000000).toFixed(8)) }
    function display() {
        if (btc) return (euroInput === '' ? '0' : euroInput.replace(',', app.ehLocale().decimalPoint)) + ' BTC'
        if (euroInput === '') return app.ehSym() + ' 0'
        var p = euroInput.split(',')
        return app.ehSym() + ' ' + Number(p[0] || '0').toLocaleString(app.ehLocale(), 'f', 0) + (p.length > 1 ? app.ehLocale().decimalPoint + p[1] : '')
    }
    function press(k) {
        if (k === 'del') { euroInput = euroInput.slice(0, -1); return }
        if (k === ',') { if (euroInput.indexOf(',') < 0) euroInput = (euroInput === '' ? '0' : euroInput) + ','; return }
        var d = euroInput.indexOf(',')
        if (d >= 0 && euroInput.length - d > (btc ? 8 : 2)) return
        if (euroInput === '0') euroInput = ''
        if (euroInput.replace(',', '').length >= (btc ? 10 : 7 + Math.round(Math.log(app.ehCcyMult()) / Math.LN10))) return
        euroInput += k
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.bottomMargin: 18 + app.navigationBarHeight
        spacing: 9
        EhPageTop { title: '' }
        Label {
            Layout.topMargin: -14
            text: '‹ ' + qsTr('Back')
            color: '#5e1a33'; font.pixelSize: 17; font.bold: true
            TapHandler { margin: 10; onTapped: dialog.doReject() }
        }
        RowLayout {
            spacing: 10
            Image { source: Qt.resolvedUrl('../../icons/eh_rx_olive.svg'); sourceSize.width: 34; sourceSize.height: 34 }
            Label { text: qsTr('How much are you asking for?'); color: '#45541f'; font.family: TitleFont ? TitleFont : font.family; font.weight: Font.Black; font.pixelSize: 26 }
        }
        Label { visible: !dialog.coinsMode; Layout.alignment: Qt.AlignHCenter; text: dialog.display(); color: '#3f0f21'; font.family: TitleFont ? TitleFont : font.family; font.weight: Font.Black; font.pixelSize: 50 }
        Label { visible: !dialog.btc && !dialog.coinsMode; Layout.alignment: Qt.AlignHCenter; text: qsTr('about %1').arg(app.ehBtc(dialog.amount())); color: '#6b5d55'; font.pixelSize: 15 }
        EhCoinPad {
            visible: dialog.coinsMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            onEuroInputChanged: if (dialog.coinsMode) dialog.euroInput = euroInput
        }
        Label {
            visible: dialog.coinsMode
            Layout.alignment: Qt.AlignHCenter
            text: qsTr('Prefer to write the numbers?')
            color: '#45541f'; font.pixelSize: 15; font.bold: true; font.underline: true
            TapHandler { margin: 8; onTapped: dialog.coinsMode = false }
        }
        Item { visible: !dialog.coinsMode; Layout.fillHeight: true }
        GridLayout {
            visible: !dialog.coinsMode
            Layout.fillWidth: true
            columns: 3; rowSpacing: 9; columnSpacing: 9
            Repeater {
                model: ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', 'del']
                delegate: Rectangle {
                    id: key
                    required property string modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 54; radius: 27
                    color: modelData === 'del' ? '#efe6d3' : (kt.pressed ? '#f3ecdd' : '#ffffff')
                    border.width: modelData === 'del' ? 0 : 2; border.color: '#e2d7c1'
                    EhBackspaceIcon { visible: key.modelData === 'del'; anchors.centerIn: parent; width: 38; height: 27; fill: '#efe6d3' }
                    Label { anchors.centerIn: parent; visible: key.modelData !== 'del'; text: key.modelData === ',' ? app.ehLocale().decimalPoint : key.modelData; font.pixelSize: 27; font.bold: true }
                    TapHandler { id: kt; onTapped: dialog.press(key.modelData) }
                }
            }
        }
        EhNextButton {
            enabled: dialog.sats() > 0
            text: qsTr('Enter the amount')
            color: '#45541f'
            onClicked: {
                // a request with an amount expires after 1 day, so its address frees itself
                Daemon.currentWallet.createRequest(dialog.amount(), '', 86400, false, true)
                dialog.doAccept()
            }
        }
    }
}
