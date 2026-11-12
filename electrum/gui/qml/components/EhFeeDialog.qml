// Easy Heirs (schèi): "How much do you pay for sending?". Electrum's own fee
// slider (ETA targets 1008 ... 1 blocks), shown as cost in euro + time.
// The choice is for this payment only: every new payment starts from normal.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

ElDialog {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'

    property var finalizer
    readonly property int normalPos: 4          // owner 12/11: the middle, "in about 1 hour" (eta:5)
    readonly property int pos: finalizer ? finalizer.sliderPos : normalPos
    // T44 (owner 12/11): no "within a week" and no "within a day": the slowest is "a few hours"
    readonly property int minPos: 2
    Component.onCompleted: if (finalizer && finalizer.sliderPos < minPos) finalizer.sliderPos = minPos
    // owner 12/11: the tip written by hand (Settings for experts > "Tip written by hand")
    readonly property bool manualOn: app.ehOption('manual_fee')
    property string manualText: ''                     // what is typed, with the decimal comma
    property bool padOpen: false                       // owner 12/11: the keypad opens only when the field is tapped
    readonly property bool manual: manualOn && manualText !== ''
    readonly property real manualRate: Number(manualText.replace(',', '.'))
    readonly property real slowRate: Config.ehFeeRateForBlocks(25)   // about 4 hours
    // owner 12/11: the lowest hand-written tip is what the server accepts (it can be 0.1 sat/vB)
    readonly property real minRate: finalizer ? finalizer.ehMinFeerate() : 1
    function setManual(txt) {
        manualText = txt
        if (!finalizer) return
        if (txt === '') { finalizer.ehBackToSlider(Math.max(minPos, finalizer.sliderPos)); return }
        var r = Number(txt.replace(',', '.'))
        if (!isNaN(r) && r > 0) finalizer.ehSetManualFeerate('' + r)
    }
    function press(k) {
        var t = manualText
        if (k === 'del') t = t.slice(0, -1)
        else if (k === ',') { if (t.indexOf(',') < 0) t = (t === '' ? '0' : t) + ',' }
        else {
            var d = t.indexOf(',')
            if (d >= 0 && t.length - d > 1) return          // one decimal is enough
            if (t.replace(',', '').length >= 4) return
            if (t === '0') t = ''
            t += k
        }
        setManual(t)
    }

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    background: Rectangle { color: '#faf7ef' }

    Flickable {
        id: fl
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        flickableDirection: Flickable.VerticalFlick
        // T4: the page must not steal the finger from the slider; scroll only if needed
        interactive: !slider.pressed && contentHeight > height + 1
        contentHeight: Math.max(height, col.implicitHeight + 18)
        clip: true
    ColumnLayout {
        id: col
        x: 18
        width: fl.width - 36
        height: Math.max(fl.height - 18, implicitHeight)
        spacing: 10

        EhPageTop { title: '' ; Layout.bottomMargin: -14 }
        Label {
            text: '‹ ' + qsTr('Back')
            color: '#5e1a33'; font.pixelSize: 17; font.bold: true
            TapHandler { margin: 10; onTapped: root.doAccept() }
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr('How much do you pay for sending?')
            color: '#3f0f21'
            font.family: TitleFont ? TitleFont : font.family
            font.weight: Font.Black
            font.pixelSize: 24
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: why.implicitHeight + 22
            radius: 16
            color: '#fbf0d6'
            Label {
                id: why
                anchors.fill: parent; anchors.margins: 11
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                font.pixelSize: 16
                text: qsTr('Who leaves a <b>higher tip</b> to the miners goes first. With the lowest tip it can take <b>a few hours</b>.')
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: big.implicitHeight + 24
            radius: 18
            color: '#ffffff'
            ColumnLayout {
                id: big
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Label { Layout.alignment: Qt.AlignHCenter; textFormat: Text.StyledText
                        text: '<b>' + qsTr('SENDING COST') + '</b> ' + qsTr('(tip to the miners)'); color: '#6b5d55'; font.pixelSize: 13 }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.finalizer && root.finalizer.valid ? app.ehMoney(root.finalizer.fee) : '…'
                    color: '#3f0f21'
                    font.family: TitleFont ? TitleFont : font.family
                    font.weight: Font.Black
                    font.pixelSize: 32
                }
                Label { Layout.topMargin: 8; Layout.alignment: Qt.AlignHCenter; text: qsTr('IT ARRIVES'); color: '#6b5d55'; font.pixelSize: 13; font.bold: true }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: app.ehFeeEta(root.pos)
                    color: root.pos <= 2 ? '#8a5a12' : '#45541f'
                    font.family: TitleFont ? TitleFont : font.family
                    font.weight: Font.Black
                    font.pixelSize: 26
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            ColumnLayout {
                spacing: 0
                Image { Layout.alignment: Qt.AlignHCenter; source: Qt.resolvedUrl('../../icons/eh_slow.svg'); sourceSize.width: 54; sourceSize.height: 36 }
                Label { Layout.alignment: Qt.AlignHCenter; horizontalAlignment: Text.AlignHCenter; text: qsTr('slower\ncosts less'); color: '#45541f'; font.pixelSize: 13; font.bold: true }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
                spacing: 0
                Image { Layout.alignment: Qt.AlignHCenter; source: Qt.resolvedUrl('../../icons/eh_fast.svg'); sourceSize.width: 54; sourceSize.height: 36 }
                Label { Layout.alignment: Qt.AlignHCenter; horizontalAlignment: Text.AlignHCenter; text: qsTr('faster\ncosts more'); color: '#5e1a33'; font.pixelSize: 13; font.bold: true }
            }
        }
        Slider {
            id: slider
            Layout.fillWidth: true
            from: root.minPos
            to: root.finalizer ? root.finalizer.sliderSteps : 6
            stepSize: 1
            snapMode: Slider.SnapAlways
            // T4: easier to grab: tall touch area, follows the finger at once,
            // a tap anywhere on the bar moves the handle there
            Layout.preferredHeight: 64
            touchDragThreshold: 2
            value: root.pos
            opacity: root.manual ? 0.4 : 1
            // moving the slider goes back from the hand-written tip to the slider (Electrum's ETA)
            onMoved: if (root.finalizer) {
                         root.padOpen = false
                         if (root.manual) { root.manualText = ''; root.finalizer.ehBackToSlider(Math.round(value)) }
                         else root.finalizer.sliderPos = Math.round(value)
                     }
            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 14
                radius: 7
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: '#c9d39a' }
                    GradientStop { position: 0.5; color: '#e8c56a' }
                    GradientStop { position: 1.0; color: '#e2a0b6' }
                }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 46; height: 46; radius: 23
                color: '#ffffff'
                border.width: 4
                border.color: '#5e1a33'
            }
        }
        // T44: the times under the slider, from "1 day" to "10 min"
        Item {
            Layout.fillWidth: true
            Layout.topMargin: -14
            Layout.preferredHeight: 16
            Repeater {
                model: [qsTr('4 hours'), qsTr('2 hours'), qsTr('1 hour'), qsTr('20 min'), qsTr('10 min')]
                Label {
                    required property string modelData
                    required property int index
                    readonly property real k: index / 4
                    x: slider.leftPadding + 23 + k * (slider.availableWidth - 46) - implicitWidth / 2
                    text: modelData
                    font.pixelSize: 11
                    color: root.pos === index + root.minPos ? '#3f0f21' : '#6b5d55'
                    font.bold: root.pos === index + root.minPos
                }
            }
        }
        // the tip written by hand: field + keypad (only with the option on)
        Rectangle {
            visible: root.manualOn
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: 14
            color: fieldTap.pressed ? '#f3ecdd' : '#ffffff'
            border.width: 2
            border.color: root.padOpen ? '#5e1a33' : '#d9b25a'
            TapHandler { id: fieldTap; onTapped: root.padOpen = !root.padOpen }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                Label { text: qsTr('Tip by hand'); font.pixelSize: 14; font.bold: true }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.manualText !== '' ? root.manualText : (root.padOpen ? '–' : qsTr('tap to write'))
                    font.family: root.manualText !== '' ? 'monospace' : font.family
                    font.pixelSize: root.manualText !== '' || root.padOpen ? 24 : 15
                    font.bold: true
                    color: '#3f0f21'
                }
                Label { text: 'sat/vB'; font.pixelSize: 14 }
            }
        }
        Rectangle {
            visible: root.manual && (root.manualRate < 1 || (root.slowRate > 0 && root.manualRate < root.slowRate))
            Layout.fillWidth: true
            Layout.preferredHeight: lowL.implicitHeight + 18
            radius: 12
            color: '#fbf0d8'
            border.width: 2
            border.color: '#d9b25a'
            Label {
                id: lowL
                anchors.fill: parent; anchors.margins: 9
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                font.pixelSize: 14
                text: root.manualRate < root.minRate
                      ? '<b>' + qsTr('Too low.') + '</b> '
                        + qsTr('The connected server accepts at least %1 sat/vB.').arg(app.ehFeeRate(root.minRate.toFixed(1) + ' sat/vB').replace(' sat/vB', ''))
                      : root.manualRate < 1
                      ? '<b>' + qsTr('Very low tip.') + '</b> '
                        + qsTr('Less than 1 sat/vB: the payment can wait a long time, and some nodes may not pass it on.')
                      : '<b>' + qsTr('Very low tip.') + '</b> '
                        + qsTr('It is less than what is needed to arrive within 4 hours (now about %1 sat/vB): the payment can wait a long time, or the miners may never take it.')
                          .arg(app.ehFeeRate(root.slowRate.toFixed(1) + ' sat/vB').replace(' sat/vB', ''))
            }
        }
        GridLayout {
            visible: root.manualOn && root.padOpen
            Layout.fillWidth: true
            columns: 3; rowSpacing: 6; columnSpacing: 6
            Repeater {
                model: ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', 'del']
                delegate: Rectangle {
                    id: fk
                    required property string modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 21
                    color: modelData === 'del' ? '#efe6d3' : (fkt.pressed ? '#f3ecdd' : '#ffffff')
                    border.width: modelData === 'del' ? 0 : 2; border.color: '#e2d7c1'
                    EhBackspaceIcon { visible: fk.modelData === 'del'; anchors.centerIn: parent; width: 32; height: 23; fill: '#efe6d3' }
                    Label { anchors.centerIn: parent; visible: fk.modelData !== 'del'; text: fk.modelData === ',' ? app.ehLocale().decimalPoint : fk.modelData; font.pixelSize: 21; font.bold: true }
                    TapHandler { id: fkt; onTapped: root.press(fk.modelData) }
                }
            }
        }
        Item { Layout.fillHeight: true }
        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: root.finalizer && root.finalizer.valid
            text: qsTr('for experts: %1').arg(root.finalizer ? app.ehFeeRate(root.finalizer.feeRate + ' sat/vB') : '')
            color: '#6b5d55'
            font.pixelSize: 13
        }
        EhNextButton {
            Layout.fillWidth: true
            enabled: !root.manual || root.manualRate >= root.minRate
            text: qsTr('That is fine')
            onClicked: root.doAccept()
        }
        EhPillButton {
            text: qsTr('Back to normal')
            color: '#ffffff'
            textColor: '#2a2220'
            tileColor: '#efe6d3'
            fontSize: 18
            onClicked: if (root.finalizer) { root.padOpen = false; root.manualText = ''; root.finalizer.ehBackToSlider(root.normalPos) }
            Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_undo.svg'); sourceSize.width: 26; sourceSize.height: 26 }
        }
    }
    }
}
