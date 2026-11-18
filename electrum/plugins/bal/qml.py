"""
bal.qml
=======

Entry point of the Àncòra plugin for the Schȅi (QML, Android) app, and the
bridge between the "Eredità semplice" pages and the plugin.

The pages never touch the heirs or the will themselves: they call the slots
of :class:`QEBal`, which runs the plugin's own ``bal_*`` commands (the same
ones as the command line and the Console) through ONE private door,
:meth:`QEBal._cmd`. So the logic stays exactly the one of the desktop plugin,
and a later terminal page can show (and reuse) the very same commands.

Rules of the bridge (plan "pagine eredità", section 1):

* every slot starts one worker thread; the GUI thread never waits
  (``Commands._run`` blocks, and every ``bal_`` command takes the wallet's
  lock for up to 20 s). A second call while ``busy`` answers
  ``failed(op, 'busy', '')`` at once;
* the results come back through Qt signals (queued to the GUI thread); the
  QML-visible state is written only there;
* the signing password never passes through QML: ``_cmd`` hands
  ``Commands._run`` the getter ``wallet.get_unlocked_password`` (the wallet is
  unlocked when it is loaded, as for a normal Send). The PIN is asked by the
  pages before ``confirm()``, ``renew()``, ``update()``, ``replaceKeepers()``
  and ``cancelWill()``;
* ``bal_save_history`` is turned OFF at start: Schȅi must not save the will
  transactions as wallet-local transactions (the coins would look spent).

Schȅi ships the plugin as an internal plugin (electrum/plugins/bal), so a
normal relative import is enough here (no zip loading on Android).
"""

import asyncio
import json
import math
import threading
import time
import traceback
from decimal import Decimal

from PyQt6.QtCore import pyqtProperty, pyqtSignal, pyqtSlot

from electrum import util
from electrum.bitcoin import COIN, is_address
from electrum.gui.common_qt.plugins import PluginQObject
from electrum.logging import get_logger
from electrum.plugin import hook
from electrum.transaction import tx_from_any
from electrum.util import UserFacingException

from .cli.plugin import Plugin as CliPlugin

_logger = get_logger(__name__)

DAY = 86400
#: Average days in a calendar month (the "when to remind you" rule, plan 1.3).
MONTH_DAYS = 30.4375
#: "Quando avvisarti": the reminder comes 1/2, 1/3 or 1/4 of the period before the delivery.
WARN_FRACTIONS = {'half': 2, 'third': 3, 'quarter': 4}
WARN_DEFAULT = 'half'
#: The config key of the "when to remind you" choice (app-wide).
WARN_KEY = 'eh_heir_warn'
#: The two keepers (will-executors) Schȅi always tries first, on every chain (owner, plan 1.5 / 9.4).
KEEPERS = ('https://we.bitcoin-after.life', 'https://we.safe21.io')
#: How many keepers to use (owner 15/11, point 4c): 3 by default, an odd number up to 19.
KEEPERS_KEY = 'eh_heir_keepers'
KEEPERS_DEFAULT = 3
KEEPERS_CHOICES = tuple(range(3, 20, 2))
#: Wallet db keys of the bridge (not will data): the keepers' check results
#: (point 4d) and the txid of the cancellation of the will (point 7).
CHECKS_KEY = 'eh_heir_keeper_checks'
CHECKS_KEEP = 60
CANCEL_KEY = 'eh_heir_cancel_txid'
#: "Non valida" (point 4d): no keeper answered at any check for this long, at least this many checks.
INVALID_DAYS = 7
INVALID_CHECKS = 3
#: Above this share of the balance the keepers' cost is shown as a warning (owner 9.5: never blocks).
FEE_WARN_SHARE = 0.20
#: How long renew() waits for the wallet to see its invalidation, seconds.
WAIT_INVALIDATION = 30
#: The last commands kept for the expert bar / terminal.
LOG_SIZE = 50


def warn_days(months, fraction):
    """Days before the delivery the renewal is asked (plan 1.3)."""
    return int(round(months * MONTH_DAYS / WARN_FRACTIONS.get(fraction, 2)))


def _sats(btc_text):
    """A BTC amount as Electrum's commands print it, in satoshis."""
    return int(Decimal(str(btc_text)) * COIN)


def _short(value):
    """An argument for ``lastCommand``: long texts (addresses, txs) shortened."""
    text = str(value)
    if len(text) > 24:
        return text[:8] + '…' + text[-4:]
    return text


def _percent(amount):
    """``"60%"`` -> 60; a fixed amount (or a fraction of a percent) -> None."""
    text = str(amount).strip()
    if not text.endswith('%'):
        return None
    try:
        value = Decimal(text[:-1])
    except Exception:
        return None
    return int(value) if value == int(value) else None


def _days(threshold):
    """``"-365d"`` -> 365 (0 when not a "-Nd" value)."""
    text = str(threshold or '')
    if text.startswith('-') and text.endswith('d'):
        try:
            return int(text[1:-1])
        except ValueError:
            return 0
    return 0


def _fee_of(we):
    return int((we or {}).get('base_fee') or 0)


# owner 18/11: the keepers' maximum price (sats); changed only at the EXPERT level
KEEPER_MAX_KEY = 'eh_heir_keeper_max'
KEEPER_MAX_DEFAULT = 50000
KEEPER_MAX_CHOICES = (25000, 50000, 100000, 200000)   # the buttons; any value can be typed
KEEPER_MAX_MIN = 1000
KEEPER_MAX_TOP = 500000     # the plugin's own ceiling (MAX_WILLEXECUTOR_FEE)
# owner 18/11: the keepers chosen by hand (EXPERT level); [] = automatic
KEEPERS_MINE_KEY = 'eh_heir_keepers_mine'


def _fail_code(e):
    """owner 18/11: the plugin's money errors get their own code (said in Schȅi's words)."""
    from .core import heirs as heirs_mod, will as will_mod
    c = e.__cause__ if e.__cause__ is not None else e
    if isinstance(c, heirs_mod.WillExecutorFeeTooHighException):
        return 'keeper_fee'
    if isinstance(c, heirs_mod.HeirAmountIsDustException):
        return 'dust'
    if isinstance(c, (heirs_mod.BalanceTooLowException, will_mod.AmountException)):
        return 'too_low'
    return 'user'


def _welist_order(wes):
    """Sort key of a keeper's url: its place in the public list (welist), best first.

    Owner 15/11 (P5): the price is never the criterion; the welist already
    puts the best keepers first. ``welist_rank`` is stored by
    ``bal_willexecutors_download``; a keeper not in the last download goes
    after the listed ones (sorted() is stable: their order stays).
    """
    def key(url):
        rank = ((wes or {}).get(url) or {}).get('welist_rank')
        return (0, rank) if isinstance(rank, int) else (1, 0)
    return key


