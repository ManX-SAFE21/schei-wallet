// Easy Heirs (schȅi): "Quando avvisarti" (inheritance, screen 9; Settings › Inheritance).
// How long before the delivery "Sei ancora qui?" starts: half way, one third or one quarter
// from the end of the period. Save = bal.setWarn('half' | 'third' | 'quarter'), then back.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

Item {
    id: page
    property bool ehHideHeader: true
    property bool ehHeirPage: true
    Material.theme: Material.Light
    Material.foreground: S.ink

    readonly property var bal: AppController.plugin('bal')
    readonly property var st: app.ehHeirState(bal)   // M1: only the wallet open
    // the example uses the period of the inheritance in force (owner 16/11), else the one
    // chosen (2 years when none is set yet)
    readonly property int months: (st.monthsInForce || 0) > 0 ? st.monthsInForce : ((st.months || 0) > 0 ? st.months : 24)
    property string choice: st.warn || 'half'
    property string error: ''

    Rectangle { anchors.fill: parent; color: S.parch }

    Connections {
        target: page.bal
        function onDone(op, result) { if (op === 'setWarn') app.stack.pop() }
        function onFailed(op, code, message) { if (op === 'setWarn') page.error = app.ehHeirErrorText(code, message) }
    }

    // a choice: wine disc with the tick when chosen, an empty olive ring when not;
    // the text (and "recommended") in the middle, "N months before" on the right
    component Choice: Item {
        id: ch
        property string key
        property int div: 2
        property string text
        property string hint: ''
        property bool last: false
        readonly property bool on: page.choice === ch.key
        Layout.fillWidth: true
        implicitHeight: Math.max(64, chl.implicitHeight + 16)
        Layout.preferredHeight: implicitHeight
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            radius: 10
            color: S.sand
            opacity: chTap.pressed ? 0.4 : 0
        }
        RowLayout {
            id: chl
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                radius: 20
                color: ch.on ? S.wine : 'transparent'
                border.width: ch.on ? 0 : 2.5
                border.color: S.olive
                Image {
                    anchors.centerIn: parent
                    visible: ch.on
                    source: Qt.resolvedUrl('../../icons/eh_check_white.svg')
                    sourceSize.width: 22
                    sourceSize.height: 22
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    text: ch.text
                    color: S.ink
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: app.ehFsText
                    font.bold: true
                    lineHeight: 1.1
                    wrapMode: Text.WordWrap
                }
                Label {
                    Layout.fillWidth: true
                    visible: ch.hint !== ''
                    text: ch.hint
                    color: S.muted
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: app.ehFsText
                    wrapMode: Text.WordWrap
                }
            }
            Label {
                Layout.maximumWidth: ch.width * 0.4
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr('%1 months before').arg(Math.round(page.months / ch.div))
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                font.weight: Font.DemiBold
            }
        }
        EhDotLine {
            visible: !ch.last
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }
        TapHandler { id: chTap; onTapped: page.choice = ch.key }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.height + 12
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 2 * S.margin
            x: S.margin
            height: Math.max(implicitHeight, flick.height - 12)
            spacing: S.gap

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            EhBackLink { onClicked: app.stack.pop() }
            EhTitle { text: qsTr('When to remind you'); icon: 'eh_cal.svg' }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: -4
                text: qsTr('How long before the delivery do you want Schȅi to ask you whether to renew?')
                wrapMode: Text.WordWrap
                color: S.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                lineHeight: 1.1
            }

            EhCaption { text: qsTr('Remind me'); Layout.topMargin: 2; Layout.bottomMargin: -6 }
            EhSheet {
                Choice { key: 'half'; div: 2; text: qsTr('Half way through the period'); hint: qsTr('recommended') }
                Choice { key: 'third'; div: 3; text: qsTr('One third from the end') }
                Choice { key: 'quarter'; div: 4; text: qsTr('One quarter from the end'); last: true }
            }
            EhInfoBox {
                kind: 'tip'
                text: qsTr('Example with your inheritance of <b>%1</b>. The earlier it reminds you, the more time you have if you forget.').arg(app.ehHeirYears(page.months))
            }
            EhInfoBox {
                visible: page.error !== ''
                kind: 'danger'
                text: page.error
            }

            Item { Layout.fillHeight: true; Layout.minimumHeight: 4 }

            EhStitchButton {
                kind: 'olive'
                icon: 'eh_check_white.svg'
                text: qsTr('Save')
                enabled: !!page.bal && !page.bal.busy
                onClicked: {
                    page.error = ''
                    if (page.choice === (page.st.warn || 'half')) { app.stack.pop(); return }
                    page.bal.setWarn(page.choice)
                }
            }
        }
    }
}
