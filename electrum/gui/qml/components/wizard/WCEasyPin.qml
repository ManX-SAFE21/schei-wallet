// Easy Heirs (schȅi): step 3, choose a 4-digit PIN (twice). Replaces
// WCWalletPassword. Electrum needs at least 6 characters, so the wallet
// password is the PIN followed by "00" (owner's decision).
// "Bottega" (WP6): parchment page, Fraunces title (EhPageTop), brass PIN pad (WP1).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "../controls"
import "../controls/EhStyle.js" as S

WizardComponent {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'
    valid: password !== ''
    property bool hideWizardButtons: true
    securePage: true    // the PIN is typed here: black on mainnet

    // other wallets exist and Electrum wants one password for all: ask that PIN
    // third review: after "this phone no longer recognises the key" the old PIN protects
    // nothing: a new one is chosen
    property bool enforceExistingPassword: Config.walletShouldUseSinglePassword && Daemon.availableWallets.rowCount() > 0
                                           && !Daemon.ehVaultBroken()
    property string phase: enforceExistingPassword ? 'existing' : 'choose'   // choose | repeat | existing
    property string firstPin: ''
    property string password: ''
    property string chosenPin: ''

    background: Rectangle { color: S.parch }
    topPadding: 0
    leftPadding: 22
    rightPadding: 22
    bottomPadding: 22   // the wizard (ElDialog) already leaves room for the Android keys

    function apply() {
        wizard_data['password'] = password
        wizard_data['encrypt'] = password !== ''
    }

    // Easy Heirs: the wallet is locked with the secret of the phone's safe; the
    // PIN is kept apart as the app's check. Without a safe: PIN + "00" as before.
    function finishWith(pin) {
        var secret = ''
        // PIN+"00" only for the old wallets that already use it (no safe yet): the same
        // password for one more wallet. Everything else uses the phone's safe.
        var legacy = phase === 'existing' && !Daemon.ehVaultReady() && !Daemon.ehVaultBroken()
        // the safe cannot read its secret any more (key lost): a new one replaces it, or the
        // restored wallet would be locked with PIN+"00" and the key-lost page would come back
        if (!legacy)
            secret = Daemon.ehVaultSecretOrCreate()
        if (secret !== '') {
            password = secret
            Daemon.ehPinSet(pin)
        } else if (legacy) {
            password = pin + '00'
        } else {
            // owner 17/11 (controllo-mainnet M3): the phone's safe did not work. Never PIN+"00"
            // in silence (a copied file would open in seconds): stop here and say it
            password = ''
            firstPin = ''
            pad.clear()
            pad.message = qsTr('The phone could not lock the wallet safely. Try again; if it happens again, restart the phone.')
            pad.messageBad = true
            AppController.haptic()
            if (phase === 'repeat') phase = 'choose'
            return
        }
        chosenPin = pin
        if (root.last)
            wizard.pages.finish()
        else
            wizard.pages.next()
    }

    function onPin(pin) {
        if (phase === 'choose') {
            firstPin = pin
            pad.clear()
            pad.message = ''
            phase = 'repeat'
        } else if (phase === 'repeat') {
            if (pin === firstPin) {
                finishWith(pin)
            } else {
                firstPin = ''
                pad.clear()
                pad.message = qsTr('The two PINs are different. Try again.')
                pad.messageBad = true
                AppController.haptic()
                phase = 'choose'
            }
        } else {
            // review 2026-11-11: same check and same 5-tries / 1-hour lockout as everywhere else
            if (Daemon.ehPinIsSet() ? app.ehCheckPin(pin) : Daemon.numWalletsWithPassword(pin + '00') > 0) {
                finishWith(pin)
            } else {
                pad.clear()
                pad.message = app.ehPinLockMessage() || qsTr('Wrong PIN, try again.')
                pad.messageBad = true
                AppController.haptic()
            }
        }
    }

    // owner 12/11: the page scrolls when the phone is short (buttons never under the keys)
    Flickable {
        id: ehFlick
        anchors.fill: parent
        // over the side margins too, so the hills on top are not cut
        anchors.leftMargin: -22
        anchors.rightMargin: -22
        contentHeight: ehCol.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
    ColumnLayout {
        id: ehCol
        x: 22
        width: ehFlick.width - 44
        height: Math.max(implicitHeight, ehFlick.height)
        spacing: 8

        EhPageTop {
            step: qsTr('STEP %1 OF %2').arg(3).arg(3)
            title: root.phase === 'repeat' ? qsTr('Repeat the PIN')
                 : root.phase === 'existing' ? qsTr('Your PIN') : qsTr('Choose a PIN')
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.family: BodyFont ? BodyFont : font.family
            font.pixelSize: app.ehFsStrong
            lineHeight: 1.2
            color: S.ink
            text: root.phase === 'repeat' ? qsTr('Type the same 4 numbers again.')
                : root.phase === 'existing' ? qsTr('Type the PIN you already use for your other wallets.')
                : qsTr('4 numbers that are easy for you to remember. You will need them for big payments and to see the words (SEED).')
        }

        EhPinPad {
            id: pad
            Layout.fillWidth: true
            Layout.fillHeight: true
            onCompleted: (pin) => root.onPin(pin)
            onPinChanged: if (pin.length > 0 && messageBad) { message = ''; messageBad = false }
        }
    }
    }
}
