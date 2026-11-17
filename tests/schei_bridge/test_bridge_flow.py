# Schȅi: the inheritance bridge (electrum/plugins/bal/qml.py) driven like the phone pages do.
# Moved into the repo 17/11/2026 (it was in tools/ancora-test only): run with
#   QT_QPA_PLATFORM=offscreen python -m pytest tests/schei_bridge
"""Headless flow of the Schȅi inheritance bridge (bal.qml.QEBal), WP-A.

The real bridge, the real plugin and the real Electrum commands on a FUNDED
offline testnet wallet. Faked: the keepers (``Willexecutors.send_request``),
the network (``broadcast_transaction`` puts the transaction in the wallet's
mempool, as a server would) and the clock. Nothing leaves the PC.

Run (WSL):
  cd ~/easy-heirs-wallet/tools/ancora-test
  PYTHONPATH=~/easy-heirs-wallet/wt-ancora:$PWD QT_QPA_PLATFORM=offscreen \
    python -m pytest -q test_bridge_flow.py

Every flow runs twice: a wallet WITHOUT password and one WITH a password
(unlocked as the QML app does at load; the password never goes through the
bridge).
"""
import hashlib
import importlib
import os
import shutil
import sys
import tempfile
import math
import time
from datetime import datetime, timezone
from types import SimpleNamespace

import pytest

# the plugin is imported as `bal`, like Àncòra's own tests (from electrum/plugins)
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'electrum', 'plugins'))

from PyQt6.QtCore import QCoreApplication, QObject  # noqa: E402

from electrum import constants  # noqa: E402
from electrum import util as electrum_util  # noqa: E402
from electrum.bip32 import BIP32Node  # noqa: E402
from electrum.bitcoin import address_to_script  # noqa: E402
from electrum.fee_policy import FixedFeePolicy  # noqa: E402
from electrum.segwit_addr import encode_segwit_address  # noqa: E402
from electrum.simple_config import SimpleConfig  # noqa: E402
from electrum.transaction import PartialTxOutput, Transaction, tx_from_any  # noqa: E402
from electrum.wallet import restore_wallet_from_text  # noqa: E402

import bal  # noqa: E402,F401  (registers the bal_* commands)
from bal import qml as bal_qml  # noqa: E402
from bal.cli.controller import BalController  # noqa: E402
from bal.core import delivery  # noqa: E402
from bal.core.willexecutors import Willexecutors  # noqa: E402

DAY = 86400
PASSWORD = 'test-only-pass'   # a test value, for a throw-away testnet wallet


def addr(n):
    return encode_segwit_address('tb', 0, bytes([n]) * 20)


MARCO, GIULIA, OUTSIDE = addr(10), addr(11), addr(30)
K0, K1 = bal_qml.KEEPERS
#: Keepers of the public list (welist), offered only when a test lists them.
E1, E2, E3 = 'https://we.third.example', 'https://we.fourth.example', 'https://we.fifth.example'
ONION = 'http://keeperxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyz.onion'
ALL_KEEPERS = (K0, K1, E1, E2, E3, ONION)
KEEPER_ADDR = {u: addr(1 + i) for i, u in enumerate(ALL_KEEPERS)}
KEEPER_FEE = 1000


# ------------------------------------------------------------------ world
class Clock:
    def __init__(self):
        self.now = time.time()

    def time(self):
        return float(self.now)

    def travel(self, days):
        self.now += days * DAY


def install_clock(monkeypatch, clock):
    """Every plugin clock read (and the bridge's) reads ``clock``."""
    class ClockDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            moment = datetime.fromtimestamp(clock.now, tz=timezone.utc)
            return moment.replace(tzinfo=None) if tz is None else moment.astimezone(tz)

    for name in ('bal.core.checkalive', 'bal.core.messages', 'bal.core.plugin_base',
                 'bal.core.report', 'bal.core.reminders', 'bal.core.summary',
                 'bal.core.util', 'bal.core.will', 'bal.core.willexecutors'):
        monkeypatch.setattr(importlib.import_module(name), 'datetime', ClockDatetime)
    fake_time = SimpleNamespace(time=clock.time, sleep=time.sleep, monotonic=time.monotonic,
                                strftime=time.strftime)
    for name in ('bal.engine.context', 'bal.engine.build', 'bal.cli.controller', 'bal.qml'):
        mod = importlib.import_module(name)
        if hasattr(mod, 'time'):
            monkeypatch.setattr(mod, 'time', fake_time)


class Keepers:
    """The will-executors (and the welist), answering like the real servers.

    ``listed``: the keepers of the public list (none by default: on testnet4
    the list has only the fixed pair); ``fees``: a fee per keeper (else
    ``KEEPER_FEE``); ``down``: the keepers that do not answer.
    """

    def __init__(self):
        self.held = {u: {} for u in ALL_KEEPERS}
        self.down = set()
        self.listed = []
        self.fees = {}
        self.calls = []

    def fee(self, url):
        return self.fees.get(url, KEEPER_FEE)

    def send_request(self, method, url, data=None, **kw):
        self.calls.append((method, url))
        base = next((u for u in self.held if url.startswith(u)), None)
        if '/data/' in url and 'welist' not in url:
            return {}
        if '/data/' in url:
            return {u: {'url': u, 'address': KEEPER_ADDR[u], 'base_fee': self.fee(u), 'info': ''}
                    for u in (K0, K1) + tuple(self.listed)}
        if base is None or base in self.down:
            raise ConnectionError('keeper down (test)')
        if url.endswith('/info'):
            return {'address': KEEPER_ADDR[base], 'base_fee': self.fee(base), 'info': 'fake keeper'}
        if url.endswith('/pushtxs'):
            for line in data.decode().split('\n'):
                if line.strip():
                    self.held[base][tx_from_any(line.strip()).txid()] = line.strip()
            return 'thx'
        if url.endswith('/searchtx'):
            raw = self.held[base].get(data.decode())
            return {'tx': raw} if raw else {}
        raise AssertionError('unexpected request ' + url)


def to_mempool(wallet, tx):
    """What a server does with a broadcast: the wallet sees it, unconfirmed."""
    raw = str(tx)
    wallet.adb.add_transaction(tx_from_any(raw))
    wallet.adb.add_unverified_or_unconfirmed_tx(tx.txid(), 0)


class FakeNetwork:
    def __init__(self):
        self.wallet = None
        self.broadcasts = []
        self.fee_estimates = SimpleNamespace(eta_target_to_fee=lambda blocks: 2000)   # 2 sat/vB

    def is_connected(self):
        return True

    def blockchain(self):
        return SimpleNamespace(is_tip_stale=lambda: True, height=lambda: 0)

    def get_server_height(self):
        return 0

    def get_local_height(self):
        return 0

    async def broadcast_transaction(self, tx, *, timeout=None):
        self.broadcasts.append(tx.txid())
        to_mempool(self.wallet, tx)


