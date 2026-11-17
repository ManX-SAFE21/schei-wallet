# Schȅi, owner 17/11: SEED of 24 words (and 15/18/21), words of another wallet (BIP39).
# - restore page: "12 words / 24 words" first, the words are judged only when all are written
# - "Looking for your money" instead of Electrum's technical page (same search as Electrum's
#   "Detect Existing Accounts", automatic; on testnet with the testnet paths)
# - "Forgot the PIN?" works also for wallets made from the words of another wallet
# - QWERTY keyboard; the words always top to bottom, left column first
import asyncio
import os
import types
from unittest import TestCase, mock

from electrum import bitcoin, constants, keystore
from electrum.bip32 import BIP32Node
from electrum.bip39_recovery import scan_for_active_accounts
from electrum.gui.qml import qeapp, qeehfindfunds as ff
from electrum.gui.qml.qewallet import eh_bip39_words_match

COMP = os.path.join(os.path.dirname(qeapp.__file__), 'components')
# BIP39 test vectors (public, no value)
WORDS12 = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
WORDS24 = ('abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon '
           'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art')


def _read(*parts):
    return open(os.path.join(COMP, *parts), encoding='utf-8').read()


class TestFormats(TestCase):

    def test_mainnet_is_electrum_list(self):
        self.assertEqual(list(constants.BIP39_WALLET_FORMATS), ff.eh_wallet_formats(testnet=False))

    def test_testnet_standard_paths_use_coin_1(self):
        with mock.patch.object(constants, 'net', constants.BitcoinTestnet4):
            fs = ff.eh_wallet_formats(testnet=True)
        paths = {(f['derivation_path'], f['script_type']) for f in fs}
        self.assertIn(("m/84'/1'/0'", 'p2wpkh'), paths)
        self.assertIn(("m/49'/1'/0'", 'p2wpkh-p2sh'), paths)
        self.assertIn(("m/44'/1'/0'", 'p2pkh'), paths)
        self.assertIn(("m/0'", 'p2wpkh'), paths)          # non-standard: unchanged
        self.assertNotIn(("m/84'/0'/0'", 'p2wpkh'), paths)
        self.assertEqual(len(constants.BIP39_WALLET_FORMATS), len(fs))
        # Electrum's own list is not changed
        self.assertTrue(any(f['derivation_path'] == "m/84'/0'/0'" for f in constants.BIP39_WALLET_FORMATS))


class TestPick(TestCase):

    def test_nothing_found_modern_first_account(self):
        p = ff.eh_pick([], testnet=False)
        self.assertFalse(p['mustChoose'])
        self.assertFalse(p['found'])
        self.assertEqual(("m/84'/0'/0'", 'p2wpkh', 'modern'),
                         (p['choice']['derivation_path'], p['choice']['script_type'], p['choice']['kind']))

    def test_nothing_found_on_testnet(self):
        with mock.patch.object(constants, 'net', constants.BitcoinTestnet4):
            p = ff.eh_pick([], testnet=True)
        self.assertEqual("m/84'/1'/0'", p['choice']['derivation_path'])

    def test_one_found_is_used(self):
        a = ff.eh_describe({'description': 'x', 'derivation_path': "m/49'/0'/0'", 'script_type': 'p2wpkh-p2sh'}, testnet=False)
        p = ff.eh_pick([a], testnet=False)
        self.assertFalse(p['mustChoose'])
        self.assertTrue(p['found'])
        self.assertEqual(a, p['choice'])

    def test_more_found_the_person_chooses(self):
        a = ff.eh_describe({'description': 'x', 'derivation_path': "m/84'/0'/0'", 'script_type': 'p2wpkh'}, testnet=False)
        b = ff.eh_describe({'description': 'y', 'derivation_path': "m/44'/0'/0'", 'script_type': 'p2pkh'}, testnet=False)
        p = ff.eh_pick([a, b], testnet=False)
        self.assertTrue(p['mustChoose'])
        self.assertIsNone(p['choice'])

    def test_samourai_special_accounts_are_special_paths(self):
        d = ff.eh_describe({'description': '', 'derivation_path': "m/84h/1h/2147483647h", 'script_type': 'p2wpkh'},
                           testnet=True)
        self.assertEqual((False, 0), (d['standard'], d['account']))
        self.assertEqual("m/84'/1'/2147483647'", d['derivation_path'])

    def test_sort_normal_kinds_first(self):
        raw = [("m/84'/0'/2147483647'", 'p2wpkh'), ("m/44'/0'/0'", 'p2pkh'), ("m/0'", 'p2wpkh'),
               ("m/84'/0'/1'", 'p2wpkh'), ("m/49'/0'/0'", 'p2wpkh-p2sh'), ("m/84'/0'/0'", 'p2wpkh')]
        got = ff.eh_sort([ff.eh_describe({'description': '', 'derivation_path': p, 'script_type': t}, testnet=False)
                          for p, t in raw])
        self.assertEqual(["m/84'/0'/0'", "m/84'/0'/1'", "m/49'/0'/0'", "m/44'/0'/0'"],
                         [a['derivation_path'] for a in got[:4]])
        self.assertTrue(all(not a['standard'] for a in got[4:]))

    def test_describe(self):
        d = ff.eh_describe({'description': '', 'derivation_path': "m/84'/0'/2'", 'script_type': 'p2wpkh'}, testnet=False)
        self.assertEqual(('modern', True, 2), (d['kind'], d['standard'], d['account']))
        d = ff.eh_describe({'description': '', 'derivation_path': "m/0'", 'script_type': 'p2wpkh-p2sh'}, testnet=False)
        self.assertEqual(('compat', False, 0), (d['kind'], d['standard'], d['account']))
        d = ff.eh_describe({'description': '', 'derivation_path': "m/44'/0'/0'", 'script_type': 'p2pkh'}, testnet=False)
        self.assertEqual(('old', True, 0), (d['kind'], d['standard'], d['account']))


