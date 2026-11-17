# Schȅi, owner 17/11 (controllo-mainnet M4): our send page lets ONE signature through without the
# PIN (the page asked it before when needed). That go-ahead must never outlive that one call.
import os
from unittest import TestCase

from electrum.gui.qml import qeapp

COMP = os.path.join(os.path.dirname(qeapp.__file__), 'components')


def _read(*p):
    return open(os.path.join(COMP, *p), encoding='utf-8').read()


def _body(src, start, end):
    return src[src.index(start):src.index(end, src.index(start))]


class TestSendGoAheadDoesNotStayOn(TestCase):

    def test_go_ahead_off_right_after_sign_and_send(self):
        body = _body(_read('EhInvoiceDialog.qml'), 'function doSend()', '\n    }\n')
        on = body.index('app._ehSendOk = true')
        call = body.index('finalizer.signAndSend()')
        off = body.index('app._ehSendOk = false')
        self.assertLess(on, call)
        self.assertLess(call, off)
        self.assertIn('} finally {', body[call:off])

    def test_only_place_that_turns_it_on(self):
        on = 0
        for root, _, files in os.walk(COMP):
            for f in files:
                if f.endswith('.qml'):
                    on += open(os.path.join(root, f), encoding='utf-8').read().count('_ehSendOk = true')
        self.assertEqual(1, on)

    def test_used_once_only_for_a_payment_of_the_wallet_open(self):
        body = _body(_read('main.qml'), 'function handleAuthRequired', '\n    }\n')
        self.assertIn("method === 'payment_auth' && qtobject === Daemon.currentWallet && app._ehSendOk", body)
        i = body.index('&& app._ehSendOk) {')
        self.assertIn('app._ehSendOk = false', body[i:i + 80])
