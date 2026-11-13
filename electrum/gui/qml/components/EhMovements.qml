// Easy Heirs (schèi): all movements, grouped by period, filter All /
// Received / Sent, CSV export at the bottom. Tap a row for the details.
// Look: "Bottega" (one paper sheet for the list, periods with the gold rule, dotted lines).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

Item {
    id: page
    property bool ehHideHeader: true
    property string filter: 'all'      // all | in | out
    readonly property var filterKeys: ['all', 'in', 'out']
    Material.theme: Material.Light
    Material.foreground: S.ink

    Rectangle { anchors.fill: parent; color: S.parch }

    function sectionName(s) {
        switch (s) {
        case 'today': return qsTr('Today')
        case 'yesterday': return qsTr('Yesterday')
        case 'thisweek': return qsTr('This week')
        case 'lastweek': return qsTr('Last week')
        case 'thismonth': return qsTr('This month')
        case 'lastmonth': return qsTr('Last month')
        case 'mempool': case 'local': return qsTr('Arriving')
        default: return qsTr('Older')
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16 + app.navigationBarHeight
        spacing: 9

        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }

        EhBackLink { Layout.topMargin: -15; onClicked: app.stack.pop() }

        EhTitle { text: qsTr('Movements') }

        // filter
        EhSegmented {
            model: [qsTr('All'), qsTr('Received'), qsTr('Sent')]
            currentIndex: page.filterKeys.indexOf(page.filter)
            onActivated: (i) => page.filter = page.filterKeys[i]
        }

        // the list on one paper sheet (the list scrolls, not the page)
        Item {
            id: sheet
            visible: list.count > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 3
            Layout.preferredHeight: list.contentHeight + 7
            Layout.maximumHeight: list.contentHeight + 7
            // hard shadow
            Rectangle {
                y: 3
                width: face.width
                height: face.height
                radius: face.radius
                color: S.edgeShadow
            }
            Rectangle {
                id: face
                width: parent.width
                height: parent.height - 3
                radius: 18
                color: S.paper
                border.width: 1.5
                border.color: S.edge
            }

            ListView {
                id: list
                anchors.fill: face
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 2
                anchors.bottomMargin: 2
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                model: Daemon.currentWallet ? Daemon.currentWallet.historyModel : null
                section.property: 'section'
                section.criteria: ViewSection.FullString
                section.delegate: Column {
                    required property string section
                    width: ListView.view.width
                    topPadding: 12
                    spacing: 4
                    Label {
                        width: parent.width
                        text: page.sectionName(section).toUpperCase()
                        color: S.olive
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: 16
                        font.bold: true
                        font.letterSpacing: 0.5
                        elide: Text.ElideRight
                    }
                    EhRule { width: parent.width }
                }
                delegate: Item {
                    id: row
                    required property var model
                    required property int index
                    readonly property bool incoming: model.value.satsInt >= 0
                    readonly property bool shown: page.filter === 'all' || (page.filter === 'in') === incoming
                    readonly property bool waiting: model.confirmations < 1
                    readonly property string amount: app.ehTxAmount(row.model.value, row.model.timestamp, true)
                    // the + / − sign is drawn with the body font: in the serif font it is a hairline
                    readonly property string sgn: '+−-'.indexOf(amount.charAt(0)) >= 0 ? amount.charAt(0) : ''
                    readonly property string rest: sgn !== '' ? amount.substring(1) : amount
                    readonly property color ink: incoming ? S.oliveInk : S.wine
                    // bitcoin amounts are long: 18 instead of 21, and never more than about half the row (from the text, no layout loop)
                    TextMetrics { id: tm; font.family: SerifFont ? SerifFont : font.family; font.weight: Font.ExtraBold; font.pixelSize: 21; text: row.rest }
                    readonly property real amtSize: Math.max(16, Math.min(rest.indexOf(app.ehBtcUnit()) >= 0 ? 18 : 21, 21 * (width * 0.46 - 14) / Math.max(1, tm.advanceWidth)))
                    width: ListView.view.width
                    height: shown ? (waiting ? 84 : 68) : 0
                    visible: shown

                    // pressed
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 2
                        anchors.bottomMargin: 2
                        radius: 10
                        color: S.sand
                        opacity: rowTap.pressed ? 0.4 : 0
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12
                        EhIconRing {
                            icon: row.incoming ? 'eh_mv_in.svg' : 'eh_mv_out.svg'
                            ringColor: row.incoming ? S.olive : S.wine
                            iconSize: 24
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1      // the room the amount leaves
                            spacing: 1
                            Label {
                                Layout.fillWidth: true
                                text: row.model.label !== '' ? row.model.label : (row.incoming ? qsTr('Received') : qsTr('Sent'))
                                color: S.ink
                                font.family: BodyFont ? BodyFont : font.family
                                font.pixelSize: 17
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label {
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: implicitWidth
                                    elide: Text.ElideRight
                                    text: app.ehWhen(row.model.timestamp, true)
                                    color: S.muted
                                    font.family: BodyFont ? BodyFont : font.family
                                    font.pixelSize: 16
                                }
                                Label {
                                    visible: !row.waiting
                                    text: '✓'
                                    color: S.olive
                                    font.family: BodyFont ? BodyFont : font.family
                                    font.pixelSize: 18
                                    font.bold: true
                                }
                            }
                            Label {
                                visible: row.waiting
                                Layout.fillWidth: true
                                text: '⏳ ' + qsTr('Unconfirmed') + (app.ehFeeRate(row.model.date) ? ' · ' + app.ehFeeRate(row.model.date) : '')
                                color: S.waitInk
                                font.family: BodyFont ? BodyFont : font.family
                                font.pixelSize: 16
                                font.bold: true
                                elide: Text.ElideRight
                            }
                        }
                        Row {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.minimumWidth: implicitWidth
                            spacing: 1
                            Label {
                                anchors.baseline: amtL.baseline
                                text: row.sgn
                                color: row.ink
                                font.family: BodyFont ? BodyFont : font.family
                                font.pixelSize: row.amtSize
                                font.bold: true
                            }
                            Label {
                                id: amtL
                                text: row.rest
                                color: row.ink
                                font.family: SerifFont ? SerifFont : font.family
                                font.weight: Font.ExtraBold
                                font.pixelSize: row.amtSize
                            }
                        }
                    }
                    // dotted line between two rows of the same period (on top of the second one)
                    EhDotLine {
                        visible: row.index > 0 && row.ListView.previousSection === row.ListView.section
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                    }
                    TapHandler {
                        id: rowTap
                        onTapped: app.stack.push(Qt.resolvedUrl('EhTxDetailsPage.qml'), { txid: row.model.key })
                    }
                }
            }
        }

        // nothing yet
        ColumnLayout {
            visible: list.count === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            Item { Layout.fillHeight: true }
            Image {
                Layout.alignment: Qt.AlignHCenter
                source: Qt.resolvedUrl('../../icons/eh_list.svg')
                sourceSize.width: 90
                sourceSize.height: 90
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr('No movements yet')
                color: S.wine
                font.family: SerifFont ? SerifFont : font.family
                font.weight: Font.ExtraBold
                font.pixelSize: 22
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr('When you receive or send bitcoin, you find them here.')
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 17
            }
            Item { Layout.fillHeight: true }
        }

        EhStitchButton {
            visible: list.count > 0
            Layout.topMargin: 5
            kind: 'paper'
            icon: 'eh_download_wine.svg'
            text: qsTr('Export the movements (CSV file)')
            onClicked: app.stack.push(Qt.resolvedUrl('EhExportPage.qml'))
        }

        // when the list is short, the room left goes here (the export button stays under the list)
        Item { visible: list.count > 0; Layout.fillHeight: true; Layout.preferredHeight: 0 }
    }
}