class _FakeNetwork:
    """a server that knows the history of some scripthashes only"""

    def __init__(self, used):
        self.used = set(used)
        self.asked = 0

    async def get_history_for_scripthash(self, sh):
        self.asked += 1
        return [{'tx_hash': '00' * 32, 'height': 1}] if sh in self.used else []


def _scripthash(words, path, script_type):
    root = BIP32Node.from_rootseed(keystore.bip39_to_seed(words, passphrase=''), xtype='standard')
    node = root.subkey_at_private_derivation(path)
    addr = bitcoin.pubkey_to_address(script_type, node.eckey.get_public_key_hex())
    return bitcoin.script_to_scripthash(bitcoin.address_to_script(addr))


def _scan(words, net, testnet):
    root = BIP32Node.from_rootseed(keystore.bip39_to_seed(words, passphrase=''), xtype='standard')

    def xpub(path):
        return root.subkey_at_private_derivation(path).to_xpub()

    async def go():
        res = await asyncio.gather(*[scan_for_active_accounts(net, xpub, f)
                                     for f in ff.eh_wallet_formats(testnet=testnet)])
        return [ff.eh_describe(a, testnet=testnet) for r in res for a in r]
    return asyncio.run(go())


class TestSearch(TestCase):

    def test_finds_testnet_modern_money_of_24_words(self):
        with mock.patch.object(constants, 'net', constants.BitcoinTestnet4):
            used = {_scripthash(WORDS24, "m/84'/1'/0'/0/3", 'p2wpkh')}
            net = _FakeNetwork(used)
            found = _scan(WORDS24, net, True)
            p = ff.eh_pick(found, testnet=True)
        self.assertEqual(1, len(found))
        self.assertEqual(("m/84'/1'/0'", 'p2wpkh', 'modern'),
                         (found[0]['derivation_path'], found[0]['script_type'], found[0]['kind']))
        self.assertFalse(p['mustChoose'])
        self.assertTrue(net.asked > 0)

    def test_electrum_list_alone_would_miss_testnet_money(self):
        # why the testnet paths are needed: Electrum's list has only coin 0'
        with mock.patch.object(constants, 'net', constants.BitcoinTestnet4):
            used = {_scripthash(WORDS24, "m/84'/1'/0'/0/0", 'p2wpkh')}
            found = _scan(WORDS24, _FakeNetwork(used), False)
        self.assertEqual([], found)

    def test_money_in_two_kinds_asks_to_choose(self):
        used = {_scripthash(WORDS12, "m/84'/0'/0'/0/0", 'p2wpkh'), _scripthash(WORDS12, "m/49'/0'/0'/1/2", 'p2wpkh-p2sh')}
        found = _scan(WORDS12, _FakeNetwork(used), False)
        self.assertEqual({'modern', 'compat'}, {a['kind'] for a in found})
        self.assertTrue(ff.eh_pick(found, testnet=False)['mustChoose'])

    def test_nothing_used(self):
        found = _scan(WORDS12, _FakeNetwork(set()), False)
        self.assertEqual([], found)


