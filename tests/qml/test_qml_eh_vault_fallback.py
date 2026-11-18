# Schȅi, owner 17/11 (controllo-mainnet M3): when the phone's safe (Android keystore) fails, a new
# wallet must NEVER be locked with PIN+"00" in silence (a copied wallet file would open in seconds).
# PIN+"00" stays only for the old wallets that already use it.
import os
import re
from unittest import TestCase

from electrum.gui.qml import qeapp, qedaemon

COMP = os.path.join(os.path.dirname(qeapp.__file__), 'components')


def _body(src, start, end):
    return src[src.index(start):src.index(end, src.index(start))]


class TestVaultFailureNeverFallsBack(TestCase):

    def setUp(self):
        self.w = open(os.path.join(COMP, 'wizard', 'WCEasyPin.qml'), encoding='utf-8').read()
        self.body = _body(self.w, 'function finishWith(pin)', 'function onPin(pin)')

    def test_pin00_only_for_old_wallets(self):
        self.assertIn("var legacy = phase === 'existing' && !Daemon.ehVaultReady() && !Daemon.ehVaultBroken()",
                      self.body)
        uses = [m.start() for m in re.finditer(r"password = pin \+ '00'", self.body)]
        self.assertEqual(1, len(uses))
        self.assertIn('} else if (legacy) {', self.body[uses[0] - 40:uses[0]])

    def test_vault_failure_stops_with_a_message(self):
        tail = self.body[self.body.index('} else {', self.body.index('else if (legacy)')):]
        self.assertIn("password = ''", tail)
        self.assertIn("qsTr('The phone could not lock the wallet safely.", tail)
        self.assertIn('return', tail[:tail.index('chosenPin = pin')])
        # the wizard can not go on without a password
        self.assertIn("valid: password !== ''", self.w)

    def test_no_next_page_before_the_check(self):
        self.assertLess(self.body.index('} else if (legacy) {'), self.body.index('wizard.pages.next()'))

    def test_daemon_returns_empty_when_the_safe_fails(self):
        src = open(qedaemon.__file__, encoding='utf-8').read()
        body = _body(src, 'def ehVaultSecretOrCreate', '@pyqtSlot')
        self.assertIn("return ''", body)
