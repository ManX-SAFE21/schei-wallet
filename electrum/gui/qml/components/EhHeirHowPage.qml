// Easy Heirs (schȅi): "Come funziona, con calma" (inheritance, from the Intro page): four short
// paragraphs on one paper sheet (the sealed envelope and its keepers, the period and the
// renewal, the money that stays yours, what happens on the date).
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

    Rectangle { anchors.fill: parent; color: S.parch }

    component Para: Label {
        Layout.fillWidth: true
        textFormat: Text.StyledText
        wrapMode: Text.WordWrap
        color: S.ink
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 16
        lineHeight: 1.15
    }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: col.implicitHeight + 24
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 2 * S.margin
            x: S.margin
            spacing: S.gap

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            EhBackLink { onClicked: app.stack.pop() }
            EhTitle { text: qsTr('How it works, calmly'); icon: 'eh_will.svg' }

            EhSheet {
                topPadding: 14
                bottomPadding: 14
                spacing: 12
                Para { text: qsTr('Schȅi prepares a sealed envelope with your bitcoin for the people you chose. Two keepers (Will Executor) hold it: computers that are always on and send it only on the delivery date. Before that date nobody can send it.') }
                EhDotLine { Layout.fillWidth: true }
                Para { text: qsTr('You choose in how long: 1, 2, 3 or 5 years. From half the period, every time you open Schȅi it asks you: <b>"Are you still here?"</b> If you say yes, the inheritance starts again from today. The renewal costs a small network fee and joins all the coins into one.') }
                EhDotLine { Layout.fillWidth: true }
                Para { text: qsTr('Your money stays yours: you receive and pay as always. If new money arrives or you make a payment, Schȅi asks you to update the envelope: the PIN is enough and it costs nothing.') }
                EhDotLine { Layout.fillWidth: true }
                Para { text: qsTr('If you no longer answer, on the date the keepers send the envelope and the heirs receive the bitcoin. Only then is a keeper paid, from the envelope. It is made for pocket amounts: for big sums use Àncòra on the computer.') }
            }
        }
    }
}
