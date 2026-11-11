import asyncio
import base64
import queue
import threading
import time
from typing import TYPE_CHECKING, Callable, Optional, Any, Tuple
from functools import partial

from PyQt6.QtCore import pyqtProperty, pyqtSignal, pyqtSlot, QObject, QTimer

from electrum.i18n import _
from electrum.invoices import InvoiceError, PR_PAID, PR_BROADCASTING, PR_BROADCAST
from electrum.logging import get_logger
from electrum.network import TxBroadcastError, BestEffortRequestFailed
from electrum.interface import TxBroadcastServerReturnedError
from electrum.transaction import PartialTransaction, Transaction
from electrum.util import (
    InvalidPassword, event_listener, AddTransactionException, get_asyncio_loop, NotEnoughFunds, NoDynamicFeeEstimates,
    UserFacingException,
)
from electrum.lnutil import MIN_FUNDING_SAT
from electrum.plugin import run_hook
from electrum.wallet import Multisig_Wallet
from electrum.crypto import pw_decode_with_version_and_mac
from electrum.fee_policy import FeePolicy, FixedFeePolicy

from electrum.gui.common_qt.util import QtEventListener, qt_event_listener

from .auth import AuthMixin, auth_protect
from .qeaddresslistmodel import QEAddressCoinListModel
from .qechannellistmodel import QEChannelListModel
from .qeinvoicelistmodel import QEInvoiceListModel, QERequestListModel
from .qetransactionlistmodel import QETransactionListModel
from .qetypes import QEAmount

if TYPE_CHECKING:
    from electrum.wallet import Abstract_Wallet
    from electrum.invoices import Invoice


def eh_pocket_move(wallet, outpoints, aside):
    """Easy Heirs, privacy pockets: "Da spendere" <-> "Da parte" (= blocked).
    - aside, all the coins of an address with more coins: block the ADDRESS
      (also the coins that will arrive there later);
    - aside, otherwise: block only the chosen coins;
    - back to spend, from a blocked address: unblock the address and keep
      blocked, one by one, its coins that were not chosen.
    Returns the addresses touched."""
    chosen_all = set(outpoints)
    by_op = {c.prevout.to_str(): c for c in wallet.get_utxos()}
    addresses = sorted({by_op[o].address for o in chosen_all if o in by_op})
    for a in addresses:
        coins = [c.prevout.to_str() for c in wallet.get_utxos([a])]
        chosen = [o for o in coins if o in chosen_all]
        rest = [o for o in coins if o not in chosen_all]
        if aside:
            if len(coins) > 1 and not rest:
                wallet.set_frozen_state_of_addresses([a], True)
            else:
                wallet.set_frozen_state_of_coins(chosen, True)
        else:
            if wallet.is_frozen_address(a):
                wallet.set_frozen_state_of_addresses([a], False)
                if rest:
                    wallet.set_frozen_state_of_coins(rest, True)
            wallet.set_frozen_state_of_coins(chosen, False)
    return addresses