class FakeDaemon:
    def __init__(self, config, plugin, network):
        self.config = config
        self.network = network
        self._plugin = plugin
        self._plugins = self

    def get_plugin(self, name):
        return self._plugin if name == 'bal' else None


class FakeApp(QObject):
    """What ``init_qml`` gets: only ``app.daemon.daemon`` / ``currentWallet`` are read."""


_LOOP = {}


def ensure_loop():
    if not _LOOP:
        try:
            electrum_util.get_asyncio_loop()
            _LOOP['ok'] = True
        except Exception:
            loop, fut, thread = electrum_util.create_and_start_event_loop()
            _LOOP.update(loop=loop, fut=fut, thread=thread, ok=True)


@pytest.fixture(scope='module', autouse=True)
def _stop_loop_at_the_end():
    """The event loop thread is not a daemon: stop it, or pytest never exits."""
    yield
    loop = _LOOP.pop('loop', None)
    if loop is not None:
        loop.call_soon_threadsafe(_LOOP['fut'].set_result, 1)
        _LOOP.pop('thread').join(timeout=10)
    _LOOP.clear()


def funding_tx(address, value, tag):
    spk = address_to_script(address)
    raw = ('02000000' + '01' + tag * 32 + '00000000' + '00' + 'ffffffff'
           + '01' + value.to_bytes(8, 'little').hex()
           + bytes([len(spk)]).hex() + spk.hex() + '00000000')
    return Transaction(raw)


class Session:
    """One wallet, the bridge on it, the fake world around."""

    def __init__(self, monkeypatch, password=None):
        constants.net = constants.BitcoinTestnet
        ensure_loop()
        self.app_qt = QCoreApplication.instance() or QCoreApplication([])
        self.clock = Clock()
        install_clock(monkeypatch, self.clock)
        self.keepers = Keepers()
        monkeypatch.setattr(Willexecutors, 'send_request', staticmethod(self.keepers.send_request))
        self.dir = tempfile.mkdtemp(prefix='qebal_flow_')
        self.config = SimpleConfig({'electrum_path': self.dir, 'testnet': True},
                                   read_user_config_function=lambda path: {})
        self.plugin = bal_qml.Plugin(None, self.config, 'bal')
        seed = hashlib.sha256(b'schei qebal flow test wallet (testnet, no funds)').digest()
        xprv = BIP32Node.from_rootseed(seed, xtype='p2wpkh').to_xprv(net=constants.BitcoinTestnet)
        self.password = password
        self.wallet = restore_wallet_from_text(
            xprv, path=os.path.join(self.dir, 'w'), config=self.config, password=password)['wallet']
        if password:
            self.wallet.unlock(password)   # as QEDaemon does when the wallet is loaded
        self.wallet.is_up_to_date = lambda: True
        self.tags = iter(['ab', 'cd', 'ef', 'a1', 'a2', 'a3', 'a4'])
        self.add_coin(1_000_000)
        self.network = FakeNetwork()
        self.network.wallet = self.wallet
        self.daemon = FakeDaemon(self.config, self.plugin, self.network)
        self.app = FakeApp()
        self.app.daemon = SimpleNamespace(daemon=self.daemon,
                                          currentWallet=SimpleNamespace(wallet=self.wallet))
        self.plugin.init_qml(self.app)
        self.bal = self.plugin.so
        self.events = []
        self.bal.done.connect(lambda op, r: self.events.append(('done', op, dict(r))))
        self.bal.failed.connect(lambda op, c, m: self.events.append(('failed', op, c, m)))

    def close(self):
        self.bal.unregister()
        shutil.rmtree(self.dir, ignore_errors=True)

    def add_coin(self, value):
        address = self.wallet.get_unused_address() or self.wallet.get_receiving_addresses()[-1]
        fund = funding_tx(address, value, next(self.tags))
        self.wallet.adb.add_transaction(fund)
        self.wallet.adb.add_unverified_or_unconfirmed_tx(fund.txid(), 100)
        return fund

    def pay(self, value):
        """A payment of ``value`` sat from the wallet (one coin), to the mempool."""
        coins = sorted(self.wallet.get_utxos(), key=lambda c: c.value_sats())
        tx = self.wallet.make_unsigned_transaction(
            coins=[coins[0]], outputs=[PartialTxOutput.from_address_and_value(OUTSIDE, value)],
            fee_policy=FixedFeePolicy(300))
        self.wallet.sign_transaction(tx, self.password)
        to_mempool(self.wallet, tx)
        return tx

    auto_fee = True

    def call(self, slot, *args, timeout=60):
        """Call a slot, let Qt deliver the worker's answer, return it."""
        if self.auto_fee and slot in ('cancelWill', 'renew', 'confirm'):
            # as the page does: the fee chosen like a payment (here 2 sat/vB, by size)
            self.bal.setInvalidationFee({'sats': 1, 'rate': 2.0, 'coins': []})
        n = len(self.events)
        start = time.monotonic()
        getattr(self.bal, slot)(*args)
        returned = time.monotonic() - start
        while len(self.events) == n:
            QCoreApplication.processEvents()
            time.sleep(0.005)
            if time.monotonic() - start > timeout:
                raise AssertionError('no answer from ' + slot)
        ev = self.events[n]
        ev_op = ev[1]
        assert ev_op == slot, ev
        return ev, returned

    def ok(self, slot, *args):
        ev, _ = self.call(slot, *args)
        assert ev[0] == 'done', ev
        return ev[2]

    @property
    def state(self):
        return self.bal.state

    def controller(self):
        return BalController(self.plugin, self.wallet)


@pytest.fixture(params=[None, PASSWORD], ids=['no-password', 'password'])
def s(request, monkeypatch):
    start_net = constants.net
    session = Session(monkeypatch, password=request.param)
    yield session
    session.close()
    constants.net = start_net


def make_will(s, keepers=2):
    assert s.ok('refresh') == {}
    assert s.state['phase'] == 'none'
    s.ok('heirSave', '', 'Marco', MARCO, 60)
    s.ok('heirSave', '', 'Giulia', GIULIA, 40)
    assert s.state['phase'] == 'draft' and s.state['total'] == 100
    r = s.ok('setPeriod', 24)
    assert r['applied'] is True
    today = delivery.utc_midnight(s.clock.now)
    assert r['delivery'] == delivery.add_months(today, 24)
    assert r['delivery'] - r['warnAt'] == 365 * DAY
    review = s.ok('review')
    assert review['result'] == 'rebuilt'
    assert [h['name'] for h in review['heirs']] == ['Marco', 'Giulia']
    assert review['heirs'][0]['sats'] > review['heirs'][1]['sats'] > 0
    fees = [c['feeSats'] for c in review['custodians']]
    assert review['custodianFeeSats'] == review['custodianFeeMaxSats'] == max(fees)
    assert review['custodianFeeMinSats'] == min(fees)
    assert review['feeWarning'] is False
    assert len(review['custodians']) == keepers
    assert review['custodiansWanted'] == 3
    assert s.state['phase'] == 'unfinished'      # prepared, not signed yet
    r = s.ok('confirm')
    assert r == {'sent': keepers, 'total': keepers, 'change': 'new'}
    assert s.state['phase'] == 'active'
    assert s.state['custodians']['ok'] == keepers
    assert s.state['custodians']['status'] == 'ok'
    return review


