# Schȅi (owner 16/11, "non sbagliare mai"): on the normal version (mainnet) screenshots and screen
# videos must come out BLACK on the screens with important data (12 words, wallet creation, forgotten
# PIN, send...). Only the testnet4 app allows them (presentations; test coins have no value).
import os
import re
import types
from unittest import TestCase, mock

from electrum.gui.qml import qeapp

COMP = os.path.join(os.path.dirname(qeapp.__file__), 'components')

# screens that turn the screen black while visible (same list in the published Schȅi, 16/11)
SECURE_SCREENS = {
    'AddressDetails.qml': 'Boolean(addressdetails.privkey)',  # while the private key is shown
    'EhForgotPinDialog.qml': 'true',
    'EhPinDialog.qml': 'true',
    'EhChangePinDialog.qml': 'true',
    'EhInvoiceDialog.qml': 'true',
    'EhSeedPage.qml': 'true',
    'EhSendDialog.qml': 'true',
    'ImportAddressesKeysDialog.qml': 'true',
    'ScanDialog.qml': 'true',
    'SendDialog.qml': 'true',
    'SweepDialog.qml': 'true',
    'WalletDetails.qml': 'seedText.visible',  # while the 12 words are shown
}
# wallet wizard pages with the 12 words / keys (Wizard.qml uses their securePage)
SECURE_WIZARD_PAGES = [
    'WCCreateSeed.qml', 'WCConfirmSeed.qml', 'WCHaveSeed.qml', 'WCEasyCreateSeed.qml',
    'WCEasyConfirmSeed.qml', 'WCEasyHaveSeed.qml', 'WCImport.qml', 'WCHaveMasterKey.qml',
    'WCEnterExt.qml', 'WCConfirmExt.qml',
    'WCEasyPin.qml',
]


def _controller(always_allow=False):
    me = types.SimpleNamespace()
    me.isAndroid = lambda: True
    me.config = types.SimpleNamespace(GUI_QML_ALWAYS_ALLOW_SCREENSHOTS=always_allow)
    me._secureWindow = False
    me.secureWindowChanged = mock.Mock()
    return me


def _set_secure(me, value, testnet):
    activity = mock.Mock()
    net = types.SimpleNamespace(TESTNET=testnet)
    with mock.patch.object(qeapp, 'jpythonActivity', activity, create=True), \
            mock.patch.object(qeapp.constants, 'net', net):
        qeapp.QEAppController.secureWindow.fset(me, value)
    return activity


class TestScreenshotsBlack(TestCase):

    def test_mainnet_screen_goes_black(self):
        me = _controller()
        activity = _set_secure(me, True, testnet=False)
        activity.setSecureWindow.assert_called_once_with(True)
        self.assertTrue(me._secureWindow)

    def test_mainnet_screen_back_to_normal_when_leaving(self):
        me = _controller()
        _set_secure(me, True, testnet=False)
        activity = _set_secure(me, False, testnet=False)
        activity.setSecureWindow.assert_called_once_with(False)

    def test_only_testnet_allows_screenshots(self):
        me = _controller()
        activity = _set_secure(me, True, testnet=True)
        activity.setSecureWindow.assert_not_called()

    def test_the_testnet_exception_is_only_for_testnet(self):
        # the exception must depend on the test network and on nothing else
        src = open(qeapp.__file__, encoding='utf-8').read()
        body = src[src.index('def secureWindow(self, secure):'):src.index('def enforcesEdgeToEdge')]
        returns = re.findall(r'if (.+):\n\s+return', body)
        self.assertEqual(['not self.isAndroid()', 'self.config.GUI_QML_ALWAYS_ALLOW_SCREENSHOTS',
                          'constants.net.TESTNET'], returns)
        self.assertIn('jpythonActivity.setSecureWindow(secure)', body)

    def test_secure_screens_still_ask_for_black(self):
        wrong = []
        for name, value in SECURE_SCREENS.items():
            s = open(os.path.join(COMP, name), encoding='utf-8').read()
            blocks = re.findall(r'Binding\s*\{([^}]*)\}', s)
            pattern = r'value:\s*' + re.escape(value) + r'\s*(?:;|$)'
            if not any("property: 'secureWindow'" in b and re.search(pattern, b, re.M) for b in blocks):
                wrong.append(name)
        self.assertEqual([], wrong)

    def test_wizard_seed_pages_are_secure(self):
        wiz = open(os.path.join(COMP, 'wizard', 'Wizard.qml'), encoding='utf-8').read()
        self.assertIn("property: 'secureWindow'", wiz)
        self.assertIn('.securePage', wiz)
        missing = [n for n in SECURE_WIZARD_PAGES
                   if 'securePage: true' not in open(os.path.join(COMP, 'wizard', n), encoding='utf-8').read()]
        self.assertEqual([], missing)