class QEWallet(AuthMixin, QObject, QtEventListener):
    __instances = []

    # this factory method should be used to instantiate QEWallet
    # so we have only one QEWallet for each electrum.wallet
    @classmethod
    def getInstanceFor(cls, wallet):
        for i in cls.__instances:
            if i.wallet == wallet:
                return i
        i = QEWallet(wallet)
        cls.__instances.append(i)
        return i

    _logger = get_logger(__name__)

    # emitted when wallet wants to display a user notification
    # actual presentation should be handled on app or window level
    userNotify = pyqtSignal(object, object)

    # shared signal for many static wallet properties
    dataChanged = pyqtSignal()

    balanceChanged = pyqtSignal()
    requestStatusChanged = pyqtSignal([str, int], arguments=['key', 'status'])
    requestCreateSuccess = pyqtSignal([str], arguments=['key'])
    requestCreateError = pyqtSignal([str], arguments=['error'])
    invoiceStatusChanged = pyqtSignal([str, int], arguments=['key', 'status'])
    invoiceCreateSuccess = pyqtSignal()
    invoiceCreateError = pyqtSignal([str, str], arguments=['code', 'error'])
    paymentAuthRejected = pyqtSignal()
    paymentSucceeded = pyqtSignal([str], arguments=['key'])
    paymentFailed = pyqtSignal([str, str], arguments=['key', 'reason'])
    requestNewPassword = pyqtSignal()
    broadcastSucceeded = pyqtSignal([str], arguments=['txid'])
    broadcastFailed = pyqtSignal([str, str, str], arguments=['txid', 'code', 'reason'])
    saveTxSuccess = pyqtSignal([str], arguments=['txid'])
    saveTxError = pyqtSignal([str, str, str], arguments=['txid', 'code', 'message'])
    importChannelBackupFailed = pyqtSignal([str], arguments=['message'])
    otpRequested = pyqtSignal()
    otpSuccess = pyqtSignal()
    otpFailed = pyqtSignal([str, str], arguments=['code', 'message'])
    peersUpdated = pyqtSignal()
    seedRetrieved = pyqtSignal()
    messageSigned = pyqtSignal([str], arguments=['signature'])
    signMessageError = pyqtSignal([str], arguments=['error'])

    _network_signal = pyqtSignal(str, object)

    def __init__(self, wallet: 'Abstract_Wallet', parent=None):
        super().__init__(parent)
        self.wallet = wallet

        self._logger = get_logger(f'{__name__}.[{wallet}]')

        self._synchronizing = False
        self._synchronizing_progress = ''

        self._historyModel = None
        self._addressCoinModel = None
        self._requestModel = None
        self._invoiceModel = None
        self._channelModel = None

        self._lightningbalance = QEAmount()
        self._confirmedbalance = QEAmount()
        self._unconfirmedbalance = QEAmount()
        self._frozenbalance = QEAmount()
        self._totalbalance = QEAmount()
        self._lightningcanreceive = QEAmount()
        self._minchannelfunding = QEAmount(amount_sat=int(MIN_FUNDING_SAT))
        self._lightningcansend = QEAmount()
        self._lightningbalancefrozen = QEAmount()

        self._seed = ''
        self._seed_passphrase = ''

        self._otp_on_submit = None  # type: Callable[[str], None]

        self.tx_notification_queue = queue.Queue()
        self.tx_notification_last_time = 0

        self.notification_timer = QTimer(self)
        self.notification_timer.setSingleShot(False)
        self.notification_timer.setInterval(500)  # msec
        self.notification_timer.timeout.connect(self.notify_transactions)

        self.sync_progress_timer = QTimer(self)
        self.sync_progress_timer.setSingleShot(False)
        self.sync_progress_timer.setInterval(2000)
        self.sync_progress_timer.timeout.connect(self.update_sync_progress)

        # post-construction init in GUI thread
        # QMetaObject.invokeMethod(self, 'qt_init', Qt.QueuedConnection)

        # To avoid leaking references to "self" that prevent the
        # window from being GC-ed when closed, callbacks should be
        # methods of this class only, and specifically not be
        # partials, lambdas or methods of subobjects.  Hence...

        self.register_callbacks()
        self.destroyed.connect(lambda: self.on_destroy())
        self.synchronizing = not wallet.is_up_to_date()

    synchronizingChanged = pyqtSignal()
    @pyqtProperty(bool, notify=synchronizingChanged)
    def synchronizing(self):
        return self._synchronizing

    @synchronizing.setter
    def synchronizing(self, synchronizing):
        if self._synchronizing != synchronizing:
            self._logger.debug(f'SYNC {self._synchronizing} -> {synchronizing}')
            self._synchronizing = synchronizing
            self.synchronizingChanged.emit()
            if synchronizing:
                if not self.sync_progress_timer.isActive():
                    self.update_sync_progress()
                    self.sync_progress_timer.start()
            else:
                self.sync_progress_timer.stop()

    synchronizingProgressChanged = pyqtSignal()
    @pyqtProperty(str, notify=synchronizingProgressChanged)
    def synchronizingProgress(self):
        return self._synchronizing_progress

    @synchronizingProgress.setter
    def synchronizingProgress(self, progress):
        if self._synchronizing_progress != progress:
            self._synchronizing_progress = progress
            self._logger.info(progress)
            self.synchronizingProgressChanged.emit()

    multipleChangeChanged = pyqtSignal()
    @pyqtProperty(bool, notify=multipleChangeChanged)
    def multipleChange(self):
        return self.wallet.multiple_change

    @multipleChange.setter
    def multipleChange(self, multiple_change):
        if self.wallet.multiple_change != multiple_change:
            self.wallet.multiple_change = multiple_change
            self.wallet.db.put('multiple_change', self.wallet.multiple_change)
            self.multipleChangeChanged.emit()

    @qt_event_listener
    def on_event_request_status(self, wallet, key, status):
        if wallet == self.wallet:
            self._logger.debug('request status %d for key %s' % (status, key))
            self.requestStatusChanged.emit(key, status)
            if status == PR_PAID:
                # might be new incoming LN payment, update history
                # TODO: only update if it was paid over lightning,
                # and even then, we can probably just add the payment instead
                # of recreating the whole history (expensive)
                self.historyModel.initModel(True)

    @event_listener
    def on_event_invoice_status(self, wallet, key, status):
        if wallet == self.wallet:
            self._logger.debug(f'invoice status update for key {key} to {status}')
            self.invoiceStatusChanged.emit(key, status)

    @qt_event_listener
    def on_event_new_transaction(self, wallet: 'Abstract_Wallet', tx: Transaction):
        if wallet == self.wallet:
            self._logger.debug(f'new transaction {tx.txid()}')
            self.add_tx_notification(tx)
            if self._addressCoinModel is not None:  # only setDirty if it was already initialized
                self._addressCoinModel.setDirty()
            self.historyModel.setDirty()  # assuming wallet.is_up_to_date triggers after
            if self.wallet.is_up_to_date():
                # don't update during sync as this recomputes the balance on each new tx, blocking the UI thread.
                # on_event_wallet_updated emits balanceChanged once we are up-to-date.
                self.balanceChanged.emit()

    @qt_event_listener
    def on_event_adb_tx_height_changed(self, adb, txid, old_height, new_height):
        if adb == self.wallet.adb:
            self._logger.debug(f'tx_height_changed {txid}. {old_height} -> {new_height}')
            self.historyModel.setDirty()  # assuming wallet.is_up_to_date triggers after

    @qt_event_listener
    def on_event_removed_transaction(self, wallet, tx):
        # NOTE: this event only triggers once, only for the first deleted tx, when for imported wallets an address
        # is deleted along with multiple associated txs
        if wallet == self.wallet:
            self._logger.info(f'removed transaction {tx.txid()}')
            if self._addressCoinModel is not None:
                self._addressCoinModel.setDirty()
            self.historyModel.setDirty()
            self.balanceChanged.emit()

    @qt_event_listener
    def on_event_wallet_updated(self, wallet):
        if wallet == self.wallet:
            self._logger.debug('wallet_updated')
            self.balanceChanged.emit()
            self.historyModel.setDirty()
            self.synchronizing = not wallet.is_up_to_date()
            if not self.synchronizing:
                self.historyModel.initModel()  # refresh if dirty

    @event_listener
    def on_event_channel(self, wallet, channel):
        if wallet == self.wallet:
            self.balanceChanged.emit()
            self.peersUpdated.emit()

    @event_listener
    def on_event_channels_updated(self, wallet):
        if wallet == self.wallet:
            self.balanceChanged.emit()
            self.peersUpdated.emit()

    @qt_event_listener
    def on_event_payment_succeeded(self, wallet, key):
        if wallet == self.wallet:
            self.paymentSucceeded.emit(key)
            self.historyModel.initModel(True)  # TODO: be less dramatic

    @event_listener
    def on_event_payment_failed(self, wallet, key, reason):
        if wallet == self.wallet:
            self.paymentFailed.emit(key, reason)

    def on_destroy(self):
        if self not in QEWallet.__instances:
            return
        QEWallet.__instances.remove(self)
        self.unregister_callbacks()

    def add_tx_notification(self, tx: Transaction):
        self._logger.debug('new transaction event')
        self.tx_notification_queue.put(tx)
        if not self.notification_timer.isActive():
            self._logger.debug('starting wallet notification timer')
            self.notification_timer.start()

    def notify_transactions(self):
        if self.tx_notification_queue.qsize() == 0:
            self._logger.debug('queue empty, stopping wallet notification timer')
            self.notification_timer.stop()
            return
        if not self.wallet.is_up_to_date():
            return  # no notifications while syncing
        now = time.time()
        rate_limit = 20  # seconds
        if self.tx_notification_last_time + rate_limit > now:
            return
        self.tx_notification_last_time = now
        self._logger.info("Notifying app about new transactions")
        txns = []
        while True:
            try:
                txns.append(self.tx_notification_queue.get_nowait())
            except queue.Empty:
                break

        for notification in self._eh_notifications(txns):
            self.userNotify.emit(self.wallet, notification)

    def _eh_notifications(self, txns):
        """Easy Heirs (T17): simple texts in the chosen language, in euro
        (bitcoin only in 'only bitcoin' mode), instead of Electrum's messages."""
        if len(txns) > 20:
            return [_('{} new movements').format(len(txns))]
        cfg = self.wallet.config
        btc_only = cfg.get('eh_opt_btc_only', False) is True
        fx = None
        try:
            from .qedaemon import QEDaemon
            fx = QEDaemon.instance.qefx.fx if QEDaemon.instance else None
        except Exception:
            fx = None

        def money(sats):
            try:
                if not btc_only and fx and fx.is_enabled():
                    rate = fx.exchange_rate()
                    if rate is not None and rate.is_finite():
                        v = fx.fiat_value(sats, rate)
                        s = f'{v:,.2f}'.replace(',', ' ').replace('.', ',').replace(' ', '.')
                        ccy = fx.get_currency()
                        return ('€ ' + s) if ccy == 'EUR' else (s + ' ' + ccy)
            except Exception as e:
                self._logger.info(f'eh notify: no fiat value ({e!r})')
            return cfg.format_amount_and_units(sats)

        received = sent = 0
        for tx in txns:
            d = self.wallet.get_wallet_delta(tx)
            if not d.is_relevant:
                continue
            if d.delta < 0:
                sent += -d.delta
            else:
                received += d.delta
        lines = []
        if received:
            lines.append(_('You received {}').format(money(received)))
        if sent:
            lines.append(_('You sent {}').format(money(sent)))
        return ['\n'.join(lines)] if lines else []

    def update_sync_progress(self):
        if self.wallet.network and self.wallet.network.is_connected():
            num_sent, num_answered = self.wallet.adb.get_history_sync_state_details()
            self.synchronizingProgress = \
                ("{} ({}/{})".format(_("Synchronizing..."), num_answered, num_sent))

    historyModelChanged = pyqtSignal()
    @pyqtProperty(QETransactionListModel, notify=historyModelChanged)
    def historyModel(self):
        if self._historyModel is None:
            self._historyModel = QETransactionListModel(self.wallet)
        return self._historyModel

    addressCoinModelChanged = pyqtSignal()
    @pyqtProperty(QEAddressCoinListModel, notify=addressCoinModelChanged)
    def addressCoinModel(self):
        if self._addressCoinModel is None:
            self._addressCoinModel = QEAddressCoinListModel(self.wallet)
        return self._addressCoinModel

    requestModelChanged = pyqtSignal()
    @pyqtProperty(QERequestListModel, notify=requestModelChanged)
    def requestModel(self):
        if self._requestModel is None:
            self._requestModel = QERequestListModel(self.wallet)
        return self._requestModel

    invoiceModelChanged = pyqtSignal()
    @pyqtProperty(QEInvoiceListModel, notify=invoiceModelChanged)
    def invoiceModel(self):
        if self._invoiceModel is None:
            self._invoiceModel = QEInvoiceListModel(self.wallet)
        return self._invoiceModel

    channelModelChanged = pyqtSignal()
    @pyqtProperty(QEChannelListModel, notify=channelModelChanged)
    def channelModel(self):
        if self._channelModel is None:
            self._channelModel = QEChannelListModel(self.wallet)
        return self._channelModel

    nameChanged = pyqtSignal()
    @pyqtProperty(str, notify=nameChanged)
    def name(self):
        return self.wallet.basename()

    isLightningChanged = pyqtSignal()
    @pyqtProperty(bool, notify=isLightningChanged)
    def isLightning(self):
        return bool(self.wallet.lnworker)

    billingInfoChanged = pyqtSignal()
    @pyqtProperty('QVariantMap', notify=billingInfoChanged)
    def billingInfo(self):
        if self.wallet.wallet_type != '2fa':
            return {}
        return self.wallet.billing_info if self.wallet.billing_info is not None else {}

    @pyqtProperty(bool, notify=dataChanged)
    def canHaveLightning(self):
        return self.wallet.can_have_lightning()

    @pyqtProperty(str, notify=dataChanged)
    def walletType(self):
        return self.wallet.wallet_type

    @pyqtProperty(bool, notify=dataChanged)
    def isMultisig(self):
        return isinstance(self.wallet, Multisig_Wallet)

    @pyqtProperty(bool, notify=dataChanged)
    def hasSeed(self):
        return self.wallet.has_seed()

    @pyqtProperty(str, notify=dataChanged)
    def seed(self):
        return self._seed

    @pyqtProperty(str, notify=dataChanged)
    def seedPassphrase(self):
        return self._seed_passphrase

    @pyqtProperty(str, notify=dataChanged)
    def txinType(self):
        if self.wallet.wallet_type == 'imported':
            return self.wallet.txin_type
        return self.wallet.get_txin_type(self.wallet.dummy_address())

    @pyqtProperty(str, notify=dataChanged)
    def seedType(self):
        return self.wallet.get_seed_type()

    @pyqtProperty(bool, notify=dataChanged)
    def isWatchOnly(self):
        return self.wallet.is_watching_only()

    @pyqtProperty(bool, notify=dataChanged)
    def isDeterministic(self):
        return self.wallet.is_deterministic()

    @pyqtProperty(bool, notify=dataChanged)
    def isEncrypted(self):
        return self.wallet.storage.is_encrypted()

    @pyqtProperty(bool, notify=dataChanged)
    def isHardware(self):
        return self.wallet.storage.is_encrypted_with_hw_device()

    @pyqtProperty('QVariantList', notify=dataChanged)
    def keystores(self):
        result = []
        for k in self.wallet.get_keystores():
            result.append({
                'keystore_type': k.type,
                'watch_only': k.is_watching_only(),
                'derivation_prefix': (k.get_derivation_prefix() if k.is_deterministic() else '') or '',
                'master_pubkey': (k.get_master_public_key() if k.is_deterministic() else '') or '',
                'fingerprint': (k.get_root_fingerprint() if k.is_deterministic() else '') or '',
                'num_imported': len(k.keypairs) if k.can_import() else 0,
            })
        return result

    @pyqtProperty(str, notify=dataChanged)
    def lightningNodePubkey(self):
        return self.wallet.lnworker.node_keypair.pubkey.hex() if self.wallet.lnworker else ''

    @pyqtProperty(bool, notify=dataChanged)
    def lightningHasDeterministicNodeId(self):
        return self.wallet.lnworker.has_deterministic_node_id() if self.wallet.lnworker else False

    @pyqtProperty(str, notify=dataChanged)
    def derivationPrefix(self):
        keystores = self.wallet.get_keystores()
        if len(keystores) > 1:
            self._logger.debug('multiple keystores not supported yet')
        if len(keystores) == 0:
            self._logger.debug('no keystore')
            return ''
        if not self.isDeterministic:
            return ''
        return keystores[0].get_derivation_prefix()

    @pyqtProperty(str, notify=dataChanged)
    def masterPubkey(self):
        return self.wallet.get_master_public_key()

    @pyqtProperty(bool, notify=dataChanged)
    def canSignWithoutServer(self):
        return self.wallet.can_sign_without_server() if self.wallet.wallet_type == '2fa' else True

    @pyqtProperty(bool, notify=dataChanged)
    def canSignWithoutCosigner(self):
        if isinstance(self.wallet, Multisig_Wallet):
            if self.wallet.wallet_type == '2fa':  # 2fa is multisig, but it handles cosigning itself
                return True
            return self.wallet.m == 1
        return True

    @pyqtProperty(bool, notify=dataChanged)
    def canSignMessage(self):
        return not isinstance(self.wallet, Multisig_Wallet) and not self.wallet.is_watching_only()

    canGetZeroconfChannelChanged = pyqtSignal()
    @pyqtProperty(bool, notify=canGetZeroconfChannelChanged)
    def canGetZeroconfChannel(self) -> bool:
        return self.wallet.lnworker and self.wallet.lnworker.can_get_zeroconf_channel()

    @pyqtProperty(QEAmount, notify=balanceChanged)
    def frozenBalance(self):
        c, u, x = self.wallet.get_frozen_balance()
        # Easy Heirs (third review): the balance shown counts money arriving, so blocked money
        # arriving is blocked too
        self._frozenbalance.satsInt = c + max(0, u) + x
        return self._frozenbalance

    @pyqtProperty(QEAmount, notify=balanceChanged)
    def unconfirmedBalance(self):
        self._unconfirmedbalance.satsInt = self.wallet.get_balance()[1]
        return self._unconfirmedbalance

    @pyqtProperty(QEAmount, notify=balanceChanged)
    def confirmedBalance(self):
        c, u, x = self.wallet.get_balance()
        self._confirmedbalance.satsInt = c+x
        return self._confirmedbalance

    @pyqtProperty(QEAmount, notify=balanceChanged)
    def lightningBalance(self):
        if self.isLightning:
            self._lightningbalance.satsInt = int(self.wallet.lnworker.get_balance())
        return self._lightningbalance

    @pyqtProperty(QEAmount, notify=balanceChanged)
    def lightningBalanceFrozen(self):
        if self.isLightning:
            self._lightningbalancefrozen.satsInt = int(self.wallet.lnworker.get_balance(frozen=True))
        return self._lightningbalancefrozen

    @pyqtProperty(QEAmount, notify=balanceChanged)
    def totalBalance(self):
        total = self.confirmedBalance.satsInt + self.lightningBalance.satsInt
        self._totalbalance.satsInt = total
        return self._totalbalance

    # Easy Heirs (third review): money received but not confirmed yet. It is counted in the
    # balance (Electrum can already spend it, e.g. "All the balance"), and shown as "arriving".
    @pyqtProperty(QEAmount, notify=balanceChanged)
    def ehArriving(self):
        if not hasattr(self, '_eh_arriving'):
            self._eh_arriving = QEAmount()
        self._eh_arriving.satsInt = max(0, self.wallet.get_balance()[1])
        return self._eh_arriving

    @pyqtProperty(QEAmount, notify=balanceChanged)
    def ehTotal(self):
        if not hasattr(self, '_eh_total'):
            self._eh_total = QEAmount()
        self._eh_total.satsInt = self.totalBalance.satsInt + max(0, self.wallet.get_balance()[1])
        return self._eh_total

    @pyqtProperty(QEAmount, notify=balanceChanged)
    def lightningCanSend(self):
        if self.isLightning:
            self._lightningcansend.satsInt = int(self.wallet.lnworker.num_sats_can_send())
        return self._lightningcansend

    @pyqtProperty(QEAmount, notify=balanceChanged)
    def lightningCanReceive(self):
        if self.isLightning:
            self._lightningcanreceive.satsInt = int(self.wallet.lnworker.num_sats_can_receive())
        return self._lightningcanreceive

    @pyqtProperty(bool, notify=balanceChanged)
    def isLowReserve(self):
        return self.wallet.is_low_reserve()

    @pyqtProperty(QEAmount, notify=dataChanged)
    def minChannelFunding(self):
        return self._minchannelfunding

    @pyqtProperty(int, notify=peersUpdated)
    def lightningNumPeers(self):
        if self.isLightning:
            return self.wallet.lnworker.lnpeermgr.num_peers()
        return 0

    @pyqtProperty('QVariantList', notify=dataChanged)
    def startupWarnings(self):
        return [{
            'key': warning.key,
            'title': warning.title,
            'message': warning.message,
        } for warning in self.wallet.get_startup_warnings()]

    @pyqtSlot(str)
    def acknowledgeWarning(self, key: str):
        self.wallet.acknowledge_warning(key)

    @pyqtSlot()
    def enableLightning(self):
        self.wallet.init_lightning(password=self.password)
        self.isLightningChanged.emit()
        self.dataChanged.emit()

    @auth_protect(message=_('Sign and send on-chain transaction?'))
    def sign_and_broadcast(self, tx, *,
                           on_success: Callable[[Transaction], None] = None,
                           on_failure: Callable[[Optional[Any]], None] = None) -> None:
        self.do_sign(tx, True, on_success, on_failure)

    @auth_protect(message=_('Sign on-chain transaction?'))
    def sign(self, tx, *,
             on_success: Callable[[Transaction], None] = None,
             on_failure: Callable[[Optional[Any]], None] = None) -> None:
        self.do_sign(tx, False, on_success, on_failure)

    def do_sign(self, tx, broadcast, on_success: Callable[[Transaction], None] = None, on_failure: Callable[[Optional[Any]], None] = None):
        # tc_sign_wrapper is only used by 2fa. don't pass on_failure handler, it is handled via otpFailed signal
        sign_hook = run_hook('tc_sign_wrapper', self.wallet, tx,
                             partial(self.on_sign_complete, broadcast, on_success),
                             partial(self.on_sign_failed, None))
        try:
            # ignore_warnings=True, because UI checks and asks user confirmation itself
            tx = self.wallet.sign_transaction(tx, self.password, ignore_warnings=True)
        except BaseException as e:
            self._logger.error(f'{e!r}')
            if on_failure:
                on_failure(str(e))
            return

        if tx is None:
            self._logger.info('did not sign')
            if on_failure:
                on_failure('')   # Easy Heirs: signError is a str signal, None would raise
            return

        if sign_hook:
            self._logger.debug('plugin needs to sign tx too')
            sign_hook(tx)
            return

        txid = tx.txid()
        self._logger.debug(f'do_sign(), txid={txid}')

        if not tx.is_complete():
            self._logger.debug('tx not complete')
            broadcast = False

        if broadcast:
            self.broadcast(tx)
        else:
            # not broadcasted, so refresh history here
            self.historyModel.initModel(True)

        if on_success:
            on_success(tx)

    # this assumes a 2fa wallet, but there are no other tc_sign_wrapper hooks, so that's ok
    def on_sign_complete(self, broadcast, cb: Callable[[Transaction], None] = None, tx: Transaction = None):
        self.otpSuccess.emit()
        if cb:
            cb(tx)
        if broadcast:
            self.broadcast(tx)

    # this assumes a 2fa wallet, but there are no other tc_sign_wrapper hooks, so that's ok
    def on_sign_failed(self, cb: Callable[[], None] | None = None, error: str | None = None):
        self.otpFailed.emit('error', error)
        if cb:
            cb()

    def request_otp(self, on_submit: Callable[[str], None]):
        self._otp_on_submit = on_submit
        self.otpRequested.emit()

    @pyqtSlot(str)
    def submitOtp(self, otp):
        def submit_otp_task():
            self._otp_on_submit(otp)
        threading.Thread(target=submit_otp_task, daemon=True).start()

    def broadcast(self, tx):
        assert tx.is_complete()

        async def broadcast_coro():
            self.wallet.set_broadcasting(tx, broadcasting_status=PR_BROADCASTING)
            try:
                self._logger.info('broadcasting tx in coroutine')
                await self.wallet.network.broadcast_transaction(tx)
            except TxBroadcastError as e:
                self._logger.error(repr(e))
                # Easy Heirs (third review): after a timeout Electrum sends again to another
                # server, which may answer "already known": the payment DID leave
                if any(s in str(e) for s in ('txn-already-in-mempool', 'txn-already-known',
                                             'already in block chain', 'outputs already in utxo set')):
                    self._logger.info('broadcast: already known by the server, counted as sent')
                    self.broadcastSucceeded.emit(tx.txid())
                    self.historyModel.requestRefresh.emit()  # via qt thread
                    return
                # only a real refusal of the server is sure; an unknown error or a different txid is not
                code = 'rejected' if isinstance(e, TxBroadcastServerReturnedError) else 'unsure'
                self.broadcastFailed.emit(tx.txid(), code, e.get_message_for_gui())
            except BestEffortRequestFailed as e:
                self._logger.error(repr(e))
                # the connection failed: we do not know if a server got it
                self.broadcastFailed.emit(tx.txid(), 'unsure', repr(e))
            except Exception as e:
                self._logger.exception("failed to broadcast tx")
                # Easy Heirs (second review F3): always tell the page, or it stays on "Sending..."
                self.broadcastFailed.emit(tx.txid(), 'unsure', repr(e))
            else:
                self._logger.info('broadcast success')
                self.broadcastSucceeded.emit(tx.txid())
                self.historyModel.requestRefresh.emit()  # via qt thread
            finally:
                self.wallet.set_broadcasting(tx, broadcasting_status=None)

        asyncio.run_coroutine_threadsafe(broadcast_coro(), get_asyncio_loop())

        # TODO: properly catch server side errors, e.g. bad-txns-inputs-missingorspent

    def save_tx(self, tx: 'PartialTransaction') -> bool:
        assert tx

        try:
            if not self.wallet.adb.add_transaction(tx):
                self.saveTxError.emit(tx.txid(), 'conflict',
                            _("Transaction could not be saved.") + "\n" + _("It conflicts with current history."))
                return False
            self.wallet.save_db()
            self.saveTxSuccess.emit(tx.txid())
            self.historyModel.initModel(True)
            return True
        except AddTransactionException as e:
            self.saveTxError.emit(tx.txid(), 'error', str(e))
            return False

    def ln_auth_rejected(self):
        self.paymentAuthRejected.emit()

    @auth_protect(message=_('Pay lightning invoice?'), reject='ln_auth_rejected')
    def pay_lightning_invoice(self, invoice: 'Invoice', amount_msat: int | None = None):
        # at this point, the user confirmed the payment, potentially with an override amount.
        # we save the invoice with the override amount if there was no amount defined in the invoice.
        # (this is similar to what the desktop client does)
        #
        # Note: amount_msat can be greater than the invoice-specified amount. This is validated and handled
        # in lnworker.pay_invoice()
        if amount_msat is not None:
            assert type(amount_msat) is int
            if invoice.get_amount_msat() is None:
                invoice.set_amount_msat(amount_msat)
        else:
            amount_msat = invoice.get_amount_msat()

        self.wallet.save_invoice(invoice)
        if self._invoiceModel:
            self._invoiceModel.initModel()

        async def pay_coro():
            try:
                await self.wallet.lnworker.pay_invoice(invoice, amount_msat=amount_msat)
            except Exception as e:
                self._logger.error(f'pay_invoice failed! {e!r}')
                self.paymentFailed.emit(invoice.get_id(), str(e))

        asyncio.run_coroutine_threadsafe(pay_coro(), get_asyncio_loop())

    @pyqtSlot()
    def deleteExpiredRequests(self):
        keys = self.wallet.delete_expired_requests()
        for key in keys:
            self.requestModel.delete_invoice(key)

    # Easy Heirs: "pull down to receive" must not use up the addresses.
    # Every pull used to create a new request that never expires, and each one
    # keeps an address busy: after about 20 pulls "No address available".
    # Now the same address is shown until money arrives on it.
    def _eh_is_plain_request(self, req) -> bool:
        return (not req.is_lightning()) and not req.get_amount_sat() and not req.get_message()

    # Easy Heirs: "Le tue monete d'oro" (one UTXO = one gold coin)
    @pyqtSlot(str, bool)
    def ehSetCoinFrozen(self, outpoint: str, freeze: bool):
        """Block / unblock one coin: the app will not use it to pay."""
        self.wallet.set_frozen_state_of_coins([outpoint], freeze)
        self.addressCoinModel.updateCoin(outpoint)
        self.balanceChanged.emit()

    # ---- Easy Heirs T8: "I tuoi indirizzi" (opened from Receive) ----
    def _eh_coin_dict(self, coin):
        op = coin.prevout.to_str()
        txid = coin.prevout.txid.hex()
        return {
            'outpoint': op,
            'txid': txid,
            'sats': int(coin.value_sats()),
            'height': int(coin.block_height or 0),
            'held': bool(self.wallet.is_frozen_coin(coin)),
            'label': self.wallet.get_label_for_outpoint(op) or self.wallet.get_label_for_txid(txid) or '',
            'origin': self._eh_origins().get(op, ''),
        }

    def _eh_address_dict(self, address, kind):
        w = self.wallet
        coins = w.get_utxos([address])
        coins.sort(key=lambda x: x.block_height)
        c, u, x = w.get_addr_balance(address)
        return {
            'address': address,
            'kind': kind,                    # 'receive' or 'change'
            'label': w.get_label_for_address(address) or '',
            'sats': int(c + u + x),
            'numtx': int(w.adb.get_address_history_len(address)),
            'held': bool(w.is_frozen_address(address)),
            'coins': [self._eh_coin_dict(coin) for coin in coins],
        }

    @pyqtSlot(result='QVariantList')
    def ehAddresses(self):
        """Addresses that were used or hold money, plus the first unused one to
        receive on ('new'). Change addresses only if used."""
        w = self.wallet
        out = []
        recv = w.get_receiving_addresses()
        change = w.get_change_addresses() if w.wallet_type != 'imported' else []
        first_new = None
        for a in recv:
            d = self._eh_address_dict(a, 'receive')
            if d['numtx'] > 0 or d['sats'] > 0:
                out.append(d)
            elif first_new is None:
                first_new = d
        if first_new is not None:
            first_new['new'] = True
            out.append(first_new)
        for a in change:
            d = self._eh_address_dict(a, 'change')
            if d['numtx'] > 0 or d['sats'] > 0:
                out.append(d)
        return out

    @pyqtSlot(str, result='QVariantMap')
    def ehAddressInfo(self, address):
        w = self.wallet
        kind = 'change' if w.is_change(address) else 'receive'
        return self._eh_address_dict(address, kind)

    # ---- Easy Heirs T20 step 3: where a coin comes from (id of an origin category) ----
    # Kept in the wallet file (key 'eh_origins': outpoint -> category id), so it
    # follows the wallet. Only a note for the user: Electrum itself ignores it.
    def _eh_origins(self) -> dict:
        try:
            return dict(self.wallet.db.get('eh_origins') or {})
        except Exception:
            return {}

    @pyqtSlot(str, result=str)
    def ehCoinOrigin(self, outpoint: str) -> str:
        return str(self._eh_origins().get(outpoint, ''))

    @pyqtSlot('QVariantList', str)
    def ehSetOrigin(self, outpoints, cat: str):
        """Give the coins an origin category ('' = "I don't know")."""
        d = self._eh_origins()
        for o in outpoints:
            o = str(o)
            if cat:
                d[o] = cat
            else:
                d.pop(o, None)
        # forget the coins that were spent meanwhile
        live = {c.prevout.to_str() for c in self.wallet.get_utxos()}
        d = {k: v for k, v in d.items() if k in live}
        self.wallet.db.put('eh_origins', d)
        self.wallet.save_db()

    @pyqtSlot(str)
    def ehForgetOrigin(self, cat: str):
        """A category was deleted: its coins go back to "I don't know"."""
        d = {k: v for k, v in self._eh_origins().items() if v != cat}
        self.wallet.db.put('eh_origins', d)
        self.wallet.save_db()

    @pyqtSlot('QVariantList', bool)
    def ehPocketMove(self, outpoints, aside: bool):
        """Privacy pockets: move the chosen coins "Da parte" (aside=True) or back."""
        eh_pocket_move(self.wallet, [str(o) for o in outpoints], aside)
        self.addressCoinModel.setDirty()
        self.balanceChanged.emit()

    @pyqtSlot(str, bool)
    def ehSetAddressFrozen(self, address: str, freeze: bool):
        """Block / unblock a whole address: none of its coins is used to pay,
        also the ones that will arrive later (Electrum's 'freeze address')."""
        self.wallet.set_frozen_state_of_addresses([address], freeze)
        self.addressCoinModel.setDirty()
        self.balanceChanged.emit()

    @pyqtSlot(str, str)
    def ehSetAddressNote(self, address: str, text: str):
        self.wallet.set_label(address, text.strip() or None)
        self.addressCoinModel.setDirty()

    @pyqtSlot(str)
    def ehReceiveOn(self, address: str):
        """'Ricevi su questo indirizzo': open Receive with this address."""
        w = self.wallet
        for req in w.get_unpaid_requests():
            if self._eh_is_plain_request(req) and req.get_address() == address:
                self.requestCreateSuccess.emit(req.get_id())
                return
        try:
            key = w.create_request(0, '', 0, address)
        except InvoiceError as e:
            self.requestCreateError.emit(_('Error creating payment request') + ':\n' + str(e))
            return
        self.requestModel.add_invoice(w.get_request(key))
        self.requestCreateSuccess.emit(key)

    @pyqtSlot(str, str)
    def ehSetCoinNote(self, outpoint: str, text: str):
        """Note of one gold coin (Electrum label by outpoint)."""
        self.wallet.set_label(outpoint, text.strip() or None)
        self.addressCoinModel.updateCoin(outpoint)

    # Easy Heirs: "Cerca più indirizzi" = Electrum's gap limit (desktop: console only)
    @pyqtSlot(result=int)
    def ehGapLimit(self) -> int:
        return int(getattr(self.wallet, 'gap_limit', 20) or 20)

    @pyqtSlot(result=int)
    def ehMinGapLimit(self) -> int:
        try:
            return int(self.wallet.min_acceptable_gap())
        except Exception:
            return 20

    @pyqtSlot(int, result=bool)
    def ehSetGapLimit(self, value: int) -> bool:
        if not hasattr(self.wallet, 'change_gap_limit'):
            return False
        if not self.wallet.change_gap_limit(value):
            return False
        # create the new addresses now, so the synchronizer looks at them
        try:
            self.wallet.synchronize()
        except Exception as e:
            self._logger.warning(f'eh gap limit: synchronize: {e!r}')
        self.addressCoinModel.setDirty()
        self._logger.info(f'eh gap limit set to {value}')
        return True

    @pyqtSlot(str, result=str)
    def ehSeedType(self, seed: str) -> str:
        """Electrum seed type of the words ('segwit', 'standard'...), '' if not an Electrum seed."""
        from electrum.mnemonic import calc_seed_type
        try:
            return calc_seed_type(seed) or ''
        except Exception:
            return ''

    @pyqtSlot(str, result=int)
    def ehTxTimestamp(self, txid: str) -> int:
        """When the transaction that made a coin was mined (0 = not yet)."""
        try:
            info = self.wallet.adb.get_tx_height(txid)
            return int(info.timestamp or 0)
        except Exception:
            return 0

    @pyqtSlot()
    def ehCleanRequests(self):
        """Drop expired requests and keep at most one open request without
        amount and text (on an address that got no money yet)."""
        self.deleteExpiredRequests()
        w = self.wallet
        if not w.is_up_to_date():
            # before the sync we do not know which addresses got money: drop nothing, or an
            # address already shown could be handed out again as "new"
            return
        keep = None
        drop = []
        # third review: newest first, so the address shown last is the one that stays
        reqs = sorted(w.get_unpaid_requests(), key=lambda r: r.get_time() or 0, reverse=True)
        for req in reqs:
            if not self._eh_is_plain_request(req):
                continue
            addr = req.get_address()
            if keep is None and addr and not w.adb.is_used(addr):
                keep = req
                continue
            drop.append(req.get_id())
        for key in drop:
            w.delete_request(key, write_to_disk=False)
            self.requestModel.delete_invoice(key)
        if drop:
            w.save_db()
            self._logger.info(f'eh: removed {len(drop)} old empty requests')

    @pyqtSlot()
    def ehReceive(self):
        """The address for "Receive": the open one if it got no money yet, else a new one."""
        self.ehCleanRequests()
        w = self.wallet
        # second review (RN-2): before the wallet is up to date we do not know if money arrived
        # on the open address while the app was closed: do not reuse it, take a new one
        reuse_ok = w.is_up_to_date()
        if not reuse_ok:
            # third review: while not up to date, reuse the address made in THIS session
            # (one new address, not one per pull, each shown to a different person)
            key = getattr(self, '_eh_offline_req', None)
            req = w.get_request(key) if key else None
            if req is not None and not w.adb.is_used(req.get_address()):
                self.requestCreateSuccess.emit(key)
                return
        reqs = sorted(w.get_unpaid_requests(), key=lambda r: r.get_time() or 0, reverse=True)
        for req in (reqs if reuse_ok else []):
            addr = req.get_address()
            if self._eh_is_plain_request(req) and addr and not w.adb.is_used(addr):
                self.requestCreateSuccess.emit(req.get_id())
                return
        self._eh_offline_wanted = not reuse_ok
        self.createRequest(QEAmount(amount_sat=0), '', 0, False, True)

    @pyqtSlot(QEAmount, str, int)
    @pyqtSlot(QEAmount, str, int, bool)
    @pyqtSlot(QEAmount, str, int, bool, bool)
    @pyqtSlot(QEAmount, str, int, bool, bool, bool)
    def createRequest(self, amount: QEAmount, message: str, expiration: int, lightning: bool = False, reuse_address: bool = False):
        self.deleteExpiredRequests()
        try:
            amount = amount.satsInt
            if not lightning:
                addr = self.wallet.get_unused_address()
                if addr is None:
                    if reuse_address:
                        addr = self.wallet.get_receiving_address()
                    else:
                        msg = [
                            _('No address available.'),
                            _('All your addresses are used in pending requests.'),
                            _('To see the list, press and hold the Receive button.'),
                        ]
                        self.requestCreateError.emit(' '.join(msg))
                        return
            else:
                addr = None

            key = self.wallet.create_request(amount, message, expiration, addr)
        except InvoiceError as e:
            self.requestCreateError.emit(_('Error creating payment request') + ':\n' + str(e))
            return

        assert key is not None
        if getattr(self, '_eh_offline_wanted', False):   # Easy Heirs: the offline Receive address
            self._eh_offline_wanted = False
            self._eh_offline_req = key
        self._logger.debug(f'created request with key {key} addr {addr}')
        self.addressCoinModel.setDirty()
        self.requestModel.add_invoice(self.wallet.get_request(key))
        self.requestCreateSuccess.emit(key)

    @pyqtSlot(str)
    def deleteRequest(self, key: str):
        self._logger.debug('delete req %s' % key)
        self.wallet.delete_request(key)
        self.requestModel.delete_invoice(key)

    @pyqtSlot(str)
    def deleteInvoice(self, key: str):
        self._logger.debug('delete inv %s' % key)
        self.wallet.delete_invoice(key)
        self.invoiceModel.delete_invoice(key)

    @pyqtSlot(str, result=bool)
    def verifyPassword(self, password):
        if not self.wallet.has_password():
            return not bool(password)
        try:
            self.wallet.check_password(password)
            return True
        except InvalidPassword as e:
            return False

    @pyqtSlot(str, result=bool)
    def setPassword(self, password):
        if password == '':
            password = None

        storage = self.wallet.storage

        # HW wallet not supported yet
        if storage.is_encrypted_with_hw_device():
            return False

        current_password = self.password if self.password != '' else None

        try:
            self._logger.info('setting new password')
            self.wallet.update_password(current_password, password, encrypt_storage=True)
            # restore the invariant that all loaded wallets in qml must be unlocked:
            self.wallet.unlock(password)
            return True
        except InvalidPassword as e:
            self._logger.exception(repr(e))
            return False

    @property
    def password(self):
        return self.wallet.get_unlocked_password()

    @pyqtSlot(str, result=bool)
    def ehSeedMatches(self, words):
        """Easy Heirs (third review, forgot PIN): are these the words of this wallet?"""
        try:
            if not self.wallet.has_seed():
                return False
            seed = self.wallet.get_seed(self.password)
        except Exception as e:
            self._logger.error(f'ehSeedMatches: {e!r}')
            return False
        from electrum.mnemonic import normalize_text
        import hmac
        a = ' '.join(normalize_text(seed or '').split())
        b = ' '.join(normalize_text(words or '').split())
        return bool(a) and hmac.compare_digest(a.encode('utf-8'), b.encode('utf-8'))

    @pyqtSlot(str)
    def importAddresses(self, addresslist):
        self.wallet.import_addresses(addresslist.split())
        if self._addressCoinModel:
            self._addressCoinModel.setDirty()
        self.dataChanged.emit()

    @pyqtSlot(str)
    def importPrivateKeys(self, keyslist):
        self.wallet.import_private_keys(keyslist.split(), self.password)
        if self._addressCoinModel:
            self._addressCoinModel.setDirty()
        self.dataChanged.emit()

    @pyqtSlot(str)
    def importChannelBackup(self, backup_str):
        try:
            self.wallet.lnworker.import_channel_backup(backup_str)
        except UserFacingException as e:
            self.importChannelBackupFailed.emit(str(e))
        except Exception as e:
            self._logger.debug(f'could not import channel backup: {repr(e)}')
            self.importChannelBackupFailed.emit(f'Failed to import backup:\n\n{str(e)}')

    @pyqtSlot(str, result=bool)
    def isValidChannelBackup(self, backup_str):
        try:
            assert backup_str.startswith('channel_backup:')
            encrypted = backup_str[15:]
            xpub = self.wallet.get_fingerprint()
            decrypted = pw_decode_with_version_and_mac(encrypted, xpub)
            return True
        except Exception:
            return False

    @pyqtSlot()
    def requestShowSeed(self):
        self.retrieve_seed()

    @auth_protect(method='wallet')
    def retrieve_seed(self):
        try:
            self._seed = self.wallet.get_seed(self.password)
            self._seed_passphrase = self.wallet.keystore.get_passphrase(self.password)
            self.seedRetrieved.emit()
        except Exception:
            self._seed = ''
            self._seed_passphrase = ''

        self.dataChanged.emit()

    @pyqtSlot(str, result='QVariantList')
    def getSerializedTx(self, txid):
        tx = self.wallet.db.get_transaction(txid)
        txqr = tx.to_qr_data()
        return [str(tx), txqr[0], txqr[1]]

    @pyqtSlot(result='QVariantMap')
    def getBalancesForPiechart(self):
        p_bal = self.wallet.get_balances_for_piechart()
        return {
            'confirmed': p_bal.confirmed,
            'unconfirmed': p_bal.unconfirmed,
            'unmatured': p_bal.unmatured,
            'frozen': p_bal.frozen,
            'lightning': int(p_bal.lightning),
            'f_lightning': int(p_bal.lightning_frozen),
            'total': int(p_bal.total())
        }

    @pyqtSlot(str, result=bool)
    def isAddressMine(self, addr):
        return self.wallet.is_mine(addr)

    @pyqtSlot(str, str)
    @auth_protect(message=_("Sign message?"))
    def signMessage(self, address, message):
        try:
            sig = self.wallet.sign_message(address=address, message=message, password=self.password)
        except UserFacingException as e:
            self.signMessageError.emit(str(e))
            return
        result = base64.b64encode(sig).decode('ascii')
        self.messageSigned.emit(result)

    def determine_max(self, *, mktx: Callable[[FeePolicy], PartialTransaction]) -> Tuple[Optional[int], Optional[str]]:
        # TODO: merge with SendTab.spend_max() and move to backend wallet
        amount = message = None
        try:
            try:
                fee_policy = FeePolicy(self.wallet.config.FEE_POLICY)
                tx = mktx(fee_policy)
            except (NotEnoughFunds, NoDynamicFeeEstimates) as e:
                # Check if we had enough funds excluding fees,
                # if so, still provide opportunity to set lower fees.
                fee_policy = FixedFeePolicy(0)
                tx = mktx(fee_policy)
            amount = tx.output_value()
        except NotEnoughFunds as e:
            self._logger.debug(str(e))
            message = self.wallet.get_text_not_enough_funds_mentioning_frozen(for_amount='!')

        return amount, message
