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

    # ---- Easy Heirs T32: where to see a movement on the blockchain ----
    # Electrum's own setting (BLOCK_EXPLORER / BLOCK_EXPLORER_CUSTOM, util.block_explorer_URL).
    # Schèi default: mempool.space, until the user chooses something else.
    _EH_BE_ORDER = ('mempool.space', 'Blockstream.info', 'Blockchair.com', 'mempool.emzy.de')
    ehExplorerChanged = pyqtSignal()

    def _eh_be_name(self) -> str:
        from electrum.util import block_explorer_info
        info = block_explorer_info()
        chosen = self.config.get('block_explorer', None)
        if chosen in info:
            return chosen
        return 'mempool.space' if 'mempool.space' in info else self.config.cv.BLOCK_EXPLORER.get_default_value()

    @pyqtSlot(result='QVariantList')
    def ehExplorers(self):
        """The sites offered, best first (only the ones Electrum knows for this network)."""
        from electrum.util import block_explorer_info
        info = block_explorer_info()
        names = [n for n in self._EH_BE_ORDER if n in info]
        if not names:
            names = [n for n in info if n != 'system default']
        return [{'name': n, 'url': info[n][0]} for n in names]

    @pyqtProperty('QVariantMap', notify=ehExplorerChanged)
    def ehExplorer(self):
        custom = self.config.BLOCK_EXPLORER_CUSTOM
        return {'name': '' if custom else self._eh_be_name(), 'custom': custom if isinstance(custom, str) else ''}

    @pyqtSlot(str)
    def ehSetExplorer(self, name: str):
        self.config.BLOCK_EXPLORER_CUSTOM = None
        self.config.BLOCK_EXPLORER = name
        self.ehExplorerChanged.emit()

    @pyqtSlot(str, result=bool)
    def ehSetExplorerCustom(self, url: str) -> bool:
        """'Il mio nodo': the address of one's own mempool (e.g. http://umbrel.local:3006)."""
        url = url.strip()
        if not (url.startswith('http://') or url.startswith('https://')) or len(url) < 12:
            return False
        if not url.endswith('/'):
            url += '/'
        self.config.BLOCK_EXPLORER_CUSTOM = url
        self.ehExplorerChanged.emit()
        return True

    @pyqtSlot(str, result=str)
    def ehExplorerTxUrl(self, txid: str) -> str:
        from electrum.util import block_explorer_URL
        if not self.config.BLOCK_EXPLORER_CUSTOM and self.config.get('block_explorer', None) is None:
            self.config.BLOCK_EXPLORER = self._eh_be_name()   # write the Schèi default once
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