# ------------------------------------------------------------------ tests
def test_plugin_defaults(s):
    """(1) init_qml: the bridge exists and bal_save_history is OFF."""
    assert s.bal is not None
    assert s.config.get('bal_save_history') is False


def test_whole_flow(s):
    """(2) heirs -> period -> review -> confirm -> due -> renew -> new coin -> update -> payment."""
    balance_before = s.wallet.get_balance()
    utxos_before = sorted(c.prevout.to_str() for c in s.wallet.get_utxos())
    make_will(s)
    # (3) F7: the will changes neither the balance nor the coins
    assert s.wallet.get_balance() == balance_before
    assert sorted(c.prevout.to_str() for c in s.wallet.get_utxos()) == utxos_before
    assert s.ok('checkCustodians') == {'ok': 2, 'total': 2, 'status': 'ok'}

    # past the reminder: "Sei ancora qui?"
    warn_at = s.state['warnAt']
    s.clock.now = warn_at + DAY
    s.ok('refresh')
    assert s.state['phase'] == 'due'
    info = s.controller().check_alive_info()
    assert info is not None and info['renewable'] is True
    s.clock.now = warn_at - DAY
    s.ok('refresh')
    assert s.state['phase'] == 'active'
    assert s.controller().check_alive_info() is None
    s.clock.now = warn_at + DAY
    s.ok('refresh')

    # renewal: the delivery becomes today + 24 months
    r = s.ok('renew')
    today = delivery.utc_midnight(s.clock.now)
    assert r['delivery'] == delivery.add_months(today, 24)
    assert r['sent'] == 2 and r['feeSats'] > 0
    assert s.state['phase'] == 'active'
    assert s.state['delivery'] == r['delivery']
    assert len(s.network.broadcasts) == 1     # the invalidation only

    # new money
    old_delivery = s.state['delivery']
    s.add_coin(250_000)
    s.ok('refresh')
    assert s.state['phase'] == 'needs_update'
    assert s.state['updateReason'] == 'received' and s.state['uncoveredSats'] == 250_000
    r = s.ok('update')
    assert s.state['phase'] == 'active'
    assert r['delivery'] == old_delivery - DAY        # owner 9.2: one day earlier
    assert s.state['uncoveredSats'] == 0

    # a payment spends a coin of the will
    s.pay(100_000)
    s.ok('refresh')
    assert s.state['phase'] == 'needs_update'
    assert s.state['updateReason'] == 'spent'
    s.ok('update')
    assert s.state['phase'] == 'active'


def test_renewal_interrupted_is_unfinished(s, monkeypatch):
    """Plan 8.9: invalidation sent, then a stop before the new will -> unfinished -> update()."""
    make_will(s)
    s.clock.now = s.state['warnAt'] + DAY
    s.ok('refresh')
    orig = bal_qml.QEBal._prepare

    def stop(self):
        raise bal_qml._Fail('offline', 'stopped (test)')
    monkeypatch.setattr(bal_qml.QEBal, '_prepare', stop)
    ev, _ = s.call('renew')
    assert ev[:3] == ('failed', 'renew', 'offline')
    assert len(s.network.broadcasts) == 1
    # F4: the new will is built on the unconfirmed change of the invalidation
    assert s.state["phase"] == "unfinished", (s.state["updateReason"], s.state["detail"], s.state["uncoveredSats"])
    monkeypatch.setattr(bal_qml.QEBal, '_prepare', orig)
    r = s.ok('update')
    assert s.state['phase'] == 'active'
    today = delivery.utc_midnight(s.clock.now)
    assert r['delivery'] == delivery.add_months(today, 24)


def test_one_keeper_down_and_none(s):
    s.ok('heirSave', '', 'Marco', MARCO, 100)
    s.ok('setPeriod', 12)
    s.keepers.down.add(bal_qml.KEEPERS[1])
    review = s.ok('review')
    assert [c['url'] for c in review['custodians']] == [bal_qml.KEEPERS[0]]
    assert s.ok('confirm') == {'sent': 1, 'total': 1, 'change': 'new'}
    s.keepers.down.update(bal_qml.KEEPERS)
    ev, _ = s.call('review')
    assert ev[2] == 'custodians'


def test_fee_warning_never_blocks(s):
    """Owner 9.5: a keepers' cost above 20% of the balance is a warning only."""
    s.ok('heirSave', '', 'Marco', MARCO, 100)
    s.ok('setPeriod', 12)
    global KEEPER_FEE
    old = KEEPER_FEE
    KEEPER_FEE = 300_000
    try:
        review = s.ok('review')
    finally:
        KEEPER_FEE = old
    assert review['feeWarning'] is True
    assert review['custodianFeeSats'] == 300_000


def test_wrong_inputs(s):
    ev, _ = s.call('heirSave', '', 'Marco', 'not-an-address', 50)
    assert ev[2] == 'address'
    ev, _ = s.call('review')
    assert ev[2] == 'no_heirs'
    s.ok('heirSave', '', 'Marco', MARCO, 50)
    ev, _ = s.call('review')
    assert ev[2] == 'percent'
    # rename keeps one person
    s.ok('heirSave', 'Marco', 'Marco Rossi', MARCO, 100)
    assert [h['name'] for h in s.state['heirs']] == ['Marco Rossi']
    s.ok('heirDelete', 'Marco Rossi')
    assert s.state['phase'] == 'none'


def test_set_warn_rewrites_the_check_alive(s):
    s.ok('heirSave', '', 'Marco', MARCO, 100)
    s.ok('setPeriod', 24)
    r = s.ok('setWarn', 'third')
    assert r['warnDays'] == 244
    assert s.state['warnDays'] == 244 and s.state['warn'] == 'third'
    assert s.controller().will_settings['threshold'] == '-244d'
    r = s.ok('setWarn', 'quarter')
    assert r['warnDays'] == 183
    ev, _ = s.call('setWarn', 'tomorrow')
    assert ev[2] == 'user'


def _today(s):
    return delivery.utc_midnight(s.clock.now)


def _sent_locktimes(s):
    """The locktimes of the will copies the keepers hold now (newest first)."""
    lts = set()
    for held in s.keepers.held.values():
        for raw in held.values():
            lts.add(tx_from_any(raw).locktime)
    return sorted(lts)


