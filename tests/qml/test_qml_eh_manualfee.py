# Easy Heirs (owner Q8, 16/11): when the servers give no fee estimate the send flow asks the
# fee by hand («Quanto pagare al miner?»), with decimals; never Electrum's 150 sat/vB, and
# the wallet never asks mempool.space anything.
import os
from decimal import Decimal
from types import SimpleNamespace

from electrum import SimpleConfig
from electrum.address_synchronizer import TX_HEIGHT_UNCONFIRMED
from electrum.fee_policy import FeePolicy, FeeTimeEstimates, FeeHistogram, FEERATE_FALLBACK_STATIC_FEE
from electrum.transaction import Transaction, PartialTxOutput
from electrum.util import NoDynamicFeeEstimates
from electrum.gui.qml.qetxfinalizer import (
    QETxFinalizer, eh_parse_feerate, eh_fee_step, eh_feerate_policy, eh_mempool_url, eh_feerate_text,
)

from .. import ElectrumTestCase
from ..test_wallet_vertical import WalletIntegrityHelper
from .qt_util import QETestCase, qt_test

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

FUNDING_TX = '01000000000101197a89cff51096b9dd4214cdee0eb90cb27a25477e739521d728a679724042730100000000fdffffff048096980000000000160014dab37af8fefbbb31887a0a5f9b2698f4a7b45f6a80969800000000001976a91405a20074ef7eb42c7c6fcd4f499faa699742783288ac809698000000000017a914b808938a8007bc54509cd946944c479c0fa6554f87131b2c0400000000160014a04dfdb9a9aeac3b3fada6f43c2a66886186e2440247304402204f5dbb9dda65eab26179f1ca7c37c8baf028153815085dd1bbb2b826296e3b870220379fcd825742d6e2bdff772f347b629047824f289a5499a501033f6c3495594901210363c9c98740fe0455c646215cea9b13807b758791c8af7b74e62968bef57ff8ae1e391400'


def _net_like_testnet4():
    """What the testnet4 servers give today: estimates only for 144 and 1008 blocks."""
    fe = FeeTimeEstimates()
    fe.set_data(144, 1000)
    fe.set_data(1008, 1000)
    return SimpleNamespace(fee_estimates=fe, mempool_fees=FeeHistogram(), relay_fee=None)


class TestManualFeeHelpers(ElectrumTestCase):

    def test_parse_decimal_comma_and_dot(self):
        self.assertEqual(Decimal('0.7'), eh_parse_feerate('0,7'))
        self.assertEqual(Decimal('0.7'), eh_parse_feerate('0.7'))
        self.assertEqual(Decimal('2'), eh_parse_feerate(' 2 '))
        self.assertEqual(Decimal('1.3'), eh_parse_feerate('1,25'))      # one decimal
        self.assertIsNone(eh_parse_feerate(''))
        self.assertIsNone(eh_parse_feerate('abc'))
        self.assertIsNone(eh_parse_feerate('nan'))

    def test_minimum_is_0_1(self):
        self.assertEqual(Decimal('0.1'), eh_parse_feerate('0,1'))
        self.assertIsNone(eh_parse_feerate('0'))
        self.assertIsNone(eh_parse_feerate('0,04'))
        self.assertIsNone(eh_parse_feerate('-3'))
        self.assertEqual(Decimal('0.1'), eh_fee_step('0.1', False))     # − stops at 0.1
        self.assertEqual(Decimal('0.1'), eh_fee_step('0.2', False))

    def test_step_rule(self):
        # 0.1 below 2 sat/vB, 1 from 2 up
        self.assertEqual(Decimal('0.8'), eh_fee_step('0.7', True))
        self.assertEqual(Decimal('0.6'), eh_fee_step('0.7', False))
        self.assertEqual(Decimal('2'), eh_fee_step('1.9', True))
        self.assertEqual(Decimal('3'), eh_fee_step('2', True))
        self.assertEqual(Decimal('1.9'), eh_fee_step('2', False))
        self.assertEqual(Decimal('4'), eh_fee_step('5', False))
        self.assertEqual(Decimal('2'), eh_fee_step('2.5', False))       # never jumps over 2
        self.assertEqual(Decimal('3.5'), eh_fee_step('2.5', True))
        self.assertEqual('0.7', eh_feerate_text(eh_fee_step('0.8', False)))
        self.assertEqual('3', eh_feerate_text(eh_fee_step('2', True)))

    def test_policy_keeps_the_decimal(self):
        pol = eh_feerate_policy('0,7')
        self.assertEqual('feerate:700', pol.get_descriptor())
        self.assertEqual(70, pol.estimate_fee(100))                     # 0.7 sat/vB, not 1
        self.assertEqual(141, pol.estimate_fee(201))                    # ceil(140.7)
        self.assertIsNone(eh_feerate_policy('0'))

    def test_mempool_link_per_network(self):
        self.assertEqual('https://mempool.space', eh_mempool_url('mainnet'))
        self.assertEqual('https://mempool.space/testnet4', eh_mempool_url('testnet4'))
        self.assertEqual('https://mempool.space/testnet', eh_mempool_url('testnet'))
        self.assertEqual('https://mempool.space/signet', eh_mempool_url('signet'))

    def test_no_estimate_raises_never_150(self):
        # eta:5 (the app's "about 1 hour") with the testnet4 servers: no estimate
        net = _net_like_testnet4()
        pol = FeePolicy('eta:5')
        self.assertIsNone(pol.fee_per_kb(net))
        with self.assertRaises(NoDynamicFeeEstimates):
            pol.estimate_fee(200, network=net)
        self.assertNotEqual(FEERATE_FALLBACK_STATIC_FEE, eh_feerate_policy('2').fee_per_kb(net))

    def test_mempool_space_code_is_gone(self):
        src = open(os.path.join(ROOT, 'electrum', 'network.py'), encoding='utf-8').read()
        self.assertNotIn('mempool.space', src)
        self.assertNotIn('_testnet4_fees_from_mempool_space', src)
        for dirpath, _dirs, files in os.walk(os.path.join(ROOT, 'electrum')):
            for f in files:
                if f.endswith('.py'):
                    text = open(os.path.join(dirpath, f), encoding='utf-8').read()
                    self.assertNotIn('api/v1/fees', text, f)


