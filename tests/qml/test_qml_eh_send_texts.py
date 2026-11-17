# Schȅi, owner 17/11 (phone test build59): two texts of the sending page.
# - manual fee: when the cost is above a tenth of the amount, the question says so (not "2 sat/vB is very high")
# - "Paste" with nothing copied: the message stays on the page (a one-second toast was missed)
import os
from unittest import TestCase

from electrum.gui.qml import qeapp

COMP = os.path.join(os.path.dirname(qeapp.__file__), 'components')


def _read(*p):
    return open(os.path.join(COMP, *p), encoding='utf-8').read()


class TestManualFeeQuestion(TestCase):

    def test_two_reasons_two_texts(self):
        m = _read('EhManualFeeSheet.qml')
        self.assertIn('readonly property bool rateHigh: rateNum > highRate', m)
        self.assertIn('readonly property bool isHigh: rateHigh\n'
                      '                                   || (costSats > 0 && amountSats > 0 && costSats > amountSats * 0.1)', m)
        self.assertIn("text: root.rateHigh\n              ? qsTr('%1 sat/vB is <b>very high</b>", m)
        self.assertIn("qsTr('This sending would cost about %1: <b>more than a tenth</b> of what you send. Are you sure?')", m)

    def test_translated(self):
        from electrum import eh_strings
        src = open(eh_strings.__file__, encoding='utf-8').read()
        self.assertIn('<b>più di un decimo</b> di quello che mandi. Sei sicuro?', src)
        self.assertIn('<b>pì de un decimo</b> de quel che te mandi. Te si sicuro?', src)


class TestPasteNothing(TestCase):

    def test_message_stays(self):
        s = _read('EhSendDialog.qml')
        self.assertIn('root.pasteEmpty = !cliptext', s)
        self.assertIn("visible: root.pasteEmpty", s)
        self.assertNotIn("toaster.show(pasteBtn,qsTr('There is nothing to paste", s)

    def test_cleared_with_the_address(self):
        s = _read('EhSendDialog.qml')
        self.assertIn("root.pasted = ''; root.pasteError = false; root.pasteSame = false; root.pasteEmpty = false", s)
