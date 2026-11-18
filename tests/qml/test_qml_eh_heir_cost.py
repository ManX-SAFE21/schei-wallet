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


class TestBusyConfirm(TestCase):
    # controllo-mainnet 2.5: a confirmation refused for "busy" puts the coin back

    def test_coin_back_when_busy(self):
        s = _read('EhHeirCheckPage.qml')
        self.assertIn("if (code === 'busy') { slide.reset(); return }", s)


class TestPluginLabelsInMovements(TestCase):
    # owner 17/11: «Annullamento eredità», never "Safe21 Heartbeat"; never edited

    def test_known_labels_mapped(self):
        m = _read('main.qml')
        for k in ("'Àncòra – annullamento eredità': 'cancel'", "'Safe21 Heartbeat invalidation': 'cancel'",
                  "'Safe21 Heartbeat backup transaction': 'backup'", "qsTr('Inheritance cancellation')"):
            self.assertIn(k, m)

    def test_rows_use_the_mapped_note(self):
        self.assertIn('app.ehTxNote(row.model.label)', _read('controls', 'EhHistoryPanel.qml'))
        self.assertIn('app.ehTxNote(row.model.label)', _read('EhMovements.qml'))

    def test_details_never_overwrite_the_plugin_label(self):
        d = _read('EhTxDetailsPage.qml')
        self.assertIn("readOnly: app.ehPluginLabelKind(tx.label) !== ''", d)
        self.assertIn("if (app.ehPluginLabelKind(tx.label) !== '') return", d)

    def test_labels_match_the_plugin(self):
        from electrum.plugins.bal.core import will_versions as wv
        from electrum.plugins.bal.engine import build
        m = _read('main.qml')
        for l in (wv.INVALIDATION_LABEL,) + wv.OLD_INVALIDATION_LABELS + (build.BACKUP_LABEL,) + build.OLD_BACKUP_LABELS:
            self.assertIn(l.replace("'", "\\'") if False else l, m)


class TestSelfSendDetails(TestCase):
    # owner 17/11 (phone, build58): the cancellation read "+ € 0,00 · received" in the details

    def test_self_send_reads_as_cost_out(self):
        d = _read('EhTxDetailsPage.qml')
        self.assertIn("readonly property bool selfSend: tx.amount.satsInt === 0 && !tx.fee.isEmpty && tx.fee.satsInt > 0", d)
        self.assertIn("readonly property bool incoming: tx.amount.satsInt >= 0 && !selfSend", d)
        self.assertIn("page.selfSend ? '− ' + app.ehTxAmount(tx.fee, tx.timestamp, false)", d)
        self.assertIn("qsTr('cost paid')", d)

    def test_self_send_address_is_the_own_one(self):
        d = _read('EhTxDetailsPage.qml')
        self.assertIn("if ((incoming || selfSend) ? outs[i].is_mine : !outs[i].is_mine)", d)
        self.assertIn("(page.incoming || page.selfSend) ? qsTr('ON YOUR ADDRESS')", d)

    def test_plugin_note_has_no_pen_and_no_focus(self):
        d = _read('EhTxDetailsPage.qml')
        self.assertIn("Image { visible: !page.pluginNote; source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg')", d)
        self.assertIn("activeFocusOnPress: !page.pluginNote", d)

    def test_home_row_never_cuts_the_plugin_words(self):
        h = _read('controls', 'EhHistoryPanel.qml')
        self.assertIn("visible: row.note !== '' && !row.pluginNote", h)
        self.assertIn("wrapMode: row.pluginNote ? Text.WordWrap : Text.WrapAtWordBoundaryOrAnywhere", h)
        self.assertIn("id: wordTm", h)

    def test_cost_paid_translated(self):
        from electrum import eh_strings
        src = open(eh_strings.__file__, encoding='utf-8').read()
        self.assertIn("'cost paid': 'costo pagato'", src)
        self.assertIn("'cost paid': 'costo pagà'", src)
