// Easy Heirs (schèi): step 3, choose a 4-digit PIN (twice). Replaces
// WCWalletPassword. Electrum needs at least 6 characters, so the wallet
// password is the PIN followed by "00" (owner's decision).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "../controls"

WizardComponent {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'
    valid: password !== ''
    property bool hideWizardButtons: true

    // other wallets exist and Electrum wants one password for all: ask that PIN
    // third review: after "this phone no longer recognises the key" the old PIN protects
    // nothing: a new one is chosen
    property bool enforceExistingPassword: Config.walletShouldUseSinglePassword && Daemon.availableWallets.rowCount() > 0
                                           && !Daemon.ehVaultBroken()
    property string phase: enforceExistingPassword ? 'existing' : 'choose'   // choose | repeat | existing
    property string firstPin: ''
    property string password: ''
    property string chosenPin: ''

    background: Rectangle { color: '#faf7ef' }
    topPadding: 0
    leftPadding: 22
    rightPadding: 22
    bottomPadding: 22 + app.navigationBarHeight

    function apply() {
        wizard_data['password'] = password
        wizard_data['encrypt'] = password !== ''
    }

    // Easy Heirs: the wallet is locked with the secret of the phone's safe; the
    // PIN is kept apart as the app's check. Without a safe: PIN + "00" as before.
    function finishWith(pin) {
        chosenPin = pin
        var secret = ''
        // the safe cannot read its secret any more (key lost): a new one replaces it, or the
        // restored wallet would be locked with PIN+"00" and the key-lost page would come back
        if (phase !== 'existing' || Daemon.ehVaultReady() || Daemon.ehVaultBroken())
            secret = Daemon.ehVaultSecretOrCreate()
        if (secret !== '') {
            password = secret
            Daemon.ehPinSet(pin)
        } else {
            password = pin + '00'
        }
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        EhPageTop {
            step: qsTr('STEP %1 OF %2').arg(3).arg(3)
            title: root.phase === 'repeat' ? qsTr('Repeat the PIN')
                 : root.phase === 'existing' ? qsTr('Your PIN') : qsTr('Choose a PIN')
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 20
            lineHeight: 1.2
            color: '#2a2220'
            text: root.phase === 'repeat' ? qsTr('Type the same 4 numbers again.')
                : root.phase === 'existing' ? qsTr('Type the PIN you already use for your other wallets.')
                : qsTr('4 numbers that are easy for you to remember. You will need them for big payments and to see the 12 words.')
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
