// Easy Heirs (schȅi): inheritance wizard, screen 4 "In how long?" (step 2 of 4).
// 1 / 2 / 3 / 5 years (period form of the Àncòra plugin, 12/24/36/60 months) and the dates
// on a line: today, the renewal reminder, the delivery. The dates here are only for the eye
// (from state.now, the period and state.warn); Next calls bal.setPeriod(months) and goes on
// to "All right?" (EhHeirCheckPage) when the bridge answers.
// Owner 15/11 (P2, preview anteprima/custode-spento/elenco-custodi.html): with a will already
// in force the line shows its TRUE dates (state.now / warnAt / delivery, "Your current
// inheritance"), not dates counted from today with the new period: that one starts from the
// next renewal, as the green box says.
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

    // the period shown: the one chosen for the next renewal (pendingMonths), else the one in force
    readonly property int savedMonths: st && st.pendingMonths && choices.indexOf(st.pendingMonths) >= 0
                                       ? st.pendingMonths : (st && st.months ? st.months : 0)
    property int months: choices.indexOf(savedMonths) >= 0 ? savedMonths : 24
    property string error: ''
    // a will is already in force: the new period counts from the next renewal (F10)
    readonly property bool inForce: st && ['active', 'due', 'needs_update', 'unfinished', 'expired'].indexOf(st.phase) >= 0
    readonly property bool periodChanged: inForce && st.months > 0 && months !== st.months

    // the dates (UNIX seconds), as the bridge computes them
    readonly property real now: st && st.now ? st.now : Math.floor(Date.now() / 1000)
    function addMonths(t, m) {
        var d = new Date(t * 1000)
        return Math.floor(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + m, d.getUTCDate()) / 1000)
    }
    // with a will in force: its own dates (P2); else counted from today with the period picked
    readonly property bool realDates: inForce && (st.delivery || 0) > 0 && (st.warnAt || 0) > 0
    readonly property real delivery: realDates ? st.delivery : addMonths(now, months)
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

            EhCaption {
                text: page.realDates ? qsTr('Your current inheritance') : qsTr('The dates')
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
                visible: page.periodChanged
                kind: 'tip'
                text: qsTr('Your current inheritance <b>does not change</b>: the delivery stays on <b>%1</b>.<br>The new period of <b>%2</b> starts from the next renewal: when you say «Yes, I am still here», the delivery will be %2 after that day.')
                      .arg(page.day(page.st.delivery || 0)).arg(app.ehHeirYears(page.months))
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
