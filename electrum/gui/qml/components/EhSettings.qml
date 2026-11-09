// Easy Heirs (schèi): settings. Here only the comfortable things, that do not
// touch the money: anyone can change them, no PIN. At the bottom the big
// "Advanced settings" button (golden lock): the PIN opens it (12 words, PIN,
// money and wallets are in there, see EhExpertPage.qml).
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

    Rectangle { anchors.fill: parent; color: '#faf7ef' }
    // "luce colorata": soft lights behind the cards
    EhGlow { tone: 'green'; x: -page.width * 0.3; y: 60; width: page.width * 1.6; height: 380 }
    EhGlow { tone: 'wine'; x: -page.width * 0.2; y: page.height - 360; width: page.width * 1.4; height: 360; opacity: 0.6 }

    // a row that opens something
    component Row1: Rectangle {
        id: r
        property string icon
        property string text
        property string value
        signal clicked
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(56, r1.implicitHeight + 16)
        color: rt.pressed ? Qt.rgba(1, 1, 1, 0.5) : 'transparent'
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0.16, 0.13, 0.13, 0.07) }
        RowLayout {
            id: r1
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                color: Qt.rgba(0.94, 0.90, 0.83, 0.9)
                Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/' + r.icon); sourceSize.width: 22; sourceSize.height: 22 }
            }
            Label { Layout.fillWidth: true; text: r.text; font.pixelSize: 17; font.bold: true; wrapMode: Text.WordWrap }
            Label { text: r.value; font.pixelSize: 14; color: '#6b5d55' }
            Label { text: '›'; font.pixelSize: 22; color: '#5e1a33' }
        }
        TapHandler { id: rt; onTapped: r.clicked() }
    }
    // a row with a switch (an option of the app)
    component RowSw: Rectangle {
        id: s
        property string icon
        property string text
        property string hint
        property string key
        property bool invert: false     // the option stores the opposite (no_anim)
        signal toggled(bool on)
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(60, sRow.implicitHeight + 16)
        color: 'transparent'
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0.16, 0.13, 0.13, 0.07) }
        RowLayout {
            id: sRow
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                color: Qt.rgba(0.94, 0.90, 0.83, 0.9)
                Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/' + s.icon); sourceSize.width: 22; sourceSize.height: 22 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: s.text; font.pixelSize: 17; font.bold: true; wrapMode: Text.WordWrap }
                Label { Layout.fillWidth: true; visible: s.hint !== ''; text: s.hint; font.pixelSize: 13; color: '#6b5d55'; wrapMode: Text.WordWrap }
            }
            Switch {
                checked: s.invert ? !app.ehOption(s.key) : app.ehOption(s.key)
                onToggled: { app.ehSetOption(s.key, s.invert ? !checked : checked); s.toggled(s.invert ? !checked : checked) }
            }
        }
    }
    component Group: Label {
        font.pixelSize: 13
        font.bold: true
        font.letterSpacing: 0.6
        color: '#6b5d55'
        Layout.leftMargin: 4
        Layout.topMargin: 4
    }
    // translucent card, as on the home
    component Card: Rectangle {
        default property alias content: cardCol.data
        Layout.fillWidth: true
        Layout.preferredHeight: cardCol.implicitHeight
        radius: 18
        color: Qt.rgba(1, 1, 1, 0.66)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.9)
        clip: true
        ColumnLayout { id: cardCol; width: parent.width; spacing: 0 }
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
                text: '‹ ' + qsTr('Back')
                color: '#5e1a33'
                font.pixelSize: 17
                font.bold: true
                TapHandler { margin: 10; onTapped: app.stack.pop() }
            }

            RowLayout {
                spacing: 10
                Image { source: Qt.resolvedUrl('../../icons/eh_gear.svg'); sourceSize.width: 32; sourceSize.height: 32 }
                Label {
                    text: qsTr('Settings')
                    color: '#3f0f21'
                    font.family: TitleFont ? TitleFont : font.family
                    font.weight: Font.Black
                    font.pixelSize: 28
                }
            }

            Group { text: qsTr('HOW YOU SEE THE APP') }
            Card {
                Row1 {
                    icon: 'eh_globe.svg'; text: qsTr('Language')
                    value: Config.language === 'vec_IT' ? 'Veneto' : (Config.language === 'en_UK' ? 'English' : 'Italiano')
                    onClicked: app.ehChangeLanguage()
                }
                RowSw {
                    icon: 'eh_textsize.svg'; text: qsTr('Bigger text'); hint: qsTr('to read better'); key: 'bigtext'
                    onToggled: {
                        var m = app.messageDialog.createObject(app, { text: qsTr('Close and reopen Schèi to see the new text size.') })
                        m.open()
                    }
                }
                Row1 { icon: 'eh_palette.svg'; text: qsTr('Name and colour'); onClicked: app.stack.push(Qt.resolvedUrl('EhNamePage.qml')) }
                RowSw { visible: !app.ehBtcOnly(); icon: 'eh_euro.svg'; text: qsTr('Banknotes and coins'); hint: qsTr('as when you use cash'); key: 'coins' }
            }

            Group { text: qsTr('COMFORT') }
            Card {
                RowSw { icon: 'eh_list.svg'; text: qsTr('Buttons instead of the bar'); hint: qsTr('for those who find it hard to drag'); key: 'buttons' }
                RowSw { icon: 'eh_anim.svg'; text: qsTr('Animations'); hint: qsTr('turn them off if the phone is slow'); key: 'no_anim'; invert: true }
                Row1 { icon: 'eh_info.svg'; text: qsTr('Information'); onClicked: app.stack.push(Qt.resolvedUrl('EhAboutPage.qml')) }
            }

            // ---- the way into the advanced settings: stitched like the wallet, golden lock ----
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.preferredHeight: advRow.implicitHeight + 28
                radius: 20
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0.54, 0.18, 0.32, advTap.pressed ? 0.95 : 0.84) }
                    GradientStop { position: 1.0; color: Qt.rgba(0.25, 0.06, 0.13, advTap.pressed ? 0.95 : 0.8) }
                }
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.3)
                EhDashedBorder { anchors.fill: parent; inset: 6; radius: 15; lineWidth: 1.4; color: Qt.rgba(1, 0.91, 0.77, 0.55) }
                RowLayout {
                    id: advRow
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 16; anchors.rightMargin: 16
                    spacing: 12
                    Image { source: Qt.resolvedUrl('../../icons/eh_snap_lock.svg'); sourceSize.width: 42; sourceSize.height: 42 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Label { Layout.fillWidth: true; text: qsTr('Advanced settings'); color: '#ffffff'; font.pixelSize: 18; font.bold: true; wrapMode: Text.WordWrap }
                        Label { Layout.fillWidth: true; text: qsTr('12 words, PIN, money and wallets · the PIN is needed'); color: '#ffffff'; opacity: 0.85; font.pixelSize: 13; wrapMode: Text.WordWrap }
                    }
                    Label { text: '›'; color: '#ffffff'; font.pixelSize: 26 }
                }
                TapHandler {
                    id: advTap
                    onTapped: app.ehAskPin(qsTr('Type the PIN to open the advanced settings'),
                                           function() { app.stack.push(Qt.resolvedUrl('EhExpertPage.qml')) })
                }
            }
        }
    }
}
