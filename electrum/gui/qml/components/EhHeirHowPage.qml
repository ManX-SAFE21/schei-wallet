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
        font.pixelSize: app.ehFsText
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
                Para { text: qsTr('Schȅi prepares a <b>sealed envelope</b> with your bitcoin for the people you chose. Several keepers (Will Executor) each hold a copy: computers that are always on and send it only on the delivery date. Before that date nobody can send it: even if someone tried, the Bitcoin nodes would refuse it.') }
                EhDotLine { Layout.fillWidth: true }
                Para { text: qsTr('You choose how long from now to deliver the inheritance: 1, 2, 3 or 5 years (we suggest 2). When the delivery gets close, every time you open Schȅi it asks you: <b>"Are you still here?"</b> An example: if you chose 2 years, the question starts when 1 year is left. If you say yes, the time starts again from the beginning: 2 more whole years from that day. If you choose "Later", it asks you again the next time you open Schȅi: no alerts arrive on the phone, so open it now and then. The renewal costs a small network fee and joins all the coins into one. In Settings › "When to remind you" you can make the question start later: when a third or a quarter of the period is left.') }
                EhDotLine { Layout.fillWidth: true }
                Para { text: qsTr('<b>Your money stays yours</b>: you receive and pay as always. If new money arrives or you make a payment, Schȅi asks you to update the envelope. The PIN is enough and you pay nothing.') }
                EhDotLine { Layout.fillWidth: true }
                Para { text: qsTr('If you no longer answer, on the delivery date you chose the keepers send the envelope and the heirs receive the bitcoin. Only then is one keeper paid, with a small part of the envelope. Schȅi is made for <b>pocket amounts</b>: for big sums use Àncòra (the plugin for the Electrum wallet) on the computer.') }
            }
        }
    }
}
