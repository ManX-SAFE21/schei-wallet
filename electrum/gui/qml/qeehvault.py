# Easy Heirs (Schèi): the phone's safe and the PIN.
#
# The wallet password is a long random secret, kept "wrapped" by the Android
# keystore (java_classes/org/safe21/eh/KeyVault.java), so the wallet opens and
# small payments are signed without asking anything, while the keys on disk stay
# encrypted (as in Electrum). The 4-digit PIN is a separate check of the app:
# big payments, the 12 words, the advanced settings. Like a contactless card.
import hashlib
import hmac
import os
import secrets

from electrum.logging import get_logger

_logger = get_logger(__name__)

ON_ANDROID = 'ANDROID_DATA' in os.environ
_jKeyVault = None
if ON_ANDROID:
    try:
        from jnius import autoclass
        _jKeyVault = autoclass('org.safe21.eh.KeyVault')
    except Exception as e:
        _logger.error(f'eh vault: java class not available: {e!r}')

KEY_VAULT = 'eh_vault'   # wrapped wallet secret
KEY_PIN = 'eh_pin'       # salt:hash of the PIN
PC_PREFIX = 'pc-test-only:'   # PC previews have no keystore: plain text, never on a phone


def available() -> bool:
    return _jKeyVault is not None or not ON_ANDROID


def _wrap(plain: str) -> str:
    if _jKeyVault is not None:
        return 'ak:' + str(_jKeyVault.wrap(plain))
    if ON_ANDROID:
        raise RuntimeError('keystore not available')
    _logger.warning('eh vault: PC test mode, secret stored without keystore')
    return PC_PREFIX + plain


def _unwrap(data: str) -> str:
    if data.startswith('ak:'):
        if _jKeyVault is None:
            raise RuntimeError('keystore not available')
        return str(_jKeyVault.unwrap(data[3:]))
    if data.startswith(PC_PREFIX) and not ON_ANDROID:
        return data[len(PC_PREFIX):]
    raise RuntimeError('unknown vault data')


def get_secret(config) -> str:
    data = config.get(KEY_VAULT, '') or ''
    if not data:
        return ''
    try:
        return _unwrap(data)
    except Exception as e:
        _logger.error(f'eh vault: cannot unwrap: {e!r}')
        return ''


def get_or_create_secret(config) -> str:
    s = get_secret(config)
    if s:
        return s
    s = secrets.token_hex(32)
    config.set_key(KEY_VAULT, _wrap(s))
    if get_secret(config) != s:
        config.set_key(KEY_VAULT, '')
        raise RuntimeError('eh vault: read-back failed')
    return s


def _pin_hash(pin: str, salt: bytes) -> bytes:
    return hashlib.pbkdf2_hmac('sha256', pin.encode('utf-8'), salt, 200_000)


def pin_is_set(config) -> bool:
    return bool(config.get(KEY_PIN, ''))


def set_pin(config, pin: str) -> None:
    salt = secrets.token_bytes(16)
    config.set_key(KEY_PIN, salt.hex() + ':' + _pin_hash(pin, salt).hex())


def check_pin(config, pin: str) -> bool:
    data = config.get(KEY_PIN, '') or ''
    if ':' not in data:
        return False
    salt_hex, h_hex = data.split(':', 1)
    return hmac.compare_digest(_pin_hash(pin, bytes.fromhex(salt_hex)).hex(), h_hex)
