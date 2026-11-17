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


class TestBanknotesNeverHideAnAmount(TestCase):
    # M6: what the banknotes show is the amount that goes to the check page

    def test_switch_to_euro_with_notes_starts_from_zero(self):
        d = _read('EhInvoiceDialog.qml')
        i = d.index('dialog.btcMode = b')
        nxt = d[i:i + 900]
        self.assertIn("if (sats <= 0 || dialog.useCoins) { dialog.euroInput = ''; return }", nxt)
        # the conversion to euro comes only after that check
        self.assertLess(nxt.index('dialog.useCoins'), nxt.index('Daemon.fx.fiatValue'))

    def test_notes_pad_drives_the_amount(self):
        d = _read('EhInvoiceDialog.qml')
        self.assertIn('onBtcModeChanged: if (!btcMode && coinsMode) coinPad.clear()', d)
        self.assertIn('onEuroInputChanged: if (dialog.useCoins) dialog.euroInput = euroInput', d)

    def test_draft_back_from_step_one_turns_the_notes_off(self):
        d = _read('EhInvoiceDialog.qml')
        i = d.index('euroInput = d.euroInput')
        self.assertIn('coinsMode = false', d[i - 200:i])


class TestSendAnswersAndUnits(TestCase):
    # controllo-mainnet 3.5 / 3.7

    def test_sent_only_for_our_payment(self):
        d = _read('EhInvoiceDialog.qml')
        self.assertIn('dialog.sentTxid = finalizer.finalizedTxid', d)
        for sig in ('function onBroadcastSucceeded(txid) {', 'function onBroadcastFailed(txid, code, reason) {'):
            i = d.index(sig)
            self.assertIn('if (!mine(txid)) return', d[i:i + 120], sig)
        self.assertIn("dialog.busy && (dialog.sentTxid === '' || txid === dialog.sentTxid)", d)

    def test_no_fixed_btc_unit(self):
        d = _read('EhInvoiceDialog.qml')
        self.assertNotIn("'0 BTC'", d)
        self.assertNotIn("'Bitcoin (BTC)'", d)


class TestFeeByHand(TestCase):
    # controllo-mainnet 3.2 / 3.3

    def test_invalid_typed_rate_never_goes_on(self):
        m = _read('EhManualFeeSheet.qml')
        i = m.index("qsTr('Fine, continue')")
        self.assertIn("root.finalizer.ehParseFeerate(root.typed) !== ''", m[i - 400:i])

    def test_rows_show_the_rate_written_by_hand(self):
        for f in ('EhInvoiceDialog.qml', 'EhHeirCostRow.qml'):
            self.assertIn("finalizer.userFeerate !== '' ? app.ehFeeRate(finalizer.userFeerate + ' sat/vB')", _read(f), f)


class TestNeverPaidTwice(TestCase):
    # owner 17/11 (controllo-mainnet 3.4): «not sure it left» -> the same coins for the next try

    def test_unsure_locks_the_same_coins(self):
        d = _read('EhInvoiceDialog.qml')
        i = d.index('function onBroadcastFailed(txid, code, reason) {')
        body = d[i:i + 600]
        self.assertIn("if (code !== 'rejected') {", body)
        self.assertIn('finalizer.ehCoins = same; dialog.coinsLocked = true', body)

    def test_other_coins_cannot_be_chosen_while_locked(self):
        d = _read('EhInvoiceDialog.qml')
        i = d.index('function chooseCoins() {')
        self.assertIn('if (dialog.coinsLocked) {', d[i:i + 200])

    def test_finalizer_gives_the_coins_of_the_payment(self):
        from electrum.gui.qml import qetxfinalizer
        src = open(qetxfinalizer.__file__, encoding='utf-8').read()
        i = src.index('def ehTxCoins(self):')
        self.assertIn('self._tx.inputs()', src[i:i + 300])
