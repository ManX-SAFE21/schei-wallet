import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"

// Easy Heirs (schèi): change the 4-digit PIN: old PIN, new PIN, repeat.
ElDialog {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    property string phase: 'old'
    property string first: ''
    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    background: Rectangle { color: '#faf7ef' }

    function bad(msg) { pad.clear(); pad.message = msg; pad.messageBad = true; AppController.haptic() }
    function onPin(p) {
        if (phase === 'old') {
            if (app.ehCheckPin(p)) { pad.clear(); pad.message = ''; phase = 'new' }
            else bad(app.ehPinLockMessage() || qsTr('Wrong PIN, try again.'))
        } else if (phase === 'new') {
            first = p; pad.clear(); pad.message = ''; phase = 'repeat'
        } else {
            if (p !== first) { first = ''; phase = 'new'; bad(qsTr('The two PINs are different. Try again.')); return }
            // with the phone's safe the wallet password does not change: only the PIN
            var ok = true
            if (Daemon.ehVaultReady()) Daemon.ehPinSet(p)
            else ok = Daemon.singlePasswordEnabled ? Daemon.setPassword(p + '00') : Daemon.currentWallet.setPassword(p + '00')
            if (ok) {
                var d = app.messageDialog.createObject(app, { title: qsTr('PIN changed'), text: qsTr('From now on use the new PIN.') })
                d.open()
                root.doAccept()
            } else {
                bad(qsTr('The PIN could not be changed.'))
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 22; anchors.rightMargin: 22
        anchors.bottomMargin: 22 + app.navigationBarHeight
        spacing: 8
        EhPageTop { title: '' }
        Label {
            Layout.topMargin: -14
            text: '‹ ' + qsTr('Cancel')
            color: '#5e1a33'; font.pixelSize: 17; font.bold: true
            TapHandler { margin: 10; onTapped: root.doReject() }
        }
        Label {
            text: root.phase === 'old' ? qsTr('Your current PIN') : (root.phase === 'new' ? qsTr('Choose the new PIN') : qsTr('Repeat the PIN'))
            color: '#3f0f21'; font.family: TitleFont ? TitleFont : font.family; font.weight: Font.Black; font.pixelSize: 28
        }
        EhPinPad {
            id: pad
            Layout.fillWidth: true
            Layout.fillHeight: true
            onCompleted: (p) => root.onPin(p)
            onPinChanged: if (pin.length > 0 && messageBad) { message = ''; messageBad = false }
        }
    }
}
