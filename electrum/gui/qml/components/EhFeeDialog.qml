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
    readonly property int normalPos: 5          // eta:2, Electrum's default
    readonly property int pos: finalizer ? finalizer.sliderPos : normalPos
    // T44 (owner 12/11): no "within a week" and no "within a day": the slowest is "a few hours"
    readonly property int minPos: 2
    Component.onCompleted: if (finalizer && finalizer.sliderPos < minPos) finalizer.sliderPos = minPos

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
            onMoved: if (root.finalizer) root.finalizer.sliderPos = Math.round(value)
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
            text: qsTr('That is fine')
            onClicked: root.doAccept()
        }
        EhPillButton {
            text: qsTr('Back to normal')
            color: '#ffffff'
            textColor: '#2a2220'
            tileColor: '#efe6d3'
            fontSize: 18
            onClicked: if (root.finalizer) root.finalizer.sliderPos = root.normalPos
            Image { anchors.centerIn: parent; source: Qt.resolvedUrl('../../icons/eh_undo.svg'); sourceSize.width: 26; sourceSize.height: 26 }
        }
    }
    }
}
