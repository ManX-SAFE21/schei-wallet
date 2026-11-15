// Easy Heirs (schȅi): the "i" next to "To the keepers, only at the delivery" of the Check page
// (owner 15/11, point 4b): each keeper asks its own price, only one is paid (the one that
// sends the envelope), the price is fixed in bitcoin so in euro it can change.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "controls"
import "controls/EhStyle.js" as S

EhBottomSheet {
    id: root
    onClosed: destroy()

    EhTitle {
        text: qsTr('What the keepers take')
        icon: 'eh_shield_olive.svg'
        fontSize: 26
        Layout.bottomMargin: 0
    }
    Repeater {
        model: [qsTr('Each keeper asks its own price. At the delivery only one is paid: the one that sends the envelope.'),
                qsTr('The price is fixed in bitcoin, so in euro it can change.')]
        delegate: Label {
            required property string modelData
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 16
            lineHeight: 1.15
            color: S.ink
            text: modelData
        }
    }
    EhInfoBox {
        kind: 'tip'
        text: qsTr('Today you pay nothing.')
    }
    EhStitchButton {
        kind: 'paper'
        text: qsTr('OK (go ahead)')
        onClicked: root.close()
    }
}