def test_longer_period_with_a_will_in_force_is_a_renewal(s):
    """Owner 16/11 (Q2): a later delivery (today + N) means a renewal NOW, with its fee."""
    make_will(s)                                    # 24 months
    x = s.state['delivery']
    s.clock.travel(40)
    r = s.ok('setPeriod', 60)
    assert r['applied'] is False                    # nothing moves before the PIN
    assert s.state['months'] == 60 and s.state['monthsInForce'] == 24
    assert 'pendingMonths' not in s.state
    assert s.state['delivery'] == x                 # the will in force, unchanged
    y = delivery.add_months(_today(s), 60)
    review = s.ok('review')
    assert review['change'] == 'renew'
    assert review['inForceDelivery'] == x
    assert review['delivery'] == y
    assert review['changeFeeSats'] == review['renewFeeSats'] > 0
    assert review["delivery"] - review["warnAt"] == bal_qml.warn_days(60, "half") * DAY
    assert s.state["warnDays"] == 365          # the reminder in force waits for the PIN
    assert len(s.network.broadcasts) == 0
    r = s.ok('confirm')
    assert r['change'] == 'renew' and r['feeSats'] > 0
    assert r['delivery'] == y
    assert len(s.network.broadcasts) == 1           # ONE invalidation
    assert s.state['phase'] == 'active'
    assert s.state['delivery'] == y and s.state['monthsInForce'] == 60
    assert y in _sent_locktimes(s)


def test_shorter_period_with_a_will_in_force_is_a_free_update(s):
    """Owner 16/11 (Q2): an earlier delivery is a free update with the EARLIER locktime."""
    make_will(s)                                    # 24 months
    x = s.state['delivery']
    s.clock.travel(40)
    s.ok('setPeriod', 12)
    assert s.state['months'] == 12 and s.state['monthsInForce'] == 24
    y = delivery.add_months(_today(s), 12)
    assert y < x
    review = s.ok('review')
    assert review['change'] == 'update'
    assert review['inForceDelivery'] == x and review['delivery'] == y
    assert review['changeFeeSats'] == 0
    r = s.ok('confirm')
    assert r['change'] == 'update' and 'feeSats' not in r
    assert len(s.network.broadcasts) == 0           # nothing on the blockchain
    assert r['delivery'] == y
    assert s.state['phase'] == 'active'
    assert s.state['delivery'] == y and s.state['monthsInForce'] == 12
    assert min(_sent_locktimes(s)) == y             # the keepers hold the earlier copy
    show = s.controller().delivery_show()
    assert show['locktime'] == y
    assert show['period_start']['locktime'] == _today(s)


def test_same_period_with_a_will_in_force_changes_nothing(s):
    """Owner 16/11 (Q2): the period of the will in force: no renewal, no new date."""
    make_will(s)
    x = s.state['delivery']
    s.clock.travel(40)
    s.ok('setPeriod', 24)
    assert s.state['monthsInForce'] == 24
    review = s.ok('review')
    assert review['change'] == 'none'
    assert review['delivery'] == x and review['changeFeeSats'] == 0
    r = s.ok('confirm')
    assert r['change'] == 'none'
    assert len(s.network.broadcasts) == 0
    assert s.state['delivery'] == x and s.state['phase'] == 'active'


@pytest.mark.parametrize('months', [60, 12], ids=['longer', 'shorter'])
def test_heirs_and_period_changed_together_is_one_operation(s, months):
    """Owner 16/11 (Q2): new heirs + new period -> ONE renewal or ONE update."""
    make_will(s)
    s.clock.travel(40)
    s.ok('heirSave', 'Marco', 'Marco', MARCO, 50)
    s.ok('heirSave', 'Giulia', 'Giulia', GIULIA, 50)
    s.ok('setPeriod', months)
    y = delivery.add_months(_today(s), months)
    review = s.ok('review')
    assert review['change'] == ('renew' if months == 60 else 'update')
    assert review['heirs'][0]['sats'] == review['heirs'][1]['sats']
    pushes = len([c for c in s.keepers.calls if c[1].endswith('/pushtxs')])
    r = s.ok('confirm')
    assert r['delivery'] == y
    assert len(s.network.broadcasts) == (1 if months == 60 else 0)
    # one sending of the new will to each keeper
    assert len([c for c in s.keepers.calls if c[1].endswith('/pushtxs')]) - pushes == 2
    assert s.state['phase'] == 'active' and s.state['delivery'] == y
    assert [h['percent'] for h in s.state['heirs']] == [50, 50]
    s.ok('refresh')
    assert s.state['phase'] == 'active'


def test_wizard_in_the_due_phase_is_a_renewal(s):
    """From the day of the reminder an update is refused: the wizard renews (same period too)."""
    make_will(s)
    s.clock.now = s.state['warnAt'] + DAY
    s.ok('refresh')
    assert s.state['phase'] == 'due'
    s.ok('setPeriod', 24)
    y = delivery.add_months(_today(s), 24)
    review = s.ok('review')
    assert review['change'] == 'renew' and review['delivery'] == y
    assert review['changeFeeSats'] > 0
    r = s.ok('confirm')
    assert r['change'] == 'renew' and r['delivery'] == y
    assert len(s.network.broadcasts) == 1
    assert s.state['phase'] == 'active'


def test_renew_after_a_wizard_left_halfway_uses_the_period_stored(s):
    """setPeriod(60) then back out: the reminder in force stays; the renewal takes 60 months
    and its reminder is counted on them."""
    make_will(s)
    s.ok('setPeriod', 60)
    assert s.state['warnDays'] == 365 and s.state['phase'] == 'active'
    s.clock.now = s.state['warnAt'] + DAY
    s.ok('refresh')
    r = s.ok('renew')
    assert r['delivery'] == delivery.add_months(_today(s), 60)
    assert s.state['warnDays'] == bal_qml.warn_days(60, 'half')
    assert s.state['phase'] == 'active' and s.state['monthsInForce'] == 60


def test_cli_months_confirm_earlier_anticipates(s):
    """The plugin rule (Q2): with a will in force bal_delivery_set --months N stores N only;
    with --confirm_earlier true an earlier period applies from today, a later one never."""
    make_will(s)
    x = s.state['delivery']
    s.clock.travel(40)
    c = s.controller()
    out = c.delivery_set(months=60, confirm_earlier=True)
    assert out['locktime'] == x                     # later: waits for the renewal
    out = c.delivery_set(months=12)
    assert out['locktime'] == x                     # earlier but not confirmed: N only
    out = c.delivery_set(months=12, confirm_earlier=True)
    assert out['locktime'] == delivery.add_months(_today(s), 12)
    assert 'earlier than the will in force' in out['message']


def test_busy_and_gui_thread_never_waits(s, monkeypatch):
    """(4) a slot returns at once while the worker works; a second call is 'busy'."""
    orig = bal_qml.QEBal._cmd

    def slow(self, name, *a, **kw):
        time.sleep(0.2)
        return orig(self, name, *a, **kw)
    monkeypatch.setattr(bal_qml.QEBal, '_cmd', slow)
    n = len(s.events)
    t = time.monotonic()
    s.bal.refresh()
    assert time.monotonic() - t < 0.05
    assert s.bal.busy is True
    s.bal.review()
    assert s.events[n] == ('failed', 'review', 'busy', '')
    while len(s.events) == n + 1:
        QCoreApplication.processEvents()
        time.sleep(0.01)
    assert s.events[n + 1][:2] == ('done', 'refresh')
    assert s.bal.busy is False


