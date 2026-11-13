// Easy Heirs (schèi): "Il tuo portafoglio è pronto" — shown once, after a new
// wallet is created, with the "few schei, it is not a safe" notice.
// "Bottega" (WP6): parchment page, green "done" box, warning box, wine leather button; it scrolls.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

ElDialog {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    allowClose: false
    closePolicy: Popup.NoAutoClose

    background: Rectangle { color: S.parch }

    Flickable {
        id: ehFlick
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight   // nothing under the Android keys
        contentHeight: ehCol.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
    ColumnLayout {
        id: ehCol
        x: 22
        width: ehFlick.width - 44
        height: Math.max(implicitHeight, ehFlick.height)
        spacing: 12

        EhPageTop {
            title: qsTr('Your wallet is ready')
        }

        EhInfoBox {
            kind: 'tip'
            icon: 'eh_check.svg'
            text: qsTr('Done! Now you can receive and send bitcoin.')
            fontSize: 18
        }

        EhInfoBox {
            kind: 'warn'
            icon: 'eh_wallet.svg'
            text: '<b>' + qsTr('Schèi is like the wallet in your pocket:') + '</b> '
                + qsTr('keep only a few schei in it, the ones for spending. It is not a safe: for big savings use a safer system.')
            fontSize: 17
        }

        Item { Layout.fillHeight: true; Layout.minimumHeight: 8 }

        EhStitchButton {
            Layout.bottomMargin: 22
            kind: 'wine'
            text: qsTr('Open the wallet')
            endIcon: 'next'
            onClicked: root.doAccept()
        }
    }
    }
}
