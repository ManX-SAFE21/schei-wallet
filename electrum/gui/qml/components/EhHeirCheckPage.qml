// Easy Heirs (schȅi): inheritance wizard, screen 5 "All right?" (step 3 of 4).
// bal.review() at once (asks the keepers, prepares the envelope): who gets about how much,
// the delivery and reminder dates, what it costs. Push the coin to the right, type the PIN,
// then bal.confirm() signs and sends the envelope to the keepers; on success the stack goes
// back to its first page and the status page (EhHeirStatusPage, WP-C) opens.
// A keepers' cost above 20% of the balance is only a warning (owner 2026-11-14, point 5).
// Owner 15/11: the keepers' cost "from X to Y" with an "i" (EhHeirFeeSheet, point 4b); the
// keepers' sentence counts those that answered against the number chosen (points 3, 4c).
// Owner 16/11 (Q2): with a will in force and a new period, review().change says what
// confirm() does: 'renew' (the delivery moves later: invalidation on the blockchain, its cost
// shown here as "Today you pay", BEFORE the PIN) or 'update' (earlier: free). Heirs changed in
// the same pass go into that one operation.
// "Bottega" look as the preview anteprima/eredita-semplice.html, screen 5.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

Item {
    id: page
    property bool ehHideHeader: true
    property bool ehHeirPage: true
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.wine

    readonly property var bal: AppController.plugin('bal')
    readonly property var st: app.ehHeirState(bal)   // M1: only the wallet open
    readonly property bool busy: bal ? bal.busy : false

    property var rv: null              // the review() result, null until it comes
    property string error: ''
    property string failedOp: ''

    function day(t) { return t > 0 ? Qt.formatDate(new Date(t * 1000), 'dd/MM/yyyy') : '…' }
    function okKeepers() {
        if (!rv || !rv.custodians) return 0
        var n = 0
        for (var i = 0; i < rv.custodians.length; i++) if (rv.custodians[i].ok) n++
        return n
    }
    // owner 15/11 (points 3, 4c): the keepers that answered against the number chosen
    function keepersText() {
        var t = qsTr('The <b>keepers</b> (Will Executor) are servers that keep the sealed envelope and send it on the delivery date.')
        if (!rv) return t
        var n = okKeepers(), w = rv.custodiansWanted || st.keepersWanted || 3
        // owner 18/11: keepers chosen by hand (ESPERTO): never "there are no others"
        if ((st.keepersMine || []).length > 0)
            return t + ' ' + (n <= 1 ? qsTr('We use 1: the one you chose.') : qsTr('We use %1: the ones you chose.').arg(n))
        if (n <= 1) return t + ' ' + qsTr('We use 1: for now there are no others.')
        if (n === 2 && n < w) return t + ' ' + qsTr('We use 2 of the %1 chosen: if one switches off there is the other.').arg(w)
        if (n < w) return t + ' ' + qsTr('We use %1 of the %2 chosen: if one switches off there are the others.').arg(n).arg(w)
        return t + ' ' + qsTr('We use %1: if one switches off there are the others.').arg(n)
    }
    // owner 15/11 (point 4b): "from X to Y" (each keeper its price), one figure when equal
    function keepersFee() {
        if (!rv) return '…'
        var hi = rv.custodianFeeMaxSats !== undefined ? rv.custodianFeeMaxSats : rv.custodianFeeSats
        if (rv.custodianFeeMaxSats === undefined && rv.custodianFeeMinSats === undefined) return app.ehMoney(hi)
        var lo = rv.custodianFeeMinSats !== undefined ? rv.custodianFeeMinSats : hi
        var a = app.ehMoney(lo), b = app.ehMoney(hi)
        // no break inside an amount, and the word before the second amount stays with it:
        // "from 0,58 €" / "to 0,61 €"
        if (a === b) return b
        return qsTr('from %1 to %2').arg(a.replace(/ /g, '\u00a0')).arg('@@')
                .replace(/ ([^ ]+) @@/, ' $1\u00a0@@').replace('@@', b.replace(/ /g, '\u00a0'))
    }
    // owner 16/11 (Q2): what the confirmation does with the will in force
    readonly property string change: rv && rv.change ? rv.change : ''
    readonly property bool renewing: change === 'renew'
    // owner 17/11: confirm() of a renewal gets the cost chosen on the row, right before it starts
    function confirmNow() {
        if (page.renewing && !cost.commit(page.bal)) {
            page.error = qsTr('First choose the cost of the operation.')
            page.failedOp = 'confirm'
            return
        }
        page.bal.confirm()
    }
    function pinText() {
        if (renewing) return qsTr('Type the PIN to renew the inheritance')
        if (change === 'update') return qsTr('Type the PIN to update the inheritance')
        return qsTr('Type the PIN to confirm the inheritance')
    }
    readonly property bool feeRange: rv !== null && rv.custodianFeeMinSats !== undefined
                                     && app.ehMoney(rv.custodianFeeMinSats) !== app.ehMoney(rv.custodianFeeMaxSats)

    function startReview() {
        if (!bal) return
        error = ''
        failedOp = ''
        if (bal.busy) { waitIdle.start(); return }
        bal.review()
    }
    Component.onCompleted: startReview()
    // the bridge was still busy with something else: review as soon as it is free
    Timer {
        id: waitIdle
        interval: 300
        repeat: true
        onTriggered: if (page.bal && !page.bal.busy) { stop(); page.bal.review() }
    }

    Connections {
        target: page.bal
        function onDone(op, result) {
            if (op === 'review') {
                page.rv = result
            } else if (op === 'confirm') {
                var stack = app.stack
                stack.pop(null)
                stack.push(Qt.resolvedUrl('EhHeirStatusPage.qml'))
            }
        }
        function onFailed(op, code, message) {
            if (op !== 'review' && op !== 'confirm') return
            // controllo-mainnet 2.5: another job was running: nothing happened, the coin goes back
            // to the left so it can be pushed again (no error, it was not a failure)
            if (code === 'busy') { slide.reset(); return }
            page.failedOp = op
            page.error = top.failText(code, message)
            slide.reset()
        }
    }

    Rectangle { anchors.fill: parent; color: S.parch }

    // a key / value line of a sheet; value: plain text, or a figure with "about" before it
    component Kv: Item {
        id: kv
        property string key
        property string keySmall: ''
        property string value: ''
        property bool figure: false
        property bool about: false
        property color figColor: S.wineDark
        property bool last: false
        property real figSize: 19
        property bool info: false            // an "i" after the key that opens an explanation
        signal infoTapped
        Layout.fillWidth: true
        implicitHeight: Math.max(41, kvRow.implicitHeight + 10)
        Layout.preferredHeight: implicitHeight
        RowLayout {
            id: kvRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Label {
                Layout.fillWidth: true
                textFormat: Text.StyledText
                text: kv.keySmall !== ''
                      ? '<b>' + kv.key + '</b> <font color="' + S.muted + '" size="2">· ' + kv.keySmall + '</font>'
                      : kv.key
                color: S.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                wrapMode: Text.WordWrap
            }
            Image {
                visible: kv.info
                Layout.alignment: Qt.AlignVCenter
                source: Qt.resolvedUrl('../../icons/eh_info_brass.svg')
                sourceSize.width: 24
                sourceSize.height: 24
                opacity: infoTap.pressed ? 0.6 : 1
                TapHandler { id: infoTap; margin: 10; onTapped: kv.infoTapped() }
            }
            Label {
                visible: kv.about && kv.value !== '…'
                text: qsTr('about')
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsSmall
            }
            Label {
                // a long value ("from X to Y") goes on two lines on the right
                Layout.maximumWidth: kv.width * 0.56
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: kv.value
                color: kv.figure ? kv.figColor : S.ink
                font.family: kv.figure ? (SerifFont ? SerifFont : font.family) : (BodyFont ? BodyFont : font.family)
                font.weight: kv.figure ? Font.ExtraBold : Font.Bold
                font.pixelSize: kv.figure ? kv.figSize : app.ehFsText
            }
        }
        EhDotLine {
            visible: !kv.last
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: parent.width
        }
    }

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: foot.top
        anchors.bottomMargin: 8
        contentHeight: col.implicitHeight + 10
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height + 1
        clip: true

        ColumnLayout {
            id: col
            x: S.margin
            width: flick.width - 2 * S.margin
            spacing: 10

            EhHeirTop {
                id: top
                stepNow: 3
                stepsBack: !page.busy
                onStepClicked: (n) => { if (n === 1) app.stack.pop(); app.stack.pop() }
            }

            EhBackLink {
                enabled: !page.busy
                opacity: enabled ? 1 : 0.35
                onClicked: app.stack.pop()
            }

            EhTitle { text: qsTr('All right?') }

            // owner 16/11 (Q2): the delivery in force and the new one, a renewal or a free update
            EhInfoBox {
                visible: page.renewing || page.change === 'update'
                kind: page.renewing ? 'warn' : 'tip'
                text: page.renewing
                      ? qsTr('The delivery moves from <b>%1</b> to <b>%2</b>: it is a <b>renewal</b>. Schȅi cancels the envelope of now on the bitcoin network and joins all the coins into one.')
                        .arg(app.ehHeirDate(page.rv ? page.rv.inForceDelivery : 0)).arg(app.ehHeirDate(page.rv ? page.rv.delivery : 0))
                      : qsTr('The delivery moves from <b>%1</b> to <b>%2</b>: it is a <b>free update</b>.')
                        .arg(app.ehHeirDate(page.rv ? page.rv.inForceDelivery : 0)).arg(app.ehHeirDate(page.rv ? page.rv.delivery : 0))
            }

            EhSheet {
                Repeater {
                    // before the answer: the heirs of the state, amounts "…"
                    model: page.rv && page.rv.heirs ? page.rv.heirs : (page.st && page.st.heirs ? page.st.heirs : [])
                    delegate: Kv {
                        required property var modelData
                        key: modelData.name
                        keySmall: modelData.percent + '%'
                        figure: true
                        about: true
                        value: modelData.sats !== undefined ? app.ehMoney(modelData.sats) : '…'
                    }
                }
                Kv {
                    key: qsTr('Delivery')
                    value: page.day(page.rv ? page.rv.delivery : page.st.delivery)
                }
                Kv {
                    key: qsTr('Renewal reminder, from')
                    value: page.day(page.rv ? page.rv.warnAt : page.st.warnAt)
                    last: true
                }
            }

            EhCaption { text: qsTr('What it costs'); Layout.topMargin: 4; Layout.bottomMargin: -4 }
            EhSheet {
                Kv {
                    visible: !page.renewing
                    key: qsTr('Today you pay')
                    figure: true
                    figColor: S.oliveInk
                    value: page.rv ? app.ehMoney(0) : '…'
                }
                // owner 17/11: a renewal is paid today, chosen like a payment
                EhHeirCostRow {
                    id: cost
                    heirSt: page.st
                    visible: page.renewing && coins.length > 0
                }
                EhDotLine { visible: page.renewing }
                Kv {
                    key: qsTr('To the keepers, only at the delivery')
                    figure: true
                    about: !page.feeRange
                    figSize: page.feeRange ? 17 : 19
                    info: true
                    value: page.keepersFee()
                    onInfoTapped: app._ehHeirOpenSheet('EhHeirFeeSheet.qml')
                }
                Kv {
                    key: qsTr('Every time you renew')
                    figure: true
                    about: true
                    value: page.rv ? (page.rv.renewFeeSats > 0 ? app.ehMoney(page.rv.renewFeeSats) : qsTr('as a payment')) : '…'
                    last: true
                }
            }
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                text: page.keepersText()
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                lineHeight: 1.1
            }
        }
    }

    // the foot: always in view, above the Android keys; the page scrolls above it
    ColumnLayout {
        id: foot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: S.margin
        anchors.rightMargin: S.margin
        spacing: 6

        EhInfoBox {
            visible: page.error !== ''
            Layout.bottomMargin: 6
            kind: 'danger'
            text: page.error
            EhStitchButton {
                kind: 'paper'
                compact: true
                icon: 'eh_refresh.svg'
                text: qsTr('Try again')
                enabled: !page.busy
                onClicked: {
                    if (page.failedOp === 'confirm') {
                        page.error = ''
                        page.failedOp = ''
                        app.ehAskPin(page.pinText(), function() { page.confirmNow() })
                    } else {
                        page.startReview()
                    }
                }
            }
        }

        EhInfoBox {
            visible: page.error === '' && page.rv !== null && page.rv.feeWarning === true
            kind: 'warn'
            text: page.rv ? qsTr("The keepers' cost is high for this wallet: %1 out of %2. You can go on anyway.")
                            .arg(app.ehMoney(page.rv.custodianFeeSats)).arg(app.ehMoney(page.rv.balanceSats)) : ''
        }

        RowLayout {
            visible: page.busy && top.stepText(page.bal ? page.bal.step : '') !== ''
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            BusyIndicator { Layout.preferredWidth: 28; Layout.preferredHeight: 28; running: parent.visible }
            Label {
                text: top.stepText(page.bal ? page.bal.step : '')
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                font.bold: true
            }
        }

        Label {
            visible: !page.busy && page.error === ''
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: page.renewing ? qsTr('To renew push the coin to the right.') : qsTr('To confirm push the coin to the right.')
            color: S.ink
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: app.ehFsText
            font.bold: true
        }
        EhSlideH {
            id: slide
            visible: page.error === ''
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            Layout.bottomMargin: 6
            enabled: page.rv !== null && !page.busy && page.error === ''
            onReached: if (page.renewing && !cost.ensure()) slide.reset()
                       else app.ehAskPin(page.pinText(), function() { page.confirmNow() },
                                    function() { slide.reset() })   // PIN cancelled: the coin goes back at once
        }
    }
}
