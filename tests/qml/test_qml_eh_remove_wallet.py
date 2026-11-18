# Schȅi, owner 17/11: "Togli questo portafoglio" (gear page). Only in ESPERTO, never the main
# wallet, never with an inheritance; a yes / no question, then the PIN. owner 18/11: no balance
# check, always the warning that without the words (SEED) the money is lost.
import os
import types
from unittest import TestCase, mock

from electrum.gui.qml import qeapp
from electrum.gui.qml.qedaemon import QEDaemon
from electrum.gui.qml import qedaemon as qedaemon_mod

COMP = os.path.join(os.path.dirname(qeapp.__file__), 'components')


def _read(*p):
    return open(os.path.join(COMP, *p), encoding='utf-8').read()


class _W:
    def __init__(self, path, money=0, watch=False):
        self.path, self.money, self.watch = path, money, watch
        self.storage = types.SimpleNamespace(get_path=lambda: path)
        self.will = {}
        self.db = types.SimpleNamespace(get=lambda k, d=None: self.will if k == 'will' else d)

    def get_utxos(self):
        return []

    def is_watching_only(self):
        return self.watch

    def get_balance(self):
        return (self.money, 0, 0)


class _Fake:
    """Only what QEDaemon.ehRemoveWallet uses; the real file is never touched."""

    def __init__(self, names, money=None, watch=(), current=None):
        self.availableWallets = types.SimpleNamespace(_wallets=[(n, '/w/' + n) for n in names])
        self.availableWallets.remove_wallet = self._removed
        money = money or {}
        self.wallets = {'/w/' + n: _W('/w/' + n, money.get(n, 0), n in watch) for n in names}
        self.deleted, self.emitted = [], []
        self.daemon = types.SimpleNamespace(get_wallet=lambda p: self.wallets.get(p),
                                            delete_wallet=lambda p: self.deleted.append(p) or True)
        self._current_wallet = types.SimpleNamespace(wallet=self.wallets['/w/' + current]) if current else None
        self.walletLoaded = types.SimpleNamespace(emit=lambda *a: self.emitted.append(a))
        self._logger = types.SimpleNamespace(info=lambda *a: None, error=lambda *a: None)
        for f in ('ehWalletPathFor', 'ehMainWalletName'):
            setattr(self, f, types.MethodType(getattr(QEDaemon, f), self))

    def _removed(self, path):
        self.availableWallets._wallets = [w for w in self.availableWallets._wallets if w[1] != path]

    def remove(self, name):
        return QEDaemon.ehRemoveWallet(self, name)


class TestRemoveInTheDaemon(TestCase):

    def test_added_empty_wallet_is_removed(self):
        f = _Fake(['Portafoglio', 'Portafoglio_2'], current='Portafoglio_2')
        self.assertTrue(f.remove('Portafoglio_2'))
        self.assertEqual(f.deleted, ['/w/Portafoglio_2'])
        self.assertEqual([n for n, _ in f.availableWallets._wallets], ['Portafoglio'])
        self.assertIsNone(f._current_wallet)          # the open one was closed first
        self.assertEqual(f.emitted, [(None, None)])

    def test_never_the_main_one(self):
        f = _Fake(['Portafoglio', 'Portafoglio_2'])
        self.assertFalse(f.remove('Portafoglio'))
        self.assertEqual(f.deleted, [])

    def test_main_is_the_first_when_no_portafoglio(self):
        f = _Fake(['Casa', 'Viaggi'])
        self.assertEqual(f.ehMainWalletName(), 'Casa')
        self.assertFalse(f.remove('Casa'))
        self.assertTrue(f.remove('Viaggi'))

    def test_with_money_it_goes_too(self):
        # owner 18/11: the balance is not checked (it can be wrong before the sync); the app warned
        f = _Fake(['Portafoglio', 'Portafoglio_2'], money={'Portafoglio_2': 1}, current='Portafoglio_2')
        self.assertTrue(f.remove('Portafoglio_2'))
        self.assertEqual(f.deleted, ['/w/Portafoglio_2'])

    def test_watch_wallet_with_money_can_go(self):
        # a wallet to watch has no words: removing it loses nothing
        f = _Fake(['Portafoglio', 'Portafoglio_2'], money={'Portafoglio_2': 5000}, watch=('Portafoglio_2',))
        self.assertTrue(f.remove('Portafoglio_2'))

    def test_unknown_name(self):
        f = _Fake(['Portafoglio', 'Portafoglio_2'])
        self.assertFalse(f.remove('Altro'))


