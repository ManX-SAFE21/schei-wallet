import copy
from decimal import Decimal
from typing import TYPE_CHECKING

from PyQt6.QtCore import pyqtProperty, pyqtSignal, pyqtSlot, QObject, QRegularExpression

from electrum.bitcoin import TOTAL_COIN_SUPPLY_LIMIT_IN_BTC
from electrum.i18n import set_language, get_gui_lang_names
from electrum.logging import get_logger
from electrum.util import base_unit_name_to_decimal_point
from electrum.gui import messages

from .qetypes import QEAmount
from .auth import AuthMixin, auth_protect

if TYPE_CHECKING:
    from electrum.simple_config import SimpleConfig


EASY_HEIRS_LANGUAGES = [
    ('it_IT', 'Italiano'),
    ('vec_IT', 'Veneto'),
    ('en_UK', 'English'),
]


class QEConfig(AuthMixin, QObject):
    instance = None  # type: Optional[QEConfig]
    _logger = get_logger(__name__)

    def __init__(self, config: 'SimpleConfig', parent=None):
        super().__init__(parent)
        if QEConfig.instance:
            raise RuntimeError('There should only be one QEConfig instance')
        QEConfig.instance = self
        self.config = config

    @pyqtSlot(str, result=str)
    def shortDescFor(self, key) -> str:
        cv = getattr(self.config.cv, key)
        return cv.get_short_desc() if cv else ''

    @pyqtSlot(str, result=str)
    def longDescFor(self, key) -> str:
        cv = getattr(self.config.cv, key)
        if not cv:
            return ""
        desc = cv.get_long_desc()
        return messages.to_rtf(desc)

    @pyqtSlot(str, result=str)
    def getTranslatedMessage(self, key) -> str:
        return getattr(messages, key)

    languageChanged = pyqtSignal()
    @pyqtProperty(str, notify=languageChanged)
    def language(self):
        return self.config.LOCALIZATION_LANGUAGE

    @language.setter
    def language(self, language):
        if language not in get_gui_lang_names():
            return
        if self.config.LOCALIZATION_LANGUAGE != language:
            self.config.LOCALIZATION_LANGUAGE = language
            set_language(language)
            self.languageChanged.emit()

    # Easy Heirs: small key/value store for our options (keys prefixed 'eh_')
    @pyqtSlot(str, result='QVariant')
    def ehGet(self, key):
        return self.config.get('eh_' + key, None)

    @pyqtSlot(str, 'QVariant')
    def ehSet(self, key, value):
        self.config.set_key('eh_' + key, value)

    @pyqtSlot(int, result=float)
    def ehFeeRateForBlocks(self, blocks: int) -> float:
        """sat/vB that Electrum estimates to be mined within `blocks` blocks; 0 if unknown."""
        try:
            from electrum.network import Network
            net = Network.get_instance()
            fee_kb = net.fee_estimates.eta_target_to_fee(blocks) if net else None
            return float(fee_kb) / 1000.0 if fee_kb else 0.0
        except Exception:
            return 0.0

    @pyqtSlot(result=float)
    def ehMonoMs(self) -> float:
        """Milliseconds since the phone was switched on (Android SystemClock.elapsedRealtime,
        counts also while asleep). Changing the date / time in the settings does not move it:
        used for the PIN lockout (review 2026-11-11)."""
        try:
            from jnius import autoclass
            return float(autoclass('android.os.SystemClock').elapsedRealtime())
        except Exception:
            import time
            return time.monotonic() * 1000.0

    # ---- Easy Heirs T32: where to see a movement on the blockchain ----
    # The list = Electrum's sites for this network (best first) + "Il mio nodo" + sites added
    # by the user; every one can be renamed / given another address (owner 2026-11-11).
    # Kept in the config per network: eh_explorers_<net> = {id: {name, url, tx, addr}},
    # eh_explorer_sel_<net> = id. Applied to Electrum's own BLOCK_EXPLORER(_CUSTOM).
    _EH_BE_ORDER = ('mempool.space', 'Blockstream.info', 'Blockchair.com', 'mempool.emzy.de')
    ehExplorerChanged = pyqtSignal()

    def _eh_net(self):
        from electrum import constants
        return constants.net.NET_NAME

    def _eh_be_defaults(self):
        from electrum.util import block_explorer_info
        info = block_explorer_info()
        names = [n for n in self._EH_BE_ORDER if n in info] or [n for n in info if n != 'system default']
        out = []
        for n in names:
            url, kinds = info[n]
            out.append({'id': n, 'name': n, 'url': url, 'tx': kinds.get('tx', 'tx/'), 'addr': kinds.get('addr', 'address/'),
                        'builtin': True})
        out.append({'id': 'mine', 'name': '', 'url': '', 'tx': 'tx/', 'addr': 'address/', 'builtin': True})
        return out

    def _eh_be_saved(self) -> dict:
        d = self.config.get('eh_explorers_' + self._eh_net(), None)
        return dict(d) if isinstance(d, dict) else {}

    @pyqtSlot(result='QVariantList')
    def ehExplorers(self):
        saved = self._eh_be_saved()
        out = []
        for e in self._eh_be_defaults():
            s = saved.get(e['id'])
            if s:
                e = dict(e, name=s.get('name', e['name']), url=s.get('url', e['url']), edited=True)
            out.append(e)
        for k, s in saved.items():
            if k.startswith('u'):
                out.append({'id': k, 'name': s.get('name', ''), 'url': s.get('url', ''), 'tx': 'tx/', 'addr': 'address/',
                            'builtin': False})
        # the old setting "my node" (block_explorer_custom as a plain address) shows up in "Il mio nodo"
        custom = self.config.BLOCK_EXPLORER_CUSTOM
        for e in out:
            if e['id'] == 'mine' and not e['url'] and isinstance(custom, str):
                e['url'] = custom
        return out

    def _eh_sel_id(self) -> str:
        sel = self.config.get('eh_explorer_sel_' + self._eh_net(), None)
        if sel:
            return sel
        if isinstance(self.config.BLOCK_EXPLORER_CUSTOM, str):
            return 'mine'
        chosen = self.config.get('block_explorer', None)
        ids = [e['id'] for e in self._eh_be_defaults()]
        if chosen in ids:
            return chosen
        return 'mempool.space' if 'mempool.space' in ids else ids[0]

    @pyqtProperty('QVariantMap', notify=ehExplorerChanged)
    def ehExplorer(self):
        sel = self._eh_sel_id()
        for e in self.ehExplorers():
            if e['id'] == sel:
                return e
        return {'id': '', 'name': '', 'url': ''}

    def _eh_apply(self):
        """Write the chosen site into Electrum's own setting."""
        e = self.ehExplorer
        if not e.get('id') or not e.get('url'):
            return
        if e.get('builtin') and not e.get('edited') and e['id'] != 'mine':
            self.config.BLOCK_EXPLORER_CUSTOM = None
            self.config.BLOCK_EXPLORER = e['id']
        else:
            self.config.BLOCK_EXPLORER_CUSTOM = [e['url'], {'tx': e.get('tx', 'tx/'), 'addr': e.get('addr', 'address/')}]

    @pyqtSlot(str)
    def ehSelectExplorer(self, id_: str):
        self.config.set_key('eh_explorer_sel_' + self._eh_net(), id_)
        self._eh_apply()
        self.ehExplorerChanged.emit()

    @staticmethod
    def _eh_clean_url(url: str) -> str:
        url = url.strip()
        if not (url.startswith('http://') or url.startswith('https://')) or len(url) < 12 or ' ' in url:
            return ''
        return url if url.endswith('/') else url + '/'

    @pyqtSlot(str, str, str, result=str)
    def ehSaveExplorer(self, id_: str, name: str, url: str) -> str:
        """Save name + address of a site ('' id = a new one). Returns its id, '' if the address is wrong."""
        url = self._eh_clean_url(url)
        if not url:
            return ''
        saved = self._eh_be_saved()
        if not id_:
            import time
            id_ = 'u%d' % int(time.time() * 1000)
        saved[id_] = {'name': name.strip()[:30], 'url': url}
        self.config.set_key('eh_explorers_' + self._eh_net(), saved)
        if self._eh_sel_id() == id_:
            self._eh_apply()
        self.ehExplorerChanged.emit()
        return id_

    @pyqtSlot(str)
    def ehForgetExplorer(self, id_: str):
        """A site of Electrum: back to its original name and address. A site added by the user: removed."""
        saved = self._eh_be_saved()
        saved.pop(id_, None)
        self.config.set_key('eh_explorers_' + self._eh_net(), saved)
        if id_ == 'mine' and isinstance(self.config.BLOCK_EXPLORER_CUSTOM, str):
            self.config.BLOCK_EXPLORER_CUSTOM = None
        if self._eh_sel_id() == id_ and not id_.startswith('u') and id_ != 'mine':
            self._eh_apply()
        elif self._eh_sel_id() == id_:
            self.ehSelectExplorer('mempool.space')
        self.ehExplorerChanged.emit()

    @pyqtSlot(str, result=str)
    def ehExplorerTxUrl(self, txid: str) -> str:
        from electrum.util import block_explorer_URL
        if not self.config.BLOCK_EXPLORER_CUSTOM and self.config.get('block_explorer', None) is None:
            self._eh_apply()   # write the Schȅi default (mempool.space) once
        return block_explorer_URL(self.config, 'tx', txid) or ''

    languagesChanged = pyqtSignal()
    @pyqtProperty('QVariantList', notify=languagesChanged)
    def languagesAvailable(self):
        # Easy Heirs: only Italian, Veneto and English, each name in its own language
        return [{'value': code, 'text': name} for code, name in EASY_HEIRS_LANGUAGES]

    @pyqtProperty(bool, notify=languageChanged)
    def languageChosen(self) -> bool:
        return bool(self.config.LOCALIZATION_LANGUAGE)

    @pyqtProperty(str, constant=True)
    def phoneLanguage(self) -> str:
        """The one of our 3 languages closest to the phone language."""
        try:
            from electrum.gui.default_lang import get_default_language
            name = get_default_language(gui_name='qml') or ''
        except Exception:
            name = ''
        if name.startswith('vec'):
            return 'vec_IT'
        if name.startswith('it'):
            return 'it_IT'
        return 'en_UK'

    termsOfUseChanged = pyqtSignal()
    @pyqtProperty(bool, notify=termsOfUseChanged)
    def termsOfUseAccepted(self) -> bool:
        return self.config.TERMS_OF_USE_ACCEPTED >= messages.TERMS_OF_USE_LATEST_VERSION

    @termsOfUseAccepted.setter
    def termsOfUseAccepted(self, accepted: bool) -> None:
        if accepted:
            self.config.TERMS_OF_USE_ACCEPTED = messages.TERMS_OF_USE_LATEST_VERSION
        else:
            self.config.TERMS_OF_USE_ACCEPTED = 0
        self.termsOfUseChanged.emit()

    baseUnitChanged = pyqtSignal()
    @pyqtProperty(str, notify=baseUnitChanged)
    def baseUnit(self):
        return self.config.get_base_unit()

    @baseUnit.setter
    def baseUnit(self, unit):
        self.config.set_base_unit(unit)
        self.baseUnitChanged.emit()

    @pyqtProperty('QRegularExpression', notify=baseUnitChanged)
    def btcAmountRegex(self):
        return self._btcAmountRegex()

    @pyqtProperty('QRegularExpression', notify=baseUnitChanged)
    def btcAmountRegexMsat(self):
        return self._btcAmountRegex(3)

    def _btcAmountRegex(self, extra_precision: int = 0):
        decimal_point = base_unit_name_to_decimal_point(self.config.get_base_unit())
        max_digits_before_dp = (
            len(str(TOTAL_COIN_SUPPLY_LIMIT_IN_BTC))
            + (base_unit_name_to_decimal_point("BTC") - decimal_point))
        exp = '^[0-9]{0,%d}' % max_digits_before_dp
        decimal_point += extra_precision
        if decimal_point > 0:
            exp += '(\\.[0-9]{0,%d})?' % decimal_point
        exp += '$'
        return QRegularExpression(exp)

    thousandsSeparatorChanged = pyqtSignal()
    @pyqtProperty(bool, notify=thousandsSeparatorChanged)
    def thousandsSeparator(self):
        return self.config.BTC_AMOUNTS_ADD_THOUSANDS_SEP

    @thousandsSeparator.setter
    def thousandsSeparator(self, checked):
        self.config.BTC_AMOUNTS_ADD_THOUSANDS_SEP = checked
        self.config.amt_add_thousands_sep = checked
        self.thousandsSeparatorChanged.emit()

    spendUnconfirmedChanged = pyqtSignal()
    @pyqtProperty(bool, notify=spendUnconfirmedChanged)
    def spendUnconfirmed(self):
        return not self.config.WALLET_SPEND_CONFIRMED_ONLY

    @spendUnconfirmed.setter
    def spendUnconfirmed(self, checked):
        self.config.WALLET_SPEND_CONFIRMED_ONLY = not checked
        self.spendUnconfirmedChanged.emit()

    freezeReusedAddressUtxosChanged = pyqtSignal()
    @pyqtProperty(bool, notify=freezeReusedAddressUtxosChanged)
    def freezeReusedAddressUtxos(self):
        return self.config.WALLET_FREEZE_REUSED_ADDRESS_UTXOS

    @freezeReusedAddressUtxos.setter
    def freezeReusedAddressUtxos(self, checked):
        self.config.WALLET_FREEZE_REUSED_ADDRESS_UTXOS = checked
        self.freezeReusedAddressUtxosChanged.emit()

    requestExpiryChanged = pyqtSignal()
    @pyqtProperty(int, notify=requestExpiryChanged)
    def requestExpiry(self):
        return self.config.WALLET_PAYREQ_EXPIRY_SECONDS

    @requestExpiry.setter
    def requestExpiry(self, expiry):
        self.config.WALLET_PAYREQ_EXPIRY_SECONDS = expiry
        self.requestExpiryChanged.emit()

    paymentAuthenticationChanged = pyqtSignal()
    @pyqtProperty(bool, notify=paymentAuthenticationChanged)
    def paymentAuthentication(self):
        return self.config.GUI_QML_PAYMENT_AUTHENTICATION

    @paymentAuthentication.setter
    def paymentAuthentication(self, enabled: bool):
        if enabled:
            self.config.GUI_QML_PAYMENT_AUTHENTICATION = True
            self.paymentAuthenticationChanged.emit()
        else:
            self._disable_payment_authentication()

    @auth_protect(method='wallet', reject='_payment_auth_reject')
    def _disable_payment_authentication(self):
        self.config.GUI_QML_PAYMENT_AUTHENTICATION = False
        self.paymentAuthenticationChanged.emit()

    def _payment_auth_reject(self):
        self.paymentAuthenticationChanged.emit()

    useGossipChanged = pyqtSignal()
    @pyqtProperty(bool, notify=useGossipChanged)
    def useGossip(self):
        return self.config.LIGHTNING_USE_GOSSIP

    @useGossip.setter
    def useGossip(self, gossip):
        self.config.LIGHTNING_USE_GOSSIP = gossip
        self.useGossipChanged.emit()

    enableDebugLogsChanged = pyqtSignal()
    @pyqtProperty(bool, notify=enableDebugLogsChanged)
    def enableDebugLogs(self):
        gui_setting = self.config.GUI_ENABLE_DEBUG_LOGS
        return gui_setting or bool(self.config.get('verbosity'))

    @pyqtProperty(bool, notify=enableDebugLogsChanged)
    def canToggleDebugLogs(self):
        gui_setting = self.config.GUI_ENABLE_DEBUG_LOGS
        return not self.config.get('verbosity') or gui_setting

    @enableDebugLogs.setter
    def enableDebugLogs(self, enable):
        self.config.GUI_ENABLE_DEBUG_LOGS = enable
        self.enableDebugLogsChanged.emit()

    alwaysAllowScreenshotsChanged = pyqtSignal()
    @pyqtProperty(bool, notify=alwaysAllowScreenshotsChanged)
    def alwaysAllowScreenshots(self):
        return self.config.GUI_QML_ALWAYS_ALLOW_SCREENSHOTS

    @alwaysAllowScreenshots.setter
    def alwaysAllowScreenshots(self, enable):
        self.config.GUI_QML_ALWAYS_ALLOW_SCREENSHOTS = enable
        self.alwaysAllowScreenshotsChanged.emit()

    setMaxBrightnessOnQrDisplayChanged = pyqtSignal()
    @pyqtProperty(bool, notify=setMaxBrightnessOnQrDisplayChanged)
    def setMaxBrightnessOnQrDisplay(self):
        return self.config.GUI_QML_SET_MAX_BRIGHTNESS_ON_QR_DISPLAY

    @setMaxBrightnessOnQrDisplay.setter
    def setMaxBrightnessOnQrDisplay(self, enable):
        self.config.GUI_QML_SET_MAX_BRIGHTNESS_ON_QR_DISPLAY = enable

    useRecoverableChannelsChanged = pyqtSignal()
    @pyqtProperty(bool, notify=useRecoverableChannelsChanged)
    def useRecoverableChannels(self):
        return self.config.LIGHTNING_USE_RECOVERABLE_CHANNELS

    @useRecoverableChannels.setter
    def useRecoverableChannels(self, useRecoverableChannels):
        self.config.LIGHTNING_USE_RECOVERABLE_CHANNELS = useRecoverableChannels
        self.useRecoverableChannelsChanged.emit()

    trustedcoinPrepayChanged = pyqtSignal()
    @pyqtProperty(int, notify=trustedcoinPrepayChanged)
    def trustedcoinPrepay(self):
        return self.config.PLUGIN_TRUSTEDCOIN_NUM_PREPAY

    @trustedcoinPrepay.setter
    def trustedcoinPrepay(self, num_prepay):
        if num_prepay != self.config.PLUGIN_TRUSTEDCOIN_NUM_PREPAY:
            self.config.PLUGIN_TRUSTEDCOIN_NUM_PREPAY = num_prepay
            self.trustedcoinPrepayChanged.emit()

    preferredRequestTypeChanged = pyqtSignal()
    @pyqtProperty(str, notify=preferredRequestTypeChanged)
    def preferredRequestType(self):
        return self.config.GUI_QML_PREFERRED_REQUEST_TYPE

    @preferredRequestType.setter
    def preferredRequestType(self, preferred_request_type):
        if preferred_request_type != self.config.GUI_QML_PREFERRED_REQUEST_TYPE:
            self.config.GUI_QML_PREFERRED_REQUEST_TYPE = preferred_request_type
            self.preferredRequestTypeChanged.emit()

    userKnowsPressAndHoldChanged = pyqtSignal()
    @pyqtProperty(bool, notify=userKnowsPressAndHoldChanged)
    def userKnowsPressAndHold(self):
        return self.config.GUI_QML_USER_KNOWS_PRESS_AND_HOLD

    @userKnowsPressAndHold.setter
    def userKnowsPressAndHold(self, userKnowsPressAndHold):
        if userKnowsPressAndHold != self.config.GUI_QML_USER_KNOWS_PRESS_AND_HOLD:
            self.config.GUI_QML_USER_KNOWS_PRESS_AND_HOLD = userKnowsPressAndHold
            self.userKnowsPressAndHoldChanged.emit()

    addresslistShowTypeChanged = pyqtSignal()
    @pyqtProperty(int, notify=addresslistShowTypeChanged)
    def addresslistShowType(self):
        return self.config.GUI_QML_ADDRESS_LIST_SHOW_TYPE

    @addresslistShowType.setter
    def addresslistShowType(self, addresslistShowType):
        if addresslistShowType != self.config.GUI_QML_ADDRESS_LIST_SHOW_TYPE:
            self.config.GUI_QML_ADDRESS_LIST_SHOW_TYPE = addresslistShowType
            self.addresslistShowTypeChanged.emit()

    addresslistShowUsedChanged = pyqtSignal()
    @pyqtProperty(bool, notify=addresslistShowUsedChanged)
    def addresslistShowUsed(self):
        return self.config.GUI_QML_ADDRESS_LIST_SHOW_USED

    @addresslistShowUsed.setter
    def addresslistShowUsed(self, addresslistShowUsed):
        if addresslistShowUsed != self.config.GUI_QML_ADDRESS_LIST_SHOW_USED:
            self.config.GUI_QML_ADDRESS_LIST_SHOW_USED = addresslistShowUsed
            self.addresslistShowUsedChanged.emit()

    outputValueRoundingChanged = pyqtSignal()
    @pyqtProperty(bool, notify=outputValueRoundingChanged)
    def outputValueRounding(self):
        return self.config.WALLET_COIN_CHOOSER_OUTPUT_ROUNDING

    @outputValueRounding.setter
    def outputValueRounding(self, outputValueRounding):
        if outputValueRounding != self.config.WALLET_COIN_CHOOSER_OUTPUT_ROUNDING:
            self.config.WALLET_COIN_CHOOSER_OUTPUT_ROUNDING = outputValueRounding
            self.outputValueRoundingChanged.emit()

    lightningPaymentFeeMaxMillionthsChanged = pyqtSignal()
    @pyqtProperty(int, notify=lightningPaymentFeeMaxMillionthsChanged)
    def lightningPaymentFeeMaxMillionths(self):
        return self.config.LIGHTNING_PAYMENT_FEE_MAX_MILLIONTHS

    @lightningPaymentFeeMaxMillionths.setter
    def lightningPaymentFeeMaxMillionths(self, lightningPaymentFeeMaxMillionths):
        if lightningPaymentFeeMaxMillionths != self.config.LIGHTNING_PAYMENT_FEE_MAX_MILLIONTHS:
            self.config.LIGHTNING_PAYMENT_FEE_MAX_MILLIONTHS = lightningPaymentFeeMaxMillionths
            self.lightningPaymentFeeMaxMillionthsChanged.emit()

    nostrRelaysChanged = pyqtSignal()
    @pyqtProperty(str, notify=nostrRelaysChanged)
    def nostrRelays(self):
        return self.config.NOSTR_RELAYS

    @nostrRelays.setter
    def nostrRelays(self, nostr_relays):
        if nostr_relays != self.config.NOSTR_RELAYS:
            self.config.NOSTR_RELAYS = nostr_relays if nostr_relays else None
            self.nostrRelaysChanged.emit()

    swapServerNPubChanged = pyqtSignal()
    @pyqtProperty(str, notify=swapServerNPubChanged)
    def swapServerNPub(self):
        return self.config.SWAPSERVER_NPUB

    @swapServerNPub.setter
    def swapServerNPub(self, swapserver_npub):
        if swapserver_npub != self.config.SWAPSERVER_NPUB:
            self.config.SWAPSERVER_NPUB = swapserver_npub
            self.swapServerNPubChanged.emit()

    lnUtxoReserveChanged = pyqtSignal()
    @pyqtProperty(QEAmount, notify=lnUtxoReserveChanged)
    def lnUtxoReserve(self):
        self._lnutxoreserve = QEAmount(amount_sat=self.config.LN_UTXO_RESERVE)
        return self._lnutxoreserve

    walletShouldUseSinglePasswordChanged = pyqtSignal()
    @pyqtProperty(bool, notify=walletShouldUseSinglePasswordChanged)
    def walletShouldUseSinglePassword(self):
        """
        NOTE: this only indicates if we even want to use a single password, to check if we
        actually use a single password the daemon needs to be checked.
        """
        return self.config.WALLET_SHOULD_USE_SINGLE_PASSWORD

    walletDidUseSinglePasswordChanged = pyqtSignal()
    @pyqtProperty(bool, notify=walletDidUseSinglePasswordChanged)
    def walletDidUseSinglePassword(self):
        """
        Allows to guess if this is a unified password instance without having
        unlocked any wallet yet. Might be out of sync e.g. if wallet files get copied manually.
        """
        # TODO: consider removing once encrypted wallet file headers are available
        return self.config.WALLET_DID_USE_SINGLE_PASSWORD

    @pyqtSlot('qint64', result=str)
    @pyqtSlot(QEAmount, result=str)
    def formatSatsForEditing(self, satoshis):
        if isinstance(satoshis, QEAmount):
            satoshis = satoshis.satsInt
        return self.config.format_amount(
            satoshis,
            add_thousands_sep=False,
        )

    @pyqtSlot('qint64', result=str)
    @pyqtSlot('qint64', bool, result=str)
    @pyqtSlot(QEAmount, result=str)
    @pyqtSlot(QEAmount, bool, result=str)
    def formatSats(self, satoshis, with_unit=False):
        if isinstance(satoshis, QEAmount):
            satoshis = satoshis.satsInt
        if with_unit:
            return self.config.format_amount_and_units(satoshis)
        else:
            return self.config.format_amount(satoshis)

    @pyqtSlot(QEAmount, result=str)
    @pyqtSlot(QEAmount, bool, result=str)
    def formatMilliSats(self, amount, with_unit=False):
        assert isinstance(amount, QEAmount), f"unexpected type for amount: {type(amount)}"
        msats = amount.msatsInt
        precision = 3  # config.amt_precision_post_satoshi is not exposed in preferences
        if with_unit:
            return self.config.format_amount_and_units(msats/1000, precision=precision)
        else:
            return self.config.format_amount(msats/1000, precision=precision)

    @pyqtSlot(str, result=QEAmount)
    def unitsToSats(self, unitAmount):
        self._amount = QEAmount()
        try:
            x = Decimal(unitAmount)
        except Exception:
            return self._amount

        sat_max_precision = self.config.BTC_AMOUNTS_DECIMAL_POINT
        msat_max_precision = self.config.BTC_AMOUNTS_DECIMAL_POINT + 3
        sat_max_prec_amount = int(pow(10, sat_max_precision) * x)
        msat_max_prec_amount = int(pow(10, msat_max_precision) * x)
        self._amount = QEAmount(amount_sat=sat_max_prec_amount, amount_msat=msat_max_prec_amount)
        return self._amount

    @pyqtSlot('quint64', result=float)
    def satsToUnits(self, satoshis):
        return satoshis / pow(10, self.config.BTC_AMOUNTS_DECIMAL_POINT)
