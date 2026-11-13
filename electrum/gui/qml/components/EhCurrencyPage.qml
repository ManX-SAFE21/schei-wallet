// Easy Heirs (schèi): "Valuta" (T48, owner 12/11, preview valuta.html). The reference
// currency for the amounts. Electrum knows many; only real money is listed (no other crypto),
// the most used first, with a search. Changing it uses Electrum's own exchange rates.
// Look: "Bottega" (paper sheets, rows like EhRow, the chosen one with an olive tick).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.wine          // the text cursor

    // code: [Italian name, English name]
    readonly property var names: ({
        EUR: ['Euro', 'Euro'], USD: ['Dollaro americano', 'US dollar'], GBP: ['Sterlina inglese', 'British pound'],
        CHF: ['Franco svizzero', 'Swiss franc'], CAD: ['Dollaro canadese', 'Canadian dollar'],
        AUD: ['Dollaro australiano', 'Australian dollar'], NZD: ['Dollaro neozelandese', 'New Zealand dollar'],
        CNY: ['Yuan cinese', 'Chinese yuan'], HKD: ['Dollaro di Hong Kong', 'Hong Kong dollar'], SGD: ['Dollaro di Singapore', 'Singapore dollar'],
        INR: ['Rupia indiana', 'Indian rupee'], BRL: ['Real brasiliano', 'Brazilian real'],
        MXN: ['Peso messicano', 'Mexican peso'], ARS: ['Peso argentino', 'Argentine peso'],
        COP: ['Peso colombiano', 'Colombian peso'], PEN: ['Sol peruviano', 'Peruvian sol'], SEK: ['Corona svedese', 'Swedish krona'],
        NOK: ['Corona norvegese', 'Norwegian krone'], DKK: ['Corona danese', 'Danish krone'],
        CZK: ['Corona ceca', 'Czech koruna'], PLN: ['Zloty polacco', 'Polish zloty'], HUF: ['Fiorino ungherese', 'Hungarian forint'],
        RON: ['Leu rumeno', 'Romanian leu'], BGN: ['Lev bulgaro', 'Bulgarian lev'], RSD: ['Dinaro serbo', 'Serbian dinar'],
        TRY: ['Lira turca', 'Turkish lira'], RUB: ['Rublo russo', 'Russian ruble'], UAH: ['Grivnia ucraina', 'Ukrainian hryvnia'],
        ILS: ['Nuovo siclo israeliano', 'Israeli new shekel'], AED: ['Dirham degli Emirati', 'UAE dirham'], SAR: ['Riyal saudita', 'Saudi riyal'],
        ZAR: ['Rand sudafricano', 'South African rand'], NGN: ['Naira nigeriana', 'Nigerian naira'], KES: ['Scellino keniota', 'Kenyan shilling'],
        EGP: ['Sterlina egiziana', 'Egyptian pound'], MAD: ['Dirham marocchino', 'Moroccan dirham'], THB: ['Baht thailandese', 'Thai baht'],
        IDR: ['Rupia indonesiana', 'Indonesian rupiah'], MYR: ['Ringgit malese', 'Malaysian ringgit'], PHP: ['Peso filippino', 'Philippine peso'], TWD: ['Dollaro taiwanese', 'New Taiwan dollar'], PKR: ['Rupia pakistana', 'Pakistani rupee']
    })
    readonly property var topCodes: ['EUR', 'USD', 'GBP', 'CHF']
    property string query: ''
    readonly property var available: Daemon.fx.ehCurrencies()

    function nameOf(code) {
        var n = names[code]
        if (!n) return code
        return Config.language === 'en_UK' ? n[1] : n[0]
    }
    function others() {
        var out = []
        for (var code in names) {
            if (query === '' && topCodes.indexOf(code) >= 0) continue
            if (available.length && available.indexOf(code) < 0) continue
            var q = query.toLowerCase()
            if (q !== '' && nameOf(code).toLowerCase().indexOf(q) < 0 && code.toLowerCase().indexOf(q) < 0) continue
            out.push(code)
        }
        out.sort(function(a, b) { return nameOf(a).localeCompare(nameOf(b)) })
        return out
    }
    function choose(code) {
        app.ehSetCurrency(code)
        app.stack.pop()
    }

    Rectangle { anchors.fill: parent; color: S.parch }

    // a currency: symbol in a ring, name, code; the chosen one has the olive tick
    component Row1: Item {
        id: r
        property string code
        property bool last: false
        readonly property bool on: app.ehCcy() === r.code
        readonly property string sym: app.ehCcySymbols[r.code] || r.code
        Layout.fillWidth: true
        implicitHeight: Math.max(64, rl.implicitHeight + 16)
        Layout.preferredHeight: implicitHeight
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            radius: 10
            color: S.sand
            opacity: rt.pressed ? 0.4 : 0
        }
        RowLayout {
            id: rl
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20
                color: 'transparent'
                border.width: 2.5
                border.color: S.wine
                Label {
                    anchors.centerIn: parent
                    text: r.sym
                    color: S.wine
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: r.sym.length > 2 ? 16 : 18
                    font.bold: true
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    Layout.fillWidth: true
                    text: page.nameOf(r.code)
                    color: r.on ? S.oliveInk : S.ink
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 17
                    font.bold: true
                    elide: Text.ElideRight
                }
                Label {
                    text: r.code
                    color: S.muted
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: 16
                }
            }
            Label {
                visible: r.on
                text: '✓'
                color: S.olive
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 24
                font.bold: true
            }
        }
        EhDotLine {
            visible: !r.last
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }
        TapHandler { id: rt; onTapped: page.choose(r.code) }
    }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.implicitHeight + 24
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 32
            x: 16
            spacing: 8
            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            EhBackLink { text: '‹ ' + qsTr('Settings'); onClicked: app.stack.pop() }
            EhTitle { text: qsTr('Currency') }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
                text: qsTr('The amounts are shown in this currency, at the price of the day. Banknotes and coins exist for the euro and the dollar.')
            }
            // search field: paper, magnifier on the left, our own hint
            Item {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.preferredHeight: 63
                Rectangle {      // hard shadow
                    y: 3
                    width: searchBox.width
                    height: searchBox.height
                    radius: searchBox.radius
                    color: S.edgeShadow
                }
                Rectangle {
                    id: searchBox
                    width: parent.width
                    height: 60
                    radius: 16
                    color: S.paper
                    border.width: searchField.activeFocus ? 2.5 : 2
                    border.color: searchField.activeFocus ? S.wine : S.edge
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        Image { source: Qt.resolvedUrl('../../icons/eh_zoom.svg'); sourceSize.width: 24; sourceSize.height: 24 }
                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            placeholderText: ''          // no Material floating label: our own hint below
                            topPadding: 0
                            bottomPadding: 0
                            leftPadding: 0
                            rightPadding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            background: null
                            color: S.ink
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 18
                            onTextChanged: page.query = text
                            inputMethodHints: Qt.ImhNoPredictiveText
                            Label {
                                visible: searchField.text === '' && !searchField.inputMethodComposing
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                elide: Text.ElideRight
                                text: qsTr('Search (e.g. franc, yen…)')
                                color: S.muted
                                font.family: BodyFont ? BodyFont : font.family
                                font.pixelSize: 17
                            }
                        }
                    }
                }
            }
            EhCaption { visible: page.query === ''; text: qsTr('THE MOST USED'); Layout.topMargin: 8; Layout.bottomMargin: -2 }
            EhSheet {
                visible: page.query === ''
                Repeater { model: page.topCodes; Row1 { required property string modelData; required property int index; code: modelData; last: index === page.topCodes.length - 1 } }
            }
            EhCaption { text: qsTr('ALL THE OTHERS'); Layout.topMargin: 8; Layout.bottomMargin: -2 }
            EhSheet {
                id: othersSheet
                readonly property var list: page.others()
                Repeater { model: othersSheet.list; Row1 { required property string modelData; required property int index; code: modelData; last: index === othersSheet.list.length - 1 } }
            }
        }
    }
}
