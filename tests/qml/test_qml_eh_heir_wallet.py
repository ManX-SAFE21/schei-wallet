# Schȅi, owner 17/11 (controllo-mainnet M1): right after switching wallet the bridge still holds the
# inheritance state of the previous wallet. Every inheritance page must use the state ONLY when it
# belongs to the wallet open (state['wallet']), never the raw bal.state.
import glob
import os
import re
from unittest import TestCase

from electrum.gui.qml import qeapp

COMP = os.path.join(os.path.dirname(qeapp.__file__), 'components')


def _read(*p):
    return open(os.path.join(COMP, *p), encoding='utf-8').read()


def _body(src, start, end):
    return src[src.index(start):src.index(end, src.index(start))]


class TestHeirStateOnlyOfTheWalletOpen(TestCase):

    def test_state_helper_checks_the_wallet(self):
        body = _body(_read('main.qml'), 'function ehHeirState(b)', '\n    }\n')
        self.assertIn('b.state.wallet === Daemon.currentWallet.name ? b.state : ({})', body)
        self.assertIn('!Daemon.currentWallet) return ({})', body)

    def test_no_heir_page_reads_the_raw_state(self):
        pages = sorted(glob.glob(os.path.join(COMP, 'EhHeir*.qml')))
        self.assertGreaterEqual(len(pages), 10)
        for p in pages:
            s = open(p, encoding='utf-8').read()
            self.assertIsNone(re.search(r'\bbal\.state\b', s), os.path.basename(p))
            if 'property var st:' in s:
                self.assertIn('readonly property var st: app.ehHeirState(bal)', s, os.path.basename(p))

    def test_main_reads_raw_state_only_where_the_wallet_is_checked(self):
        m = _read('main.qml')
        lines = [ln for ln in m.split('\n') if re.search(r'\bb\.state\b', ln)]
        allowed = ('function ehHeirState', 'if (!b || !b.state || !Daemon.currentWallet)',
                   'return b.state.wallet === Daemon.currentWallet.name', 'var s = b.state')
        for ln in lines:
            self.assertTrue(any(a in ln for a in allowed), ln)
        # ehHeirDecide is the one raw reader: it must compare s.wallet with the wallet open
        body = _body(m, 'function ehHeirDecide', '\n    }\n')
        self.assertIn('var s = b.state', body)
        self.assertRegex(body, r's\.wallet\s*!==?\s*Daemon\.currentWallet\.name|s\.wallet\s*===?\s*Daemon\.currentWallet\.name')

    def test_open_page_uses_the_checked_state(self):
        self.assertIn("var ph = ehHeirState(b).phase || 'none'", _read('main.qml'))

    def test_delete_heirs_later_only_on_the_same_wallet(self):
        m = _read('main.qml')
        self.assertIn("_ehHeirDropWallet = Daemon.currentWallet ? Daemon.currentWallet.name : ''", m)
        body = _body(m, 'function _ehHeirDropNext', '\n    }\n')
        self.assertIn('Daemon.currentWallet.name !== _ehHeirDropWallet) return', body)
        self.assertIn('var s = ehHeirState(b)', body)

    def test_settings_check_the_wallet(self):
        self.assertIn('bal.state.wallet === Daemon.currentWallet.name ? bal.state : ({})', _read('EhSettings.qml'))


class TestHeirsChangedOutside(TestCase):
    # M2: the update sheet never says "You made a payment" when the people were changed

    def test_update_sheet_has_its_own_changed_text(self):
        u = _read('EhHeirUpdateSheet.qml')
        i = u.index("root.reason === 'changed'")
        self.assertLess(i, u.index("qsTr('You made a payment."))
        # owner 18/11: the text says what can have changed (the heirs or a keeper)
        # owner 22/11: the sentence and the question are two labels (the question bigger)
        self.assertIn("qsTr('The inheritance must be put in order: for example the heirs changed, or a keeper no longer has the envelope.')", u)
        self.assertIn("qsTr('Do I fix it now?')", u)

    def test_percent_error_is_a_clear_sentence(self):
        body = _body(_read('main.qml'), 'function ehHeirErrorText', '\n    }\n')
        self.assertIn("if (code === 'percent') return qsTr(", body)