def test_frozen_coin_enters_the_will(s):
    """Plan 8.7: a frozen (blocked) coin is in the will too."""
    frozen = s.add_coin(300_000)
    op = frozen.txid() + ':0'
    s.wallet.set_frozen_state_of_coins([op], True)
    make_will(s)
    ins = set()
    for it in s.controller().will_status()['items']:
        if it['status']['VALID']:
            ins.update(bal_qml._inputs(it['tx']))
    assert op in ins


def test_command_log_never_holds_the_password(s):
    make_will(s)
    log = ' '.join(s.bal.commandLog)
    assert 'bal_will_sign' in log and 'bal_will_broadcast' in log
    if s.password:
        assert s.password not in log


# ------------------------------------------------------------------ owner 15/11: points 4, 4b, 4c, 4d, 7
def selected(s):
    return {u for u, we in s.controller().willexecutors_list().items()
            if isinstance(we, dict) and we.get('selected')}


def test_three_wanted_two_available(s):
    """4c: 3 keepers wanted, the public list has only the pair -> go on with 2, say so."""
    s.ok('refresh')
    assert s.state['keepersWanted'] == 3 and s.state['keepersChoices'][0] == 3
    assert s.state['keepersChoices'][-1] == 19
    make_will(s)
    assert s.state['custodians']['wanted'] == 3
    assert s.state['custodians']['total'] == 2
    assert any('/data/' in u for _m, u in s.keepers.calls)   # the welist was asked


def test_set_keepers_fills_from_the_welist(s):
    """4c + P5: the pair first, then the answering ones in the order of the public list.

    Never by price (owner 15/11): E1 is the most expensive but comes first in the welist.
    No .onion.
    """
    s.keepers.listed = [E3, E1, E2, ONION]
    s.keepers.fees = {E1: 3000, E2: 1500, E3: 500}
    s.keepers.down.add(E3)                     # the first of the list does not answer
    ev, _ = s.call('setKeepers', 4)
    assert ev[:3] == ('failed', 'setKeepers', 'user')
    ev, _ = s.call('setKeepers', 21)
    assert ev[2] == 'user'
    s.ok('heirSave', '', 'Marco', MARCO, 100)
    s.ok('setPeriod', 12)
    review = s.ok('review')
    assert [c['url'] for c in review['custodians']] == [K0, K1, E1]
    assert selected(s) == {K0, K1, E1}
    # the place in the welist is kept at the download (the local list loses the order)
    wes = s.controller().willexecutors_list()
    assert [wes[u].get('welist_rank') for u in (K0, K1, E3, E1, E2)] == [0, 1, 2, 3, 4]
    assert s.ok('setKeepers', 5) == {'keepersWanted': 5}
    assert s.state['keepersWanted'] == 5 and s.config.get('eh_heir_keepers') == 5
    review = s.ok('review')
    assert review['custodiansWanted'] == 5
    assert [c['url'] for c in review['custodians']] == [K0, K1, E1, E2]   # 4 of the 5 wanted
    assert not any(ONION in u for _m, u in s.keepers.calls)
    assert s.ok('confirm') == {'sent': 4, 'total': 4, 'change': 'new'}
    c = s.state['custodians']
    assert (c['wanted'], c['ok'], c['total'], c['status']) == (5, 4, 4, 'ok')
    # back to 3: the last of the list goes out (not the most expensive)
    s.ok('setKeepers', 3)
    review = s.ok('review')
    assert [c['url'] for c in review['custodians']] == [K0, K1, E1]


def test_fee_min_and_max(s):
    """4b: every copy has its keeper's fee: the range, not the first copy only."""
    s.keepers.fees = {K0: 1000, K1: 2500}
    s.ok('heirSave', '', 'Marco', MARCO, 100)
    s.ok('setPeriod', 12)
    review = s.ok('review')
    assert review['custodianFeeMinSats'] == 1000
    assert review['custodianFeeMaxSats'] == 2500
    assert review['custodianFeeSats'] == 2500
    s.ok('confirm')
    f = s.state['fees']
    assert (f['custodianMinSats'], f['custodianMaxSats'], f['custodianSats']) == (1000, 2500, 2500)
    assert f['cancelSats'] == f['renewSats'] > 0


def test_health_statuses_and_invalid(s):
    """4d, P6 (W = 3): ok / some / low / none, then invalid after >= 3 checks over >= 7 days."""
    s.keepers.listed = [E1]
    make_will(s, keepers=3)
    assert s.ok('checkCustodians') == {'ok': 3, 'total': 3, 'status': 'ok'}
    s.keepers.down.add(K1)
    assert s.ok('checkCustodians') == {'ok': 2, 'total': 3, 'status': 'some'}
    c = s.state['custodians']
    assert c['status'] == 'some' and c['ok'] == 2
    assert {x['url']: x['ok'] for x in c['list']} == {K0: True, K1: False, E1: True}
    s.keepers.down.add(K0)
    assert s.ok('checkCustodians')['status'] == 'low'
    assert s.state['custodians']['status'] == 'low'
    s.keepers.down.add(E1)
    assert s.ok('checkCustodians')['status'] == 'none'
    s.clock.travel(3)
    assert s.ok('checkCustodians')['status'] == 'none'
    s.clock.travel(3)
    assert s.ok('checkCustodians')['status'] == 'none'      # 3 checks, but only 6 days
    s.clock.travel(1)
    assert s.ok('checkCustodians')['status'] == 'invalid'   # 4 checks over 7 days
    s.ok('refresh')
    assert s.state['custodians']['status'] == 'invalid' and s.state['custodians']['ok'] == 0
    assert s.state['phase'] == 'active'
    # one comes back: no more invalid
    s.keepers.down.discard(E1)
    assert s.ok('checkCustodians')['status'] == 'low'
    # the results are kept in the wallet file (per wallet)
    assert len(bal_qml.QEBal._load_checks(s.wallet)) == 8


def test_keeper_check_times(s):
    """P1: per keeper the time of its last check and the days it has not answered."""
    s.keepers.listed = [E1]
    make_will(s, keepers=3)
    assert s.ok('checkCustodians')['status'] == 'ok'
    t0 = int(s.clock.now)
    c = {x['url']: x for x in s.state['custodians']['list']}
    assert {u: (x['checkedAt'], x['downDays']) for u, x in c.items()} == \
        {K0: (t0, 0), K1: (t0, 0), E1: (t0, 0)}
    s.keepers.down.add(K1)
    s.clock.travel(1)
    s.ok('checkCustodians')
    s.clock.travel(2)
    s.ok('checkCustodians')
    t3 = int(s.clock.now)
    s.ok('refresh')
    c = {x['url']: x for x in s.state['custodians']['list']}
    assert (c[K1]['ok'], c[K1]['checkedAt'], c[K1]['downDays']) == (False, t3, 2)
    assert (c[K0]['ok'], c[K0]['checkedAt'], c[K0]['downDays']) == (True, t3, 0)
    assert bal_qml._check_times([], K0, t3) == (0, 0)


