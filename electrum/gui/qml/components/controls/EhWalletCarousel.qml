// Easy Heirs (schèi): more wallets (expert option). Wallet cards side by side,
// swipe to change wallet (BlueWallet-like idea, own design). The last card adds
// a new wallet (max 7). Dots show where you are.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ColumnLayout {
    id: root
    spacing: 6
    readonly property int maxWallets: 7
    property bool compact: false   // home: narrow column next to the slide
    property bool strapLeft: false // T19: home with the slide on the right
    property real openK: 0         // T37: the open wallet opens as the coin comes down
    readonly property int count: list.count - 1   // wallets (the last card is "Add wallet")

    // copy of the wallet list + the "Add wallet" card at the end
    Instantiator {
        id: mirror
        model: Daemon.availableWallets
        delegate: QtObject {
            required property var model
            readonly property string name: model.name
            readonly property string path: model.path
        }
        onObjectAdded: Qt.callLater(root.rebuild)
        onObjectRemoved: Qt.callLater(root.rebuild)
    }
    property var cards: [{ add: true }]
    function rebuild() {
        var a = []
        for (var i = 0; i < mirror.count; i++) {
            var o = mirror.objectAt(i)
            if (o) a.push({ add: false, name: o.name, path: o.path })
        }
        a.push({ add: true })
        cards = a
        Qt.callLater(list.positionOnCurrent)
    }

    ListView {
        id: list
        Layout.fillWidth: true
        // the open wallet's card is taller with the pills "spendable / blocked" and "arriving":
        // room from the data, NOT from the card's own height (that made an endless layout loop)
        // owner 12/11: the home card has one fixed height (pills next to the cash button)
        // owner 13/11 (home-ritocchi.html): the home card is 184 high, always
        Layout.preferredHeight: root.compact || root.strapLeft ? 184
                                             : (app.ehOption('coins') && !app.ehBtcOnly() && app.ehHasCash() ? 188 : 140)
                                               + (Daemon.currentWallet && Daemon.currentWallet.frozenBalance.satsInt > 0 ? 12 : 0)
                                               + (Daemon.currentWallet && Daemon.currentWallet.ehArriving.satsInt > 0 ? 30 : 0)
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: root.strapLeft ? 8 : (root.compact ? 0 : 34)
        preferredHighlightEnd: root.strapLeft ? width - 48 : (root.compact ? width - 30 : width - 34)
        spacing: 10
        // T38: the wallet is now under the slide, as wide as the page: no clip, so the inside of
        // the wallet can rise above it and the next wallet peeks at the edge
        clip: false
        model: root.cards
        currentIndex: 0

        delegate: Item {
            id: d
            required property var modelData
            required property int index
            readonly property bool isAdd: modelData.add === true
            readonly property var model: modelData
            readonly property color wc: isAdd ? "#5e1a33" : app.ehWalletColorFor(modelData.name || "")
            readonly property bool isCurrent: !isAdd && Daemon.currentWallet && Daemon.currentWallet.name === modelData.name
            width: list.width - (root.strapLeft ? 56 : (root.compact ? 30 : 68))
            height: list.height
            // the cards next to the open one: smaller and more transparent,
            // so it is clear that there are more wallets
            scale: isCurrent || (isAdd && list.currentIndex === index) ? 1 : 0.9
            opacity: isCurrent || (isAdd && list.currentIndex === index) ? 1 : 0.9   // T45: clearly visible
            Behavior on scale { NumberAnimation { duration: 180 } }
            Behavior on opacity { NumberAnimation { duration: 180 } }

            EhWalletInside {
                visible: d.isCurrent && openK > 0.01
                anchors.fill: card
                baseColor: card.baseColor
                openK: root.openK
            }
            EhBalanceCard {
                id: card
                visible: d.isCurrent
                showGear: true
                compact: root.compact
                strapLeft: root.strapLeft
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                // T37: the front comes down from the top (opening), the inside appears above it
                transform: Scale {
                    origin.y: card.height
                    yScale: 1 - 0.22 * root.openK
                }
            }
            // other wallets: name and colour, swipe here to open
            Rectangle {
                id: otherCard
                visible: !d.isCurrent && !d.isAdd
                anchors.fill: parent
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                radius: 24
                // T45: a watch-only wallet is light: a wine border so it stands out from the page
                readonly property bool light: d.model.name ? app.ehWalletIsWatchFor(d.model.name) : false
                gradient: Gradient {
                    GradientStop { position: 0.0; color: otherCard.light ? '#fffdf8' : Qt.rgba(Qt.lighter(d.wc, 1.3).r, Qt.lighter(d.wc, 1.3).g, Qt.lighter(d.wc, 1.3).b, 0.92) }
                    GradientStop { position: 1.0; color: otherCard.light ? '#fbf3ee' : Qt.rgba(Qt.darker(d.wc, 1.35).r, Qt.darker(d.wc, 1.35).g, Qt.darker(d.wc, 1.35).b, 0.88) }
                }
                border.width: light ? 2.5 : 0
                border.color: '#b98a9a'
                // T45: the stitching, as on the open wallet
                EhDashedBorder {
                    anchors.fill: parent
                    inset: 7
                    radius: 17
                    lineWidth: 1.6
                    color: parent.light ? '#b98a9a' : (root.strapLeft ? '#e3c57e' : Qt.rgba(1, 0.91, 0.77, 0.75))
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    Label { text: app.ehWalletNameFor(d.model.name || ""); color: '#ffffff'; font.pixelSize: 17; font.bold: true }
                    // the balance seen the last time this wallet was open
                    Label {
                        visible: text !== ''
                        text: app.ehLastBalanceFor(d.model.name || "")
                        color: '#ffffff'
                        font.family: TitleFont ? TitleFont : font.family
                        font.weight: Font.Black
                        font.pixelSize: 28
                    }
                    Item { Layout.fillHeight: true }
                    Label { text: qsTr('tap to open it'); color: '#ffffff'; opacity: 0.8; font.pixelSize: 14 }
                }
                TapHandler { enabled: !d.isAdd; onTapped: { list.currentIndex = d.index; Daemon.loadWallet(d.model.path) } }
            }

            // last card: add a new wallet
            Rectangle {
                visible: d.isAdd
                anchors.fill: parent
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                radius: 24
                // T49 (owner 12/11): it was white on the cream page, almost invisible. Now a pale
                // wine wallet with a wine border and stitching, and a "+" already on the edge
                // that peeks out next to the open wallet
                gradient: Gradient {
                    GradientStop { position: 0.0; color: addTap.pressed ? '#ecd3dc' : '#f6e6ec' }
                    GradientStop { position: 1.0; color: addTap.pressed ? '#dcb5c3' : '#e9ccd7' }
                }
                border.width: 3
                border.color: '#5e1a33'
                EhDashedBorder { anchors.fill: parent; inset: 8; radius: 16; lineWidth: 1.8; color: '#8a3d5a' }
                Label {
                    // the "+" on the left edge: the part that is seen next to the open wallet
                    visible: list.currentIndex !== d.index
                    x: 5
                    anchors.verticalCenter: parent.verticalCenter
                    text: '+'
                    color: '#5e1a33'
                    font.pixelSize: 30
                    font.bold: true
                }
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        EhGlow { tone: 'gold'; anchors.fill: parent; anchors.margins: -10; z: 0 }
                        Label { anchors.centerIn: parent; text: '+'; font.pixelSize: 34; font.bold: true; color: '#5e1a33' }
                    }
                    Label { Layout.alignment: Qt.AlignHCenter; text: qsTr('Add wallet'); font.pixelSize: 17; font.bold: true; color: '#5e1a33' }
                    Label { Layout.alignment: Qt.AlignHCenter; text: qsTr('%1 of %2').arg(root.count).arg(root.maxWallets); font.pixelSize: 13; color: '#6b5d55' }
                }
                TapHandler {
                    id: addTap
                    enabled: d.isAdd
                    onTapped: app.ehAddWallet(root.count >= root.maxWallets)
                }
            }
        }

        onMovementEnded: {
            if (currentIndex < 0 || currentIndex >= count) return
            var item = itemAtIndex(currentIndex)
            if (item && !item.isAdd && !item.isCurrent)
                Daemon.loadWallet(item.model.path)
        }
        Component.onCompleted: Qt.callLater(positionOnCurrent)
        // second review (S2): look in the data, not in the cards on screen: cards far from the
        // view are not created, so the 4th wallet and after were never found
        function positionOnCurrent() {
            if (!Daemon.currentWallet) return
            for (var i = 0; i < root.cards.length; i++) {
                if (!root.cards[i].add && root.cards[i].name === Daemon.currentWallet.name) { currentIndex = i; return }
            }
        }
    }

    Connections {
        target: Daemon
        function onWalletLoaded() { Qt.callLater(list.positionOnCurrent) }
    }
    Connections {
        target: app
        function onEhWalletPickCancelled() { Qt.callLater(list.positionOnCurrent) }
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 7
        Repeater {
            model: root.cards
            Item {
                required property var modelData
                required property int index
                readonly property bool on: index === list.currentIndex
                // home "Bottega": the other wallets are small gold diamonds, the open one a pill
                readonly property bool diamond: root.strapLeft && !on
                width: modelData.add ? plusL.implicitWidth : (on ? (root.strapLeft ? 26 : 24) : (diamond ? 11 : 9))
                height: root.strapLeft ? 12 : 9
                Rectangle {
                    visible: !modelData.add
                    anchors.centerIn: parent
                    width: parent.diamond ? 8 : parent.width
                    height: parent.diamond ? 8 : (root.strapLeft ? 10 : parent.height)
                    radius: parent.diamond ? 1.5 : 5
                    rotation: parent.diamond ? 45 : 0
                    color: parent.diamond ? '#c9b48a' : app.ehWalletColorFor(modelData.name || '')
                    opacity: parent.on || parent.diamond ? 1 : 0.35
                }
                Label {
                    id: plusL
                    visible: modelData.add
                    anchors.verticalCenter: parent.verticalCenter
                    text: '+'
                    font.pixelSize: 15
                    font.bold: true
                    color: '#5e1a33'
                    opacity: parent.on ? 1 : 0.6
                }
            }
        }
    }
}
