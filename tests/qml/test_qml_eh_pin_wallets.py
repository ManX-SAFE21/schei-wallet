# Schȅi, owner 17/11 (controllo-mainnet G2): whoever holds the unlocked phone must not be able to add
# a wallet with HIS words and then use "Forgot the PIN?" with them to change the PIN of every wallet.
# Rules fixed here:
# - another wallet WITH words only at level ESPERTO (which asks the PIN to enter), and the PIN again
# - BASE / MEDIO: only wallets to watch can be added
# - the words choices are allowed only for the first wallet, the "key lost" restore and ESPERTO
# - the wizard's default is the safe side (no words choices)
import os
import re
from unittest import TestCase

from electrum.gui.qml import qeapp

COMP = os.path.join(os.path.dirname(qeapp.__file__), 'components')


def _read(*p):
    return open(os.path.join(COMP, *p), encoding='utf-8').read()


def _body(src, start, end):
    return src[src.index(start):src.index(end, src.index(start))]


class TestOtherWalletsWithWords(TestCase):

    def test_wizard_default_has_no_words_choices(self):
        self.assertIn('property bool ehSeedAllowed: false', _read('NewWalletWizard.qml'))

    def test_welcome_shows_words_choices_only_when_allowed(self):
        w = _read('wizard', 'WCEasyWelcome.qml')
        for label in ("qsTr('Create a new wallet')", "qsTr('I already have the words (SEED)')"):
            i = w.index(label)
            block = w[w.rindex('EhStitchButton {', 0, i):i]
            self.assertIn('visible: wizard.ehSeedAllowed === true', block, label)

    def test_add_wallet_words_only_in_esperto_and_with_pin(self):
        m = _read('main.qml')
        body = _body(m, 'function ehAddWallet(full)', 'function ehSetWalletLook')
        self.assertIn("var seed = ehLevel() === 'esperto' || Daemon.availableWallets.rowCount() === 0", body)
        self.assertIn('createObject(app, { ehSeedAllowed: seed })', body)
        self.assertIn("if (seed && Daemon.ehPinIsSet()) ehAskPin(", body)

    def test_esperto_level_asks_the_pin(self):
        # entering ESPERTO is guarded by the PIN (the second lock of the rule above)
        m = _read('main.qml')
        body = _body(m, 'function ehChooseLevel', '\n    function ')
        self.assertIn("ehAskPin(qsTr('Type the PIN to switch to EXPERT.')", body)

    def test_only_trusted_flows_allow_words(self):
        m = _read('main.qml')
        allowed = re.findall(r'newWalletWizard\.createObject\(app, \{ ehSeedAllowed: true \}\)', m)
        self.assertEqual(2, len(allowed))   # first wallet, put back the words after "key lost"
        self.assertEqual(0, len(re.findall(r'newWalletWizard\.createObject\(app\)', m)))


class TestSchéiMessages(TestCase):
    # owner 17/11: the explanation came in Electrum's message box

    def test_schei_messages_in_schei_style(self):
        m = _read('main.qml')
        for text in ("You already have 7 wallets, the maximum.",
                     "Another wallet with the words (SEED) can be added only at the EXPERT level.",
                     "Close and reopen Schȅi to see everything in the new language."):
            self.assertIn("ehTell(qsTr('%s'))" % text, m)
            self.assertNotIn("messageDialog.createObject(app, { text: qsTr('%s')" % text, m)
