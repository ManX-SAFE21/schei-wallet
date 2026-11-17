# Schȅi, Opus review 18/11 (point 4): after «I am not sure the payment left» the coins of that
# payment stay inside EVERY next payment of the wallet, also after the page (or the app) is closed,
# until that payment is in the history or the coins are spent. So it is never paid twice.
import os
from types import SimpleNamespace
from unittest import TestCase

from electrum.gui.qml import qeapp
from electrum.gui.qml.qetxfinalizer import QETxFinalizer
from electrum.gui.qml.qewallet import QEWallet

COMP = os.path.join(os.path.dirname(qeapp.__file__), "components")


def _read(*p):
    return open(os.path.join(COMP, *p), encoding="utf-8").read()


def _coin(s):
    return SimpleNamespace(prevout=SimpleNamespace(to_str=lambda s=s: s))


class _Wallet:
    def __init__(self, coins, known=()):
        self.coins = [_coin(c) for c in coins]
        self.known = set(known)
        self.db = SimpleNamespace(get_transaction=lambda txid: object() if txid in self.known else None)
        self.call = None

    def get_spendable_coins(self, domain=None):
        return list(self.coins)

    def make_unsigned_transaction(self, **kw):
        self.call = kw
        return SimpleNamespace(get_fee=lambda: 1, inputs=lambda: [], outputs=lambda: [])


def _make_tx(w, must=(), chosen=()):
    f = SimpleNamespace(f_make_tx=None, _wallet=SimpleNamespace(wallet=w), _eh_must=list(must),
                        _eh_coins=list(chosen), address="bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
                        _fee_policy=None, _rbf=True, _logger=SimpleNamespace(debug=lambda *a: None))
    QETxFinalizer.make_tx.__wrapped__(f, 1000) if hasattr(QETxFinalizer.make_tx, "__wrapped__") \
        else QETxFinalizer.make_tx(f, 1000)
    return w.call


class TestMustCoinsGoInside(TestCase):

    def test_coins_of_before_are_fixed_inputs(self):
        call = _make_tx(_Wallet(["a:0", "b:1", "c:0"]), must=["b:1"])
        self.assertEqual([c.prevout.to_str() for c in call["inputs"]], ["b:1"])
        # the other coins can still be added when the amount needs them
        self.assertEqual([c.prevout.to_str() for c in call["coins"]], ["a:0", "b:1", "c:0"])

    def test_without_a_payment_before_nothing_is_fixed(self):
        call = _make_tx(_Wallet(["a:0", "b:1"]))
        self.assertIsNone(call["inputs"])

    def test_a_coin_already_spent_is_not_forced(self):
        call = _make_tx(_Wallet(["a:0"]), must=["z:9"])
        self.assertIsNone(call["inputs"])


class TestWhenTheLockEnds(TestCase):

    def test_still_unsure_keeps_the_unspent_coins(self):
        w = SimpleNamespace(wallet=_Wallet(["a:0", "b:1"]))
        self.assertEqual(QEWallet.ehUnsureCoins(w, "t1", ["b:1", "z:9"]), ["b:1"])

    def test_the_payment_in_the_history_ends_it(self):
        w = SimpleNamespace(wallet=_Wallet(["a:0", "b:1"], known=["t1"]))
        self.assertEqual(QEWallet.ehUnsureCoins(w, "t1", ["b:1"]), [])

    def test_coins_spent_by_something_else_end_it(self):
        w = SimpleNamespace(wallet=_Wallet(["a:0"]))
        self.assertEqual(QEWallet.ehUnsureCoins(w, "t1", ["b:1"]), [])


class TestInThePages(TestCase):

    def test_remembered_for_the_next_payments(self):
        d = _read("EhInvoiceDialog.qml")
        i = d.index("function onBroadcastFailed(txid, code, reason) {")
        self.assertIn("app.ehUnsureSet(txid, same)", d[i:i + 700])

    def test_every_new_payment_starts_with_them(self):
        d = _read("EhInvoiceDialog.qml")
        i = d.index("    Component.onCompleted: {\n        var u = app.ehUnsureCoins()")
        self.assertIn("finalizer.ehMustCoins = u; unsureLock = true; coinsLocked = true", d[i:i + 300])

    def test_box_on_the_review(self):
        d = _read("EhInvoiceDialog.qml")
        self.assertIn("visible: dialog.unsureLock", d)
        self.assertIn("qsTr(\x27The payment before maybe left\x27)", d)

    def test_saved_per_wallet_and_cleared(self):
        m = _read("main.qml")
        self.assertIn("Config.ehSet(\x27unsure_\x27 + ehWalletKey(), JSON.stringify(", m)
        self.assertIn("if (left.length === 0) Config.ehSet(\x27unsure_\x27 + w.name, \x27\x27)", m)
        self.assertIn("\x27heir_on_\x27, \x27unsure_\x27]", m)