def test_offline_check_is_not_counted(s, monkeypatch):
    """4d: no keeper answers while the phone is offline: the check says nothing."""
    make_will(s)
    s.keepers.down.update((K0, K1))
    monkeypatch.setattr(bal_qml.QEBal, '_online_now', lambda self: False)
    for _ in range(4):
        ev, _ = s.call('checkCustodians')
        assert ev[:3] == ('failed', 'checkCustodians', 'offline')
        s.clock.travel(3)
    assert bal_qml.QEBal._load_checks(s.wallet) == []
    assert s.state['custodians']['status'] == 'ok'


def test_online_now_reads_the_server():
    """The server.ping probe behind the 'offline' rule."""
    async def no_answer(method):
        raise ConnectionError('no route (test)')

    async def pong(method):
        return None
    ensure_loop()
    net = SimpleNamespace(is_connected=lambda: False)
    bridge = SimpleNamespace(_network=lambda: net)
    assert bal_qml.QEBal._online_now(bridge) is False
    net = SimpleNamespace(is_connected=lambda: True,
                          interface=SimpleNamespace(session=SimpleNamespace(send_request=no_answer)))
    assert bal_qml.QEBal._online_now(bridge) is False
    net.interface.session.send_request = pong
    assert bal_qml.QEBal._online_now(bridge) is True


def test_keeper_health_rule():
    h = bal_qml.keeper_health
    assert h(0, 0, []) == ''
    assert (h(3, 3, []), h(2, 3, []), h(1, 3, []), h(0, 3, [])) == ('ok', 'some', 'low', 'none')
    # owner P6: ask only below W - 1 answering (W = 5 asks at 3, W = 7 at 5)
    assert [h(n, 5, [], 5) for n in (5, 4, 3, 2, 1, 0)] == ['ok', 'some', 'low', 'low', 'low', 'none']
    assert [h(n, 7, [], 7) for n in (7, 6, 5, 1)] == ['ok', 'some', 'low', 'low']
    # testnet4: 2 keepers only, 3 wanted: 1 of 2 asks; 1 of 1 is all of them
    assert (h(2, 2, [], 3), h(1, 2, [], 3), h(1, 1, [], 3)) == ('ok', 'low', 'ok')
    zero = [{'t': d * DAY, 'ok': 0} for d in (0, 4, 7)]
    assert h(0, 3, zero) == 'invalid'
    assert h(0, 3, zero[1:]) == 'none'                             # only 2 checks
    assert h(0, 3, [{'t': 0, 'ok': 0}, {'t': 6 * DAY, 'ok': 0}, {'t': 6 * DAY + 1, 'ok': 0}]) == 'none'
    assert h(0, 3, zero[:1] + [{'t': 5 * DAY, 'ok': 1}] + zero[1:]) == 'none'   # one answered between


def test_find_and_replace_keeper(s):
    """4d «Sostituisci il custode»: the first free one of the welist that answers (P5), free."""
    s.keepers.listed = [E1]
    s.keepers.fees = {E1: 1200}
    make_will(s, keepers=3)
    delivery_before = s.state['delivery']
    s.keepers.down.add(K1)
    s.ok('checkCustodians')
    # nobody free: E1 is already used, the welist has no other
    ev, _ = s.call('findKeeper')
    assert ev[:3] == ('failed', 'findKeeper', 'custodians')
    s.keepers.listed = [E1, E2, E3]
    s.keepers.fees = {E1: 1200, E2: 4000, E3: 2000}
    found = s.ok('findKeeper')
    rows = {r['url']: r for r in found['candidates']}
    # P5: the order of the welist, the price ignored (E3 is cheaper, E2 comes first)
    assert found['pick'] == E2
    assert [r['url'] for r in found['candidates'] if not r['used']] == [E2, E3]
    assert rows[K1]['used'] and not rows[K1]['ok']
    assert rows[E1]['used'] and rows[E1]['ok']
    assert not rows[E2]['used'] and rows[E2]['ok'] and rows[E2]['feeSats'] == 4000
    assert set(rows[E3]) == {'url', 'name', 'feeSats', 'ok', 'used'}
    assert found['picks'] == [E2] and found['need'] == 1
    # a keeper that does not answer cannot be the new one
    s.keepers.down.add(E2)
    ev, _ = s.call('replaceKeepers', [E2])
    assert ev[:3] == ('failed', 'replaceKeepers', 'custodians')
    ev, _ = s.call('replaceKeepers', ['https://not.in.the.list'])
    assert ev[2] == 'user'
    ev, _ = s.call('replaceKeepers', [])
    assert ev[2] == 'user'
    n = len(s.network.broadcasts)
    r = s.ok('replaceKeepers', [E3])
    # the core adds a copy for the new keeper only: same delivery, no new date
    assert r == {'delivery': delivery_before, 'ok': 3, 'total': 3, 'added': 1}
    assert len(s.network.broadcasts) == n                 # nothing on the blockchain: free
    assert selected(s) == {K0, E1, E3}
    c = s.state['custodians']
    assert {x['url'] for x in c['list']} == {K0, E1, E3}
    assert (c['ok'], c['total'], c['status']) == (3, 3, 'ok')
    assert s.state['delivery'] == delivery_before and s.state['phase'] == 'active'
    assert s.keepers.held[E3]                              # the new keeper holds its copy
    assert s.ok('checkCustodians') == {'ok': 3, 'total': 3, 'status': 'ok'}


def test_replace_keeper_needs_a_will(s):
    s.keepers.listed = [E1]
    s.ok('heirSave', '', 'Marco', MARCO, 100)
    ev, _ = s.call('replaceKeepers', [K0])
    assert ev[:3] == ('failed', 'replaceKeepers', 'user')


def _count_prepares(monkeypatch):
    """How many times the will is made again (``_prepare``) and signed."""
    n = {'prepare': 0, 'sign': 0}
    prepare, sign = bal_qml.QEBal._prepare, bal_qml.QEBal._sign_and_send

    def counted_prepare(self):
        n['prepare'] += 1
        return prepare(self)

    def counted_sign(self):
        n['sign'] += 1
        return sign(self)
    monkeypatch.setattr(bal_qml.QEBal, '_prepare', counted_prepare)
    monkeypatch.setattr(bal_qml.QEBal, '_sign_and_send', counted_sign)
    return n


