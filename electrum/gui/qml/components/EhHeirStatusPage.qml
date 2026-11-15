// Easy Heirs (schȅi): "Eredità attiva" (inheritance, screen 6). The countdown to "Sei ancora
// qui?", the heirs with their share, the keepers (Will Executor) holding the envelope; "Renew
// now" opens the same question as the home (EhHeirAskSheet), "Change heirs or period" the
// wizard (WP-B). An inheritance made with Àncòra on the computer (phase foreign): read only.
// Owner 15/11 (points 4, 4d, 7, 8): the keepers' row and its warning follow custodians.status
// (ok / some / one / none / invalid, preview anteprima/custode-spento/proposta.html cases A-D),
// with "Replace the keeper" (EhHeirReplaceSheet); at the bottom "How it works" and
// "Cancel the inheritance" (EhHeirCancelSheet).
// Owner 15/11 (P1): a tap on the "Keepers" row opens the list of the keepers
// (EhHeirKeeperListSheet). P4: "Renew now" only from the day of the reminder (phase due /
// expired): before it, renewing would not move the delivery and would cost a fee.
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

    readonly property var bal: AppController.plugin('bal')
    readonly property var st: bal ? bal.state : ({})
    readonly property string phase: st.phase || 'none'
    readonly property bool foreign: phase === 'foreign'
    readonly property bool toRenew: phase === 'due' || phase === 'expired'
    readonly property bool toUpdate: phase === 'needs_update' || phase === 'unfinished'
    readonly property var cust: st.custodians || ({ ok: 0, total: 0 })
    readonly property bool ehHeirStatus: true       // EhHeirCancelSheet pops this page when done
    // the keepers: ok (all answer) | some (2 or more, not all) | one | none | invalid (none for days)
    readonly property string kst: foreign ? '' : (cust.status || '')
    readonly property int lost: Math.max(0, (cust.total || 0) - (cust.ok || 0))
    readonly property bool keepersBad: kst === 'none' || kst === 'invalid'
    readonly property bool keepersAlarm: kst === 'some' || kst === 'one' || keepersBad
    // the badge: red (no keeper), yellow (one keeper), else green / "to renew"
    readonly property string badgeKind: keepersBad ? 'red' : (kst === 'one' ? 'yellow' : (toRenew ? 'renew' : 'green'))
    readonly property bool canCancel: !foreign && ['active', 'due', 'needs_update', 'expired'].indexOf(phase) >= 0

    // P1: the keepers' list (not through app._ehHeirOpenSheet: its "Replace the keeper" opens
    // EhHeirReplaceSheet that way, while this one closes)
    property var keeperList: null
    function openKeepers() {
        if (keeperList) return
        var comp = Qt.createComponent(Qt.resolvedUrl('EhHeirKeeperListSheet.qml'))
        if (comp.status !== Component.Ready) { console.log('keepers sheet: ' + comp.errorString()); return }
        keeperList = comp.createObject(app)
        keeperList.closed.connect(function() { page.keeperList = null })
        keeperList.open()
    }

    function keeperHint() {
        if (kst === 'some') return lost === 1 ? qsTr('envelope safe, one does not answer') : qsTr('envelope safe, %1 do not answer').arg(lost)
        if (kst === 'one') return (cust.total || 0) > 1 ? qsTr('only one is left') : qsTr('envelope safe')
        if (kst === 'none') return qsTr('nobody answers')
        if (kst === 'invalid') return qsTr('nobody answers for days')
        return qsTr('envelope safe')
    }
    function keeperWarn() {
        var other = cust.ok || 0
        if (kst === 'some')
            return (lost === 1 ? qsTr('<b>One keeper does not answer.</b>') : qsTr('<b>%1 keepers do not answer.</b>').arg(lost)) + ' '
                 + (lost === 1 ? qsTr('The other %1 have the envelope: the inheritance works. You can replace it with another keeper.').arg(other)
                               : qsTr('The other %1 have the envelope: the inheritance works. You can replace them with other keepers.').arg(other))
        if (kst === 'one') {
            if ((cust.total || 0) <= 1) return qsTr('<b>You have only one keeper with the envelope.</b> To be safe, send it to other keepers.')
            return (lost === 1 ? qsTr('<b>One keeper does not answer.</b>') : lost === 2 ? qsTr('<b>Two keepers do not answer.</b>')
                               : qsTr('<b>%1 keepers do not answer.</b>').arg(lost)) + ' '
                 + qsTr('Only one is left with the envelope. To be safe, send it to other keepers.')
        }
        if (kst === 'none') return qsTr('<b>Today no keeper answers.</b> If they do not come back, the envelope will not reach the heirs. Your money is safe: send it to other keepers.')
        if (kst === 'invalid') return qsTr('<b>For days no keeper has answered.</b> So the envelope will not reach the heirs: the inheritance is not valid. Your money is safe: send it to other keepers.')
        return ''
    }

    // a link in wine, underlined (as "Later" of EhHeirAskSheet)
    component LinkLine: Item {
        id: lk
        property string text
        property color color: S.wine
        signal clicked
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        Label {
            id: lkText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, lk.width)
            horizontalAlignment: Text.AlignHCenter
            text: lk.text
            color: lk.color
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 16
            font.bold: true
            elide: Text.ElideRight
            opacity: !lk.enabled ? 0.35 : (lkTap.pressed ? 0.6 : 1)
        }
        Rectangle {
            x: lkText.x
            y: lkText.y + lkText.height + 1
            width: lkText.width
            height: 2
            color: lk.color
            opacity: lkText.opacity
        }
        TapHandler { id: lkTap; margin: 8; onTapped: lk.clicked() }
    }

    Component.onCompleted: if (bal && !bal.busy && !foreign) bal.checkCustodians()

    Rectangle { anchors.fill: parent; color: S.parch }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.height + 12
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 2 * S.margin
            x: S.margin
            height: Math.max(implicitHeight, flick.height - 12)
            spacing: S.gap

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            EhBackLink { onClicked: app.stack.pop() }

            // title with the badge on the right ("✓ Active" / "to renew")
            ColumnLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Image {
                        Layout.alignment: Qt.AlignVCenter
                        source: Qt.resolvedUrl('../../icons/eh_will.svg')
                        sourceSize.width: 32
                        sourceSize.height: 32
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr('Inheritance')
                        color: S.wine
                        font.family: SerifFont ? SerifFont : font.family
                        font.weight: Font.ExtraBold
                        font.pixelSize: 30
                        fontSizeMode: Text.HorizontalFit     // a long badge ("✕ Not valid") at 360 px
                        minimumPixelSize: 22
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        visible: !page.foreign && page.phase !== 'unfinished'
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: badgeRow.implicitWidth + 20
                        implicitHeight: 30
                        radius: 12
                        color: page.badgeKind === 'red' ? S.dangerBg : (page.badgeKind === 'yellow' ? '#fbefc4' : (page.badgeKind === 'renew' ? S.ivory : S.tipBg))
                        border.width: 1.5
                        border.color: page.badgeKind === 'red' ? '#d99aa8' : (page.badgeKind === 'yellow' ? '#e2c46a' : (page.badgeKind === 'renew' ? S.gold : S.tipEdge))
                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 6
                            Label {
                                visible: page.badgeKind !== 'renew'
                                text: page.badgeKind === 'red' ? '✕' : (page.badgeKind === 'yellow' ? '⚠' : '✓')
                                color: badgeText.color
                                font.pixelSize: 16
                                font.bold: true
                            }
                            Label {
                                id: badgeText
                                text: page.kst === 'invalid' ? qsTr('Not valid') : page.kst === 'none' ? qsTr('At risk')
                                    : page.toRenew ? qsTr('to renew') : qsTr('Active')
                                color: page.badgeKind === 'red' ? S.wine : (page.badgeKind === 'yellow' ? '#7a5a00' : (page.badgeKind === 'renew' ? S.waitInk : S.oliveInk))
                                font.family: BodyFont ? BodyFont : font.family
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }
                    }
                }
                EhRule {}
            }

            EhInfoBox {
                visible: page.foreign
                kind: 'warn'
                text: qsTr('This inheritance was made with Àncòra on the computer: change it there.')
            }

            // countdown (from the day of the reminder the badge says "to renew" instead)
            EhSheet {
                visible: !page.foreign && !page.toRenew && (page.st.months || 0) > 0
                topPadding: 12
                bottomPadding: 12
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr('"Are you still here?" in')
                    color: S.olive
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 15
                    font.bold: true
                    font.letterSpacing: 0.5
                    font.capitalization: Font.AllUppercase
                    wrapMode: Text.WordWrap
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: (page.st.daysToWarn || 0) === 1 ? qsTr('1 day') : qsTr('%1 days').arg(page.st.daysToWarn || 0)
                    color: S.wineDark
                    font.family: SerifFont ? SerifFont : font.family
                    font.weight: Font.ExtraBold
                    font.pixelSize: 48
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 30
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr('on %1 · delivery on %2').arg(app.ehHeirDate(page.st.warnAt)).arg(app.ehHeirDate(page.st.delivery))
                    color: S.muted
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 16
                    wrapMode: Text.WordWrap
                }
            }

            EhCaption { text: qsTr('Your inheritance'); Layout.topMargin: 2; Layout.bottomMargin: -6 }
            EhSheet {
                Repeater {
                    model: page.st.heirs || []
                    delegate: EhRow {
                        required property var modelData
                        icon: 'eh_person.svg'
                        text: modelData.name
                        chevron: false
                        Label {
                            text: modelData.percent + '%'
                            color: S.oliveInk
                            font.family: SerifFont ? SerifFont : font.family
                            font.weight: Font.ExtraBold
                            font.pixelSize: 22
                        }
                    }
                }
                EhRow {
                    visible: !page.foreign
                    icon: page.keepersBad ? 'eh_shield.svg' : 'eh_shield_olive.svg'
                    iconColor: page.keepersBad ? S.wine : S.olive
                    text: qsTr('Keepers')
                    hint: page.keeperHint()
                    chevron: (page.cust.total || 0) > 0
                    last: true
                    onClicked: if ((page.cust.total || 0) > 0) page.openKeepers()
                    Label {
                        text: page.keepersBad ? qsTr('%1 out of %2').arg(page.cust.ok || 0).arg(page.cust.total || 0)
                            : (page.kst === 'ok' || page.kst === '' ? (page.cust.ok > 0 ? '✓ ' : '') : '')
                              + qsTr('%1 of %2 ok').arg(page.cust.ok || 0).arg(page.cust.total || 0)
                        color: page.keepersBad || page.cust.ok <= 0 ? S.wine : (page.kst === 'one' ? '#8a6400' : S.oliveInk)
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: 16
                        font.bold: true
                    }
                }
            }

            // a keeper that does not answer: what it means, and the button to send the envelope to another
            EhInfoBox {
                visible: page.keepersAlarm
                Layout.topMargin: 2
                kind: page.keepersBad ? 'danger' : 'warn'
                icon: page.kst === 'some' ? 'eh_info_brass.svg' : 'eh_warn.svg'
                text: page.keeperWarn()
            }
            EhStitchButton {
                visible: page.keepersAlarm
                kind: 'wine'
                icon: 'eh_lock_white.svg'
                text: page.kst === 'some' ? qsTr('Replace the keeper') : qsTr('Send the envelope to other keepers')
                enabled: !(page.bal && page.bal.busy)
                onClicked: app._ehHeirOpenSheet('EhHeirReplaceSheet.qml')
            }
            Label {
                visible: page.keepersAlarm
                Layout.fillWidth: true
                Layout.topMargin: -6
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 14
                color: S.muted
                text: page.kst === 'some' ? qsTr('Free · the PIN is enough · not urgent')
                    : page.keepersBad ? qsTr('Free · the PIN is enough. If it finds none, try again later.') : qsTr('Free · the PIN is enough')
            }

            // while a job runs (e.g. the keepers' check): one line with the step
            Label {
                visible: page.bal !== null && page.bal.busy
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
                color: S.muted
                text: page.bal ? app.ehHeirStepText(page.bal.step) : ''
            }

            Item { Layout.fillHeight: true; Layout.minimumHeight: 4 }

            // an envelope that no longer covers the coins: update it (free, with the PIN)
            EhStitchButton {
                visible: !page.foreign && page.toUpdate
                kind: 'wine'
                icon: 'eh_lock_white.svg'
                endIcon: 'next'
                text: qsTr('Update with the PIN')
                enabled: !(page.bal && page.bal.busy)
                onClicked: app.ehHeirUpdate(page.phase === 'unfinished' ? 'unfinished' : (page.st.updateReason || 'received'))
            }
            EhStitchButton {
                visible: !page.foreign && !page.toUpdate && page.toRenew
                kind: 'olive'
                icon: 'eh_refresh_white.svg'
                text: qsTr('Renew now')
                enabled: !(page.bal && page.bal.busy)
                onClicked: app.ehHeirAsk()
            }
            EhStitchButton {
                visible: !page.foreign
                kind: 'paper'
                icon: 'eh_pen_wine.svg'
                text: qsTr('Change heirs or period')
                enabled: !(page.bal && page.bal.busy)
                onClicked: app.stack.push(Qt.resolvedUrl('EhHeirWhoPage.qml'))
            }
            LinkLine {
                Layout.topMargin: 2
                text: qsTr('How it works')
                onClicked: app.stack.push(Qt.resolvedUrl('EhHeirHowPage.qml'))
            }
            LinkLine {
                visible: page.canCancel
                Layout.topMargin: -6
                text: qsTr('Cancel the inheritance')
                color: S.muted
                enabled: !(page.bal && page.bal.busy)
                onClicked: app._ehHeirOpenSheet('EhHeirCancelSheet.qml')
            }
        }
    }
}
