// Easy Heirs (schȅi), owner 18/11: Settings › Inheritance › "Maximum price of a keeper" (EXPERT
// level): Schȅi gives the envelope only to keepers asking at most this price. 50 000 sats standard;
// 4 buttons or a value typed by hand, from 1 000 to 500 000 (the plugin's own ceiling).
// bal.setKeeperMax(n).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "controls"
import "controls/EhStyle.js" as S

EhBottomSheet {
    id: root
    readonly property var bal: AppController.plugin('bal')
    readonly property var st: app.ehHeirState(bal)
    readonly property var choices: st.keeperMaxChoices || [25000, 50000, 100000, 200000]
    property int chosen: st.keeperMax || 50000
    property string error: ''
    onClosed: destroy()
    function digits(t) { return ('' + t).replace(/[^0-9]/g, '') }

    EhTitle {
        text: qsTr('Maximum price of a keeper')
        icon: 'eh_euro.svg'
        fontSize: app.ehFsBox
        Layout.bottomMargin: 0
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.StyledText
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: app.ehFsText
        lineHeight: 1.15
        color: S.ink
        text: qsTr('Schȅi gives the envelope only to keepers who ask <b>at most</b> this price. Only one is paid, only at the delivery.')
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: root.choices
            delegate: Rectangle {
                id: chip
                required property int modelData
                readonly property bool on: modelData === root.chosen
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 14
                color: on ? S.leatherWine2 : (chipTap.pressed ? S.sand : S.paper)
                border.width: 2
                border.color: on ? S.wineDark : S.edge
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: Number(chip.modelData).toLocaleString(Qt.locale(Config.language === 'en_UK' ? 'en_GB' : 'it_IT'), 'f', 0)
                        color: chip.on ? S.ivory : S.wine
                        font.family: SerifFont ? SerifFont : font.family
                        font.weight: Font.ExtraBold
                        font.pixelSize: app.ehFsStrong
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: chip.modelData === 50000 ? qsTr('standard') : '≈ ' + app.ehHeirSats(chip.modelData)
                        color: chip.on ? S.ivory : S.muted
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: app.ehFsSmall
                    }
                }
                TapHandler { id: chipTap; onTapped: { root.chosen = chip.modelData; root.error = ''; ownField.text = '' } }
            }
        }
    }
    // owner 18/11: or a value typed by hand
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Label {
            text: qsTr('Other amount')
            color: S.ink
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: app.ehFsText
            font.bold: true
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: 16
            color: S.paper
            border.width: ownField.activeFocus || root.choices.indexOf(root.chosen) < 0 ? 2.5 : 1.5
            border.color: ownField.activeFocus || root.choices.indexOf(root.chosen) < 0 ? S.wine : S.edge
            TextField {
                id: ownField
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 44
                text: root.choices.indexOf(root.chosen) < 0 ? '' + root.chosen : ''
                placeholderText: text === '' && !activeFocus ? qsTr('e.g. 30000') : ''
                topPadding: 0; bottomPadding: 0; leftPadding: 0; rightPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                background: null
                color: S.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                font.bold: true
                maximumLength: 7
                inputMethodHints: Qt.ImhDigitsOnly
                onTextEdited: {
                    root.error = ''
                    var n = parseInt(root.digits(text))
                    if (n > 0) root.chosen = n
                }
            }
            Label {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: 'sat'
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
            }
        }
    }
    Label {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: app.ehFsSmall
        color: root.error !== '' ? S.wine : S.muted
        text: root.error !== '' ? root.error
              : qsTr('sats; %1 ≈ %2').arg(app.ehSatsText(root.chosen)).arg(app.ehHeirSats(root.chosen))
    }
    EhStitchButton {
        kind: 'olive'
        icon: 'eh_check_white.svg'
        enabled: !(root.bal && root.bal.busy)
        text: qsTr('Save')
        onClicked: {
            if (root.chosen < 1000 || root.chosen > 500000) {
                root.error = qsTr('Write an amount from 1.000 to 500.000 sats.')
                return
            }
            if (root.bal) root.bal.setKeeperMax(root.chosen)
            root.close()
        }
    }
}
