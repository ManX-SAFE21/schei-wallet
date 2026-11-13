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
import "controls/EhStyle.js" as S

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

    background: Rectangle { color: S.parch }

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

    // a text link of this page ("I forgot the PIN", "Cancel"): 17 bold wine, 2 px underline,
    // 48 px high to touch
    component PinLink: Item {
        id: lk
        property alias text: lkLabel.text
        signal clicked
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        Label {
            id: lkLabel
            anchors.centerIn: parent
            color: S.wine
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: 17
            font.bold: true
            opacity: lkTap.pressed ? 0.6 : 1
        }
        Rectangle {
            x: lkLabel.x
            y: lkLabel.y + lkLabel.height + 1
            width: lkLabel.width
            height: 2
            color: S.wine
            opacity: lkLabel.opacity
        }
        TapHandler { id: lkTap; onTapped: lk.clicked() }
    }

    // "Bottega": sky, then the B hills band (bell tower, cypresses) with the small bitcoin sun.
    // At least status bar + 100 px high, so the sun and its rays never reach the test band.
    // the page scrolls when the phone is too short for logo + pad + links (never under the keys)
    Flickable {
        id: ehFlick
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: ehCol.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
    ColumnLayout {
        id: ehCol
        width: ehFlick.width
        height: Math.max(implicitHeight, ehFlick.height)
        spacing: 0

    Rectangle {
        id: hills
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(Math.round(root.height * 0.2), app.statusBarHeight + 100)
        color: '#f8eed6'
        EhHills {
            band: true
            fade: false
            rays: true
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 86
            sunSize: 40
            sunTop: 24
            sunRight: 38
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 22
        Layout.rightMargin: 22
        Layout.bottomMargin: 4
        spacing: root.height < 800 ? 4 : 8

        Image {
            // a smaller logo on short phones, so the two links fit above the Android keys
            readonly property real w: root.height < 800 ? 116 : 160
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: w
            Layout.preferredHeight: w * 345 / 756
            source: Qt.resolvedUrl('../../icons/eh_logo_wine.png')
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: SerifFont ? SerifFont : font.family
            font.weight: Font.ExtraBold
            font.pixelSize: 26
            color: S.wine
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
        PinLink {
            visible: root.mode === 'verify' && Daemon.currentWallet !== null
                     && Daemon.currentWallet.hasSeed && !Daemon.currentWallet.isWatchOnly
            text: qsTr('I forgot the PIN')
            // the words page opens ABOVE this pad: with the new PIN chosen, the person comes
            // back here, types the new PIN and goes on with what they were doing
            onClicked: app.ehOpenForgotPin()
        }

        PinLink {
            visible: root.mode === 'verify'
            Layout.topMargin: -6
            text: qsTr('Cancel')
            onClicked: root.doReject()
        }
    }
    }
    }

    Connections {
        target: Daemon
        enabled: root.mode === 'open'
        function onWalletRequiresPassword() { root.wrong() }
        function onWalletLoaded() { root.doAccept() }
    }
}
