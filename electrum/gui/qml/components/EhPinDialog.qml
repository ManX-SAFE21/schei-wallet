// Easy Heirs (schèi): full-screen 4-digit PIN dialog.
// mode 'open'  : unlock the wallet at app start (replaces OpenWalletDialog)
// mode 'verify': confirm an action that needs the password (replaces PasswordDialog)
// Old wallets: the wallet password is the PIN followed by "00"; once opened they
// move to the phone's safe and the PIN becomes the app's own check (app.ehCheckPin).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"

ElDialog {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'

    property string mode: 'open'
    property string name
    property string path
    property bool isStartup: true
    property string prompt: ''

    signal verified
    property int keyMatches: 0     // tries with the right app PIN that still did not open the wallet

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    // third review: opening ANOTHER wallet (carousel) can be cancelled; at start it cannot
    readonly property bool canCancel: mode === 'verify' || Daemon.currentWallet !== null
    allowClose: canCancel
    closePolicy: canCancel ? Popup.CloseOnEscape : Popup.NoAutoClose

    background: Rectangle { color: '#faf7ef' }

    Component.onCompleted: if (mode === 'verify' && app.ehPinLockMessage()) { pad.message = app.ehPinLockMessage(); pad.messageBad = true }

    function onPin(pin) {
        if (mode === 'open') {
            pad.busy = true
            app._ehPendingPin = pin
            Daemon.loadWallet(root.path, pin + '00')
        } else {
            if (app.ehCheckPin(pin)) {
                root.verified()
                root.doAccept()
            } else {
                wrong()
            }
        }
    }

    function wrong() {
        // second review (W2): right PIN, wallet still closed: the problem is the key, not the PIN
        if (root.mode === 'open' && app._ehPendingPin !== '' && Daemon.ehPinIsSet() && Daemon.ehPinCheck(app._ehPendingPin)
                && (Daemon.ehVaultBroken() || ++root.keyMatches >= 3)) {
            app._ehPendingPin = ''
            pad.busy = false
            app.ehShowKeyLost(root.name, root.path)
            return
        }
        app._ehPendingPin = ''
        pad.busy = false
        pad.clear()
        pad.message = (root.mode === 'verify' && app.ehPinLockMessage()) || qsTr('Wrong PIN, try again.')
        pad.messageBad = true
        AppController.haptic()
    }

    EhHills {
        id: hills
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.round(root.height * 0.2)
    }

    ColumnLayout {
        anchors.top: hills.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.bottomMargin: 22 + app.navigationBarHeight
        spacing: 8

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 160
            Layout.preferredHeight: 160 * 345 / 756
            source: Qt.resolvedUrl('../../icons/eh_logo_wine.png')
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 21
            color: '#2a2220'
            text: root.prompt !== '' ? root.prompt : qsTr('Type your PIN')
        }

        EhPinPad {
            id: pad
            Layout.fillWidth: true
            Layout.fillHeight: true
            onCompleted: (pin) => root.onPin(pin)
            onPinChanged: if (pin.length > 0 && messageBad) { message = ''; messageBad = false }
        }

        // third review: a forgotten PIN can be replaced with the 12 words of this wallet
        Label {
            visible: root.mode === 'verify' && Daemon.currentWallet !== null
                     && Daemon.currentWallet.hasSeed && !Daemon.currentWallet.isWatchOnly
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: qsTr('I forgot the PIN')
            color: '#5e1a33'
            font.pixelSize: 16
            font.bold: true
            font.underline: true
            TapHandler {
                margin: 8
                // the words page opens ABOVE this pad: with the new PIN chosen, the person comes
                // back here, types the new PIN and goes on with what they were doing
                onTapped: app.ehOpenForgotPin()
            }
        }

        Label {
            visible: root.mode === 'verify'
            Layout.fillWidth: true
            Layout.topMargin: 6
            horizontalAlignment: Text.AlignHCenter
            text: qsTr('Cancel')
            color: '#5e1a33'
            font.pixelSize: 18
            font.underline: true
            TapHandler { onTapped: root.doReject() }
        }
    }

    Connections {
        target: Daemon
        enabled: root.mode === 'open'
        function onWalletRequiresPassword() { root.wrong() }
        function onWalletLoaded() { root.doAccept() }
    }
}
