"""The Schȅi inheritance bridge (electrum/plugins/bal/qml.py, QEBal).

What is checked here, without network and without a wallet file:

* the bal plugin loads for the QML GUI, its ``init_qml`` hook makes the
  bridge and turns ``bal_save_history`` OFF (F7);
* a slot never blocks the GUI thread: it returns at once while the worker
  works, and a second call meanwhile answers ``failed(op, 'busy', '')``;
* the "when to remind you" rule (plan 1.3) and the small readers.

The whole flow on a funded wallet (heirs, review, confirm, renew, update,
with and without password) is in ``tools/ancora-test/test_bridge_flow.py``
outside the repository (fake keepers and network).
"""
import shutil
import tempfile
import threading
import time
from types import SimpleNamespace

import pytest
from PyQt6.QtCore import QCoreApplication, QObject

from electrum import util
from electrum.simple_config import SimpleConfig


@pytest.fixture(scope='module')
def qapp():
    return QCoreApplication.instance() or QCoreApplication([])


@pytest.fixture
def plugins():
    try:
        util.get_asyncio_loop()
        stop = None
    except Exception:
        _loop, stop, _thread = util.create_and_start_event_loop()
    tmp = tempfile.mkdtemp(prefix='qebal-')
    config = SimpleConfig({'electrum_path': tmp}, read_user_config_function=lambda path: {})
    from electrum.plugin import Plugins
    p = Plugins(config, 'qml')
    yield config, p
    p.stop()
    p.join(timeout=5)
    shutil.rmtree(tmp, ignore_errors=True)
    if stop is not None:
        stop.set_result(1)


class FakeApp(QObject):
    pass


class FakeWallet:
    def is_watching_only(self):
        return False

    def get_unlocked_password(self):
        return None


def make_bridge(config, p, qapp):
    """Enable bal as qeapp.py does on a fresh config and run its init_qml hook."""
    assert not config.get('plugins.bal.enabled')
    plugin = p.enable('bal')
    assert type(plugin).__module__.endswith('bal.qml')
    app = FakeApp()
    app.daemon = SimpleNamespace(daemon=SimpleNamespace(config=config, network=None),
                                 currentWallet=SimpleNamespace(wallet=FakeWallet()))
    plugin.init_qml(app)
    return plugin, app


def test_init_qml_makes_the_bridge_and_turns_history_off(plugins, qapp):
    config, p = plugins
    plugin, app = make_bridge(config, p, qapp)
    assert plugin.so is not None and plugin.so.parent() is app
    assert config.get('bal_save_history') is False
    assert config.get('plugins.bal.enabled')
    assert plugin.so.state['phase'] == 'none' and plugin.so.busy is False
    plugin.so.unregister()


def test_slots_never_block_the_gui_thread(plugins, qapp, monkeypatch):
    config, p = plugins
    plugin, app = make_bridge(config, p, qapp)
    bal = plugin.so
    from electrum.plugins.bal import qml as bal_qml
    release = threading.Event()

    def slow_state(self, wallet):
        release.wait(5)
        return bal_qml._empty_state()
    monkeypatch.setattr(bal_qml.QEBal, '_read_state', slow_state)
    events = []
    bal.done.connect(lambda op, r: events.append(('done', op)))
    bal.failed.connect(lambda op, c, m: events.append(('failed', op, c)))

    t = time.monotonic()
    bal.refresh()
    assert time.monotonic() - t < 0.05
    assert bal.busy is True
    for slot, args in (('review', ()), ('confirm', ()), ('renew', ()), ('update', ()),
                       ('setPeriod', (24,)), ('setWarn', ('half',)), ('heirDelete', ('x',)),
                       ('heirSave', ('', 'a', 'b', 50)), ('checkCustodians', ()),
                       ('setKeepers', (5,)), ('findKeeper', ()),
                       ('replaceKeepers', (['https://we.example', 'https://we2.example'],)),
                       ('cancelWill', (True,))):
        t = time.monotonic()
        getattr(bal, slot)(*args)
        assert time.monotonic() - t < 0.05
        assert events[-1] == ('failed', slot, 'busy')
    release.set()
    end = time.monotonic() + 5
    while ('done', 'refresh') not in events and time.monotonic() < end:
        QCoreApplication.processEvents()
        time.sleep(0.01)
    assert ('done', 'refresh') in events
    assert bal.busy is False
    bal.unregister()