class TestFinderObject(TestCase):

    def test_offline_says_so(self):
        f = ff.QEEhFindFunds()
        with mock.patch.object(ff.Network, 'get_instance', return_value=None):
            f.start(WORDS12)
        self.assertEqual(('failed', 'offline'), (f.state, f.error))
        self.assertEqual('p2wpkh', f.fallback['script_type'])

    def test_rows_and_result(self):
        f = ff.QEEhFindFunds()
        f._pending = {'modern': 1, 'compat': 1, 'old': 1}
        f._state = 'scanning'
        self.assertEqual({'modern': 'scanning', 'compat': 'scanning', 'old': 'scanning'}, f.kinds)
        f._on_format_done('p2wpkh', [{'description': 'x', 'derivation_path': "m/84'/0'/0'", 'script_type': 'p2wpkh'}])
        f._on_format_done('p2wpkh', [{'description': 'x', 'derivation_path': "m/84'/0'/0'", 'script_type': 'p2wpkh'}])
        self.assertEqual(1, len(f.accounts))                 # the same account only once
        self.assertEqual('used', f.kinds['modern'])
        f._on_format_done('p2pkh', [])
        f._on_format_done('p2wpkh-p2sh', [])
        f._on_all_done(None)
        self.assertEqual({'modern': 'used', 'compat': 'none', 'old': 'none'}, f.kinds)
        self.assertFalse(f.pick['mustChoose'])

    def test_timeout_is_a_failure(self):
        f = ff.QEEhFindFunds()
        f._on_all_done(asyncio.TimeoutError())
        self.assertEqual(('failed', 'timeout'), (f.state, f.error))


class TestForgotPinOtherWallet(TestCase):

    def _ks(self, words, path="m/84'/0'/0'", xtype='p2wpkh'):
        return keystore.from_bip43_rootseed(keystore.bip39_to_seed(words, passphrase=''), derivation=path, xtype=xtype)

    def test_right_words_match(self):
        ks = self._ks(WORDS24)
        self.assertTrue(eh_bip39_words_match(ks, WORDS24))
        self.assertTrue(eh_bip39_words_match(ks, '  ' + WORDS24.upper().replace(' ', '  ') + ' '))

    def test_other_words_do_not_match(self):
        ks = self._ks(WORDS24)
        self.assertFalse(eh_bip39_words_match(ks, WORDS12))
        self.assertFalse(eh_bip39_words_match(ks, 'abandon ' * 23 + 'abandon'))   # wrong checksum
        self.assertFalse(eh_bip39_words_match(ks, ''))
        self.assertFalse(eh_bip39_words_match(None, WORDS24))

    def test_kind_and_path_are_those_of_the_wallet(self):
        ks = self._ks(WORDS12, "m/49'/0'/0'", 'p2wpkh-p2sh')
        self.assertTrue(eh_bip39_words_match(ks, WORDS12))
        self.assertFalse(eh_bip39_words_match(self._ks(WORDS12, "m/84'/0'/1'"), WORDS24))

    def test_seed_page_opens_also_without_kept_words(self):
        # Samsung 17/11: after the PIN the page did not open for a wallet from another wallet's words
        from electrum.gui.qml.qewallet import QEWallet

        class _W:
            def get_seed(self, pw):
                raise Exception('no seed')

            def has_seed(self):
                return False

        me = types.SimpleNamespace(wallet=_W(), password='x', seedRetrieved=mock.Mock(), dataChanged=mock.Mock())
        QEWallet.retrieve_seed.__wrapped__(me)   # without the PIN request
        me.seedRetrieved.emit.assert_called_once()
        self.assertEqual('', me._seed)
        # a wallet WITH words that cannot be read (e.g. wrong password): nothing opens
        me = types.SimpleNamespace(wallet=_W(), password='x', seedRetrieved=mock.Mock(), dataChanged=mock.Mock())
        me.wallet.has_seed = lambda: True
        QEWallet.retrieve_seed.__wrapped__(me)   # without the PIN request
        me.seedRetrieved.emit.assert_not_called()

    def test_forgot_pin_link_also_for_words_of_another_wallet(self):
        # Samsung 17/11: the link "I forgot the PIN" was shown only for wallets that keep the words
        from electrum.gui.qml.qewallet import QEWallet
        fget = QEWallet.ehCanCheckWords.fget
        ks = self._ks(WORDS24)
        me = types.SimpleNamespace(wallet=types.SimpleNamespace(has_seed=lambda: False, keystore=ks))
        self.assertTrue(fget(me))
        me = types.SimpleNamespace(wallet=types.SimpleNamespace(has_seed=lambda: True, keystore=None))
        self.assertTrue(fget(me))
        watch = keystore.from_master_key(ks.xpub)        # only to look at: no words to check
        me = types.SimpleNamespace(wallet=types.SimpleNamespace(has_seed=lambda: False, keystore=watch))
        self.assertFalse(fget(me))
        pin = _read('EhPinDialog.qml')
        self.assertIn('Daemon.currentWallet.ehCanCheckWords && !Daemon.currentWallet.isWatchOnly', pin)

    def test_wallet_uses_it_when_no_seed_is_kept(self):
        src = open(os.path.join(os.path.dirname(qeapp.__file__), 'qewallet.py'), encoding='utf-8').read()
        body = src[src.index('def ehSeedMatches'):src.index('def importAddresses')]
        self.assertIn("return eh_bip39_words_match(getattr(self.wallet, 'keystore', None), words)", body)


