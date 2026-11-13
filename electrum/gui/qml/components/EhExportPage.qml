// Easy Heirs (schèi): export the movements to a CSV file (Excel, accountant).
// Period: all / this year / last year. The file is shared (email, WhatsApp,
// Drive...) through the Android share sheet.
// Look: "Bottega"; the page scrolls (nothing under the Android keys).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

Item {
    id: page
    property bool ehHideHeader: true
    property int year: 0       // 0 = all
    property string csv: ''
    Material.theme: Material.Light
    Material.foreground: S.ink

    readonly property int thisYear: new Date().getFullYear()
    readonly property var years: [0, thisYear, thisYear - 1]

    function refresh() { csv = Daemon.fx.exportHistoryCsv(Daemon.currentWallet, year) }

    // the share icon in ivory, for the olive leather button (gui/icons has only the dark ones)
    readonly property string shareIvory: 'data:image/svg+xml;base64,' + Qt.btoa(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="64" height="64"><g fill="none" stroke="#fbeccb" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><circle cx="18" cy="5" r="2.6"/><circle cx="6" cy="12" r="2.6"/><circle cx="18" cy="19" r="2.6"/><path d="M8.3 10.7l7.4-4.3M8.3 13.3l7.4 4.3"/></g></svg>')

    Rectangle { anchors.fill: parent; color: S.parch }

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

            EhTitle { text: qsTr('Export the movements') }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: S.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 17
                text: qsTr('Creates a file with all your movements, to open with Excel or to give to the accountant.')
            }

            EhCaption { text: qsTr('Period'); Layout.topMargin: 6; Layout.bottomMargin: -4 }
            EhSegmented {
                model: [qsTr('All'), '' + page.thisYear, '' + (page.thisYear - 1)]
                currentIndex: page.years.indexOf(page.year)
                onActivated: (i) => { page.year = page.years[i]; page.refresh() }
            }

            // a look at the first lines of the file
            EhSheet {
                Layout.topMargin: 4
                topPadding: 10
                bottomPadding: 10
                Label {
                    Layout.fillWidth: true
                    Layout.maximumHeight: 230
                    clip: true
                    text: page.csv.split('\n').slice(0, 9).join('\n') + (page.csv.split('\n').length > 10 ? '\n…' : '')
                    color: S.ink
                    font.family: FixedFont
                    font.pixelSize: 16
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }
            EhInfoBox {
                kind: 'tip'
                text: qsTr('The amounts in %1 are the value <b>of the day</b> of each movement. Payments still arriving are not in the file.').arg(app.ehCcyName())
            }

            Item { Layout.fillHeight: true; Layout.minimumHeight: 6 }

            EhStitchButton {
                Layout.bottomMargin: 6
                kind: 'olive'
                icon: page.shareIvory
                text: qsTr('Create and share the file')
                onClicked: AppController.ehShareFile('schei-' + (Daemon.currentWallet ? Daemon.currentWallet.name : 'wallet').replace(/[^A-Za-z0-9_-]/g, '_')
                                                     + '-' + Qt.formatDateTime(new Date(), 'yyyyMMdd-hhmm') + '.csv',
                                                     page.csv, qsTr('Schèi movements (CSV)'))
            }
        }
    }

    Component.onCompleted: refresh()
}
