// Easy Heirs (schèi): compact list of the latest movements for the home.
// Icon (wallet with arrow), amount in euro (or BTC), date and status.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ColumnLayout {
    id: root
    spacing: 6
    property bool glass: false   // home with the slide: soft colours show through

    RowLayout {
        Layout.fillWidth: true
        Label {
            text: qsTr('Movements')
            font.pixelSize: 16
            font.bold: true
            color: '#2a2220'
        }
        Item { Layout.fillWidth: true }
        Label {
            visible: list.count > 0
            text: qsTr('See all')
            font.pixelSize: 13
            font.underline: true
            color: '#5e1a33'
            TapHandler {
                margin: 8
                onTapped: app.stack.push(Qt.resolvedUrl('../EhMovements.qml'))
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 18
        color: root.glass ? 'transparent' : '#ffffff'
        clip: true

        Label {
            visible: list.count === 0
            anchors.fill: parent
            anchors.margins: 14
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.StyledText
            color: '#6b5d55'
            font.pixelSize: 15
            text: '<b>' + qsTr('No movements yet.') + '</b><br>' + (app.ehOption('buttons') ? qsTr('Tap RECEIVE to get your first bitcoin.') : qsTr('Pull the coin down to receive your first bitcoin.'))
        }

        ListView {
            id: list
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            model: Daemon.currentWallet ? Daemon.currentWallet.historyModel : null
            interactive: contentHeight > height
            delegate: Item {
                id: row
                required property var model
                width: ListView.view.width
                height: 58
                readonly property bool incoming: model.value.satsInt >= 0
                // only bitcoin: always 8 decimals, sign in front ("+0,00300000 BTC")
                function btc8() {
                    var s = Math.abs(model.value.satsInt)
                    var t = (s / 100000000).toFixed(8)
                    if (Config.language !== 'en_UK') t = t.replace('.', ',')
                    return (incoming ? '+' : '−') + t + ' BTC'
                }
                // hairline that fades at both ends
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(0.16, 0.13, 0.12, 0) }
                        GradientStop { position: 0.2; color: Qt.rgba(0.16, 0.13, 0.12, 0.12) }
                        GradientStop { position: 0.8; color: Qt.rgba(0.16, 0.13, 0.12, 0.12) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.16, 0.13, 0.12, 0) }
                    }
                }
                RowLayout {
                    anchors.fill: parent
                    spacing: 8
                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 17
                        color: row.incoming ? '#e6e9cf' : '#f3e3e8'
                        Image {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl(row.incoming ? '../../../icons/eh_rx_olive.svg' : '../../../icons/eh_tx_wine.svg')
                            sourceSize.width: 24
                            sourceSize.height: 24
                        }
                    }
                    // T39 (preview movimenti-righe.html): two lines that say more.
                    // Line 1: the amount, and when (or "unconfirmed").
                    // Line 2: the note (pencil) or "received / sent", and the amount in the other unit.
                    // Only bitcoin: 8 decimals in a fixed-width font, the date goes to line 2.
                    ColumnLayout {
                        id: rc
                        Layout.fillWidth: true
                        spacing: 1
                        readonly property bool btcOnly: app.ehBtcOnly()
                        readonly property string main: btcOnly ? row.btc8() : app.ehTxAmount(row.model.value, row.model.timestamp, true)
                        readonly property bool euroShown: !btcOnly && main.indexOf('€') >= 0
                        readonly property bool waiting: row.model.confirmations < 1
                        readonly property string when: app.ehWhen(row.model.timestamp)
                        readonly property string note: row.model.label ? row.model.label : ''
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label {
                                Layout.fillWidth: true
                                text: rc.main
                                font.pixelSize: rc.btcOnly ? 15 : 16
                                font.bold: true
                                font.family: rc.btcOnly ? 'monospace' : app.font.family
                                color: row.incoming ? '#45541f' : '#5e1a33'
                                elide: Text.ElideRight
                            }
                            Label {
                                visible: !rc.btcOnly && !rc.waiting && rc.when !== ''
                                text: rc.when
                                font.pixelSize: 12
                                color: '#6b5d55'
                            }
                            Rectangle {
                                visible: !rc.btcOnly && rc.waiting
                                Layout.preferredHeight: 16
                                Layout.preferredWidth: waitL.implicitWidth + 10
                                radius: 5
                                color: '#fbf0d6'
                                Label {
                                    id: waitL
                                    anchors.centerIn: parent
                                    text: qsTr('unconfirmed')
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: '#7a4a12'
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Image {
                                visible: rc.note !== ''
                                source: Qt.resolvedUrl('../../../icons/eh_pen_wine.svg')
                                sourceSize.width: 13
                                sourceSize.height: 13
                            }
                            Label {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                font.italic: rc.note !== ''
                                color: rc.note !== '' ? '#5e1a33' : '#4a4038'
                                text: rc.note !== '' ? rc.note : (row.incoming ? qsTr('money received') : qsTr('money sent'))
                            }
                            // euro shown: the bitcoin amount, small, on the right
                            Label {
                                visible: rc.euroShown
                                text: app.ehBtc(row.model.value).replace('-', '')
                                font.pixelSize: 12
                                color: '#6b5d55'
                            }
                            // only bitcoin: the date (or "unconf.") moves here
                            Label {
                                visible: rc.btcOnly && !rc.waiting && rc.when !== ''
                                text: rc.when
                                font.pixelSize: 12
                                color: '#6b5d55'
                            }
                            Rectangle {
                                visible: rc.btcOnly && rc.waiting
                                Layout.preferredHeight: 16
                                Layout.preferredWidth: waitL2.implicitWidth + 10
                                radius: 5
                                color: '#fbf0d6'
                                Label {
                                    id: waitL2
                                    anchors.centerIn: parent
                                    text: qsTr('unconf.')
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: '#7a4a12'
                                }
                            }
                        }
                    }
                }
                TapHandler {
                    onTapped: app.stack.push(Qt.resolvedUrl('../EhTxDetailsPage.qml'), {'txid': row.model.key})
                }
            }
        }
    }
}
