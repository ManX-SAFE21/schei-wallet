// Easy Heirs (schèi): "Valuta" (T48, owner 12/11, preview valuta.html). The reference
// currency for the amounts. Electrum knows many; only real money is listed (no other crypto),
// the most used first, with a search. Changing it uses Electrum's own exchange rates.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'

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

    Rectangle { anchors.fill: parent; color: '#faf7ef' }

    component Row1: Rectangle {
        id: r
        property string code
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        color: rt.pressed ? Qt.rgba(1, 1, 1, 0.5) : (app.ehCcy() === r.code ? '#fbf3f5' : 'transparent')
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0.16, 0.13, 0.13, 0.07) }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 14
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
                color: Qt.rgba(0.94, 0.90, 0.83, 0.9)
                Label { anchors.centerIn: parent; text: app.ehCcySymbols[r.code] || r.code; font.pixelSize: (app.ehCcySymbols[r.code] || r.code).length > 2 ? 11 : 16; font.bold: true; color: '#5e1a33' }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: page.nameOf(r.code); font.pixelSize: 17; font.bold: true; elide: Text.ElideRight }
                Label { text: r.code; font.pixelSize: 12; color: '#6b5d55' }
            }
            Label { visible: app.ehCcy() === r.code; text: '✓'; font.pixelSize: 22; font.bold: true; color: '#5e1a33' }
        }
        TapHandler { id: rt; onTapped: page.choose(r.code) }
    }
    component Card: Rectangle {
        default property alias content: cc.data
        Layout.fillWidth: true
        Layout.preferredHeight: cc.implicitHeight
        radius: 18
        color: Qt.rgba(1, 1, 1, 0.7)
        clip: true
        ColumnLayout { id: cc; width: parent.width; spacing: 0 }
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
            Label {
                Layout.topMargin: -14
                text: '‹ ' + qsTr('Settings')
                color: '#5e1a33'; font.pixelSize: 17; font.bold: true
                TapHandler { margin: 10; onTapped: app.stack.pop() }
            }
            Label {
                text: qsTr('Currency')
                color: '#3f0f21'
                font.family: TitleFont ? TitleFont : font.family
                font.weight: Font.Black
                font.pixelSize: 28
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                color: '#6b5d55'
                text: qsTr('The amounts are shown in this currency, at the price of the day. Banknotes and coins exist for the euro and the dollar.')
            }
            TextField {
                Layout.fillWidth: true
                placeholderText: qsTr('Search (e.g. franc, yen…)')
                onTextChanged: page.query = text
                inputMethodHints: Qt.ImhNoPredictiveText
            }
            Label { visible: page.query === ''; text: qsTr('THE MOST USED'); font.pixelSize: 13; font.bold: true; color: '#6b5d55' }
            Card {
                visible: page.query === ''
                Repeater { model: page.topCodes; Row1 { required property string modelData; code: modelData } }
            }
            Label { text: qsTr('ALL THE OTHERS'); font.pixelSize: 13; font.bold: true; color: '#6b5d55' }
            Card {
                Repeater { model: page.others(); Row1 { required property string modelData; code: modelData } }
            }
        }
    }
}
