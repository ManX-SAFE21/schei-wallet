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
  pages before ``confirm()``, ``renew()`` and ``update()``;
* ``bal_save_history`` is turned OFF at start: Schȅi must not save the will
  transactions as wallet-local transactions (the coins would look spent).

Schȅi ships the plugin as an internal plugin (electrum/plugins/bal), so a
normal relative import is enough here (no zip loading on Android).
"""

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
#: The two keepers (will-executors) Schȅi uses, on every chain (owner, plan 1.5 / 9.4).
KEEPERS = ('https://we.bitcoin-after.life', 'https://we.safe21.io')
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
        'heirs': [], 'total': 0, 'months': 0, 'pendingMonths': 0,
        'delivery': 0, 'warn': WARN_DEFAULT, 'warnDays': 0, 'warnAt': 0,
        'daysToWarn': 0, 'monthsToDelivery': 0, 'newDelivery': 0, 'now': int(time.time()),
        'balanceSats': 0,
        'custodians': {'ok': 0, 'total': 0, 'list': []},
        'updateReason': '', 'uncoveredSats': 0,
        'fees': {'custodianSats': 0, 'minerSats': 0, 'renewSats': 0},
        'detail': '',
    }


class QEBal(PluginQObject):
    """The bridge object QML reaches with ``AppController.plugin('bal')``.

    API (plan section 1.2 + owner decisions of section 9): properties
    ``busy``, ``step``, ``state``, ``lastCommand``, ``commandLog``; signals
    ``done(op, result)`` and ``failed(op, code, message)``; slots
    ``refresh``, ``heirSave``, ``heirDelete``, ``setPeriod``, ``setWarn``,
    ``review``, ``confirm``, ``renew``, ``update``, ``checkCustodians``.
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
        (besides the read-only spender label of :meth:`_spender_label`).
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
        self._set_busy(True)
        self._set_step('check' if op == 'refresh' else '')
        threading.Thread(target=self._work, args=(op, job, wallet), daemon=True,
                         name='QEBal-' + op).start()

    def _work(self, op, job, wallet):
        """The worker: the job, then the new state, both sent to the GUI thread."""
        self._local.wallet = wallet
        try:
            outcome = ('done', job() or {})
        except _Fail as f:
            outcome = ('failed', f.code, f.message)
        except UserFacingException as e:
            outcome = ('failed', 'user', str(e))
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
            days = self._set_check_alive(int(months), self._warn_choice())
            delivery_ = self._shown_delivery(self._cmd('bal_delivery_show'))
            return {'applied': bool(applied), 'delivery': delivery_, 'warnAt': delivery_ - days * DAY}
        self._start('setPeriod', job)

    @pyqtSlot(str)
    def setWarn(self, fraction):
        def job():
            if fraction not in WARN_FRACTIONS:
                raise _Fail('user', 'not a reminder choice: %s' % fraction)
            self.plugin.config.set_key(WARN_KEY, fraction, save=True)
            show = self._cmd('bal_delivery_show')
            months = int(show.get('period_months') or 0)
            if not months:
                return {'warnDays': 0, 'warnAt': 0}
            days = self._set_check_alive(months, fraction)
            delivery_ = self._shown_delivery(show)
            return {'warnDays': days, 'warnAt': delivery_ - days * DAY}
        self._start('setWarn', job)

    @pyqtSlot()
    def review(self):
        self._start('review', self._job_review)

    @pyqtSlot()
    def confirm(self):
        def job():
            self._need_network(self._local.wallet)
            sent, total = self._sign_and_send()
            return {'sent': sent, 'total': total}
        self._start('confirm', job)

    @pyqtSlot()
    def renew(self):
        self._start('renew', self._job_renew)

    @pyqtSlot()
    def update(self):
        self._start('update', self._job_update)

    @pyqtSlot()
    def checkCustodians(self):
        def job():
            self._need_network(self._local.wallet)
            self._step_to('check')
            out = self._cmd('bal_will_check_executor') or {}
            live = {it['txid'] for it in self._live_items(self._local.wallet)}
            urls = {}
            for wid, v in out.items():
                if wid in live and v.get('url'):
                    ok = bool(v.get('checked')) and not v.get('check_fail')
                    urls[v['url']] = urls.get(v['url'], False) or ok
            return {'ok': sum(1 for v in urls.values() if v), 'total': len(urls)}
        self._start('checkCustodians', job)

    # ------------------------------------------------------------------ #
    # The jobs with several commands
    # ------------------------------------------------------------------ #
    def _keepers(self):
        """Make sure the keepers are selected and answer (plan 1.5).

        The fixed pair first (added and selected when missing), pinged; if
        fewer than 2 answer, the welist is downloaded and the cheapest
        answering ones (no .onion) are selected up to 2. A selected keeper
        that does not answer is deselected (the next review selects the
        pair again). Returns ``[{url, name, ok, feeSats}]``; none answering
        raises ``custodians``.
        """
        self._step_to('ping')
        wes = self._cmd('bal_willexecutors_list') or {}
        for url in KEEPERS:
            if url not in wes:
                self._cmd('bal_willexecutors_add', url)
            if not (wes.get(url) or {}).get('selected'):
                self._cmd('bal_willexecutors_select', url)
        pings = self._cmd('bal_willexecutors_ping', list(KEEPERS)) or {}
        ok = [u for u in KEEPERS if (pings.get(u) or {}).get('ok')]
        if len(ok) < 2:
            try:
                self._cmd('bal_willexecutors_download')
            except Exception as e:
                _logger.info('welist download failed: %r', e)
            wes = self._cmd('bal_willexecutors_list') or {}
            extra = [u for u in wes if u not in KEEPERS and '.onion' not in u]
            if extra:
                pings2 = self._cmd('bal_willexecutors_ping', extra) or {}
                wes = self._cmd('bal_willexecutors_list') or {}
                good = sorted((u for u in extra if (pings2.get(u) or {}).get('ok')),
                              key=lambda u: int(wes[u].get('base_fee') or 0))
                for u in good[:2 - len(ok)]:
                    self._cmd('bal_willexecutors_select', u)
                    ok.append(u)
        wes = self._cmd('bal_willexecutors_list') or {}
        for u, we in wes.items():
            if we.get('selected') and u not in ok:
                self._cmd('bal_willexecutors_select', u, value=False)
        if not ok:
            raise _Fail('custodians', 'No keeper answered.')
        return [{'url': u, 'name': u.split('://')[-1], 'ok': True,
                 'feeSats': int(wes[u].get('base_fee') or 0)} for u in ok]

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
            return len([u for u in urls if u not in failed]), len(urls)
        # nothing left to send: count the keepers already holding the will
        held = {it['willexecutor'] for it in self._live_items(self._local.wallet)
                if it.get('willexecutor') and (it.get('status') or {}).get('PUSHED')}
        if not held:
            raise _Fail('not_sent', 'No keeper took the envelope.')
        return len(held), len(held)

    def _job_review(self):
        wallet = self._local.wallet
        self._need_network(wallet)
        heirs = self._cmd('bal_heirs_list') or {}
        if not heirs:
            raise _Fail('no_heirs', 'Add at least one person.')
        if sum(_percent(v[1]) or 0 for v in heirs.values()) != 100:
            raise _Fail('percent', 'The total must be 100%.')
        keepers = self._keepers()
        out = self._prepare()
        coins = self._coins(wallet)
        balance = sum(coins.values())
        items = self._live_items(wallet, coins=coins)
        heir_rows, keeper_fee, miner_fee = self._split(items, heirs, coins)
        show = self._cmd('bal_delivery_show')
        delivery_ = self._min_locktime(items) or int(show.get('locktime') or 0)
        days = _days(show.get('threshold'))
        return {
            'result': out.get('result'),
            'heirs': heir_rows,
            'custodianFeeSats': keeper_fee,
            'minerFeeSats': miner_fee,
            'renewFeeSats': self._renew_estimate(len(coins), show),
            'balanceSats': balance,
            # owner 9.5: a warning only, never a refusal
            'feeWarning': bool(balance and keeper_fee > balance * FEE_WARN_SHARE),
            'delivery': delivery_,
            'warnAt': delivery_ - days * DAY,
            'custodians': keepers,
        }

    def _job_update(self):
        wallet = self._local.wallet
        self._need_network(wallet)
        if self._read_state(wallet).get('phase') in ('due', 'expired'):
            raise _Fail('needs_renew', 'The inheritance must be renewed.')
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
        fee = 0
        self._step_to('invalidate')
        inv = self._cmd('bal_will_invalidate') or {}
        if inv.get('tx'):
            coins = self._coins(wallet)
            signed = self._cmd('signtransaction', inv['tx'])
            if not signed:
                raise _Fail('user', 'The wallet is locked.')
            tx = tx_from_any(signed)
            fee = sum(coins.get(i.prevout.to_str(), 0) for i in tx.inputs()) \
                - sum(o.value for o in tx.outputs())
            self._step_to('broadcast')
            try:
                txid = self._cmd('broadcast', signed)
            except Exception as e:
                raise _Fail('offline', str(e)) from None
            self._step_to('wait')
            if not self._wait_seen(wallet, txid or tx.txid()):
                raise _Fail('not_synced', 'The renewal was sent: it is finished the next time.')
        self._keepers()
        self._prepare()
        sent, total = self._sign_and_send()
        return {'delivery': self._min_locktime(self._live_items(wallet)), 'sent': sent,
                'total': total, 'feeSats': max(0, int(fee))}

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
        """Heir sats, keeper fee and miner fee of one copy of the will."""
        if not items:
            rows = [{'name': n, 'percent': _percent(v[1]) or 0, 'sats': 0} for n, v in heirs.items()]
            return rows, 0, 0
        tx = tx_from_any(items[0]['tx'])
        outs = {}
        for o in tx.outputs():
            outs[o.address] = outs.get(o.address, 0) + o.value
        rows = []
        heir_addrs = set()
        for n, v in heirs.items():
            heir_addrs.add(v[0])
            rows.append({'name': n, 'percent': _percent(v[1]) or 0, 'sats': int(outs.get(v[0], 0))})
        keeper = sum(val for a, val in outs.items() if a not in heir_addrs)
        miner = sum(coins.get(i, 0) for i in _inputs(items[0]['tx'])) - sum(outs.values())
        return rows, int(keeper), int(max(0, miner))

    def _renew_estimate(self, n_inputs, show):
        """The miner fee of a renewal (its invalidation), estimated (plan 1.4)."""
        vbytes = 11 + 68 * max(1, n_inputs) + 31
        rate = None
        try:
            network = self._network()
            per_kvb = network.fee_estimates.eta_target_to_fee(6) if network else None
            if per_kvb:
                rate = per_kvb / 1000
        except Exception:
            rate = None
        if not rate:
            rate = float(show.get('baltx_fees') or 1)
        return int(round(vbytes * rate))

    @staticmethod
    def _spender_label(wallet, outpoint):
        """The label of the transaction that spent ``outpoint`` ('' if none). Read only."""
        txid, n = outpoint.split(':')
        spender = wallet.db.get_spent_outpoint(txid, int(n))
        return (wallet.get_label_for_txid(spender) or '') if spender else ''

    def _read_state(self, wallet):
        """The ``state`` map of plan 1.2 (worker thread, commands only)."""
        from .core import delivery as delivery_mod
        from .engine.invalidate import INVALIDATION_LABEL
        now = int(time.time())
        network = self._network()
        s = _empty_state()
        s['now'] = now
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
        months = period
        start = int((show.get('period_start') or {}).get('locktime') or 0)
        if live and period and start:
            # F10: a new period chosen with a will in force applies at the renewal
            in_force = int(round((delivery_ - start) / DAY / MONTH_DAYS))
            if in_force and in_force != period:
                months, s['pendingMonths'] = in_force, period
        s['months'] = months
        s['delivery'] = delivery_ or int(show.get('locktime') or 0)
        days = _days(show.get('threshold'))
        s['warnDays'] = days
        s['warnAt'] = s['delivery'] - days * DAY if s['delivery'] else 0
        s['daysToWarn'] = max(0, (s['warnAt'] - now) // DAY) if s['warnAt'] else 0
        s['monthsToDelivery'] = max(0, int(round((s['delivery'] - now) / DAY / MONTH_DAYS))) \
            if s['delivery'] else 0
        if period:
            s['newDelivery'] = int(delivery_mod.add_months(delivery_mod.utc_midnight(now), period))

        # keepers: those holding the will in force, else the selected ones
        if live:
            by_url = {}
            for it in live:
                url = it.get('willexecutor')
                if not url:
                    continue
                st = it.get('status') or {}
                c = by_url.setdefault(url, {
                    'url': url, 'name': url.split('://')[-1],
                    'feeSats': int((wes.get(url) or {}).get('base_fee') or 0),
                    'sent': False, 'checked': False})
                c['sent'] = c['sent'] or bool(st.get('PUSHED'))
                c['checked'] = c['checked'] or (bool(st.get('CHECKED')) and not st.get('CHECK_FAIL'))
            cust = list(by_url.values())
        else:
            cust = [{'url': u, 'name': u.split('://')[-1], 'feeSats': int(we.get('base_fee') or 0),
                     'sent': False, 'checked': False} for u, we in wes.items() if we.get('selected')]
        s['custodians'] = {'ok': sum(1 for c in cust if c['sent']), 'total': len(cust), 'list': cust}
        _rows, keeper_fee, miner_fee = self._split(live, heirs, coins)
        s['fees'] = {'custodianSats': keeper_fee, 'minerSats': miner_fee,
                     'renewSats': self._renew_estimate(len(coins), show)}

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
            labels = {self._spender_label(wallet, i)
                      for it in stale for i in _inputs(it['tx']) if i not in coins}
            if INVALIDATION_LABEL in labels:
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