def test_warn_days_rule():
    from electrum.plugins.bal.qml import warn_days, _days, _percent
    assert [warn_days(24, f) for f in ('half', 'third', 'quarter')] == [365, 244, 183]
    assert warn_days(12, 'half') == 183 and warn_days(60, 'half') == 913
    assert _days('-365d') == 365 and _days('1y') == 0 and _days(None) == 0
    assert _percent('60%') == 60 and _percent('12.5%') is None and _percent('15000') is None


def test_keepers_choice_and_health_rule():
    from electrum.plugins.bal.qml import (
        KEEPERS_CHOICES, KEEPERS_DEFAULT, INVALID_CHECKS, INVALID_DAYS, DAY, keeper_health)
    assert KEEPERS_DEFAULT == 3 and KEEPERS_CHOICES == (3, 5, 7, 9, 11, 13, 15, 17, 19)
    assert keeper_health(0, 0, []) == ''
    assert [keeper_health(n, 3, []) for n in (3, 2, 1, 0)] == ['ok', 'some', 'low', 'none']
    # owner P6: quiet down to W - 1 answering, then 'low' (replace them), 0 = 'none'
    assert [keeper_health(n, 3, [], 3) for n in (3, 2, 1, 0)] == ['ok', 'some', 'low', 'none']
    assert [keeper_health(n, 5, [], 5) for n in (5, 4, 3, 1, 0)] == ['ok', 'some', 'low', 'low', 'none']
    assert [keeper_health(n, 7, [], 7) for n in (7, 6, 5, 1, 0)] == ['ok', 'some', 'low', 'low', 'none']
    # fewer in use than wanted (testnet4: 2 of 3): all answering is 'ok', 1 of 2 asks
    assert [keeper_health(n, 2, [], 3) for n in (2, 1, 0)] == ['ok', 'low', 'none']
    assert keeper_health(4, 5, [], 7) == 'low' and keeper_health(6, 7, [], 7) == 'some'
    zero = [{'t': i * INVALID_DAYS * DAY // (INVALID_CHECKS - 1), 'ok': 0}
            for i in range(INVALID_CHECKS)]
    assert keeper_health(0, 3, zero) == 'invalid'
    assert keeper_health(0, 3, zero[:-1]) == 'none'
    assert keeper_health(0, 3, zero[:1] + [{'t': DAY, 'ok': 2}] + zero[1:]) == 'none'


def test_fee_range_of_the_copies():
    """Owner 4b: every keeper's copy has its own fee: min and max over the copies."""
    from electrum.plugins.bal.qml import QEBal, _in_use, _newest
    items = [{'txid': 'a', 'locktime': 10, 'willexecutor': 'k1'},
             {'txid': 'b', 'locktime': 10, 'willexecutor': 'k2'},
             {'txid': 'c', 'locktime': 11, 'willexecutor': 'k3'}]
    assert [it['txid'] for it in _newest(items)] == ['a', 'b']
    wes = {'k1': {'selected': True}, 'k2': {'selected': False}}
    assert [it['txid'] for it in _in_use(_newest(items), wes)] == ['a']
    assert [it['txid'] for it in _in_use(_newest(items), {})] == ['a', 'b']
    assert QEBal._split(None, [], {'Marco': ['x', '100%']}, {})[1:] == (0, 0, 0)


def test_months_of_the_will_in_force():
    """Owner 16/11 (Q2): the period of the will in force, from period_start to its delivery."""
    from electrum.plugins.bal.core import delivery
    from electrum.plugins.bal.qml import DAY, _months_in_force
    start = delivery.utc_midnight(1_794_700_000)
    show = {"period_start": {"locktime": start}}
    for months in (12, 24, 36, 60):
        x = delivery.add_months(start, months)
        assert _months_in_force(x, show) == months
        assert _months_in_force(x - DAY, show) == months      # an update one day earlier
    assert _months_in_force(0, show) == 0
    assert _months_in_force(start + 400 * DAY, {}) == 0