class TestRemoveInThePages(TestCase):

    def test_only_expert_never_main(self):
        m = _read('main.qml')
        self.assertIn("return ehLevel() === 'esperto' && Daemon.currentWallet !== null && Daemon.availableWallets.rowCount() > 1\n"
                      "               && Daemon.currentWallet.name !== Daemon.ehMainWalletName()", m)

    def test_inheritance_blocks_it_money_does_not(self):
        m = _read('main.qml')
        self.assertIn("if (st.phase !== 'none' && st.phase !== 'draft') {", m)
        self.assertIn("if (st.phase === undefined) {", m)
        body = m[m.index('function ehRemoveWallet()'):m.index('function _ehDoRemoveWallet(')]
        self.assertNotIn('ehTotal', body)
        self.assertNotIn('It is empty', body)

    def test_always_the_12_words_warning(self):
        m = _read('main.qml')
        self.assertIn("var detail = qsTr('If you did not save the words (SEED), the money of this wallet is lost. Do you want to remove it?')", m)
        from electrum.eh_strings import STRINGS
        self.assertEqual(STRINGS['it_IT']['If you did not save the words (SEED), the money of this wallet is lost. Do you want to remove it?'],
                         'Se non hai salvato le parole (SEED), i soldi di questo portafoglio sono persi. Vuoi toglierlo?')

    def test_question_then_pin(self):
        m = _read('main.qml')
        self.assertIn("ehAskPin(qsTr('Type the PIN to remove the wallet'), function() { app._ehDoRemoveWallet(name, shown) })", m)
        self.assertIn("qsTr('Yes, remove it'), qsTr('No'))", m)

    def test_main_opens_after(self):
        m = _read('main.qml')
        self.assertIn("var ok = Daemon.ehRemoveWallet(name)", m)
        self.assertIn("Daemon.loadWallet(main)", m)
        v = _read('WalletMainView.qml')
        self.assertIn("if (app._ehRemoving) return", v)

    def test_row_in_settings(self):
        s = _read('EhSettings.qml')
        self.assertIn("readonly property bool canRemove: app.ehCanRemoveWallet()", s)
        self.assertIn("EhRow { visible: walletSheet.canRemove; icon: 'eh_cross.svg'; text: qsTr('Remove this wallet')", s)
        self.assertIn("onClicked: app.ehRemoveWallet() }", s)

    def test_settings_of_the_removed_name_are_cleared(self):
        # Opus review 18/11: a new wallet gets the freed name again (Portafoglio_2): it must not
        # inherit 'inheritance off' of the removed one. '' reads as 'on' in ehHeirEnabled.
        m = _read('main.qml')
        self.assertIn("var keys = ['name_', 'color_', 'watch_', 'bal_', 'heir_on_'", m)
        self.assertIn("return Config.ehGet('heir_on_' + ehWalletKey()) !== false", m)


class TestNeverWithAnInheritance(TestCase):
    """Opus review 18/11: the daemon refuses a wallet with an inheritance in force."""

    def test_live_envelope_blocks_the_daemon(self):
        f = _Fake(['Portafoglio', 'Portafoglio_2'], current='Portafoglio_2')
        with mock.patch.object(qedaemon_mod, '_eh_has_live_will', lambda w: True):
            self.assertFalse(f.remove('Portafoglio_2'))
        self.assertEqual(f.deleted, [])

    def test_live_will_rule(self):
        coin = types.SimpleNamespace(prevout=types.SimpleNamespace(to_str=lambda: 'aa:0'))
        w = _W('/w/x')
        w.get_utxos = lambda: [coin]
        tx = types.SimpleNamespace(inputs=lambda: [coin])
        good = {'tx': 'T', 'VALID': True, 'COMPLETE': True, 'PUSHED': True}
        with mock.patch('electrum.transaction.tx_from_any', lambda t: tx):
            w.will = {'1': dict(good)}
            self.assertTrue(qedaemon_mod._eh_has_live_will(w))
            for k in ('INVALIDATED', 'REPLACED'):
                w.will = {'1': dict(good, **{k: True})}
                self.assertFalse(qedaemon_mod._eh_has_live_will(w), k)
            w.will = {'1': dict(good, PUSHED=False)}
            self.assertFalse(qedaemon_mod._eh_has_live_will(w))
            w.get_utxos = lambda: []          # coins spent: no inheritance in force
            w.will = {'1': dict(good)}
            self.assertFalse(qedaemon_mod._eh_has_live_will(w))
        w.watch = True
        self.assertFalse(qedaemon_mod._eh_has_live_will(w))

    def test_when_in_doubt_it_is_kept(self):
        w = _W('/w/x')

        def boom():
            raise RuntimeError('db')
        w.get_utxos = boom
        self.assertTrue(qedaemon_mod._eh_has_live_will(w))

    def test_the_app_never_removes_while_unchecked(self):
        m = _read('main.qml')
        body = m[m.index('    function ehRemoveWallet() {'):m.index('    function _ehDoRemoveWallet(')]
        self.assertIn("if (!b) {", body)
