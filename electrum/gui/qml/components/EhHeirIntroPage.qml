// Easy Heirs (schȅi): "Eredità" (inheritance, screen 1). Opened from Settings › Inheritance
// while there is no inheritance yet (app.ehHeirOpen). Four numbered steps, the "pocket amounts"
// note, then "Make the inheritance" (the wizard, WP-B) and "How it works, calmly".
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

    Rectangle { anchors.fill: parent; color: S.parch }

    // a numbered step: wine ring with the digit, the sentence
    component Step: Item {
        id: stp
        property int n
        property string text
        property bool last: false
        Layout.fillWidth: true
        implicitHeight: Math.max(64, stl.implicitHeight + 16)
        Layout.preferredHeight: implicitHeight
        RowLayout {
            id: stl
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                radius: 20
                color: 'transparent'
                border.width: 2.5
                border.color: S.wine
                Label {
                    anchors.centerIn: parent
                    text: '' + stp.n
                    color: S.wine
                    font.family: SerifFont ? SerifFont : font.family
                    font.weight: Font.ExtraBold
                    font.pixelSize: app.ehFsStrong
                }
            }
            Label {
                Layout.fillWidth: true
                text: stp.text
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                color: S.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                lineHeight: 1.1
            }
        }
        EhDotLine {
            visible: !stp.last
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.height + 12
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 2 * S.margin
            x: S.margin
            // the buttons sit at the foot when there is room (as in the preview)
            height: Math.max(implicitHeight, flick.height - 12)
            spacing: S.gap

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            EhBackLink { onClicked: app.stack.pop() }
            EhTitle { text: qsTr('Inheritance'); icon: 'eh_will.svg' }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: -4
                text: qsTr('If one day you are no longer here, your bitcoin go <b>by themselves</b> to the people you choose.')
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                color: S.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                lineHeight: 1.1
            }

            EhCaption { text: qsTr('How it works'); Layout.topMargin: 2; Layout.bottomMargin: -6 }
            EhSheet {
                Step { n: 1; text: qsTr('Choose <b>who</b> receives and how much.') }
                Step { n: 2; text: qsTr('Choose <b>how long from now</b>: for example 2 years.') }
                Step { n: 3; text: qsTr('When the delivery gets close, Schȅi asks you: <b>"Are you still here?"</b> You say yes, and the time starts again from the beginning.') }
                Step { n: 4; last: true; text: qsTr('If you no longer answer, on the delivery date the heirs receive.') }
            }
            EhInfoBox {
                kind: 'tip'
                text: qsTr('Made for pocket amounts, up to about <b>%1</b>. For big sums use Àncòra on the computer.').arg(app.ehHeirPocketLimit())
            }

            Item { Layout.fillHeight: true; Layout.minimumHeight: 4 }

            EhStitchButton {
                kind: 'wine'
                icon: 'eh_will_white.svg'
                endIcon: 'next'
                text: qsTr('Make the inheritance')
                onClicked: app.stack.push(Qt.resolvedUrl('EhHeirWhoPage.qml'))
            }
            EhStitchButton {
                kind: 'paper'
                icon: 'eh_info.svg'
                text: qsTr('How it works, calmly')
                onClicked: app.stack.push(Qt.resolvedUrl('EhHeirHowPage.qml'))
            }
        }
    }
}
