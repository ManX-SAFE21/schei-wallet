# Easy Heirs (schȅi), owner 17/11: words made with another wallet (BIP39) can use different kinds
# of addresses. Instead of Electrum's technical page (script type + derivation path) Schȅi does by
# itself what Electrum's "Detect Existing Accounts" button does (bip39_recovery): for every known
# wallet format it asks the server whether the first addresses were ever used.
# Read only: nothing is signed or sent. The words never leave the phone (only addresses are asked).
import asyncio
import copy
from typing import Optional

from PyQt6.QtCore import QObject, pyqtProperty, pyqtSignal, pyqtSlot

from electrum import constants, keystore
from electrum.bip32 import BIP32Node
from electrum.bip39_recovery import scan_for_active_accounts
from electrum.logging import get_logger
from electrum.network import Network
from electrum.util import get_asyncio_loop

# the 3 kinds the person sees; Electrum also has p2wpkh paths of other wallets, same kind
EH_KINDS = {'p2wpkh': 'modern', 'p2wpkh-p2sh': 'compat', 'p2pkh': 'old'}
SCAN_TIMEOUT = 120  # seconds
EH_MAX_ACCOUNT = 1000


def eh_wallet_formats(formats=None, *, testnet: Optional[bool] = None) -> list:
    """Electrum's BIP39 wallet formats; on the test network the standard paths use coin 1'
    (Electrum's list has only mainnet paths, so on testnet it would never find anything)."""
    if formats is None:
        formats = constants.BIP39_WALLET_FORMATS
    if testnet is None:
        testnet = constants.net.TESTNET
    out = copy.deepcopy(list(formats))
    if not testnet:
        return out
    coin = f"{constants.net.BIP44_COIN_TYPE}'"
    for f in out:
        parts = f['derivation_path'].split('/')
        if len(parts) >= 3 and parts[1] in ("44'", "49'", "84'") and parts[2] == "0'":
            parts[2] = coin
            f['derivation_path'] = '/'.join(parts)
    return out


def eh_default_account(*, testnet: Optional[bool] = None) -> dict:
    """What Electrum's page proposes when nothing is found: native segwit, first account."""
    if testnet is None:
        testnet = constants.net.TESTNET
    coin = constants.net.BIP44_COIN_TYPE if testnet else 0
    return {'description': 'Standard BIP84 native segwit', 'derivation_path': f"m/84'/{coin}'/0'",
            'script_type': 'p2wpkh'}


def eh_describe(account: dict, *, testnet: Optional[bool] = None) -> dict:
    """account (from scan_for_active_accounts) + what the person sees: kind, which account,
    standard path or not."""
    if testnet is None:
        testnet = constants.net.TESTNET
    a = dict(account)
    # Electrum writes the found paths as m/84h/0h/0h: same notation everywhere (m/84'/0'/0')
    a['derivation_path'] = a['derivation_path'].replace('h', "'")
    a['kind'] = EH_KINDS.get(a['script_type'], 'other')
    parts = a['derivation_path'].split('/')
    coin = f"{constants.net.BIP44_COIN_TYPE if testnet else 0}'"
    purpose = {'p2pkh': "44'", 'p2wpkh-p2sh': "49'", 'p2wpkh': "84'"}.get(a['script_type'])
    try:
        account = int(parts[-1].rstrip("'h")) if len(parts) == 4 else 0
    except ValueError:
        account = 0
    # normal accounts are small numbers; the special ones of Samourai (2147483644...) are not
    a['standard'] = len(parts) == 4 and parts[1] == purpose and parts[2] == coin and account < EH_MAX_ACCOUNT
    a['account'] = account if a['standard'] else 0
    return a


def eh_sort(accounts: list) -> list:
    """normal kinds first (modern, compatible, old; first account first), special paths after"""
    order = {'modern': 0, 'compat': 1, 'old': 2}
    return sorted(accounts, key=lambda a: (not a['standard'], order.get(a['kind'], 3), a['account'],
                                           a['derivation_path']))


def eh_pick(accounts: list, *, testnet: Optional[bool] = None) -> dict:
    """0 found: the default (modern), chosen by Schȅi; 1 found: that one; more: the person chooses."""
    if not accounts:
        return {'mustChoose': False, 'choice': eh_describe(eh_default_account(testnet=testnet), testnet=testnet),
                'found': False}
    if len(accounts) == 1:
        return {'mustChoose': False, 'choice': accounts[0], 'found': True}
    return {'mustChoose': True, 'choice': None, 'found': True}