def test_replace_all_keepers_down_at_once(s, monkeypatch):
    """P6: 2 of 3 do not answer (low): 2 new ones in welist order, ONE new will, one signature."""
    s.keepers.listed = [E1]
    make_will(s, keepers=3)
    delivery_before = s.state['delivery']
    s.keepers.down.add(K1)
    assert s.ok('checkCustodians')['status'] == 'some'      # 2 of 3 with W = 3: quiet
    s.keepers.down.add(E1)
    assert s.ok('checkCustodians') == {'ok': 1, 'total': 3, 'status': 'low'}
    s.keepers.listed = [E1, E2, E3]
    s.keepers.fees = {E2: 4000, E3: 2000}                    # E3 cheaper: never by price
    found = s.ok('findKeeper')
    assert found['need'] == 2 and found['picks'] == [E2, E3] and found['pick'] == E2
    n = _count_prepares(monkeypatch)
    sent = len(s.network.broadcasts)
    r = s.ok('replaceKeepers', [E2, E3])
    assert (n['prepare'], n['sign']) == (1, 1)
    assert r == {'delivery': delivery_before, 'ok': 3, 'total': 3, 'added': 2}
    assert len(s.network.broadcasts) == sent                 # free
    assert selected(s) == {K0, E2, E3}
    assert s.keepers.held[E2] and s.keepers.held[E3]
    c = s.state['custodians']
    assert {x['url'] for x in c['list']} == {K0, E2, E3}
    assert (c['ok'], c['total'], c['status']) == (3, 3, 'ok')
    assert s.state['delivery'] == delivery_before and s.state['phase'] == 'active'


def test_replace_fewer_found_than_needed(s, monkeypatch):
    """P6: 2 do not answer, the list has 1 free: replace with that one (and say 1 of 2)."""
    s.keepers.listed = [E1]
    make_will(s, keepers=3)
    s.keepers.down.update((K1, E1))
    s.ok('checkCustodians')
    s.keepers.listed = [E1, E2]
    found = s.ok('findKeeper')
    assert found['need'] == 2 and found['picks'] == [E2]
    n = _count_prepares(monkeypatch)
    r = s.ok('replaceKeepers', found['picks'])
    assert (n['prepare'], n['sign']) == (1, 1)
    assert (r['ok'], r['total'], r['added']) == (2, 2, 1)
    assert selected(s) == {K0, E2}
    assert s.state['custodians']['status'] == 'ok'          # 2 of 2 in use
    # a new one that stopped answering meanwhile is left out, the others go on
    s.keepers.down.add(E2)
    s.keepers.listed = [E1, E2, E3]
    assert s.ok('findKeeper')['picks'] == [E3]               # E3 now in the local list
    r = s.ok('replaceKeepers', [E2, E3])
    assert r['added'] == 1 and E3 in selected(s) and E2 not in selected(s)


@pytest.mark.parametrize('delete_heirs', [False, True], ids=['keep-heirs', 'delete-heirs'])
def test_cancel_will(s, delete_heirs):
    """Point 7: the will invalidated on the blockchain; heirs kept or deleted."""
    make_will(s)
    estimate = s.state['fees']['cancelSats']
    assert estimate > 0
    r = s.ok('cancelWill', delete_heirs)
    assert r['feeSats'] > 0 and r['txid'] == s.network.broadcasts[-1]
    assert len(s.network.broadcasts) == 1
    if delete_heirs:
        assert s.state['phase'] == 'none' and s.state['heirs'] == []
    else:
        assert s.state['phase'] == 'draft'
        assert [h['name'] for h in s.state['heirs']] == ['Marco', 'Giulia']
    assert s.state['custodians']['status'] == ''
    ev, _ = s.call('cancelWill', False)
    assert ev[:3] == ('failed', 'cancelWill', 'user')      # nothing left to cancel
    if not delete_heirs:
        # a new will can be made again
        s.ok('review')
        assert s.ok('confirm') == {'sent': 2, 'total': 2, 'change': 'new'}
        assert s.state['phase'] == 'active'
        assert s.wallet.db.get(bal_qml.CANCEL_KEY) is None


def test_cancel_interrupted_is_not_a_renewal(s, monkeypatch):
    """The cancellation sent, the wallet slow to see it: still draft, not 'unfinished'."""
    make_will(s)
    monkeypatch.setattr(bal_qml.QEBal, '_wait_seen',
                        lambda self, wallet, txid, timeout=0: False)
    ev, _ = s.call('cancelWill', True)
    assert ev[:3] == ('failed', 'cancelWill', 'not_synced')
    assert s.state['phase'] == 'draft'
    assert len(s.state['heirs']) == 2           # not deleted before the wallet sees it


# ---- owner 17/11 (controllo-mainnet G1): a renewal that cannot finish never touches the will ----

def _due(s):
    make_will(s)
    s.clock.now = s.state['warnAt'] + DAY
    s.ok('refresh')
    assert s.state['phase'] == 'due'
    return s.state['delivery'], len(s.network.broadcasts)


def test_renew_with_keepers_down_leaves_the_will_in_force(s):
    delivery_before, sent_before = _due(s)
    s.keepers.down.update(bal_qml.KEEPERS)
    ev, _ = s.call('renew')
    assert ev[0] == 'failed' and ev[2] == 'custodians', ev
    assert len(s.network.broadcasts) == sent_before          # no invalidation sent
    s.ok('refresh')
    assert s.state['phase'] == 'due'                          # the old will is still in force
    assert s.state['delivery'] == delivery_before


def test_renew_with_heirs_not_100_leaves_the_will_in_force(s):
    delivery_before, sent_before = _due(s)
    s.ok('heirDelete', 'Giulia')                              # total 60%
    ev, _ = s.call('renew')
    assert ev[0] == 'failed' and ev[2] == 'percent', ev
    assert len(s.network.broadcasts) == sent_before
    s.ok('refresh')
    assert s.state['delivery'] == delivery_before


def test_cancel_still_only_invalidates(s):
    # "Annulla l'eredità" does not check keepers or heirs: it invalidates, full stop (owner 17/11)
    _due(s)
    s.keepers.down.update(bal_qml.KEEPERS)
    s.ok('heirDelete', 'Giulia')
    sent_before = len(s.network.broadcasts)
    ev, _ = s.call('cancelWill', False)
    assert ev[0] in ('done', 'failed'), ev
    if ev[0] == 'failed':
        assert ev[2] == 'not_synced', ev                      # sent, the wallet sees it soon
    assert len(s.network.broadcasts) == sent_before + 1       # the invalidation went out


# ---- owner 17/11 (controllo-mainnet M2): a person removed outside the procedure ----

def test_update_with_heirs_not_100_stops_before_signing(s):
    make_will(s)
    sent_before = len(s.network.broadcasts)
    s.ok('heirDelete', 'Giulia')                              # total 60%
    ev, _ = s.call('update')
    assert ev[0] == 'failed' and ev[2] == 'percent', ev
    assert len(s.network.broadcasts) == sent_before


