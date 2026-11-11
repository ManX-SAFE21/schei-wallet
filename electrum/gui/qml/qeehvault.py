# Easy Heirs (Schèi): the phone's safe and the PIN.
#
# The wallet password is a long random secret, kept "wrapped" by the Android
# keystore (java_classes/org/safe21/eh/KeyVault.java), so the wallet opens and
# small payments are signed without asking anything, while the keys on disk stay
# encrypted (as in Electrum). The 4-digit PIN is a separate check of the app:
# big payments, the 12 words, the advanced settings. Like a contactless card.
import hashlib
import hmac
import json
import os
import secrets
import stat

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


# review 2026-11-11 (W3): Electrum rewrites its whole config file at every change of any
# setting. If the phone died in that moment, the only copy of the wrapped wallet secret was
# lost and no wallet would open again (only the 12 words would help). Now the secret and the
# PIN check also live in their own small file, written only when they change, all or nothing.
SAFE_FILE = 'eh_safe'


def _safe_path(config):
    return os.path.join(config.path, SAFE_FILE) if getattr(config, 'path', None) else None


def _read_safe(config) -> dict:
    p = _safe_path(config)
    if not p or not os.path.exists(p):
        return {}
    try:
        with open(p, 'r', encoding='utf-8') as f:
            d = json.load(f)
        return d if isinstance(d, dict) else {}
    except Exception as e:
        _logger.error(f'eh vault: cannot read {SAFE_FILE}: {e!r}')
        return {}


def atomic_write(path: str, text: str) -> None:
    """Write all or nothing: temp file, fsync, then replace (as storage.py does for wallets)."""
    tmp = '%s.tmp.%s' % (path, os.getpid())
    with open(tmp, 'w', encoding='utf-8') as f:
        try:
            os.chmod(tmp, stat.S_IREAD | stat.S_IWRITE)
        except OSError:
            pass
        f.write(text)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def _save(config, key: str, value: str) -> None:
    """Save in the own file (first) and in the config (copy, as before)."""
    p = _safe_path(config)
    file_error = None
    if p:
        try:
            d = _read_safe(config)
            if value:
                d[key] = value
            else:
                d.pop(key, None)
            atomic_write(p, json.dumps(d, indent=1, sort_keys=True))
        except Exception as e:
            file_error = e
            _logger.error(f'eh vault: cannot write {SAFE_FILE}: {e!r}')
    try:
        config.set_key(key, value)
    except Exception:
        if file_error is not None:
            raise
        _logger.exception('eh vault: cannot write the config copy')


def _load(config, key: str) -> str:
    """The own file wins; an older install has it only in the config: copy it over once."""
    v = _read_safe(config).get(key, '') or ''
    if v:
        return v
    v = config.get(key, '') or ''
    if v and _safe_path(config):
        try:
            _save(config, key, v)
            _logger.info(f'eh vault: {key} copied to {SAFE_FILE}')
        except Exception as e:
            _logger.error(f'eh vault: cannot copy {key} to {SAFE_FILE}: {e!r}')
    return v


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
    data = _load(config, KEY_VAULT)
    if not data:
        return ''
    try:
        return _unwrap(data)
    except Exception as e:
        _logger.error(f'eh vault: cannot unwrap: {e!r}')
        return ''


def vault_broken(config) -> bool:
    """There is a wrapped secret, but this phone's safe cannot open it any more
    (app moved to another phone, restored from a backup: the keystore key is gone)."""
    return bool(_load(config, KEY_VAULT)) and not get_secret(config)


def get_or_create_secret(config) -> str:
    s = get_secret(config)
    if s:
        return s
    old = _load(config, KEY_VAULT)
    if old:
        # a secret this phone cannot read any more: kept aside, in case it was only temporary
        _save(config, KEY_VAULT + '_old', old)
        _logger.warning('eh vault: unreadable secret kept as eh_vault_old, making a new one')
    s = secrets.token_hex(32)
    _save(config, KEY_VAULT, _wrap(s))
    if get_secret(config) != s:
        _save(config, KEY_VAULT, '')
        raise RuntimeError('eh vault: read-back failed')
    return s


def _pin_hash(pin: str, salt: bytes) -> bytes:
    return hashlib.pbkdf2_hmac('sha256', pin.encode('utf-8'), salt, 200_000)


def pin_is_set(config) -> bool:
    return bool(_load(config, KEY_PIN))


def set_pin(config, pin: str) -> None:
    salt = secrets.token_bytes(16)
    _save(config, KEY_PIN, salt.hex() + ':' + _pin_hash(pin, salt).hex())


def check_pin(config, pin: str) -> bool:
    data = _load(config, KEY_PIN)
    if ':' not in data:
        return False
    salt_hex, h_hex = data.split(':', 1)
    return hmac.compare_digest(_pin_hash(pin, bytes.fromhex(salt_hex)).hex(), h_hex)
