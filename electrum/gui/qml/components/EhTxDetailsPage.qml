// Easy Heirs (schȅi): details of one movement: amount, personal note,
// date, sending cost (if sent), status with confirmations, address.
// Look: "Bottega" (ring icon, serif amount, paper sheets, stitched buttons).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"
import "controls/EhStyle.js" as S

Item {
    id: page
    property bool ehHideHeader: true
    property string txid
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.wine          // the text cursor of the note

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

    Rectangle { anchors.fill: parent; color: S.parch }

    TxDetails {
        id: tx
        wallet: Daemon.currentWallet
        txid: page.txid
    }

    // the note is saved with the Save button, with Enter, and when the page is left
    function saveNote() {
        var t = noteField.text.trim()
        if (t !== tx.label) {
            tx.setLabel(t)
            Daemon.currentWallet.historyModel.updateTxLabel(page.txid, t)
            savedTimer.restart()
        }
    }
    StackView.onDeactivating: saveNote()
    Timer { id: savedTimer; interval: 3000 }

    // a line "key ... value" of the sheet, dotted line under it unless last
    component KV: ColumnLayout {
        id: kvl
        property string k
        property string v
        property string sub: ''      // small line under the value
        property color vc: S.ink
        property bool last: false
        Layout.fillWidth: true
        spacing: 0
        // the value takes what the key leaves (the key keeps at least 38% when it is long)
        readonly property real valueW: kvl.width - 12 - Math.min(keyL.implicitWidth, kvl.width * 0.38)
        RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: 56
            spacing: 12
            Label {
                id: keyL
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: kvl.k
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
                lineHeight: 1.1
                wrapMode: Text.WordWrap
            }
            ColumnLayout {
                Layout.maximumWidth: kvl.valueW
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                spacing: 0
                Label {
                    Layout.alignment: Qt.AlignRight
                    Layout.maximumWidth: kvl.valueW
                    text: kvl.v
                    color: kvl.vc
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 17
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap
                }
                Label {
                    visible: kvl.sub !== ''
                    Layout.alignment: Qt.AlignRight
                    text: kvl.sub
                    color: S.muted
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 16
                }
            }
        }
        EhDotLine { visible: !kvl.last }
    }
    // the small caption of a card (CODE OF THE MOVEMENT...), dotted line under it
    component CardCaption: ColumnLayout {
        property alias text: ccL.text
        Layout.fillWidth: true
        spacing: 6
        Label {
            id: ccL
            Layout.fillWidth: true
            color: S.muted
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 16
            font.bold: true
            font.letterSpacing: 0.4
            wrapMode: Text.WordWrap
        }
        EhDotLine {}
    }

    // owner 12/11: the page scrolls, so "More information" is never under the phone keys
    Flickable {
        id: flick
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.height + 16
        boundsBehavior: Flickable.StopAtBounds
        clip: true

    ColumnLayout {
        id: col
        x: 16
        width: flick.width - 32
        height: Math.max(implicitHeight, flick.height - 16)
        spacing: 10

        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }

        EhBackLink { text: '‹ ' + qsTr('Movements'); onClicked: app.stack.pop() }

        EhIconRing {
            Layout.alignment: Qt.AlignHCenter
            big: true
            icon: page.incoming ? 'eh_mv_in.svg' : 'eh_mv_out.svg'
            ringColor: page.incoming ? S.olive : S.wine
        }
        Item {
            id: hero
            Layout.fillWidth: true
            Layout.preferredHeight: heroRow.height
            readonly property string amount: app.ehTxAmount(tx.amount, tx.timestamp, true)
            // the + / − sign is drawn with the body font: in the serif font it is a hairline
            readonly property string sgn: '+−-'.indexOf(amount.charAt(0)) >= 0 ? amount.charAt(0) : ''
            readonly property string rest: sgn !== '' ? amount.substring(1) : amount
            readonly property color ink: page.incoming ? S.oliveInk : S.wine
            // long bitcoin amounts: smaller, so they stay on one line (from the text: no layout loop)
            TextMetrics { id: heroTm; font.family: SerifFont ? SerifFont : font.family; font.weight: Font.ExtraBold; font.pixelSize: 42; text: hero.rest }
            readonly property real size: Math.max(24, Math.min(42, 42 * (col.width - 34) / Math.max(1, heroTm.advanceWidth)))
            Row {
                id: heroRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2
                Label {
                    anchors.baseline: heroL.baseline
                    text: hero.sgn
                    color: hero.ink
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: hero.size
                    font.bold: true
                }
                Label {
                    id: heroL
                    text: hero.rest
                    color: hero.ink
                    font.family: SerifFont ? SerifFont : font.family
                    font.weight: Font.ExtraBold
                    font.pixelSize: hero.size
                }
            }
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -6
            text: app.ehBtc(tx.amount).replace('-', '') + ' · ' + (page.incoming ? qsTr('received') : qsTr('sent'))
            color: S.muted
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 16
        }

        // personal note (owner 12/11: taller, the grey hint stays inside, Save button while writing)
        Item {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: 63
            Rectangle {      // hard shadow
                y: 3
                width: noteBox.width
                height: noteBox.height
                radius: noteBox.radius
                color: S.edgeShadow
            }
            Rectangle {
                id: noteBox
                width: parent.width
                height: 60
                radius: 16
                color: S.paper
                border.width: noteField.activeFocus ? 2.5 : 2
                border.color: noteField.activeFocus ? S.wine : S.edge
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 6
                    spacing: 10
                    Image { source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg'); sourceSize.width: 24; sourceSize.height: 24 }
                    TextField {
                        id: noteField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: tx.label
                        placeholderText: ''          // no Material floating label: our own hint below
                        topPadding: 0
                        bottomPadding: 0
                        leftPadding: 0
                        rightPadding: 0
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: 18
                        font.weight: text !== '' ? Font.DemiBold : Font.Normal
                        color: S.ink
                        background: null
                        inputMethodHints: Qt.ImhNoPredictiveText
                        onAccepted: { page.saveNote(); noteField.focus = false; Qt.inputMethod.hide() }
                        onEditingFinished: page.saveNote()
                        Label {
                            visible: noteField.text === '' && !noteField.inputMethodComposing
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr('Add a note…')
                            color: S.muted
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 17
                        }
                    }
                    EhStitchButton {
                        visible: noteField.activeFocus
                        Layout.fillWidth: false
                        Layout.preferredWidth: implicitWidth
                        kind: 'olive'
                        compact: true
                        text: qsTr('Save')
                        onClicked: { page.saveNote(); noteField.focus = false; Qt.inputMethod.hide() }
                    }
                }
            }
        }
        Label {
            visible: savedTimer.running
            Layout.topMargin: -4
            Layout.leftMargin: 6
            text: '✓ ' + qsTr('Note saved')
            color: S.olive
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 16
            font.bold: true
        }

        EhSheet {
            id: kvSheet
            Layout.topMargin: 4
            readonly property bool feeRow: page.incoming && tx.confirmations < 1 && app.ehFeeRate(tx.feeRateStr) !== ''
            KV { k: qsTr('When'); v: tx.timestamp ? new Date(tx.timestamp * 1000).toLocaleString(app.ehLocale(), 'd MMMM yyyy · HH:mm') : qsTr('not yet') }
            // one row only: the cost, and while unconfirmed the speed paid under it
            KV {
                visible: !page.incoming && !tx.fee.isEmpty
                k: qsTr('Sending cost') + ' ' + qsTr('(tip to the miners)')
                v: app.ehEuro(tx.fee) !== '' ? app.ehEuro(tx.fee) : app.ehBtc(tx.fee)
                sub: tx.confirmations < 1 ? app.ehFeeRate(tx.feeRateStr) : ''
            }
            KV {
                k: qsTr('Status')
                vc: tx.confirmations > 0 ? S.oliveInk : S.waitInk
                v: tx.confirmations > 0
                   ? '✓ ' + qsTr('Confirmed') + ' · ' + (tx.confirmations === 1 ? qsTr('1 confirmation') : qsTr('%1 confirmations').arg(tx.confirmations))
                   : '⏳ ' + qsTr('Unconfirmed')
                last: !kvSheet.feeRow
            }
            KV {
                // money coming in: no "Sending cost" row, so the speed has its own row
                visible: kvSheet.feeRow
                k: qsTr('Fee')
                v: app.ehFeeRate(tx.feeRateStr)
                last: true
            }
        }

        EhSheet {
            visible: page.otherAddress !== ''
            Layout.topMargin: 4
            topPadding: 12
            bottomPadding: 14
            spacing: 8
            CardCaption { text: page.incoming ? qsTr('ON YOUR ADDRESS') : qsTr('TO THIS ADDRESS') }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: page.grouped(page.otherAddress)
                color: S.ink
                font.family: FixedFont
                font.bold: true
                font.pixelSize: 17
                lineHeight: 1.2
                wrapMode: Text.WrapAnywhere
            }
        }

        // T32: the code of the movement (hash) and the way to see it on the blockchain
        EhSheet {
            Layout.topMargin: 4
            topPadding: 12
            bottomPadding: 14
            spacing: 10
            CardCaption { text: qsTr('CODE OF THE MOVEMENT (HASH)') }
            // all in one piece: it is only copied and pasted, never typed
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft   // left: centred it looked like two different codes
                wrapMode: Text.WrapAnywhere
                text: page.txid
                color: S.wineDark
                font.family: FixedFont
                font.pixelSize: 14
                lineHeight: 1.15
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 3
                spacing: 8
                EhStitchButton {
                    id: copyBtn
                    kind: 'paper'
                    icon: 'eh_copy_wine.svg'
                    text: qsTr('Copy')
                    onClicked: {
                        AppController.textToClipboard(page.txid)
                        hToast.show(copyBtn, qsTr('Copied!'))
                    }
                }
                EhStitchButton {
                    kind: 'paper'
                    icon: 'eh_share_wine.svg'
                    text: qsTr('Share')
                    onClicked: AppController.doShare(page.txid, qsTr('Code of the movement'))
                }
            }
            // the green button: opens the chosen site (Avanzate > Dove vedere i movimenti)
            EhStitchButton {
                kind: 'olive'
                text: qsTr('See it on the blockchain')
                sub: qsTr('opens %1').arg(Config.ehExplorer.name ? Config.ehExplorer.name : qsTr('My node'))
                endIcon: 'open'
                Image {
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl('../../icons/eh_blocks_white.svg')
                    sourceSize.width: 34
                    sourceSize.height: 24
                }
                onClicked: {
                    var u = Config.ehExplorerTxUrl(page.txid)
                    if (u !== '') Qt.openUrlExternally(u)
                }
            }
        }

        Item { Layout.fillHeight: true }

        EhStitchButton {
            Layout.bottomMargin: 3
            kind: 'paper'
            icon: 'eh_info.svg'
            text: qsTr('More information')
            onClicked: app.ehShowConfirmationsInfo()
        }
    }
    }

    Toaster { id: hToast }
}
