// Easy Heirs (schȅi): "Quanto chiedi?" (expert option "Ask for an amount").
// Euro keypad; "Inserisci l'importo" makes a new receive request with it.
// "Bottega": parchment page, the amount keys of the Send page, olive leather button.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

ElDialog {
    id: dialog
    Material.theme: Material.Light
    Material.foreground: S.ink
    font.family: BodyFont ? BodyFont : Qt.application.font.family
    property string euroInput: ''
    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    background: Rectangle { color: S.parch }

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
        if (btc) return (euroInput === '' ? '0' : euroInput.replace(',', app.ehLocale().decimalPoint)) + ' ' + app.ehBtcUnit()
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
        spacing: 9
        EhPageTop { title: '' }
        EhBackLink { onClicked: dialog.doReject() }
        EhTitle {
            text: qsTr('How much are you asking for?')
            icon: 'eh_rx_olive.svg'
            color: S.oliveInk
        }
        Label {
            visible: !dialog.coinsMode
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: col.width
            text: dialog.display()
            color: S.wineDark
            font.family: SerifFont ? SerifFont : font.family
            font.weight: Font.ExtraBold
            font.pixelSize: 50
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 22
        }
        Label {
            visible: !dialog.btc && !dialog.coinsMode
            Layout.alignment: Qt.AlignHCenter
            text: qsTr('about %1').arg(app.ehBtc(dialog.amount()))
            color: S.muted
            font.pixelSize: 16
        }
        EhCoinPad {
            visible: dialog.coinsMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            onEuroInputChanged: if (dialog.coinsMode) dialog.euroInput = euroInput
        }
        EhBackLink {
            visible: dialog.coinsMode
            Layout.topMargin: 0
            Layout.alignment: Qt.AlignHCenter
            text: qsTr('Prefer to write the numbers?')
            color: S.oliveInk
            onClicked: dialog.coinsMode = false
        }
        Item { visible: !dialog.coinsMode; Layout.fillHeight: true }
        GridLayout {
            visible: !dialog.coinsMode
            Layout.fillWidth: true
            columns: 3; rowSpacing: 9; columnSpacing: 9
            Repeater {
                model: ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', 'del']
                delegate: EhKey {
                    required property string modelData
                    text: modelData === ',' ? app.ehLocale().decimalPoint : modelData
                    isDelete: modelData === 'del'
                    onActivated: dialog.press(modelData)
                }
            }
        }
        EhStitchButton {
            kind: 'olive'
            endIcon: 'next'
            enabled: dialog.sats() > 0
            text: qsTr('Enter the amount')
            onClicked: {
                // a request with an amount expires after 1 day, so its address frees itself
                Daemon.currentWallet.createRequest(dialog.amount(), '', 86400, false, true)
                dialog.doAccept()
            }
        }
    }
    }
}
