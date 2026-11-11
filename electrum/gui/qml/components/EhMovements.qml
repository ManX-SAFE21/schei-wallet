// Easy Heirs (schèi): all movements, grouped by period, filter All /
// Received / Sent, CSV export at the bottom. Tap a row for the details.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

Item {
    id: page
    property bool ehHideHeader: true
    property string filter: 'all'      // all | in | out
    Material.theme: Material.Light
    Material.foreground: '#2a2220'

    Rectangle { anchors.fill: parent; color: '#faf7ef' }

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

        Label {
            Layout.topMargin: -14
            text: '‹ ' + qsTr('Back')
            color: '#5e1a33'
            font.pixelSize: 17
            font.bold: true
            TapHandler { margin: 10; onTapped: app.stack.pop() }
        }

        Label {
            text: qsTr('Movements')
            color: '#3f0f21'
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 28
        }

        // filter
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 24
            color: '#efe6d3'
            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4
                Repeater {
                    model: [ { k: 'all', t: qsTr('All') }, { k: 'in', t: qsTr('Received') }, { k: 'out', t: qsTr('Sent') } ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: height / 2
                        color: page.filter === modelData.k ? '#ffffff' : 'transparent'
                        Label {
                            anchors.centerIn: parent
                            text: modelData.t
                            font.pixelSize: 15
                            font.bold: true
                            color: page.filter === modelData.k ? '#3f0f21' : '#6b5d55'
                        }
                        TapHandler { onTapped: page.filter = modelData.k }
                    }
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            model: Daemon.currentWallet ? Daemon.currentWallet.historyModel : null
            section.property: 'section'
            section.criteria: ViewSection.FullString
            section.delegate: Label {
                required property string section
                width: ListView.view.width
                topPadding: 10
                bottomPadding: 4
                leftPadding: 4
                text: page.sectionName(section).toUpperCase()
                color: '#45541f'
                font.pixelSize: 13
                font.bold: true
                font.letterSpacing: 0.5
            }
            delegate: Item {
                id: row
                required property var model
                readonly property bool incoming: model.value.satsInt >= 0
                readonly property bool shown: page.filter === 'all' || (page.filter === 'in') === incoming
                width: ListView.view.width
                height: shown ? 66 : 0
                visible: shown
                Rectangle {
                    anchors.fill: parent
                    color: '#ffffff'
                    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 12; height: 2; color: '#f1ebdf' }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 19
                        color: row.incoming ? '#e6e9cf' : '#f3e3e8'
                        Image {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl(row.incoming ? '../../icons/eh_rx_olive.svg' : '../../icons/eh_tx_wine.svg')
                            sourceSize.width: 25
                            sourceSize.height: 25
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            Layout.fillWidth: true
                            text: row.model.label !== '' ? row.model.label : (row.incoming ? qsTr('Received') : qsTr('Sent'))
                            font.pixelSize: 16
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Label {
                            text: app.ehWhen(row.model.timestamp, true)
                            font.pixelSize: 13
                            color: '#6b5d55'
                        }
                    }
                    ColumnLayout {
                        spacing: 3
                        Label {
                            Layout.alignment: Qt.AlignRight
                            text: app.ehTxAmount(row.model.value, row.model.timestamp, true)
                            font.pixelSize: 16
                            font.bold: true
                            color: row.incoming ? '#45541f' : '#5e1a33'
                        }
                        Rectangle {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: badge.implicitWidth + 12
                            radius: 6
                            color: row.model.confirmations > 0 ? '#e9eed9' : '#fbf0d6'
                            Label {
                                id: badge
                                anchors.centerIn: parent
                                text: row.model.confirmations > 0 ? '✓ ' + qsTr('Confirmed') : '⏳ ' + qsTr('Unconfirmed') + (app.ehFeeRate(row.model.date) ? ' · ' + app.ehFeeRate(row.model.date) : '')
                                font.pixelSize: 11
                                font.bold: true
                                color: row.model.confirmations > 0 ? '#45541f' : '#7a4a12'
                            }
                        }
                    }
                }
                TapHandler {
                    onTapped: app.stack.push(Qt.resolvedUrl('EhTxDetailsPage.qml'), { txid: row.model.key })
                }
            }

            ColumnLayout {
                visible: list.count === 0
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 10
                Image {
                    Layout.alignment: Qt.AlignHCenter
                    source: Qt.resolvedUrl('../../icons/eh_list.svg')
                    sourceSize.width: 90
                    sourceSize.height: 90
                }
                Label { Layout.alignment: Qt.AlignHCenter; text: qsTr('No movements yet'); font.pixelSize: 20; font.bold: true }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: qsTr('When you receive or send bitcoin, you find them here.')
                    font.pixelSize: 17
                    color: '#6b5d55'
                }
            }
        }

        Rectangle {
            visible: list.count > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 24
            color: expTap.pressed ? '#eef1df' : '#ffffff'
            border.width: 2
            border.color: '#d5dbb0'
            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                Image { source: Qt.resolvedUrl('../../icons/eh_download.svg'); sourceSize.width: 22; sourceSize.height: 22 }
                Label { text: qsTr('Export the movements (CSV file)'); font.pixelSize: 16; font.bold: true; color: '#45541f' }
            }
            TapHandler {
                id: expTap
                onTapped: app.stack.push(Qt.resolvedUrl('EhExportPage.qml'))
            }
        }
    }
}