class TestManualFeeTx(ElectrumTestCase):
    TESTNET = True

    def setUp(self):
        super().setUp()
        self.config = SimpleConfig({'electrum_path': self.electrum_path})

    def _wallet(self):
        w = WalletIntegrityHelper.create_imported_wallet(privkeys=False, config=self.config)
        w.import_address('tb1qm2eh4787lwanrzr6pf0ekf5c7jnmghm2y9k529')
        w.adb.receive_tx_callback(Transaction(FUNDING_TX), tx_height=TX_HEIGHT_UNCONFIRMED)
        return w

    def _make(self, w, policy):
        outputs = [PartialTxOutput.from_address_and_value('tb1quk7ahlhr3qmjndy0uvu9y9hxfesrtahtta9ghm', 2500000)]
        return w.make_unsigned_transaction(outputs=outputs, fee_policy=policy, rbf=True)

    async def test_eta_without_estimates_is_not_150(self):
        w = self._wallet()
        w.network = _net_like_testnet4()
        with self.assertRaises(NoDynamicFeeEstimates):
            self._make(w, FeePolicy('eta:5'))

    async def test_0_7_gives_a_0_7_tx(self):
        w = self._wallet()
        tx = self._make(w, eh_feerate_policy('0,7'))
        size = tx.estimated_size()
        self.assertLess(tx.get_fee(), size)                              # under 1 sat/vB: not rounded up
        self.assertAlmostEqual(0.7, tx.get_fee() / size, delta=0.01)


class TestFinalizerAsks(QETestCase):

    @qt_test
    def test_no_estimate_sets_flag_and_manual_clears_it(self):
        calls = []

        def make_tx(amount, policy):
            calls.append(policy.get_descriptor())
            if policy.use_dynamic_estimates:
                raise NoDynamicFeeEstimates()
            raise RuntimeError('stop after the fee')     # a fee was found: enough for this test

        f = QETxFinalizer(make_tx=make_tx)
        f._wallet = object()                               # update() only needs a wallet set
        f._fee_policy = FeePolicy('eta:5')
        f.update()
        self.assertTrue(f.ehNoEstimate)
        self.assertFalse(f._valid)
        # the hand-written fee «0,7» -> feerate:700: the flag goes down
        f._fee_policy = eh_feerate_policy('0,7')
        f.update()
        self.assertEqual('feerate:700', calls[-1])
        self.assertFalse(f.ehNoEstimate)
        self.assertEqual('0.7', f.ehParseFeerate('0,7'))
        self.assertEqual('', f.ehParseFeerate('0'))
        self.assertEqual('2', f.ehFeeStep('1.9', True))

    @qt_test
    def test_cost_for_rate_does_not_change_the_policy(self):
        seen = []

        def make_tx(amount, policy):
            seen.append(policy.get_descriptor())
            return SimpleNamespace(get_fee=lambda: 141, inputs=lambda: [1], outputs=lambda: [1, 2])

        f = QETxFinalizer(make_tx=make_tx)
        f._wallet = object()
        f._fee_policy = FeePolicy('eta:5')
        self.assertEqual(141, f.ehCostForRate('0,7'))
        self.assertEqual(['feerate:700'], seen)
        self.assertEqual('eta:5', f._fee_policy.get_descriptor())
        self.assertEqual(-1, f.ehCostForRate('0'))
