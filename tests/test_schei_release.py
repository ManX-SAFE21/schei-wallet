# Schȅi, owner 17/11 (controllo-mainnet G3): the real-money app must update the published one and
# be signed only with the owner's own key, never with Electrum's public debug key.
import importlib.util
import os
from unittest import TestCase

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
ANDROID = os.path.join(ROOT, 'contrib', 'android')
PUBLISHED_PRERELEASE_CODE = 45408033   # Schȅi v0.1.0-prova (Electrum 4.8.3, arm64)


def _versioncode_module():
    spec = importlib.util.spec_from_file_location('gav', os.path.join(ANDROID, 'get_apk_versioncode.py'))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


class TestScheiRelease(TestCase):

    def test_versioncode_above_the_published_prerelease(self):
        m = _versioncode_module()
        code = m.get_android_versioncode(arch_name='arm64-v8a')
        self.assertGreater(code, PUBLISHED_PRERELEASE_CODE)
        self.assertEqual(3, code % 10)                      # the arch stays the last digit
        self.assertGreaterEqual(code, 50_000_000)

    def test_schei_version_is_three_numbers(self):
        v = open(os.path.join(ANDROID, 'SCHEI_VERSION')).read().strip()
        parts = v.split('.')
        self.assertEqual(3, len(parts))
        self.assertTrue(all(p.isdigit() for p in parts))

    def test_signing_script_never_holds_a_password(self):
        s = open(os.path.join(ANDROID, 'schei_keys.sh'), encoding='utf-8').read()
        code = '\n'.join(ln for ln in s.split('\n') if not ln.strip().startswith('#'))
        for bad in ('--ks-pass', '-storepass', '-keypass', 'pass:', 'unsafepassword'):
            self.assertNotIn(bad, code)
        self.assertIn('if [ -f "$KEYDIR/$KS" ]', code)       # never overwrites the key

    def test_release_procedure_written(self):
        doc = open(os.path.join(ROOT, 'RELEASING-SCHEI.md'), encoding='utf-8').read()
        for k in ('release-unsigned', 'schei_keys.sh sign', 'SCHEI_VERSION', '206C20114CA96172'):
            self.assertIn(k, doc)
