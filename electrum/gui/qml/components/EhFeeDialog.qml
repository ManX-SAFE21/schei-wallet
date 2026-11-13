// Easy Heirs (schȅi): "How much do you pay for sending?". Electrum's own fee
// slider (ETA targets 1008 ... 1 blocks), shown as cost in euro + time.
// The choice is for this payment only: every new payment starts from normal.
// "Bottega": parchment page, cost and time on a paper sheet, sand track with a brass knob.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

ElDialog {
    id: root
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.wine
    font.family: BodyFont ? BodyFont : Qt.application.font.family

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
    background: Rectangle { color: S.parch }

    Flickable {
        id: fl
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        flickableDirection: Flickable.VerticalFlick
        // T4: the page must not steal the finger from the slider; scroll only if needed
        interactive: !slider.pressed && contentHeight > height + 1
        contentHeight: Math.max(height, col.implicitHeight + 16)
        boundsBehavior: Flickable.StopAtBounds
        clip: true
    ColumnLayout {
        id: col
        x: S.margin
        width: fl.width - 2 * S.margin
        height: Math.max(fl.height - 16, implicitHeight)
        spacing: 10

        EhPageTop { title: '' }
        EhBackLink { onClicked: root.doAccept() }
        EhTitle { text: qsTr('How much do you pay for sending?') }
        EhInfoBox {
            id: why
            kind: 'warn'
            text: qsTr('Who leaves a <b>higher tip</b> to the miners goes first. With the lowest tip it can take <b>a few hours</b>.')
        }
        EhSheet {
            topPadding: 10
            bottomPadding: 12
            ColumnLayout {
                id: big
                Layout.fillWidth: true
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    text: '<b>' + qsTr('SENDING COST') + '</b> ' + qsTr('(tip to the miners)')
                    color: S.muted
                    font.pixelSize: 16
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.finalizer && root.finalizer.valid ? app.ehMoney(root.finalizer.fee) : '…'
                    color: S.wineDark
                    font.family: SerifFont ? SerifFont : font.family
                    font.weight: Font.ExtraBold
                    font.pixelSize: 26
                }
                EhDotLine { Layout.topMargin: 8; Layout.bottomMargin: 6 }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr('IT ARRIVES')
                    color: S.muted
                    font.pixelSize: 16
                    font.bold: true
                    font.letterSpacing: 0.5
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: big.width
                    text: app.ehFeeEta(root.pos)
                    color: root.pos <= 2 ? S.waitInk : S.oliveInk
                    font.family: SerifFont ? SerifFont : font.family
                    font.weight: Font.ExtraBold
                    font.pixelSize: 26
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 18
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            ColumnLayout {
                spacing: 0
                Image { Layout.alignment: Qt.AlignHCenter; source: Qt.resolvedUrl('../../icons/eh_slow.svg'); sourceSize.width: 54; sourceSize.height: 36 }
                Label { Layout.alignment: Qt.AlignHCenter; horizontalAlignment: Text.AlignHCenter; text: qsTr('slower\ncosts less'); color: S.oliveInk; font.pixelSize: 16; font.bold: true; lineHeight: 0.95 }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
                spacing: 0
                Image { Layout.alignment: Qt.AlignHCenter; source: Qt.resolvedUrl('../../icons/eh_fast.svg'); sourceSize.width: 54; sourceSize.height: 36 }
                Label { Layout.alignment: Qt.AlignHCenter; horizontalAlignment: Text.AlignHCenter; text: qsTr('faster\ncosts more'); color: S.wine; font.pixelSize: 16; font.bold: true; lineHeight: 0.95 }
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
            // sand track, 10 px, with a little depth at the top
            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 10
                radius: 5
                color: S.sand
                border.width: 1
                border.color: S.edge
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 1
                    height: 4
                    radius: 2
                    color: Qt.rgba(0, 0, 0, 0.08)
                }
            }
            // brass knob, 44 px (material 5: vertical gradient and a 2 px ring)
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 44; height: 44; radius: 22
                border.width: 2
                border.color: S.brassRing
                gradient: Gradient {
                    GradientStop { position: 0.0; color: S.brassLight }
                    GradientStop { position: 0.55; color: S.brass }
                    GradientStop { position: 1.0; color: S.brassDark }
                }
            }
        }
        // T44: the times under the slider, from "4 hours" to "10 min"
        Item {
            Layout.fillWidth: true
            Layout.topMargin: -14
            Layout.preferredHeight: 22
            Repeater {
                model: [qsTr('4 hours'), qsTr('2 hours'), qsTr('1 hour'), qsTr('20 min'), qsTr('10 min')]
                Label {
                    required property string modelData
                    required property int index
                    readonly property real k: index / 4
                    // centred under its stop, but never out of the page
                    x: Math.max(-4, Math.min(parent.width + 4 - implicitWidth,
                                             slider.leftPadding + 22 + k * (slider.availableWidth - 44) - implicitWidth / 2))
                    text: modelData
                    font.pixelSize: 16
                    color: root.pos === index + root.minPos ? S.wineDark : S.muted
                    font.bold: root.pos === index + root.minPos
                }
            }
        }
        // the tip written by hand: field + keypad (only with the option on)
        Rectangle {
            visible: root.manualOn
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: S.fieldH
            radius: 16
            color: fieldTap.pressed ? S.sand : S.paper
            border.width: root.padOpen ? 2.5 : 2
            border.color: root.padOpen ? S.wine : S.edge
            TapHandler { id: fieldTap; onTapped: root.padOpen = !root.padOpen }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                Image { source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg'); sourceSize.width: 24; sourceSize.height: 24 }
                Label { text: qsTr('Tip by hand'); font.pixelSize: 16; font.bold: true; color: S.ink }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.manualText !== '' ? root.manualText : (root.padOpen ? '–' : qsTr('tap to write'))
                    font.family: root.manualText !== '' ? FixedFont : font.family
                    font.pixelSize: root.manualText !== '' || root.padOpen ? 24 : 16
                    font.bold: true
                    color: root.manualText !== '' || root.padOpen ? S.wineDark : S.muted
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    lineHeight: 0.95
                    elide: Text.ElideRight
                }
                Label { text: 'sat/vB'; font.pixelSize: 16; color: S.muted }
            }
        }
        EhInfoBox {
            id: lowL
            visible: root.manual && (root.manualRate < root.minRate || root.manualRate < 1 || (root.slowRate > 0 && root.manualRate < root.slowRate))
            kind: root.manualRate < root.minRate ? 'danger' : 'warn'
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
        GridLayout {
            visible: root.manualOn && root.padOpen
            Layout.fillWidth: true
            columns: 3; rowSpacing: 8; columnSpacing: 8
            Repeater {
                model: ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', 'del']
                delegate: EhKey {
                    required property string modelData
                    implicitHeight: 56
                    text: modelData === ',' ? app.ehLocale().decimalPoint : modelData
                    isDelete: modelData === 'del'
                    onActivated: root.press(modelData)
                }
            }
        }
        Item { Layout.fillHeight: true }
        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: root.finalizer && root.finalizer.valid
            text: qsTr('for experts: %1').arg(root.finalizer ? app.ehFeeRate(root.finalizer.feeRate + ' sat/vB') : '')
            color: S.muted
            font.pixelSize: 16
        }
        EhStitchButton {
            kind: 'wine'
            icon: 'eh_check_white.svg'
            enabled: !root.manual || root.manualRate >= root.minRate
            text: qsTr('That is fine')
            onClicked: root.doAccept()
        }
        EhStitchButton {
            kind: 'paper'
            icon: 'eh_undo.svg'
            text: qsTr('Back to normal')
            onClicked: if (root.finalizer) { root.padOpen = false; root.manualText = ''; root.finalizer.ehBackToSlider(root.normalPos) }
        }
    }
    }
}