def _check_times(checks, url, now):
    """``(checkedAt, downDays)`` of a keeper from the stored checks (P1).

    ``checkedAt``: the time of the last check that asked it (0: never);
    ``downDays``: whole days since the first check of the run of checks it
    has not answered, up to the last one (0 when it answered the last one).
    """
    seen = [c for c in checks or [] if url in (c.get('urls') or {})]
    if not seen:
        return 0, 0
    last = int(seen[-1].get('t') or 0)
    if seen[-1]['urls'][url]:
        return last, 0
    first = last
    for c in reversed(seen):
        if c['urls'][url]:
            break
        first = int(c.get('t') or 0)
    return last, max(0, (now - first) // DAY)


def _is_keeper_url(url, we):
    """A usable entry of the keepers' list (the welist adds ``status``/``url`` keys); no Tor."""
    return isinstance(we, dict) and str(url).startswith('http') and '.onion' not in str(url)


def keeper_health(ok, total, checks, wanted=KEEPERS_DEFAULT):
    """``ok | some | low | none | invalid`` (points 4d, P6), '' without keepers.

    ``wanted`` = the keepers chosen (W: 3, 5 … 19). Owner P6: ask for new
    keepers only when those answering go below W - 1 (no rule on time):
    ``ok`` all answer; ``some`` at least W - 1 answer (quiet, nothing to
    do); ``low`` 1 … W - 2 answer (replace them); ``none`` nobody.
    ``checks`` is the stored list of ``{t, ok, total}`` (oldest first).
    ``invalid``: no keeper answered at the last ``INVALID_CHECKS`` checks
    or more, the first of them at least ``INVALID_DAYS`` days before the
    last one (a check made while the phone was offline is never stored).
    """
    if not total:
        return ''
    if ok <= 0:
        run = []
        for c in reversed(checks or []):
            if int(c.get('ok') or 0) > 0:
                break
            run.append(int(c.get('t') or 0))
        if len(run) >= INVALID_CHECKS and run[0] - run[-1] >= INVALID_DAYS * DAY:
            return 'invalid'
        return 'none'
    if ok >= total:
        return 'ok'
    if ok >= int(wanted or KEEPERS_DEFAULT) - 1:
        return 'some'
    return 'low'


def _newest(items):
    """The will items of the newest copies: those with the earliest delivery.

    An update or a keeper's replacement makes new copies one day earlier;
    the older ones (e.g. the copy of a keeper that stopped answering) may
    still spend coins of the wallet, but are no longer the will in force.
    """
    first = min((it['locktime'] for it in items if it.get('locktime')), default=0)
    return [it for it in items if not first or it.get('locktime') == first]


def _in_use(items, wes):
    """The will items of the keepers in use: those still selected.

    A keeper taken out (it stopped answering: :meth:`QEBal._keepers`,
    :meth:`QEBal.replaceKeepers`) may still hold a valid copy; it is no
    longer counted. When no holder is selected at all (e.g. a review just
    failed with every keeper down) every holder is counted.
    """
    chosen = [it for it in items
              if ((wes or {}).get(it.get('willexecutor')) or {}).get('selected')]
    return chosen or list(items)


def _months_in_force(delivery_, show):
    """The period (months) the will in force was made with, 0 when unknown.

    From ``period_start`` (the day the period started) to the delivery of
    the will in force; an update one day earlier (owner 9.2) rounds to the
    same months.
    """
    start = int(((show or {}).get('period_start') or {}).get('locktime') or 0)
    if not delivery_ or not start or delivery_ <= start:
        return 0
    return int(round((delivery_ - start) / DAY / MONTH_DAYS))


def _inputs(raw):
    """The ``"txid:n"`` coins a will transaction spends."""
    try:
        return [i.prevout.to_str() for i in tx_from_any(raw).inputs()]
    except Exception:
        return []


class _Fail(Exception):
    """A failure with its code for ``failed(op, code, message)``."""

    def __init__(self, code, message=''):
        super().__init__(message)
        self.code = code
        self.message = message


def _empty_state():
    return {
        'available': False, 'online': False, 'synced': False, 'phase': 'none',
        'heirs': [], 'total': 0, 'months': 0, 'monthsInForce': 0,
        'delivery': 0, 'warn': WARN_DEFAULT, 'warnDays': 0, 'warnAt': 0,
        'daysToWarn': 0, 'monthsToDelivery': 0, 'newDelivery': 0, 'now': int(time.time()),
        'balanceSats': 0,
        'keepersWanted': KEEPERS_DEFAULT, 'keepersChoices': list(KEEPERS_CHOICES),
        'keeperMax': KEEPER_MAX_DEFAULT, 'keeperMaxChoices': list(KEEPER_MAX_CHOICES), 'keepersMine': [],
        'custodians': {'wanted': KEEPERS_DEFAULT, 'ok': 0, 'total': 0, 'list': [], 'status': ''},
        'updateReason': '', 'uncoveredSats': 0,
        'fees': {'custodianSats': 0, 'custodianMinSats': 0, 'custodianMaxSats': 0,
                 'minerSats': 0, 'renewSats': 0, 'cancelSats': 0},
            'invalidate': {'coins': [], 'to': ''},
        'detail': '', 'wallet': '',
    }


class QEBal(PluginQObject):
    """The bridge object QML reaches with ``AppController.plugin('bal')``.

    API (plan section 1.2 + owner decisions of section 9): properties
    ``busy``, ``step``, ``state``, ``lastCommand``, ``commandLog``; signals
    ``done(op, result)`` and ``failed(op, code, message)``; slots
    ``refresh``, ``heirSave``, ``heirDelete``, ``setPeriod``, ``setWarn``,
    ``review``, ``confirm``, ``renew``, ``update``, ``checkCustodians``;
    owner 15/11 (points 4, 4c, 4d, 7): ``setKeepers``, ``findKeeper``,
    ``replaceKeepers`` (P6: all the keepers that do not answer in one go), ``cancelWill``.
    """

    stepChanged = pyqtSignal()
    stateChanged = pyqtSignal()
    lastCommandChanged = pyqtSignal()
    commandLogChanged = pyqtSignal()
    done = pyqtSignal(str, 'QVariantMap', arguments=['op', 'result'])
    failed = pyqtSignal(str, str, str, arguments=['op', 'code', 'message'])

    # internal: worker thread -> GUI thread (queued, the receiver lives there)
    _finished = pyqtSignal(str, object)
    _stepFromWorker = pyqtSignal(str)
    _commandFromWorker = pyqtSignal(str)
    _walletUpdated = pyqtSignal()

    def __init__(self, plugin, parent):
        super().__init__(plugin, parent)
        self._name = 'bal'
        self._step = ''
        self._state = _empty_state()
        self._last = ''
        self._log = []
        self._commands_obj = None
        self._local = threading.local()
        self._finished.connect(self._on_finished)
        self._stepFromWorker.connect(self._set_step)
        self._commandFromWorker.connect(self._add_command)
        self._walletUpdated.connect(self._on_wallet_updated)
        util.register_callback(self._on_wallet_event, ['wallet_updated'])

    def unregister(self):
        """Stop listening to the wallet events (tests, plugin close)."""
        util.unregister_callback(self._on_wallet_event)

    # ------------------------------------------------------------------ #
    # Where the wallet, the daemon and the commands come from
    # ------------------------------------------------------------------ #
    def _daemon(self):
        """The running ``Daemon`` (its ``_plugins`` is the app's Plugins)."""
        return self.app.daemon.daemon

    def _wallet(self):
        """The wallet shown now (read at the start of every job)."""
        qw = self.app.daemon.currentWallet
        return qw.wallet if qw is not None else None

    def _commands(self):
        if self._commands_obj is None:
            from electrum.commands import Commands
            daemon = self._daemon()
            self._commands_obj = Commands(config=daemon.config, network=daemon.network, daemon=daemon)
        return self._commands_obj

    def _network(self):
        return getattr(self._daemon(), 'network', None)

    # ------------------------------------------------------------------ #
    # The one door to the plugin
    # ------------------------------------------------------------------ #
    def _cmd(self, name, *args, **kw):
        """Run the Electrum command ``name`` on the job's wallet (worker thread).

        The ONLY place where the bridge changes or reads heirs / will data
        (besides the read-only spender label of :meth:`_spender_label`; the
        bridge's own records ``CHECKS_KEY`` / ``CANCEL_KEY`` are not will data).
        The password is never passed: ``Commands._run`` asks the getter
        ``wallet.get_unlocked_password`` only for a signing command on a
        wallet with a password. Records ``lastCommand`` / ``commandLog``
        (addresses and transactions shortened, never the password). The
        later terminal page reuses this door.
        """
        wallet = self._local.wallet
        parts = [name] + [_short(a) for a in args]
        parts += ['--%s %s' % (k, _short(v)) for k, v in kw.items()]
        self._commandFromWorker.emit(' '.join(parts))
        return self._commands()._run(
            name, args, password_getter=wallet.get_unlocked_password, wallet=wallet, **kw)

    # ------------------------------------------------------------------ #
    # QML properties (``busy`` / ``busyChanged`` come from PluginQObject)
    # ------------------------------------------------------------------ #
    @pyqtProperty(str, notify=stepChanged)
    def step(self):
        return self._step

    @pyqtProperty('QVariantMap', notify=stateChanged)
    def state(self):
        return self._state

    @pyqtProperty(str, notify=lastCommandChanged)
    def lastCommand(self):
        return self._last

    @pyqtProperty('QStringList', notify=commandLogChanged)
    def commandLog(self):
        return list(self._log)

    def _set_busy(self, busy):
        if self._busy != busy:
            self._busy = busy
            self.busyChanged.emit()

    @pyqtSlot(str)
    def _set_step(self, step):
        if self._step != step:
            self._step = step
            self.stepChanged.emit()

    @pyqtSlot(str)
    def _add_command(self, text):
        self._last = text
        self._log = (self._log + [text])[-LOG_SIZE:]
        self.lastCommandChanged.emit()
        self.commandLogChanged.emit()

    # ------------------------------------------------------------------ #
    # Jobs
    # ------------------------------------------------------------------ #
    def _start(self, op, job):
        """Run ``job()`` on a new worker thread; at most one job at a time."""
        if self._busy:
            self.failed.emit(op, 'busy', '')
            return
        wallet = self._wallet()
        if wallet is None:
            self.failed.emit(op, 'user', 'no wallet')
            return
        # owner 17/11: the fee chosen on the page goes to THIS job only (never kept for later)
        fee, self._inv_fee = getattr(self, '_inv_fee', None), None
        self._set_busy(True)
        self._set_step('check' if op == 'refresh' else '')
        threading.Thread(target=self._work, args=(op, job, wallet, fee), daemon=True,
                         name='QEBal-' + op).start()

    def _work(self, op, job, wallet, fee=None):
        """The worker: the job, then the new state, both sent to the GUI thread."""
        self._local.wallet = wallet
        self._local.inv_fee = fee
        try:
            outcome = ('done', job() or {})
        except _Fail as f:
            outcome = ('failed', f.code, f.message)
        except UserFacingException as e:
            outcome = ('failed', _fail_code(e), str(e))
        except Exception as e:
            _logger.error('QEBal %s failed:\n%s', op, traceback.format_exc())
            outcome = ('failed', 'internal', repr(e))
        state = None
        try:
            state = self._read_state(wallet)
        except Exception:
            _logger.error('QEBal state not read:\n%s', traceback.format_exc())
        self._finished.emit(op, (outcome, state))

    @pyqtSlot(str, object)
    def _on_finished(self, op, payload):
        outcome, state = payload
        if state is not None:
            self._state = state
        self._set_step('')
        self._set_busy(False)
        if state is not None:
            self.stateChanged.emit()
        if outcome[0] == 'done':
            self.done.emit(op, outcome[1])
        else:
            self.failed.emit(op, outcome[1], outcome[2])

    def _step_to(self, step):
        self._stepFromWorker.emit(step)

    # the bridge refreshes by itself when the wallet becomes up to date
    def _on_wallet_event(self, *args):
        # Electrum calls it with the wallet (older versions: the event name first)
        wallet = args[-1] if args else None
        try:
            if (wallet is self._wallet() and not self._state.get('synced')
                    and wallet.is_up_to_date()):
                self._walletUpdated.emit()
        except Exception:
            pass

    @pyqtSlot()
    def _on_wallet_updated(self):
        if not self._busy:
            self.refresh()

    # ------------------------------------------------------------------ #
    # Checks shared by the slots
    # ------------------------------------------------------------------ #
    def _need_network(self, wallet):
        network = self._network()
        if network is None or not network.is_connected():
            raise _Fail('offline', 'Internet is needed for the inheritance.')
        if not wallet.is_up_to_date():
            raise _Fail('not_synced', 'The wallet is not up to date yet.')

    def _warn_choice(self):
        value = self.plugin.config.get(WARN_KEY, WARN_DEFAULT)
        return value if value in WARN_FRACTIONS else WARN_DEFAULT

    def _keepers_wanted(self):
        try:
            value = int(self.plugin.config.get(KEEPERS_KEY, KEEPERS_DEFAULT))
        except (TypeError, ValueError):
            return KEEPERS_DEFAULT
        return value if value in KEEPERS_CHOICES else KEEPERS_DEFAULT

    def _keeper_max(self):
        try:
            value = int(self.plugin.config.get(KEEPER_MAX_KEY, KEEPER_MAX_DEFAULT))
        except (TypeError, ValueError):
            return KEEPER_MAX_DEFAULT
        return value if KEEPER_MAX_MIN <= value <= KEEPER_MAX_TOP else KEEPER_MAX_DEFAULT

    def _keepers_mine(self):
        value = self.plugin.config.get(KEEPERS_MINE_KEY, []) or []
        return [str(u) for u in value if isinstance(u, str)]

    def _online_now(self):
        """True when the phone really reaches the internet now (point 4d).

        Connected to the Electrum server, and (when there is a live session)
        the server answers a ``server.ping``. Asked before a check where no
        keeper answered is counted: offline, the check says nothing about them.
        """
        network = self._network()
        if network is None or not network.is_connected():
            return False
        session = getattr(getattr(network, 'interface', None), 'session', None)
        if session is None:
            return True
        try:
            fut = asyncio.run_coroutine_threadsafe(
                asyncio.wait_for(session.send_request('server.ping'), 10), util.get_asyncio_loop())
            fut.result(12)
            return True
        except Exception as e:
            _logger.info('server.ping failed: %r', e)
            return False

    # the bridge's own records in the wallet db (no will data: those go through _cmd)
    @staticmethod
    def _load_checks(wallet):
        try:
            return [c for c in json.loads(wallet.db.get(CHECKS_KEY) or '[]') if isinstance(c, dict)]
        except Exception:
            return []

    @staticmethod
    def _db_put(wallet, key, value):
        """Write one record and save the wallet file.

        The save runs on the asyncio loop thread, as for the ``bal_*``
        commands: Electrum refuses to write the db from a daemon thread
        (the worker is one).
        """
        wallet.db.put(key, value)

        async def save():
            wallet.save_db()
        try:
            asyncio.run_coroutine_threadsafe(save(), util.get_asyncio_loop()).result(20)
        except Exception as e:
            _logger.info('save_db failed: %r', e)

    def _add_check(self, wallet, ok, total, urls):
        checks = self._load_checks(wallet)
        checks.append({'t': int(time.time()), 'ok': int(ok), 'total': int(total), 'urls': urls})
        self._db_put(wallet, CHECKS_KEY, json.dumps(checks[-CHECKS_KEEP:]))
        return checks

    # ------------------------------------------------------------------ #
    # Slots
    # ------------------------------------------------------------------ #
    @pyqtSlot()
    def refresh(self):
        self._start('refresh', lambda: {})

    @pyqtSlot(str, str, str, int)
    def heirSave(self, oldName, name, address, percent):
        def job():
            name_ = name.strip()
            address_ = address.strip()
            if not name_:
                raise _Fail('user', 'Give a name.')
            if not is_address(address_):
                raise _Fail('address', 'This is not a bitcoin address.')
            if not 1 <= int(percent) <= 100:
                raise _Fail('percent', 'The share must be from 1% to 100%.')
            old = None
            if oldName and oldName != name_:
                old = (self._cmd('bal_heirs_list') or {}).get(oldName)
                self._cmd('bal_heirs_delete', oldName)
            try:
                out = self._cmd('bal_heirs_add', name_, address_, '%d%%' % int(percent))
            except Exception:
                if old is not None:  # put the old person back
                    self._cmd('bal_heirs_add', oldName, old[0], old[1])
                raise
            return {'name': name_, 'warning': (out or {}).get('warning') or ''}
        self._start('heirSave', job)

    @pyqtSlot(str)
    def heirDelete(self, name):
        def job():
            self._cmd('bal_heirs_delete', name)
            return {}
        self._start('heirDelete', job)

    def _set_check_alive(self, months, fraction):
        days = warn_days(months, fraction)
        self._cmd('bal_delivery_set', check_alive_days=days)
        return days

    @staticmethod
    def _shown_delivery(show):
        return int((show.get('will_in_force') or {}).get('locktime') or show.get('locktime') or 0)

    @pyqtSlot(int)
    def setPeriod(self, months):
        def job():
            show = self._cmd('bal_delivery_show')
            if show.get('form') != 'period':
                if show.get('will_in_force'):
                    raise _Fail('user', 'This inheritance was made with Àncòra on the '
                                        'computer: change it there.')
                self._cmd('bal_delivery_form', 'period', months=int(months))
                applied = True
            else:
                out = self._cmd('bal_delivery_set', months=int(months))
                applied = not out.get('will_in_force')
            change, _m, _x, y = self._period_change(self._local.wallet)
            if change in ('renew', 'update'):
                # owner 16/11 (Q2): it applies from today, at the confirmation (renewal or
                # free update); until then the will in force and its reminder stay as they are
                days = warn_days(int(months), self._warn_choice())
                return {'applied': False, 'change': change, 'delivery': y, 'warnAt': y - days * DAY}
            days = self._set_check_alive(int(months), self._warn_choice())
            delivery_ = self._shown_delivery(self._cmd('bal_delivery_show'))
            return {'applied': bool(applied), 'change': change, 'delivery': delivery_,
                    'warnAt': delivery_ - days * DAY}
        self._start('setPeriod', job)

    @pyqtSlot(str)
    def setWarn(self, fraction):
        def job():
            if fraction not in WARN_FRACTIONS:
                raise _Fail('user', 'not a reminder choice: %s' % fraction)
            self.plugin.config.set_key(WARN_KEY, fraction, save=True)
            show = self._cmd('bal_delivery_show')
            delivery_ = self._shown_delivery(show)
            # the reminder of the will in force: counted on ITS period (a new period
            # chosen and not confirmed yet does not move it, owner 16/11)
            months = (_months_in_force(delivery_, show) if show.get('will_in_force') else 0) \
                or int(show.get('period_months') or 0)
            if not months:
                return {'warnDays': 0, 'warnAt': 0}
            days = self._set_check_alive(months, fraction)
            return {'warnDays': days, 'warnAt': delivery_ - days * DAY}
        self._start('setWarn', job)

    @pyqtSlot()
    def review(self):
        self._start('review', self._job_review)

    @pyqtSlot()
    def confirm(self):
        self._start('confirm', self._job_confirm)

    @pyqtSlot()
    def renew(self):
        self._start('renew', self._job_renew)

    @pyqtSlot('QVariant')
    def setInvalidationFee(self, fee):
        """owner 17/11: the miner fee of the NEXT invalidation (renewal / cancellation), chosen on
        the page as for a payment: ``{sats, rate, coins}`` (rate in sat/vB, coins the "txid:n"
        the page priced). Set right before ``renew()`` / ``cancelWill()`` / ``confirm()``; used
        once, valid 10 minutes. Without it the invalidation does not start (``no_fee``)."""
        try:
            d = fee.toVariant() if hasattr(fee, 'toVariant') else fee
            d = dict(d or {})
            self._inv_fee = {'sats': int(d.get('sats') or 0), 'rate': float(d.get('rate') or 0),
                             'coins': sorted(str(c) for c in (d.get('coins') or [])),
                             'at': time.monotonic()}
        except Exception as e:
            _logger.error(f'setInvalidationFee: {e!r}')
            self._inv_fee = None

    @pyqtSlot()
    def update(self):
        self._start('update', self._job_update)

    @pyqtSlot()
    def checkCustodians(self):
        self._start('checkCustodians', self._job_check)

    @pyqtSlot(int)
    def setKeepers(self, n):
        def job():
            if int(n) not in KEEPERS_CHOICES:
                raise _Fail('user', 'The keepers must be 3, 5, 7 … 19.')
            self.plugin.config.set_key(KEEPERS_KEY, int(n), save=True)
            return {'keepersWanted': int(n)}
        self._start('setKeepers', job)

    # owner 18/11: the keepers' maximum price and the keepers chosen by hand, set at the EXPERT
    # level (jobs like setKeepers: the new state follows)
    @pyqtSlot(int)
    def setKeeperMax(self, n):
        def job():
            if not KEEPER_MAX_MIN <= int(n) <= KEEPER_MAX_TOP:
                raise _Fail('user', 'Write an amount from 1.000 to 500.000 sats.')
            self.plugin.config.set_key(KEEPER_MAX_KEY, int(n), save=True)
            return {'keeperMax': int(n)}
        self._start('setKeeperMax', job)

    @pyqtSlot('QVariantList')
    def setKeepersMine(self, urls):
        urls = list(dict.fromkeys(str(u) for u in (urls or []) if str(u)))
        def job():
            self.plugin.config.set_key(KEEPERS_MINE_KEY, urls, save=True)
            return {'keepersMine': urls}
        self._start('setKeepersMine', job)

    @pyqtSlot()
    def keepersStandard(self):
        """owner 18/11: out of the EXPERT level: 50 000 sats, keepers chosen by Schȅi."""
        def job():
            self.plugin.config.set_key(KEEPER_MAX_KEY, KEEPER_MAX_DEFAULT, save=True)
            self.plugin.config.set_key(KEEPERS_MINE_KEY, [], save=True)
            return {}
        self._start('keepersStandard', job)

    @pyqtSlot()
    def loadKeeperChoices(self):
        """owner 18/11: the keepers for "Choose the keepers", asked now (see _job_keeper_choices)."""
        self._start('loadKeeperChoices', self._job_keeper_choices)

    @pyqtSlot()
    def findKeeper(self):
        self._start('findKeeper', self._job_find_keeper)

    @pyqtSlot('QVariantList')
    def replaceKeepers(self, urls):
        urls = [str(u) for u in (urls or [])]
        self._start('replaceKeepers', lambda: self._job_replace_keepers(urls))

    @pyqtSlot(bool)
    def cancelWill(self, deleteHeirs):
        self._start('cancelWill', lambda: self._job_cancel(bool(deleteHeirs)))

    # ------------------------------------------------------------------ #
    # The jobs with several commands
    # ------------------------------------------------------------------ #
    def _keepers(self):
        """Make sure ``keepersWanted`` keepers are selected and answer (plan 1.5, owner 4c).

        The fixed pair first (added and selected when missing), then the
        other keepers selected now (a keeper chosen before, e.g. by
        :meth:`replaceKeepers`, is kept), all pinged. If fewer than wanted
        answer, the welist is downloaded and the answering ones (no .onion)
        are selected in the order of the welist (owner P5: never by price)
        up to the number wanted. Fewer answering
        than wanted is fine (one is enough to deliver): all those that
        answer are used. A selected keeper that does not answer is
        deselected (the next review selects the pair again). Returns
        ``[{url, name, ok, feeSats}]``; none answering raises ``custodians``.
        """
        wanted = self._keepers_wanted()
        cap = self._keeper_max()
        self._step_to('ping')
        wes = self._cmd('bal_willexecutors_list') or {}
        mine = self._keepers_mine()
        if mine:
            return self._keepers_mine_only(mine, cap, wes)
        for url in KEEPERS:
            if url not in wes:
                self._cmd('bal_willexecutors_add', url)
            if not (wes.get(url) or {}).get('selected'):
                self._cmd('bal_willexecutors_select', url)
        others = [u for u, we in wes.items()
                  if u not in KEEPERS and _is_keeper_url(u, we) and we.get('selected')]
        first = list(KEEPERS) + others
        pings = self._cmd('bal_willexecutors_ping', first) or {}
        wes = self._cmd('bal_willexecutors_list') or {}
        ok = [u for u in KEEPERS if (pings.get(u) or {}).get('ok')]
        ok += sorted((u for u in others if (pings.get(u) or {}).get('ok')),
                     key=_welist_order(wes))
        dear = [u for u in ok if _fee_of(wes.get(u)) > cap]     # owner 18/11: over the maximum price
        ok = [u for u in ok if u not in dear]
        if len(ok) < wanted:
            try:
                self._cmd('bal_willexecutors_download')
            except Exception as e:
                _logger.info('welist download failed: %r', e)
            wes = self._cmd('bal_willexecutors_list') or {}
            extra = [u for u, we in wes.items() if u not in first and _is_keeper_url(u, we)]
            if extra:
                pings2 = self._cmd('bal_willexecutors_ping', extra) or {}
                wes = self._cmd('bal_willexecutors_list') or {}
                good = sorted((u for u in extra if (pings2.get(u) or {}).get('ok')),
                              key=_welist_order(wes))
                dear += [u for u in good if _fee_of(wes.get(u)) > cap]
                good = [u for u in good if _fee_of(wes.get(u)) <= cap]
                for u in good[:wanted - len(ok)]:
                    self._cmd('bal_willexecutors_select', u)
                    ok.append(u)
        ok = ok[:wanted]
        wes = self._cmd('bal_willexecutors_list') or {}
        for u, we in wes.items():
            if isinstance(we, dict) and we.get('selected') and u not in ok:
                self._cmd('bal_willexecutors_select', u, value=False)
        if not ok and dear:
            raise _Fail('keeper_fee', 'All the keepers ask more than the maximum price.')
        if not ok:
            raise _Fail('custodians', 'No keeper answered.')
        return [{'url': u, 'name': u.split('://')[-1], 'ok': True,
                 'feeSats': _fee_of(wes.get(u))} for u in ok]

    def _keepers_mine_only(self, mine, cap, wes):
        """owner 18/11 (EXPERT level): only the keepers chosen by hand, those that answer and
        ask at most the maximum price; the others are deselected."""
        for url in mine:
            if url not in wes:
                self._cmd('bal_willexecutors_add', url)
            if not (wes.get(url) or {}).get('selected'):
                self._cmd('bal_willexecutors_select', url)
        pings = self._cmd('bal_willexecutors_ping', list(mine)) or {}
        wes = self._cmd('bal_willexecutors_list') or {}
        answering = [u for u in mine if (pings.get(u) or {}).get('ok')]
        ok = [u for u in answering if _fee_of(wes.get(u)) <= cap]
        for u, we in wes.items():
            if isinstance(we, dict) and we.get('selected') and u not in ok:
                self._cmd('bal_willexecutors_select', u, value=False)
        if not ok and answering:
            raise _Fail('keeper_fee', 'All the keepers chosen ask more than the maximum price.')
        if not ok:
            raise _Fail('custodians', 'No keeper answered.')
        return [{'url': u, 'name': u.split('://')[-1], 'ok': True,
                 'feeSats': _fee_of(wes.get(u))} for u in ok]

    def _prepare(self):
        self._step_to('prepare')
        out = self._cmd('bal_will_prepare') or {}
        result = out.get('result')
        if result in ('expired', 'postponed', 'rebuilt_expired'):
            raise _Fail('needs_renew', out.get('message') or '')
        if result not in ('coherent', 'rebuilt'):
            raise _Fail('user', out.get('message') or str(result))
        return out

    def _sign_and_send(self):
        """``bal_will_sign`` + ``bal_will_broadcast``; returns (sent, total)."""
        self._step_to('sign')
        signed = self._cmd('bal_will_sign')
        if signed is None:  # the password getter gave nothing: wallet locked
            raise _Fail('user', 'The wallet is locked.')
        self._step_to('send')
        try:
            out = self._cmd('bal_will_broadcast') or {}
        except UserFacingException as e:
            raise _Fail('not_sent', str(e)) from None
        urls = [u for u in out if not u.startswith('_')]
        failed = out.get('_failed') or {}
        if urls:
            sent = len([u for u in urls if u not in failed])
            if sent:
                self._new_copies_sent()
            return sent, len(urls)
        # nothing left to send: count the keepers already holding the will
        held = {it['willexecutor'] for it in self._live_items(self._local.wallet)
                if it.get('willexecutor') and (it.get('status') or {}).get('PUSHED')}
        if not held:
            raise _Fail('not_sent', 'No keeper took the envelope.')
        return len(held), len(held)

    def _new_copies_sent(self):
        """New copies are with the keepers: the old check results and a cancellation no longer apply."""
        wallet = self._local.wallet
        for key in (CHECKS_KEY, CANCEL_KEY):
            if wallet.db.get(key) is not None:
                self._db_put(wallet, key, None)

    def _period_change(self, wallet):
        """What the period chosen does to the will in force (owner 16/11, Q2).

        Returns ``(change, months, x, y)``: ``x`` the delivery of the will in
        force (signed or sent), ``y`` today (00:00 UTC) + the period chosen
        (``months``, stored by :meth:`setPeriod`). The new period applies FROM
        TODAY: ``renew`` when ``y`` is later than ``x`` (invalidate the will
        in force, paid, then the new will), ``update`` when it is earlier
        (a free update, which may only anticipate), ``none`` when the period
        is the one of the will in force (nothing special: e.g. only the heirs
        changed), ``new`` when no will is in force.
        """
        from .core import delivery as delivery_mod
        show = self._cmd('bal_delivery_show') or {}
        months = int(show.get('period_months') or 0)
        # the will in force: signed or sent copies whose coins are all still here, also
        # when a review has just rebuilt them (new heirs: the old ones are no longer VALID)
        coins = self._coins(wallet)
        held = []
        for it in self._items():
            st = it.get('status') or {}
            ins = _inputs(it['tx']) if it.get('tx') else []
            if ((st.get('PUSHED') or st.get('COMPLETE')) and not st.get('INVALIDATED')
                    and ins and all(i in coins for i in ins)):
                held.append(it)
        if not held or not months or show.get('form') != 'period':
            return 'new', months, 0, 0
        x = self._min_locktime(held)
        now = int(time.time())
        y = int(delivery_mod.add_months(delivery_mod.utc_midnight(now), months))
        # from the day of the reminder an update is refused: only a renewal goes on
        due = now >= x - _days(show.get('threshold')) * DAY
        in_force = _months_in_force(x, show)
        if not due and (not in_force or in_force == months):
            return 'none', months, x, x
        if y > x:
            return 'renew', months, x, y
        if y < x:
            return 'update', months, x, y
        return 'none', months, x, y

    def _job_confirm(self):
        """Sign and send the will reviewed; with a new period, renew or update (owner 16/11).

        ``renew``: :meth:`_job_renew` (invalidation, then the new will from
        today); ``update``: the period from today (``bal_delivery_set
        --months N --confirm_earlier true``), a new prepare, sign and send.
        Heirs changed in the same pass go into that one operation.
        """
        wallet = self._local.wallet
        self._need_network(wallet)
        self._kind_ok(wallet)
        change, months, _x, _y = self._period_change(wallet)
        if change == 'renew':
            return dict(self._job_renew(), change=change)
        if change == 'update':
            self._cmd('bal_delivery_set', months=months, confirm_earlier=True)
            self._set_check_alive(months, self._warn_choice())
            self._keepers()
            self._prepare()
        sent, total = self._sign_and_send()
        out = {'sent': sent, 'total': total, 'change': change}
        if change == 'update':
            out['delivery'] = self._min_locktime(self._live_items(wallet))
        return out

    def _job_review(self):
        wallet = self._local.wallet
        self._need_network(wallet)
        self._kind_ok(wallet)
        heirs = self._cmd('bal_heirs_list') or {}
        if not heirs:
            raise _Fail('no_heirs', 'Add at least one person.')
        if sum(_percent(v[1]) or 0 for v in heirs.values()) != 100:
            raise _Fail('percent', 'The total must be 100%.')
        change, months, x, y = self._period_change(wallet)
        keepers = self._keepers()
        show = self._cmd('bal_delivery_show')
        coins = self._coins(wallet)
        balance = sum(coins.values())
        renew_fee = self._renew_estimate(wallet, len(coins))
        if change == 'renew':
            # nothing is prepared now: the will in force is still there (from the day of
            # the reminder its prepare is refused); renew() prepares after the invalidation
            out = {'result': 'estimate'}
            heir_rows, fee_min, fee_max, miner_fee = self._estimate(heirs, keepers, balance - renew_fee, show)
        else:
            out = self._prepare()
            items = self._live_items(wallet, coins=coins)
            heir_rows, fee_min, fee_max, miner_fee = self._split(_newest(items), heirs, coins)
        delivery_ = self._min_locktime(self._live_items(wallet, coins=coins)) or int(show.get('locktime') or 0)
        days = _days(show.get('threshold'))
        if change in ('renew', 'update'):
            # the new period applies from today (owner 16/11), with its own reminder
            delivery_ = y
            days = warn_days(months, self._warn_choice())
        return {
            'result': out.get('result'),
            # owner 16/11 (Q2): new | none | renew (paid now: changeFeeSats) | update (free)
            'change': change,
            'inForceDelivery': x,
            'changeFeeSats': renew_fee if change == 'renew' else 0,
            'heirs': heir_rows,
            # owner 4b: each keeper's copy has its own fee; one only is paid
            'custodianFeeSats': fee_max,
            'custodianFeeMinSats': fee_min,
            'custodianFeeMaxSats': fee_max,
            'minerFeeSats': miner_fee,
            'renewFeeSats': renew_fee,
            'balanceSats': balance,
            # owner 9.5: a warning only, never a refusal
            'feeWarning': bool(balance and fee_max > balance * FEE_WARN_SHARE),
            'delivery': delivery_,
            'warnAt': delivery_ - days * DAY,
            'custodians': keepers,
            'custodiansWanted': self._keepers_wanted(),
        }

    def _job_update(self):
        wallet = self._local.wallet
        self._need_network(wallet)
        if self._read_state(wallet).get('phase') in ('due', 'expired'):
            raise _Fail('needs_renew', 'The inheritance must be renewed.')
        self._heirs_ready()
        self._keepers()
        self._prepare()
        sent, total = self._sign_and_send()
        return {'delivery': self._min_locktime(self._live_items(wallet)), 'sent': sent, 'total': total}

    def _job_renew(self):
        """Invalidate the will in force, wait until the wallet sees it, make the new one.

        F4: the old will stops being in force as soon as the wallet sees
        the invalidation in the mempool, so the new will is built on the
        still unconfirmed change. If the app stops in between, the next
        state is ``unfinished`` and ``update()`` finishes the job.
        """
        wallet = self._local.wallet
        self._need_network(wallet)
        # owner 17/11: never left without an inheritance. Before the invalidation (which cannot be
        # undone) check what the new will needs: heirs at 100% and keepers that answer. If not,
        # nothing is touched and the will in force stays.
        self._renew_precheck()
        inv = self._invalidate(wallet)
        if inv and not inv['seen']:
            raise _Fail('not_synced', 'The renewal was sent: it is finished the next time.')
        months = int((self._cmd('bal_delivery_show') or {}).get('period_months') or 0)
        if months:
            # the new will's reminder, counted on the period stored (owner 16/11, Q2)
            self._set_check_alive(months, self._warn_choice())
        self._keepers()
        self._prepare()
        sent, total = self._sign_and_send()
        return {'delivery': self._min_locktime(self._live_items(wallet)), 'sent': sent,
                'total': total, 'feeSats': inv['feeSats'] if inv else 0}

    def _kind_ok(self, wallet):
        """controllo-mainnet 2.6: the inheritance works only on native segwit (bc1q...) coins
        (bal core/heirs.py only_native_segwit): say it at once, not at the end."""
        from electrum.bitcoin import is_segwit_address
        kind = getattr(wallet, 'txin_type', None)
        bad_kind = kind is not None and kind not in ('p2wpkh', 'p2wsh')
        bad_coin = any(not is_segwit_address(c.get('address') or '')
                       for c in (self._cmd('listunspent') or []))
        if bad_kind or bad_coin:
            raise _Fail('address_kind', 'The inheritance works only with bc1 addresses.')

    def _heirs_ready(self):
        """M2 (owner 17/11): at least one person and the shares at 100%, before any new will."""
        heirs = self._cmd('bal_heirs_list') or {}
        if not heirs:
            raise _Fail('no_heirs', 'Add at least one person.')
        if sum(_percent(v[1]) or 0 for v in heirs.values()) != 100:
            raise _Fail('percent', 'The total must be 100%.')
        self._kind_ok(self._local.wallet)

    def _renew_precheck(self):
        """What a renewal needs before its invalidation: heirs at 100% and keepers that answer."""
        self._heirs_ready()
        self._keepers()

    def _invalidate(self, wallet, on_sent=None):
        """``bal_will_invalidate`` + ``signtransaction`` + ``broadcast``, then wait (F4).

        Returns ``None`` when there is nothing to invalidate, else
        ``{txid, feeSats, seen}`` (``seen``: the wallet has the transaction).
        ``on_sent(txid)`` is called right after the broadcast.
        """
        self._step_to('invalidate')
        fee, self._local.inv_fee = getattr(self._local, 'inv_fee', None), None
        inv = self._cmd('bal_will_invalidate') or {}
        if not inv.get('tx'):
            return None
        if not fee or fee['sats'] <= 0 or time.monotonic() - fee['at'] > 600:
            raise _Fail('no_fee', 'Choose the cost of the operation.')
        coins = self._coins(wallet)
        unsigned = self._with_fee(wallet, tx_from_any(inv['tx']), coins, fee)
        signed = self._cmd('signtransaction', unsigned)
        if not signed:
            raise _Fail('user', 'The wallet is locked.')
        tx = tx_from_any(signed)
        # the chosen fee changed the txid: the label of an invalidation goes on the new one
        # (as BalController.invalidate_will), so a renewal cut in half reads "unfinished"
        from .engine.invalidate import INVALIDATION_LABEL
        if tx.txid():
            wallet.set_label(tx.txid(), INVALIDATION_LABEL)
        fee = sum(coins.get(i.prevout.to_str(), 0) for i in tx.inputs()) \
            - sum(o.value for o in tx.outputs())
        self._step_to('broadcast')
        try:
            txid = self._cmd('broadcast', signed) or tx.txid()
        except Exception as e:
            raise _Fail('offline', str(e)) from None
        if on_sent is not None:
            on_sent(txid)
        self._step_to('wait')
        return {'txid': txid, 'feeSats': max(0, int(fee)), 'seen': self._wait_seen(wallet, txid)}

    def _with_fee(self, wallet, tx, coins, fee):
        """The invalidation ``tx`` (all the will coins -> one own address) paying ``fee``:
        exactly ``fee['sats']`` when it spends the coins the page priced, else ``rate`` x size."""
        outs = tx.outputs()
        if len(outs) != 1:
            raise _Fail('internal', 'Unexpected invalidation transaction.')
        ins = sorted(i.prevout.to_str() for i in tx.inputs())
        total = sum(coins.get(i, 0) for i in ins)
        if ins == fee['coins']:
            sats = fee['sats']
        else:
            for txin in tx.inputs():      # the scripts, or the size misses the signatures
                wallet.add_input_info(txin)
            sats = int(math.ceil(tx.estimated_size() * fee['rate']))
        if sats <= 0 or total - sats < 546:
            raise _Fail('no_fee', 'The cost is not right for this operation.')
        outs[0].value = total - sats
        tx.invalidate_ser_cache()
        return tx.serialize()

    def _job_cancel(self, delete_heirs):
        """Point 7: invalidate the will on the blockchain; then, if asked, delete every heir.

        The txid of the cancellation is kept in the wallet db, so the state
        reads ``draft`` (heirs kept) and not ``unfinished`` (a renewal cut
        in half, which spends the coins the same way).
        """
        wallet = self._local.wallet
        self._need_network(wallet)
        inv = self._invalidate(wallet, on_sent=lambda txid: self._db_put(wallet, CANCEL_KEY, txid))
        if inv is None:
            raise _Fail('user', 'There is no inheritance to cancel.')
        if not inv['seen']:
            # the heirs stay: until the wallet sees the cancellation the will looks in force
            raise _Fail('not_synced', 'The cancellation was sent: the wallet sees it soon.')
        if delete_heirs:
            names = list((self._cmd('bal_heirs_list') or {}).keys())
            if names:
                self._cmd('bal_heirs_delete', names)
        return {'feeSats': inv['feeSats'], 'txid': inv['txid']}

    def _job_check(self):
        """Ask the keepers whether they hold their copy; store the result (point 4d).

        A check where no keeper answered is stored only when the phone is
        really online (:meth:`_online_now`); offline it fails ``offline``
        and counts for nothing.
        """
        wallet = self._local.wallet
        self._need_network(wallet)
        self._step_to('check')
        out = self._cmd('bal_will_check_executor') or {}
        wes = self._cmd('bal_willexecutors_list') or {}
        live = {it['txid']: it for it in _in_use(_newest(self._live_items(wallet)), wes)}
        urls = {}
        for it in live.values():
            if it.get('willexecutor') and (it.get('status') or {}).get('PUSHED'):
                urls.setdefault(it['willexecutor'], False)
        for wid, v in out.items():
            if wid in live and v.get('url') in urls:
                ok = bool(v.get('checked')) and not v.get('check_fail')
                urls[v['url']] = urls[v['url']] or ok
        ok = sum(1 for v in urls.values() if v)
        if not ok and not self._online_now():
            raise _Fail('offline', 'Internet is needed for the inheritance.')
        checks = self._load_checks(wallet)
        if urls:
            checks = self._add_check(wallet, ok, len(urls), urls)
        return {'ok': ok, 'total': len(urls),
                'status': keeper_health(ok, len(urls), checks, self._keepers_wanted())}

    def _job_keeper_choices(self):
        """owner 18/11: the public list downloaded again and every keeper asked now: only those
        that answer, with the price they give (never the placeholder of a keeper never contacted),
        best first (welist order). A keeper chosen before that does not answer is listed too
        (``ok`` False, no price) so it can be turned off. ``{keepers: [{url, name, feeSats, mine, ok}]}``"""
        try:
            self._cmd('bal_willexecutors_download')
        except Exception as e:
            _logger.info('welist download failed: %r', e)
        wes = self._cmd('bal_willexecutors_list') or {}
        mine = self._keepers_mine()
        urls = list(dict.fromkeys([u for u, we in wes.items() if _is_keeper_url(u, we)] + mine))
        pings = (self._cmd('bal_willexecutors_ping', urls) or {}) if urls else {}
        if not any((p or {}).get('ok') for p in pings.values()) and not self._online_now():
            raise _Fail('offline', 'Internet is needed.')
        wes = self._cmd('bal_willexecutors_list') or {}
        rows = [{'url': u, 'name': u.split('://')[-1], 'feeSats': _fee_of(wes.get(u)),
                 'mine': u in mine, 'ok': True}
                for u in urls if (pings.get(u) or {}).get('ok')]
        rows.sort(key=lambda r: _welist_order(wes)(r['url']))
        rows += [{'url': u, 'name': u.split('://')[-1], 'feeSats': 0, 'mine': True, 'ok': False}
                 for u in mine if not (pings.get(u) or {}).get('ok')]
        return {'keepers': rows}

    def _job_find_keeper(self):
        """Points 4d, P6 «Sostituisci quelli che non rispondono», step 1: new keepers.

        Returns ``{candidates: [{url, name, feeSats, ok, used}], picks, need,
        pick}``: ``need`` = the keepers of the will in force that do not
        answer (at least 1); ``picks`` = the first ``need`` free ones that
        answer (``pick`` = the first of them). ``used`` = selected now or
        holding the will; the rows and ``picks`` follow the order of the
        welist (owner P5: never by price). Fewer free than needed: the ones
        found. None free: ``failed('custodians')``.
        """
        wallet = self._local.wallet
        self._need_network(wallet)
        cust = self._read_state(wallet).get('custodians') or {}
        need = max(1, int(cust.get('total') or 0) - int(cust.get('ok') or 0))
        self._step_to('ping')
        try:
            self._cmd('bal_willexecutors_download')
        except Exception as e:
            _logger.info('welist download failed: %r', e)
        wes = self._cmd('bal_willexecutors_list') or {}
        used = {u for u, we in wes.items() if isinstance(we, dict) and we.get('selected')}
        used.update(it['willexecutor'] for it in self._live_items(wallet) if it.get('willexecutor'))
        urls = [u for u, we in wes.items() if _is_keeper_url(u, we)]
        pings = (self._cmd('bal_willexecutors_ping', urls) or {}) if urls else {}
        wes = self._cmd('bal_willexecutors_list') or {}
        rows = [{'url': u, 'name': u.split('://')[-1], 'feeSats': _fee_of(wes.get(u)),
                 'ok': bool((pings.get(u) or {}).get('ok')), 'used': u in used} for u in urls]
        order = _welist_order(wes)
        rows.sort(key=lambda r: (not r['used'], order(r['url'])))
        free = [r for r in rows if r['ok'] and not r['used']]
        if not free:
            raise _Fail('custodians', 'No other keeper is free now.')
        picks = [r['url'] for r in free[:need]]
        return {'candidates': rows, 'picks': picks, 'need': need, 'pick': picks[0]}

    def _job_replace_keepers(self, urls):
        """Points 4d, P6 step 2: the keepers that do not answer out, ``urls`` in, ONE new will.

        All the new keepers in one go: one prepare, one signature (one PIN,
        asked by the page before), one sending; the delivery stays the same
        (the core adds a copy for every new keeper). A new keeper that does
        not answer now is left out; none answering: ``failed('custodians')``.
        Returns ``{delivery, ok, total, added}``.
        """
        wallet = self._local.wallet
        self._need_network(wallet)
        phase = self._read_state(wallet).get('phase')
        if phase in ('due', 'expired'):
            raise _Fail('needs_renew', 'The inheritance must be renewed.')
        if phase not in ('active', 'needs_update', 'unfinished'):
            raise _Fail('user', 'There is no inheritance in force.')
        self._heirs_ready()
        new = list(dict.fromkeys(u for u in urls or [] if u))
        if not new:
            raise _Fail('user', 'No keeper chosen.')
        self._step_to('ping')
        wes = self._cmd('bal_willexecutors_list') or {}
        if any(not _is_keeper_url(u, wes.get(u)) for u in new):
            raise _Fail('user', 'This keeper is not in the list.')
        selected = [u for u, we in wes.items() if isinstance(we, dict) and we.get('selected')]
        pings = self._cmd('bal_willexecutors_ping', list(dict.fromkeys(selected + new))) or {}
        new = [u for u in new if (pings.get(u) or {}).get('ok')]
        if not new:
            raise _Fail('custodians', 'This keeper does not answer.')
        for u in selected:
            if not (pings.get(u) or {}).get('ok'):
                self._cmd('bal_willexecutors_select', u, value=False)
        for u in new:
            self._cmd('bal_willexecutors_select', u)
        self._prepare()
        self._sign_and_send()
        wes = self._cmd('bal_willexecutors_list') or {}
        live = self._live_items(wallet)
        held = {}
        for it in _in_use(_newest(live), wes):
            if it.get('willexecutor'):
                held[it['willexecutor']] = held.get(it['willexecutor'], False)                     or bool((it.get('status') or {}).get('PUSHED'))
        return {'delivery': self._min_locktime(live), 'ok': sum(held.values()), 'total': len(held),
                'added': len(new)}

    def _wait_seen(self, wallet, txid, timeout=WAIT_INVALIDATION):
        """Wait until the wallet has ``txid`` in the mempool or mined (F4)."""
        end = time.monotonic() + timeout
        while True:
            if (wallet.adb.get_transaction(txid) is not None
                    and wallet.adb.get_tx_height(txid).height() > -2):
                return True
            if time.monotonic() >= end:
                return False
            time.sleep(0.3)

    # ------------------------------------------------------------------ #
    # Reading the state (worker thread)
    # ------------------------------------------------------------------ #
    def _coins(self, wallet):
        """``{"txid:n": sats}`` of the wallet coins (``listunspent``)."""
        return {'%s:%s' % (c['prevout_hash'], c['prevout_n']): _sats(c['value'])
                for c in (self._cmd('listunspent') or [])}

    def _items(self):
        return (self._cmd('bal_will_status') or {}).get('items') or []

    def _live_items(self, wallet, items=None, coins=None):
        """The VALID will items whose coins are all still in the wallet."""
        items = self._items() if items is None else items
        coins = self._coins(wallet) if coins is None else coins
        live = []
        for it in items:
            st = it.get('status') or {}
            if not st.get('VALID') or st.get('INVALIDATED') or not it.get('tx'):
                continue
            ins = _inputs(it['tx'])
            if ins and all(i in coins for i in ins):
                live.append(it)
        return live

    @staticmethod
    def _min_locktime(items):
        return int(min((it['locktime'] for it in items if it.get('locktime')), default=0))

    def _split(self, items, heirs, coins):
        """Heir sats and miner fee of the first copy; min and max keeper fee of all copies.

        Owner 4b: every keeper holds its own copy, with its own fee output
        (the outputs that go to no heir); one copy only is executed. A
        keeper with several copies counts with its highest fee.
        """
        if not items:
            rows = [{'name': n, 'percent': _percent(v[1]) or 0, 'sats': 0} for n, v in heirs.items()]
            return rows, 0, 0, 0
        heir_addrs = {v[0] for v in heirs.values()}
        by_keeper = {}
        first_outs = None
        for it in items:
            outs = {}
            for o in tx_from_any(it['tx']).outputs():
                outs[o.address] = outs.get(o.address, 0) + o.value
            if first_outs is None:
                first_outs = outs
            fee = sum(val for a, val in outs.items() if a not in heir_addrs)
            key = it.get('willexecutor') or ''
            by_keeper[key] = max(by_keeper.get(key, 0), int(fee))
        # controllo-mainnet 2.8: heirs sharing one address share its output by their percent
        share = {}
        for v in heirs.values():
            share[v[0]] = share.get(v[0], 0) + (_percent(v[1]) or 0)

        def sats_of(v):
            total = int(first_outs.get(v[0], 0))
            whole = share.get(v[0]) or 0
            return total if whole <= 0 else total * (_percent(v[1]) or 0) // whole
        rows = [{'name': n, 'percent': _percent(v[1]) or 0, 'sats': sats_of(v)} for n, v in heirs.items()]
        miner = sum(coins.get(i, 0) for i in _inputs(items[0]['tx'])) - sum(first_outs.values())
        fees = list(by_keeper.values())
        return rows, min(fees), max(fees), int(max(0, miner))

    def _estimate(self, heirs, keepers, balance, show):
        """Heir sats and fees of a will not prepared yet (a renewal: one coin after the invalidation)."""
        fees = [int(k.get('feeSats') or 0) for k in keepers] or [0]
        vbytes = 11 + 68 + 31 * (len(heirs) + 1)
        miner = int(round(vbytes * float(show.get('baltx_fees') or 1)))
        left = max(0, int(balance) - miner - max(fees))
        rows = [{'name': n, 'percent': _percent(v[1]) or 0,
                 'sats': left * (_percent(v[1]) or 0) // 100} for n, v in heirs.items()]
        return rows, min(fees), max(fees), miner

    def _renew_estimate(self, wallet, n_inputs):
        """About what a FUTURE renewal costs (plan 1.4), only to be shown in advance.

        owner 17/11: the network estimate of the invalidation (Will.get_invalidation_fee_rate,
        the same blocks), never baltx_fees: 0 when the servers give no estimate. What is
        really paid is chosen on the page, like a payment (setInvalidationFee).
        """
        from .core.will import INVALIDATION_FEE_ETA_BLOCKS
        try:
            network = self._network()
            per_kvb = network.fee_estimates.eta_target_to_fee(INVALIDATION_FEE_ETA_BLOCKS) if network else None
        except Exception:
            per_kvb = None
        if not isinstance(per_kvb, int) or isinstance(per_kvb, bool) or per_kvb <= 0:
            return 0
        vbytes = 11 + 68 * max(1, n_inputs) + 31
        return int(math.ceil(vbytes * per_kvb / 1000))

    def _invalidate_info(self, wallet, items):
        """``{coins, to}``: the coins the invalidation would spend (every will input still in the
        wallet and on the network) and an own address, so the page can price it as a payment."""
        ins = {i for it in items if it.get('tx') for i in _inputs(it['tx'])}
        coins = []
        for c in (self._cmd('listunspent') or []):
            key = '%s:%s' % (c['prevout_hash'], c['prevout_n'])
            if key in ins and int(c.get('height') or 0) not in (-2, -3):   # not local / future
                coins.append(key)
        to = ''
        if coins:
            try:
                to = wallet.get_change_addresses_for_new_transaction()[0]
            except Exception:
                to = ''
        return {'coins': sorted(coins), 'to': to}

    @staticmethod
    def _spender_txid(wallet, outpoint):
        """The txid of the transaction that spent ``outpoint`` (None if none). Read only."""
        txid, n = outpoint.split(':')
        return wallet.db.get_spent_outpoint(txid, int(n))

    @classmethod
    def _spender_label(cls, wallet, outpoint):
        """The label of the transaction that spent ``outpoint`` ('' if none). Read only."""
        spender = cls._spender_txid(wallet, outpoint)
        return (wallet.get_label_for_txid(spender) or '') if spender else ''

    def _read_state(self, wallet):
        """The ``state`` map of plan 1.2 (worker thread, commands only)."""
        from .core import delivery as delivery_mod
        from .core.will_versions import INVALIDATION_LABELS
        now = int(time.time())
        network = self._network()
        s = _empty_state()
        s['now'] = now
        # owner 17/11: whose state this is (the pages ignore a state of another wallet)
        s['wallet'] = wallet.basename()
        s['available'] = not wallet.is_watching_only()
        s['online'] = bool(network and network.is_connected())
        s['synced'] = bool(wallet.is_up_to_date())
        s['warn'] = self._warn_choice()
        heirs = self._cmd('bal_heirs_list') or {}
        show = self._cmd('bal_delivery_show') or {}
        items = self._items()
        wes = self._cmd('bal_willexecutors_list') or {}
        coins = self._coins(wallet)
        s['balanceSats'] = sum(coins.values())
        s['detail'] = show.get('message') or ''

        # Schȅi handles only percentages to addresses, one delivery, single-sig
        foreign = bool(show.get('staged')) or wallet.wallet_type not in ('standard', 'imported')
        rows = []
        for name, v in heirs.items():
            pct = _percent(v[1])
            if pct is None or str(v[0]).upper().startswith('OP_RETURN'):
                foreign = True
            rows.append({'name': name, 'address': v[0], 'percent': pct or 0})
        s['heirs'] = rows
        s['total'] = sum(r['percent'] for r in rows)

        live = self._live_items(wallet, items, coins)
        delivery_ = self._min_locktime(live)
        if live and show.get('form') != 'period':
            foreign = True
        period = int(show.get('period_months') or 0)
        # owner 16/11 (Q2): the period chosen applies from today (renewal or free
        # update, at the confirmation); monthsInForce = the period of the will in force
        s['months'] = period
        s['monthsInForce'] = _months_in_force(delivery_, show) if live else 0
        s['delivery'] = delivery_ or int(show.get('locktime') or 0)
        days = _days(show.get('threshold'))
        s['warnDays'] = days
        s['warnAt'] = s['delivery'] - days * DAY if s['delivery'] else 0
        s['daysToWarn'] = max(0, (s['warnAt'] - now) // DAY) if s['warnAt'] else 0
        s['monthsToDelivery'] = max(0, int(round((s['delivery'] - now) / DAY / MONTH_DAYS))) \
            if s['delivery'] else 0
        if period:
            s['newDelivery'] = int(delivery_mod.add_months(delivery_mod.utc_midnight(now), period))

        # keepers: those holding the newest copies of the will in force, else the selected ones
        wanted = self._keepers_wanted()
        s['keepersWanted'] = wanted
        s['keeperMax'] = self._keeper_max()
        s['keepersMine'] = self._keepers_mine()
        newest = _in_use(_newest(live), wes)
        checks = self._load_checks(wallet) if live else []
        last = (checks[-1].get('urls') or {}) if checks else {}
        if live:
            by_url = {}
            for it in newest:
                url = it.get('willexecutor')
                if not url:
                    continue
                st = it.get('status') or {}
                c = by_url.setdefault(url, {
                    'url': url, 'name': url.split('://')[-1], 'feeSats': _fee_of(wes.get(url)),
                    'sent': False, 'checked': False, 'ok': False, 'checkedAt': 0, 'downDays': 0})
                c['sent'] = c['sent'] or bool(st.get('PUSHED'))
                c['checked'] = c['checked'] or (bool(st.get('CHECKED')) and not st.get('CHECK_FAIL'))
            cust = list(by_url.values())
            for c in cust:
                # a keeper holding its copy is fine until a check says it does not answer
                c['ok'] = c['sent'] and bool(last.get(c['url'], True))
                c['checkedAt'], c['downDays'] = _check_times(checks, c['url'], now)
        else:
            cust = [{'url': u, 'name': u.split('://')[-1], 'feeSats': _fee_of(we),
                     'sent': False, 'checked': False, 'ok': False, 'checkedAt': 0, 'downDays': 0}
                    for u, we in wes.items() if isinstance(we, dict) and we.get('selected')]
        ok = sum(1 for c in cust if c['ok'])
        s['custodians'] = {'wanted': wanted, 'ok': ok, 'total': len(cust), 'list': cust,
                           'status': keeper_health(ok, len(cust), checks, wanted) if live else ''}
        _rows, fee_min, fee_max, miner_fee = self._split(newest, heirs, coins)
        renew = self._renew_estimate(wallet, len(coins))
        s['invalidate'] = self._invalidate_info(wallet, items)
        s['fees'] = {'custodianSats': fee_max, 'custodianMinSats': fee_min,
                     'custodianMaxSats': fee_max, 'minerSats': miner_fee,
                     'renewSats': renew, 'cancelSats': renew}

        covered = set()
        for it in live:
            covered.update(_inputs(it['tx']))
        s['uncoveredSats'] = sum(v for k, v in coins.items() if k not in covered) if live else 0
        # the will items that were the will in force until their coins were spent
        stale = [it for it in items if it.get('tx') and it not in live
                 and (it.get('status') or {}).get('VALID')
                 and not (it.get('status') or {}).get('INVALIDATED')]
        if not stale:
            stale = [it for it in items if it.get('tx') and (it.get('status') or {}).get('INVALIDATED')
                     and not any(i in coins for i in _inputs(it['tx']))][-1:]
        if foreign:
            phase = 'foreign'
        elif live:
            sent = [it for it in live if (it.get('status') or {}).get('PUSHED')]
            signed = [it for it in live if (it.get('status') or {}).get('COMPLETE')]
            if not sent or not signed:
                phase, s['updateReason'] = 'unfinished', 'unfinished'
            elif now >= delivery_:
                phase = 'expired'
            elif now >= s['warnAt']:
                phase = 'due'
            elif s['uncoveredSats'] > 0:
                phase, s['updateReason'] = 'needs_update', 'received'
            else:
                phase = 'active'
                try:
                    if not (self._cmd('bal_will_check') or {}).get('valid', True):
                        phase, s['updateReason'] = 'needs_update', 'changed'
                except Exception as e:
                    s['detail'] = str(e)
                    phase, s['updateReason'] = 'needs_update', 'changed'
        elif stale and rows:
            # the coins of the will were spent: by its invalidation (a renewal
            # not finished, plan 8.9) or by a payment (to be updated)
            spent = [i for it in stale for i in _inputs(it['tx']) if i not in coins]
            cancel = wallet.db.get(CANCEL_KEY)
            labels = {self._spender_label(wallet, i) for i in spent}
            if cancel and cancel in {self._spender_txid(wallet, i) for i in spent}:
                phase = 'draft'      # point 7: cancelled on purpose, the heirs kept
            elif labels & set(INVALIDATION_LABELS):   # the new text or the old one
                phase, s['updateReason'] = 'unfinished', 'unfinished'
            else:
                phase, s['updateReason'] = 'needs_update', 'spent'
        elif rows:
            phase = 'draft'
        else:
            phase = 'none'
        s['phase'] = phase
        return s


class Plugin(CliPlugin):
    """The bal plugin in Schȅi: the headless plugin plus the QML bridge."""

    def __init__(self, parent, config, name):
        CliPlugin.__init__(self, parent, config, name)
        self.so = None

    @hook
    def init_qml(self, app):
        # F7: never save the will transactions as wallet-local transactions
        # in Schȅi (the coins would look spent, Send would see no coins).
        self.config.set_key('bal_save_history', False, save=True)
        # parented to the app: a reference kept only in the plugin is not enough against gc
        self.so = QEBal(self, app)
        _logger.info('bal: QML bridge ready')
