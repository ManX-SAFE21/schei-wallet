// Easy Heirs (schȅi): "Eredità attiva" (inheritance, screen 6). The countdown to "Sei ancora
// qui?", the heirs with their share, the keepers (Will Executor) holding the envelope; "Renew
// now" opens the same question as the home (EhHeirAskSheet), "Change heirs or period" the
// wizard (WP-B). An inheritance made with Àncòra on the computer (phase foreign): read only.
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
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        visible: !page.foreign && page.phase !== 'unfinished'
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: badgeRow.implicitWidth + 20
                        implicitHeight: 30
                        radius: 12
                        color: page.toRenew ? S.ivory : S.tipBg
                        border.width: 1.5
                        border.color: page.toRenew ? S.gold : S.tipEdge
                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 6
                            Label {
                                visible: !page.toRenew
                                text: '✓'
                                color: S.oliveInk
                                font.pixelSize: 16
                                font.bold: true
                            }
                            Label {
                                text: page.toRenew ? qsTr('to renew') : qsTr('Active')
                                color: page.toRenew ? S.waitInk : S.oliveInk
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
                    icon: 'eh_shield_olive.svg'
                    iconColor: S.olive
                    text: qsTr('Keepers')
                    hint: qsTr('envelope safe')
                    chevron: false
                    last: true
                    Label {
                        text: (page.cust.ok > 0 ? '✓ ' : '') + qsTr('%1 of %2 ok').arg(page.cust.ok || 0).arg(page.cust.total || 0)
                        color: page.cust.ok > 0 ? S.oliveInk : S.wine
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: 16
                        font.bold: true
                    }
                }
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
                visible: !page.foreign && !page.toUpdate
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
        }
    }
}
