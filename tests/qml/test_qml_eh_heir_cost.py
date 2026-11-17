# Schȅi, owner 17/11 (M7 bis): cancelling / renewing the inheritance is paid LIKE A PAYMENT: the same
# cost row, the same speed page, by hand when the servers give no estimate. Never 20 sat/vB.
import os
from unittest import TestCase

from electrum.gui.qml import qeapp

COMP = os.path.join(os.path.dirname(qeapp.__file__), 'components')


def _read(*p):
    return open(os.path.join(COMP, *p), encoding='utf-8').read()


class TestCostRow(TestCase):

    def setUp(self):
        self.row = _read('EhHeirCostRow.qml')

    def test_same_pages_as_a_payment(self):
        self.assertIn("Qt.resolvedUrl('EhFeeDialog.qml')", self.row)
        self.assertIn("Qt.resolvedUrl('EhManualFeeSheet.qml')", self.row)
        self.assertIn('Component.onCompleted: { method = 1; sliderPos = 4 }', self.row)   # "in about 1 hour"

    def test_prices_the_real_invalidation(self):
        self.assertIn('finalizer.ehCoins = root.coins', self.row)
        self.assertIn('finalizer.amount = MAX', self.row)
        self.assertIn('heirSt.invalidate.coins', self.row)

    def test_hands_the_shown_cost_to_the_bridge(self):
        i = self.row.index('function commit(bal)')
        body = self.row[i:i + 400]
        self.assertIn('bal.setInvalidationFee({ sats: finalizer.fee.satsInt', body)
        self.assertIn('if (!bal || !root.ready) return false', body)

    def test_no_fixed_rate_anywhere(self):
        for f in ('EhHeirCostRow.qml', 'EhHeirCancelSheet.qml', 'EhHeirAskSheet.qml', 'EhHeirCheckPage.qml',
                  'EhHeirWhenPage.qml'):
            s = _read(f)
            self.assertNotIn('baltx', s, f)
            self.assertNotIn('cancelSats', s, f)
        self.assertNotIn('fees.renewSats', _read('EhHeirCancelSheet.qml'))
        self.assertNotIn('fees.renewSats', _read('EhHeirAskSheet.qml'))


class TestPagesUseTheRow(TestCase):

    def _check(self, f, call):
        s = _read(f)
        self.assertIn('EhHeirCostRow {', s, f)
        i = s.index(call)
        self.assertIn('cost.commit(', s[max(0, i - 400):i], f)     # handed over right before it starts
        self.assertIn('cost.ensure()', s, f)                        # checked before the PIN

    def test_cancel(self):
        self._check('EhHeirCancelSheet.qml', 'root.bal.cancelWill(root.deleteHeirs)')

    def test_renew(self):
        self._check('EhHeirAskSheet.qml', 'root.bal.renew()')

    def test_longer_period(self):
        self._check('EhHeirCheckPage.qml', 'page.bal.confirm()')

    def test_no_fee_error_has_a_sentence(self):
        self.assertIn("if (code === 'no_fee') return qsTr('First choose the cost of the operation.')", _read('main.qml'))
