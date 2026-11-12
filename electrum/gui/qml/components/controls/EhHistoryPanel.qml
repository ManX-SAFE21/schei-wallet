// Easy Heirs (schèi): compact list of the latest movements for the home.
// Home "Bottega" (owner 13/11, preview home-nuova-grafica.html, proposal B): the movements are
// written on a sheet of paper, like an old account book: on the left what happened and when,
// on the right the amount, all in one column. Received = olive, sent = wine.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root
    property bool glass: false   // kept for the callers (old "luce colorata" look)
    readonly property string serif: SerifFont ? SerifFont : app.font.family
    readonly property string body: BodyFont ? BodyFont : app.font.family

    // dotted line between the rows (QML borders are solid)
    component Dotted: Canvas {
        property color tint: '#d8c69a'
        height: 2
        onWidthChanged: requestPaint()
        onPaint: {
            var c = getContext('2d')
            c.reset()
            c.strokeStyle = tint
            c.lineWidth = 2
            c.setLineDash([1, 2])
            c.beginPath(); c.moveTo(0, 1); c.lineTo(width, 1); c.stroke()
        }
    }

    // the sheet's lower edge (a paper shadow line)
    Rectangle {
        anchors.fill: sheet
        anchors.topMargin: 3
        anchors.bottomMargin: -3
        radius: 18
        color: '#e2d4b0'
    }
    Rectangle {
        id: sheet
        anchors.fill: parent
        anchors.bottomMargin: 3
        radius: 18
        color: '#fffdf6'
        border.width: 1.5
        border.color: '#d8c69a'
        clip: true

        // header: "Movimenti" and "Vedi tutti", gold double rule under it
        Item {
            id: head
            x: 12
            width: parent.width - 24
            height: 52
            Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr('Movements')
                font.family: root.serif
                font.weight: Font.ExtraBold
                font.pixelSize: 24
                color: '#5e1a33'
            }
            // a small stitched button (owner rule: every button has its stitching)
            Rectangle {
                id: seeAll
                visible: list.count > 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: seeAllL.implicitWidth + 26
                height: 34
                radius: 17
                gradient: Gradient {
                    GradientStop { position: 0.0; color: seeAllTap.pressed ? '#4a1228' : '#6d2140' }
                    GradientStop { position: 1.0; color: seeAllTap.pressed ? '#35091a' : '#4a1228' }
                }
                EhDashedBorder { anchors.fill: parent; inset: 3.5; radius: 13.5; lineWidth: 1.3; color: '#e3c57e' }
                Label {
                    id: seeAllL
                    anchors.centerIn: parent
                    text: qsTr('See all') + ' ›'
                    font.family: root.body
                    font.pixelSize: 16
                    font.bold: true
                    color: '#fbeccb'
                }
                TapHandler {
                    id: seeAllTap
                    margin: 7   // touch area of 48 px
                    onTapped: app.stack.push(Qt.resolvedUrl('../EhMovements.qml'))
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: '#d9b25a' }
            Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 2; width: parent.width; height: 1; color: '#d9b25a' }
        }

        Label {
            visible: list.count === 0
            anchors.fill: parent
            anchors.topMargin: head.height + 8
            anchors.margins: 14
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.StyledText
            color: '#5a4c44'
            font.family: root.body
            font.pixelSize: 16
            text: '<b>' + qsTr('No movements yet.') + '</b><br>' + (app.ehOption('buttons') ? qsTr('Tap RECEIVE to get your first bitcoin.') : qsTr('Pull the coin down to receive your first bitcoin.'))
        }

        ListView {
            id: list
            anchors.fill: parent
            anchors.topMargin: head.height
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            clip: true
            model: Daemon.currentWallet ? Daemon.currentWallet.historyModel : null
            interactive: contentHeight > height
            delegate: Item {
                id: row
                required property var model
                required property int index
                width: ListView.view.width
                height: 64
                readonly property bool incoming: model.value.satsInt >= 0
                // only bitcoin: always 8 decimals, sign in front ("+0,00300000 BTC")
                function btc8() {
                    var s = Math.abs(model.value.satsInt)
                    var t = (s / 100000000).toFixed(8)
                    if (Config.language !== 'en_UK') t = t.replace('.', ',')
                    return (incoming ? '+' : '−') + t + ' ' + app.ehBtcUnit()
                }
                readonly property bool btcOnly: app.ehBtcOnly()
                readonly property string main: btcOnly ? row.btc8() : app.ehTxAmount(row.model.value, row.model.timestamp, true)
                readonly property bool euroShown: !btcOnly && main.indexOf(app.ehSym()) >= 0
                readonly property bool waiting: row.model.confirmations < 1
                readonly property string when: app.ehWhen(row.model.timestamp)
                readonly property string note: row.model.label ? row.model.label : ''
                readonly property string what: {
                    var s = row.incoming ? qsTr('money received') : qsTr('money sent')
                    return s.charAt(0).toUpperCase() + s.substring(1)
                }
                readonly property color ink: row.incoming ? '#33400f' : '#5e1a33'
                // the + / − sign is drawn with the body font: in the serif font it is a hairline
                readonly property string sgn: '+−-'.indexOf(main.charAt(0)) >= 0 ? main.charAt(0) : ''
                readonly property string rest: sgn !== '' ? main.substring(1) : main
                // only bitcoin: the size that fits the line (from the text, not from the layout: no loop)
                TextMetrics { id: tm; font.family: root.serif; font.weight: Font.ExtraBold; font.pixelSize: 19; text: row.rest }
                readonly property real btcSize: Math.max(12, Math.min(19, 19 * (width - 48 - 14) / Math.max(1, tm.advanceWidth)))

                Dotted {
                    visible: row.index < list.count - 1
                    anchors.bottom: parent.bottom
                    width: parent.width
                }
                // outlined round icon: arrow down = received, arrow up = sent
                Rectangle {
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40; radius: 20
                    color: 'transparent'
                    border.width: 2.5
                    border.color: row.incoming ? '#45541f' : '#5e1a33'
                    Image {
                        anchors.centerIn: parent
                        source: Qt.resolvedUrl(row.incoming ? '../../../icons/eh_mv_in.svg' : '../../../icons/eh_mv_out.svg')
                        sourceSize.width: 24
                        sourceSize.height: 24
                    }
                }
                // the amount on the right, in one column (euro: the bitcoin amount small under it)
                Column {
                    id: amtCol
                    visible: !row.btcOnly
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Row {
                        anchors.right: parent.right
                        spacing: 1
                        Label { anchors.baseline: amtL.baseline; text: row.sgn; font.family: root.body; font.bold: true; font.pixelSize: 21; color: row.ink }
                        Label {
                            id: amtL
                            text: row.rest
                            font.family: root.serif
                            font.weight: Font.ExtraBold
                            font.pixelSize: 21
                            color: row.ink
                        }
                    }
                    Label {
                        visible: row.euroShown
                        anchors.right: parent.right
                        text: app.ehBtc(row.model.value).replace('-', '')
                        font.family: root.body
                        font.pixelSize: 13
                        color: '#5a4c44'
                    }
                }
                // left: what (or the note) and when (or "unconfirmed")
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 48
                    anchors.right: row.btcOnly ? parent.right : amtCol.left
                    anchors.rightMargin: row.btcOnly ? 0 : 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Item {
                        width: parent.width
                        height: whatL.implicitHeight
                        Image {
                            id: penI
                            visible: row.note !== ''
                            anchors.verticalCenter: parent.verticalCenter
                            source: Qt.resolvedUrl('../../../icons/eh_pen_wine.svg')
                            sourceSize.width: 14
                            sourceSize.height: 14
                        }
                        Label {
                            id: whatL
                            x: penI.visible ? 19 : 0
                            // only bitcoin: the date stays on this line, the amount goes under it
                            width: parent.width - x - (row.btcOnly ? whenBox.width + 6 : 0)
                            elide: Text.ElideRight
                            text: row.note !== '' ? row.note : row.what
                            font.family: root.body
                            font.pixelSize: 17
                            font.bold: true
                            color: row.note !== '' ? '#5e1a33' : '#2a2220'
                        }
                        Item {
                            id: whenBox
                            visible: row.btcOnly
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: visible ? (row.waiting ? pill1.width : when1.implicitWidth) : 0
                            height: parent.height
                            Label {
                                id: when1
                                visible: !row.waiting
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.when
                                font.family: root.body
                                font.pixelSize: 16
                                color: '#5a4c44'
                            }
                            Rectangle {
                                id: pill1
                                visible: row.waiting
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 22
                                width: pl1.implicitWidth + 12
                                radius: 11
                                color: '#fbf0d6'
                                border.width: 1
                                border.color: '#ecd49a'
                                Label { id: pl1; anchors.centerIn: parent; text: qsTr('unconf.'); font.family: root.body; font.pixelSize: 13; font.bold: true; color: '#7a4a12' }
                            }
                        }
                    }
                    // euro: the date (or "unconfirmed")
                    Label {
                        visible: !row.btcOnly && !row.waiting
                        width: parent.width
                        elide: Text.ElideRight
                        text: row.when
                        font.family: root.body
                        font.pixelSize: 16
                        color: '#5a4c44'
                    }
                    Rectangle {
                        visible: !row.btcOnly && row.waiting
                        height: 22
                        width: Math.min(parent.width, pl2.implicitWidth + 12)
                        radius: 11
                        color: '#fbf0d6'
                        border.width: 1
                        border.color: '#ecd49a'
                        Label { id: pl2; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 8); elide: Text.ElideRight
                                text: qsTr('unconfirmed'); font.family: root.body; font.pixelSize: 13; font.bold: true; color: '#7a4a12' }
                    }
                    // only bitcoin: 8 decimals, on its own line on the right (it does not fit next to the words)
                    Item {
                        visible: row.btcOnly
                        width: parent.width
                        height: btcL.implicitHeight
                        Row {
                            anchors.right: parent.right
                            spacing: 1
                            Label { anchors.baseline: btcL.baseline; text: row.sgn; font.family: root.body; font.bold: true; font.pixelSize: row.btcSize; color: row.ink }
                            Label {
                                id: btcL
                                text: row.rest
                                font.family: root.serif
                                font.weight: Font.ExtraBold
                                font.pixelSize: row.btcSize
                                color: row.ink
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