def test_replace_keepers_with_heirs_not_100_stops_before_signing(s):
    s.keepers.listed = [E2]
    make_will(s, keepers=3)
    sent_before = len(s.network.broadcasts)
    s.ok('heirDelete', 'Giulia')
    ev, _ = s.call('replaceKeepers', [E2])
    assert ev[0] == 'failed' and ev[2] == 'percent', ev
    assert len(s.network.broadcasts) == sent_before


def test_heirs_changed_after_the_will_reads_changed(s):
    make_will(s)
    s.ok('heirDelete', 'Giulia')
    s.ok('refresh')
    assert s.state['phase'] == 'needs_update'
    assert s.state['updateReason'] == 'changed'


# ---- owner 17/11 (M7 bis): the invalidation pays the fee chosen on the page, never 20 sat/vB ----

def test_cancel_without_a_chosen_fee_does_not_start(s):
    make_will(s)
    sent_before = len(s.network.broadcasts)
    s.auto_fee = False
    ev, _ = s.call('cancelWill', False)
    assert ev[0] == 'failed' and ev[2] == 'no_fee', ev
    assert len(s.network.broadcasts) == sent_before
    s.ok('refresh')
    assert s.state['phase'] == 'active'


def test_renew_without_a_chosen_fee_does_not_start(s):
    _due(s)
    sent_before = len(s.network.broadcasts)
    s.auto_fee = False
    ev, _ = s.call('renew')
    assert ev[0] == 'failed' and ev[2] == 'no_fee', ev
    assert len(s.network.broadcasts) == sent_before


def test_cancel_pays_exactly_the_fee_shown(s):
    make_will(s)
    s.ok('refresh')
    coins = s.state['invalidate']['coins']
    assert coins and s.state['invalidate']['to']
    s.auto_fee = False
    s.bal.setInvalidationFee({'sats': 777, 'rate': 5.0, 'coins': coins})
    out = s.ok('cancelWill', False)
    assert out['feeSats'] == 777


def test_cancel_with_other_coins_pays_the_rate_chosen(s):
    make_will(s)
    s.auto_fee = False
    s.bal.setInvalidationFee({'sats': 1, 'rate': 3.0, 'coins': ['not:0']})
    out = s.ok('cancelWill', False)
    tx = s.wallet.adb.get_transaction(out['txid'])
    vsize = tx.estimated_size()
    assert 3.0 * vsize - 2 <= out['feeSats'] <= 3.0 * vsize + 8, (out['feeSats'], vsize)


def test_the_chosen_fee_is_used_once(s):
    make_will(s)
    s.auto_fee = False
    s.bal.setInvalidationFee({'sats': 1, 'rate': 2.0, 'coins': []})
    s.ok('refresh')                                     # the fee went with this job
    ev, _ = s.call('cancelWill', False)
    assert ev[0] == 'failed' and ev[2] == 'no_fee', ev  # never kept for a later one


def test_no_fixed_20_when_the_servers_give_no_estimate(s):
    make_will(s)
    s.network.fee_estimates = SimpleNamespace(eta_target_to_fee=lambda blocks: None)
    s.ok('refresh')
    assert s.state['fees']['renewSats'] == 0            # no estimate: nothing invented
    s.network.fee_estimates = SimpleNamespace(eta_target_to_fee=lambda blocks: 100_000 if blocks <= 2 else 10_000)
    s.ok('refresh')
    n = len(s.state['invalidate']['coins'])
    assert s.state['fees']['renewSats'] == math.ceil((11 + 68 * n + 31) * 100)   # 2 blocks, 100 sat/vB


def test_invalidation_coins_are_the_coins_it_spends(s):
    make_will(s)
    s.ok('refresh')
    coins = s.state['invalidate']['coins']
    assert coins
    out = s.ok('cancelWill', False)
    tx = s.wallet.adb.get_transaction(out['txid'])
    assert sorted(i.prevout.to_str() for i in tx.inputs()) == coins


# ---- controllo-mainnet 2.6: 1.../3... wallets stop at the start, clearly ----

def test_old_address_kind_stops_at_review(s, monkeypatch):
    s.ok('refresh')
    s.ok('heirSave', '', 'Marco', MARCO, 100)
    monkeypatch.setattr(s.wallet, "txin_type", "p2wpkh-p2sh", raising=False)
    ev, _ = s.call('review')
    assert ev[0] == 'failed' and ev[2] == 'address_kind', ev


def test_native_segwit_passes_the_kind_check(s):
    s.ok('refresh')
    s.ok('heirSave', '', 'Marco', MARCO, 100)
    ev, _ = s.call('review')
    assert not (ev[0] == 'failed' and ev[2] == 'address_kind'), ev


def test_two_heirs_on_one_address_share_its_output(monkeypatch):
    # controllo-mainnet 2.8 (view only): the output of a shared address is split by percent
    out = SimpleNamespace(address=MARCO, value=9000)
    monkeypatch.setattr(bal_qml, "tx_from_any", lambda raw: SimpleNamespace(outputs=lambda: [out]))
    monkeypatch.setattr(bal_qml, "_inputs", lambda raw: [])
    items = [{"tx": "x", "willexecutor": ""}]
    heirs = {"Anna": [MARCO, "60%"], "Bruno": [MARCO, "30%"], "Carla": [GIULIA, "10%"]}
    rows, *_ = bal_qml.QEBal._split(None, items, heirs, {})
    got = {r["name"]: r["sats"] for r in rows}
    assert got == {"Anna": 6000, "Bruno": 3000, "Carla": 0}


# ---- owner 17/11/2026: the dated envelope pays 50 sat/vB (was 20) ----

def test_new_will_envelope_pays_50(s):
    from electrum.plugins.bal.core import delivery
    assert delivery.DEFAULT_FEE == 50
    make_will(s)
    ws = s.controller().will_settings
    assert int(float(ws.get("baltx_fees"))) == 50, ws


# ---- owner 17/11: no more "Safe21 Heartbeat" in the movements ----

def test_cancellation_label_is_the_new_text(s):
    from electrum.plugins.bal.core import will_versions as wv
    assert wv.INVALIDATION_LABEL == "Àncòra – annullamento eredità"
    make_will(s)
    out = s.ok('cancelWill', False)
    assert s.wallet.get_label_for_txid(out['txid']) == wv.INVALIDATION_LABEL


def test_old_cancellation_label_still_means_unfinished(s, monkeypatch):
    # a renewal cut in half in a wallet that has the OLD label still reads "unfinished"
    from electrum.plugins.bal.core import will_versions as wv
    make_will(s)
    s.clock.now = s.state['warnAt'] + DAY
    s.ok('refresh')

    def stop(self):
        raise bal_qml._Fail('offline', 'stopped (test)')
    monkeypatch.setattr(bal_qml.QEBal, '_prepare', stop)
    s.call('renew')
    txid = s.network.broadcasts[-1]
    s.wallet.set_label(txid, wv.OLD_INVALIDATION_LABELS[0])
    s.ok('refresh')
    assert s.state['phase'] == 'unfinished'