class TestPages(TestCase):

    def test_restore_page_waits_for_all_words(self):
        s = _read('wizard', 'WCEasyHaveSeed.qml')
        self.assertIn('property int wantWords: 12', s)
        self.assertIn('ok = ok && n === wantWords', s)
        self.assertIn('if (doneWords >= wantWords && !typing)', s)
        self.assertIn("qsTr('Next (%1 of %2)')", s)
        self.assertNotIn('doneWords >= 12', s)     # no red box after the 12th word of 24
        self.assertIn("[qsTr('12 words'), qsTr('24 words')]", s)

    def test_next_asks_again_whether_more_pages_follow(self):
        # Samsung 17/11: a PIN already set, Electrum words chosen first, then "another wallet":
        # the words page stayed "last" and the wallet was created without the search page
        # (KeyError 'derivation_path'). "Next" must ask again.
        for name in ('WCEasyHaveSeed.qml', 'WCEasyFindFunds.qml'):
            s = _read('wizard', name)
            body = s[s.index('function goOn()'):]
            body = body[:body.index('wizard.pages.finish()')]
            self.assertIn('checkIsLast()', body, name)

    def test_welcome_does_not_say_12_words(self):
        self.assertIn("qsTr('I already have the words (SEED)')", _read('wizard', 'WCEasyWelcome.qml'))

    def test_wizard_uses_the_search_page(self):
        src = open(os.path.join(os.path.dirname(qeapp.__file__), 'qewizard.py'), encoding='utf-8').read()
        self.assertIn("'script_and_derivation': {'gui': 'WCEasyFindFunds'}", src)
        app = open(qeapp.__file__, encoding='utf-8').read()
        self.assertIn("qmlRegisterType(QEEhFindFunds, 'org.electrum', 1, 0, 'EhFindFunds')", app)

    def test_qwerty_keyboard_in_both_places(self):
        kb = _read('controls', 'EhLetterKeyboard.qml')
        self.assertIn("['qwertyuiop', 'asdfghjkl', 'zxcvbnm']", kb)
        for parts in (('wizard', 'WCEasyHaveSeed.qml'), ('EhForgotPinDialog.qml',)):
            s = _read(*parts)
            self.assertIn('EhLetterKeyboard {', s)
            self.assertNotIn('abcdefg', s)

    def test_words_top_to_bottom_left_column_first(self):
        s = _read('EhSeedPage.qml')
        self.assertIn('columns: 2; rows: Math.max(1, Math.ceil(page.words.length / 2)); flow: GridLayout.TopToBottom', s)
        c = _read('wizard', 'WCEasyCreateSeed.qml')
        self.assertIn('flow: GridLayout.TopToBottom', c)

    def test_choice_takes_the_tap_for_itself(self):
        # 17/11 on the PC: with a TapHandler the tap on an option reached also the page background
        # and the app stopped; a MouseArea keeps it
        s = _read('wizard', 'WCEasyFindFunds.qml')
        i = s.index('model: root.mustChoose ? finder.accounts : []')
        block = s[i:s.index('// ---- no internet', i)]
        self.assertIn('MouseArea { anchors.fill: parent; onClicked: { root.chosenIndex = opt.index; root.chosen = opt.modelData } }', block)
        self.assertNotIn('TapHandler {', block)
        self.assertIn('if (!chosen)', s)   # the wizard calls apply() also while searching

    def test_seed_page_explains_words_not_kept(self):
        s = _read('EhSeedPage.qml')
        self.assertIn('visible: page.words.length === 0', s)
        self.assertIn('does not keep them', s)
