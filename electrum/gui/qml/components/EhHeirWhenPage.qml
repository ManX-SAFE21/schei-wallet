// Easy Heirs (schȅi): inheritance wizard, screen 4 "In how long?" (step 2 of 4).
// 1 / 2 / 3 / 5 years (period form of the Àncòra plugin, 12/24/36/60 months) and the dates
// on a line: today, the renewal reminder, the delivery. The dates here are only for the eye
// (from state.now, the period and state.warn); Next calls bal.setPeriod(months) and goes on
// to "All right?" (EhHeirCheckPage) when the bridge answers.
// Owner 15/11 (P2, preview anteprima/custode-spento/elenco-custodi.html): with a will already
// in force and its own period the line shows its TRUE dates (state.now / warnAt / delivery,
// "Your current inheritance").
// Owner 16/11 (Q2): a new period applies FROM TODAY. With a will in force and another period
// picked, the line shows the NEW dates ("The new dates") and the green box says the delivery
// in force and the new one: later = a renewal (it costs about state.fees.renewSats), earlier =
// a free update. "All right?" then renews or updates (bal.confirm(), review().change).
// "Bottega" look as the preview anteprima/eredita-semplice.html, screen 4.
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
    readonly property var st: bal ? bal.state : ({})
    readonly property bool busy: bal ? bal.busy : false
    readonly property var choices: [12, 24, 36, 60]
    readonly property var parts: ({ half: 2, third: 3, quarter: 4 })
    readonly property real monthDays: 30.4375

    // a will is already in force: the period picked applies from today (owner 16/11, Q2)
    readonly property bool inForce: st && ['active', 'due', 'needs_update', 'unfinished', 'expired'].indexOf(st.phase) >= 0
    readonly property bool toRenew: st && (st.phase === 'due' || st.phase === 'expired')
    // the period shown first: the one of the will in force, else the one stored
    readonly property int savedMonths: inForce && st.monthsInForce ? st.monthsInForce : (st && st.months ? st.months : 0)
    property int months: choices.indexOf(savedMonths) >= 0 ? savedMonths : 24
    property string error: ''

    // the dates (UNIX seconds), as the bridge computes them
    readonly property real now: st && st.now ? st.now : Math.floor(Date.now() / 1000)
    function addMonths(t, m) {
        var d = new Date(t * 1000)
        return Math.floor(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + m, d.getUTCDate()) / 1000)
    }
    // the delivery in force and the new one (today + the period picked, as the bridge's review)
    readonly property real oldDelivery: inForce ? (st.delivery || 0) : 0
    readonly property real newDelivery: addMonths(now, months)
    // as the bridge's _period_change: another period (or, from the reminder on, any period)
    readonly property bool periodChanged: inForce && oldDelivery > 0 && (st.monthsInForce || 0) > 0
                                          && (months !== st.monthsInForce || toRenew)
                                          && newDelivery !== oldDelivery
    readonly property bool later: periodChanged && newDelivery > oldDelivery
    // with a will in force and its own period: its own dates (P2); else counted from today
    readonly property bool realDates: inForce && !periodChanged && (st.delivery || 0) > 0 && (st.warnAt || 0) > 0
    readonly property real delivery: realDates ? st.delivery : newDelivery
    readonly property int warnDays: realDates ? Math.round((st.delivery - st.warnAt) / 86400)
                                              : Math.round(months * monthDays / (parts[st && st.warn ? st.warn : 'half'] || 2))
    readonly property real warnAt: realDates ? st.warnAt : delivery - warnDays * 86400
    readonly property int warnMonths: Math.round(warnDays / monthDays)
    function day(t) { return Qt.formatDate(new Date(t * 1000), 'dd/MM/yyyy') }

    Rectangle { anchors.fill: parent; color: S.parch }

    Connections {
        target: page.bal
        function onDone(op, result) {
            if (op === 'setPeriod') app.stack.push(Qt.resolvedUrl('EhHeirCheckPage.qml'))
        }
        function onFailed(op, code, message) {
            if (op !== 'setPeriod' || code === 'busy') return
            page.error = top.failText(code, message)
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
                stepNow: 2
                stepsBack: !page.busy
                onStepClicked: (n) => app.stack.pop()
            }

            EhBackLink { onClicked: app.stack.pop() }

            EhTitle { text: qsTr('In how long?') }

            Label {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                wrapMode: Text.WordWrap
                text: qsTr('If you never renew, when do the heirs receive?')
                color: S.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
            }

            EhSegmented {
                look: 'level'
                model: [
                    { text: '1', sub: qsTr('year') },
                    { text: '2', sub: qsTr('years') },
                    { text: '3', sub: qsTr('years') },
                    { text: '5', sub: qsTr('years') }
                ]
                currentIndex: page.choices.indexOf(page.months)
                onActivated: (i) => { if (!page.busy) { page.months = page.choices[i]; page.error = '' } }
            }

            EhInfoBox {
                visible: page.periodChanged
                Layout.topMargin: 4
                kind: 'tip'
                // owner 16/11 (Q2, approved texts): the delivery in force, the new one, the cost;
                // right under the choice, so it is seen without scrolling
                text: page.later
                      ? qsTr('Your current inheritance has its delivery on <b>%1</b>.<br>If you go on, the delivery becomes <b>%2</b> (%3 from today). It costs about <b>%4</b>.')
                        .arg(app.ehHeirDate(page.oldDelivery)).arg(app.ehHeirDate(page.newDelivery))
                        .arg(app.ehHeirYears(page.months))
                        .arg(app.ehHeirSats(page.st.fees ? page.st.fees.renewSats : 0).replace(/ /g, ' '))
                      : qsTr('Your current inheritance has its delivery on <b>%1</b>.<br>If you go on, the delivery becomes <b>%2</b> (%3 from today). <b>It costs nothing: it is a free update.</b>')
                        .arg(app.ehHeirDate(page.oldDelivery)).arg(app.ehHeirDate(page.newDelivery))
                        .arg(app.ehHeirYears(page.months))
            }

            EhCaption {
                text: page.realDates ? qsTr('Your current inheritance')
                                     : (page.periodChanged ? qsTr('The new dates') : qsTr('The dates'))
                Layout.topMargin: 6
                Layout.bottomMargin: -4
            }
            EhSheet {
                bottomPadding: 12
                EhTimeline {
                    Layout.topMargin: 16
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    Layout.bottomMargin: 4
                    start: page.now
                    mid: page.warnAt
                    end: page.delivery
                }
                EhDotLine { Layout.fillWidth: true }
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    text: qsTr('From <b>%1</b>, that is <b>%2 months before</b> the delivery, every time you open Schȅi it asks you whether to renew.')
                          .arg(page.day(page.warnAt)).arg(page.warnMonths)
                    color: S.ink
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 16
                    lineHeight: 1.1
                }
            }

            EhInfoBox {
                visible: page.error !== ''
                kind: 'danger'
                text: page.error
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
        anchors.bottomMargin: app.navigationBarHeight
        spacing: 10

        RowLayout {
            visible: page.busy && top.stepText(page.bal ? page.bal.step : '') !== ''
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            BusyIndicator { Layout.preferredWidth: 28; Layout.preferredHeight: 28; running: parent.visible }
            Label {
                text: top.stepText(page.bal ? page.bal.step : '')
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
                font.bold: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: -S.margin
            Layout.rightMargin: -S.margin
            Layout.preferredHeight: 1.5
            color: S.edge
        }
        EhStitchButton {
            Layout.bottomMargin: 6
            kind: 'wine'
            endIcon: 'next'
            text: qsTr('Next')
            enabled: !page.busy && page.bal !== null
            onClicked: { page.error = ''; page.bal.setPeriod(page.months) }
        }
    }
}