class QEEhFindFunds(QObject):
    _logger = get_logger(__name__)

    stateChanged = pyqtSignal()
    resultChanged = pyqtSignal()
    _formatDone = pyqtSignal(str, object)   # from the asyncio thread: script type, accounts found
    _allDone = pyqtSignal(object)           # from the asyncio thread: error or None

    def __init__(self, parent=None):
        super().__init__(parent)
        self._state = 'idle'      # idle, scanning, done, failed
        self._error = ''          # offline, timeout, error
        self._accounts = []
        self._pending = {}        # kind -> formats still being checked
        self._fut = None
        self._root_seed = None
        self._formatDone.connect(self._on_format_done)
        self._allDone.connect(self._on_all_done)

    @pyqtProperty(str, notify=stateChanged)
    def state(self):
        return self._state

    @pyqtProperty(str, notify=stateChanged)
    def error(self):
        return self._error

    @pyqtProperty('QVariantList', notify=resultChanged)
    def accounts(self):
        return list(self._accounts)

    @pyqtProperty('QVariantMap', notify=resultChanged)
    def kinds(self):
        """for the 3 rows: kind -> 'scanning' / 'used' / 'none'"""
        out = {}
        for kind in ('modern', 'compat', 'old'):
            if any(a['kind'] == kind for a in self._accounts):
                out[kind] = 'used'
            elif self._pending.get(kind, 0) > 0 and self._state == 'scanning':
                out[kind] = 'scanning'
            else:
                out[kind] = 'none' if self._state == 'done' else ('scanning' if self._state == 'scanning' else '')
        return out

    @pyqtProperty('QVariantMap', notify=resultChanged)
    def pick(self):
        if self._state != 'done':
            return {}
        return eh_pick(self._accounts)

    @pyqtProperty('QVariantMap', notify=resultChanged)
    def fallback(self):
        """the default (modern) when the search cannot be done"""
        return eh_describe(eh_default_account())

    def _set_state(self, state, error=''):
        self._state = state
        self._error = error
        self.stateChanged.emit()
        self.resultChanged.emit()

    @pyqtSlot(str)
    def start(self, seed: str):
        self.cancel()
        self._accounts = []
        self._root_seed = keystore.bip39_to_seed(seed, passphrase='')  # Schȅi never uses extra words
        network = Network.get_instance()
        if network is None or not network.is_connected():
            self._set_state('failed', 'offline')
            return
        formats = eh_wallet_formats()
        self._pending = {}
        for f in formats:
            kind = EH_KINDS.get(f['script_type'], 'other')
            self._pending[kind] = self._pending.get(kind, 0) + 1
        self._set_state('scanning')

        async def scan_all():
            async def one(fmt):
                found = await scan_for_active_accounts(network, self._account_xpub, fmt)
                self._formatDone.emit(fmt['script_type'], found)
            await asyncio.wait_for(asyncio.gather(*[one(f) for f in formats]), timeout=SCAN_TIMEOUT)

        def done(fut):
            if fut.cancelled():
                return
            exc = fut.exception()
            self._allDone.emit(exc)

        self._fut = asyncio.run_coroutine_threadsafe(scan_all(), get_asyncio_loop())
        self._fut.add_done_callback(done)

    @pyqtSlot()
    def cancel(self):
        if self._fut is not None and not self._fut.done():
            self._fut.cancel()
        self._fut = None

    def _account_xpub(self, account_path):
        root_node = BIP32Node.from_rootseed(self._root_seed, xtype='standard')
        return root_node.subkey_at_private_derivation(account_path).to_xpub()

    def _on_format_done(self, script_type, found):
        kind = EH_KINDS.get(script_type, 'other')
        self._pending[kind] = max(0, self._pending.get(kind, 0) - 1)
        for a in found or []:
            a = eh_describe(a)
            if not any(x['derivation_path'] == a['derivation_path'] and x['script_type'] == a['script_type']
                       for x in self._accounts):
                self._accounts.append(a)
        self._accounts = eh_sort(self._accounts)
        self.resultChanged.emit()

    def _on_all_done(self, exc):
        if exc is None:
            self._set_state('done')
            return
        self._logger.info(f'find funds failed: {exc!r}')
        self._set_state('failed', 'timeout' if isinstance(exc, asyncio.TimeoutError) else 'error')
