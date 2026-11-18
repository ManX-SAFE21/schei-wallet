// Easy Heirs (schȅi), owner 17/11: about every 3 months, on opening the app, a wallet with money and
// no inheritance asks once: "If one day you are no longer here...?" (main.qml ehHeirMaybeOffer).
// "Yes, let's make it" opens the inheritance page; "Later" asks again in 3 months.
// It never comes when the inheritance is turned off in Settings › Inheritance.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "controls"
import "controls/EhStyle.js" as S

EhBottomSheet {
    id: root
    onClosed: destroy()

    EhTitle {
        text: qsTr('Inheritance')
        icon: 'eh_will.svg'
        fontSize: app.ehFsBox
        Layout.bottomMargin: 0
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.StyledText
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: app.ehFsStrong
        lineHeight: 1.15
        color: S.ink
        text: qsTr('If one day you are no longer here, do you want your bitcoin to go to the people you choose?')
    }

    EhStitchButton {
        kind: 'olive'
        icon: 'eh_check_white.svg'
        text: qsTr("Yes, let's make it")
        onClicked: {
            root.close()
            app.ehHeirOpen()
        }
    }
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        Label {
            id: later
            anchors.centerIn: parent
            text: qsTr('Later')
            color: S.wine
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: app.ehFsText
            font.bold: true
            opacity: laterTap.pressed ? 0.6 : 1
        }
        Rectangle {
            x: later.x
            y: later.y + later.height + 1
            width: later.width
            height: 2
            color: S.wine
            opacity: later.opacity
        }
        TapHandler { id: laterTap; margin: 8; onTapped: root.close() }
    }
}
