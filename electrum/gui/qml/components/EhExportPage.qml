// Easy Heirs (schèi): export the movements to a CSV file (Excel, accountant).
// Period: all / this year / last year. The file is shared (email, WhatsApp,
// Drive...) through the Android share sheet.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

Item {
    id: page
    property bool ehHideHeader: true
    property int year: 0       // 0 = all
    property string csv: ''
    Material.theme: Material.Light
    Material.foreground: '#2a2220'

    readonly property int thisYear: new Date().getFullYear()

    function refresh() { csv = Daemon.fx.exportHistoryCsv(Daemon.currentWallet, year) }

    Rectangle { anchors.fill: parent; color: '#faf7ef' }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16 + app.navigationBarHeight
        spacing: 10

        EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }

        Label {
            Layout.topMargin: -14
            text: '‹ ' + qsTr('Movements')
            color: '#5e1a33'
            font.pixelSize: 17
            font.bold: true
            TapHandler { margin: 10; onTapped: app.stack.pop() }
        }

        Label {
            text: qsTr('Export the movements')
            color: '#3f0f21'
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 26
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 16
            text: qsTr('Creates a file with all your movements, to open with Excel or to give to the accountant.')
        }

        Label { text: qsTr('Period'); font.pixelSize: 14; font.bold: true; color: '#6b5d55' }
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
                    model: [ { y: 0, t: qsTr('All') }, { y: page.thisYear, t: '' + page.thisYear }, { y: page.thisYear - 1, t: '' + (page.thisYear - 1) } ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: height / 2
                        color: page.year === modelData.y ? '#ffffff' : 'transparent'
                        Label { anchors.centerIn: parent; text: modelData.t; font.pixelSize: 15; font.bold: true; color: page.year === modelData.y ? '#3f0f21' : '#6b5d55' }
                        TapHandler { onTapped: { page.year = modelData.y; page.refresh() } }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumHeight: 260
            radius: 14
            color: '#ffffff'
            border.width: 2
            border.color: '#ece4d2'
            clip: true
            Label {
                anchors.fill: parent
                anchors.margins: 10
                text: page.csv.split('\n').slice(0, 9).join('\n') + (page.csv.split('\n').length > 10 ? '\n…' : '')
                font.family: FixedFont
                font.pixelSize: 10
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            font.pixelSize: 13
            color: '#6b5d55'
            text: qsTr('The euro are the value <b>of the day</b> of each movement. Payments still arriving are not in the file.')
        }

        Item { Layout.fillHeight: true }

        EhPillButton {
            text: qsTr('Create and share the file')
            color: '#45541f'
            textColor: '#ffffff'
            tileColor: '#e6e9cf'
            outlined: false
            fontSize: 20
            onClicked: AppController.doShare(page.csv, qsTr('Schèi movements (CSV)'))
            Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_share.svg'); sourceSize.width: 28; sourceSize.height: 28 }
        }
    }

    Component.onCompleted: refresh()
}
