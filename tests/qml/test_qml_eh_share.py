# Easy Heirs (owner Q7, 16/11): «Quanto riceve» with the slider. The rules live in
# electrum/gui/qml/components/controls/EhShare.js (used by EhHeirPersonPage and EhHeirWhoPage);
# here they run in a real QJSEngine, as in the app.
import os
import re
import unittest

from PyQt6.QtCore import QCoreApplication
from PyQt6.QtQml import QJSEngine

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
COMP = os.path.join(ROOT, 'electrum', 'gui', 'qml', 'components')
JS = os.path.join(COMP, 'controls', 'EhShare.js')


def _read(name):
    with open(os.path.join(COMP, name), encoding='utf-8') as f:
        return f.read()


class TestEhShare(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        with open(JS, encoding='utf-8') as f:
            src = f.read()
        assert '.pragma library' in src
        # a QJSEngine needs the Qt application object
        cls._own_app = QCoreApplication.instance() is None
        cls.app = QCoreApplication.instance() or QCoreApplication([])
        cls.eng = QJSEngine()
        r = cls.eng.evaluate(src.replace('.pragma library', ''), JS)
        assert not r.isError(), r.toString()

    @classmethod
    def tearDownClass(cls):
        # the other QML tests (qt_util.QETestCase) start their own application in a
        # thread: an application left here would make them wait forever
        cls.eng = None
        if cls._own_app:
            from PyQt6 import sip
            sip.delete(cls.app)
        cls.app = None

    def js(self, expr):
        r = self.eng.evaluate(expr)
        self.assertFalse(r.isError(), r.toString())
        return r.toVariant()

    def heirs(self, *pairs):
        return '[' + ','.join('{name:%r,percent:%d}' % p for p in pairs) + ']'

    # the slider: steps of 5, never over the max
    def test_step_5(self):
        self.assertEqual(5, self.js('STEP'))
        self.assertEqual(20, self.js('snap(21, 100)'))
        self.assertEqual(25, self.js('snap(23, 100)'))
        self.assertEqual(35, self.js('snap(33, 100)'))
        self.assertEqual(100, self.js('snap(100, 100)'))
        self.assertEqual(0, self.js('snap(-3, 100)'))
        for v in range(0, 101):
            self.assertEqual(0, self.js('snap(%d, 100)' % v) % 5)

    def test_max_is_100_minus_others(self):
        self.assertEqual(80, self.js('maxFor(othersTotal(%s, ""))' % self.heirs(('Bruno', 20))))
        self.assertEqual(30, self.js('maxFor(othersTotal(%s, ""))' % self.heirs(('Bruno', 20), ('Anna', 50))))
        self.assertEqual(100, self.js('maxFor(othersTotal([], ""))'))
        # the slider stops at the max even if the finger goes on
        self.assertEqual(80, self.js('snap(95, 80)'))
        self.assertEqual(30, self.js('snap(100, 30)'))
        # 66 given: the max is 34, the slider stops at 34 (not 35)
        self.assertEqual(34, self.js('snap(100, 34)'))

    def test_editing_frees_own_share(self):
        h = self.heirs(('Bruno', 20), ('Anna', 50), ('Carla', 30))
        self.assertEqual(50, self.js('othersTotal(%s, "Anna")' % h))
        self.assertEqual(50, self.js('maxFor(othersTotal(%s, "Anna"))' % h))
        self.assertEqual(50, self.js('startFor(true, 50, 50)'))          # editing keeps 50
        self.assertTrue(self.js('canSave(40, 50)'))                      # down to 40: fine
        self.assertEqual(10, self.js('remaining(50, 40)'))

    def test_typed_33_is_kept(self):
        t = self.js('press(press("", "3"), "3")')
        self.assertEqual('33', t)
        self.assertEqual(33, self.js('typedValue("33")'))
        self.assertTrue(self.js('canSave(33, 100)'))                     # not a multiple of 5
        self.assertEqual(67, self.js('remaining(100, 33)'))
        # the keypad: whole numbers 0-100 only
        self.assertEqual('100', self.js('press("10", "0")'))
        self.assertEqual('10', self.js('press("10", "1")'))              # 101: refused
        self.assertEqual('7', self.js('press("0", "7")'))                # no leading 0
        self.assertEqual('3', self.js('press("33", "del")'))
        self.assertEqual('', self.js('press("", "del")'))
        self.assertEqual('5', self.js('press("5", ",")'))                # no decimals
        self.assertEqual(0, self.js('typedValue("")'))

    def test_typed_above_max_save_off(self):
        self.assertFalse(self.js('canSave(95, 80)'))
        self.assertFalse(self.js('canSave(81, 80)'))
        self.assertTrue(self.js('canSave(80, 80)'))
        self.assertEqual(0, self.js('remaining(80, 95)'))                # never below 0

    def test_save_needs_at_least_1(self):
        self.assertFalse(self.js('canSave(0, 100)'))
        self.assertTrue(self.js('canSave(1, 100)'))

    def test_nothing_left_save_off(self):
        h = self.heirs(('Bruno', 20), ('Anna', 50), ('Carla', 30))
        self.assertEqual(0, self.js('maxFor(othersTotal(%s, ""))' % h))
        self.assertEqual(0, self.js('startFor(false, 0, 100)'))
        for p in (0, 1, 5, 100):
            self.assertFalse(self.js('canSave(%d, 0)' % p))
        # old data over 100: still nothing left, never a negative max
        self.assertEqual(0, self.js('maxFor(120)'))

    def test_new_heir_starts_from_what_is_left(self):
        self.assertEqual(0, self.js('startFor(false, 0, 0)'))            # the first: from 0
        self.assertEqual(80, self.js('startFor(false, 0, 20)'))
        self.assertEqual(30, self.js('startFor(false, 0, 70)'))          # Carla: 30, just save
        h = self.heirs(('Bruno', 33), ('Anna', 33))
        self.assertEqual(34, self.js('startFor(false, 0, othersTotal(%s, ""))' % h))
        self.assertTrue(self.js('canSave(34, maxFor(66))'))

    def test_summary_kind(self):
        self.assertEqual('ok', self.js('summaryKind(100)'))
        self.assertEqual('missing', self.js('summaryKind(90)'))
        self.assertEqual('over', self.js('summaryKind(110)'))


class TestPagesUseTheRules(unittest.TestCase):

    def test_person_page(self):
        q = _read('EhHeirPersonPage.qml')
        self.assertIn('import "controls/EhShare.js" as Share', q)
        self.assertNotIn('EhSegmented', q)                               # 25/40/50/Other gone
        self.assertIn('Share.canSave(percent, maxP)', q)
        self.assertIn('Share.startFor(', q)
        self.assertIn('Share.snap(value, page.maxP)', q)
        self.assertIn('eh_pen_wine.svg', q)
        self.assertIn("heirSave(page.oldName, nameField.text.trim(), page.address, page.percent)", q)
        # the keypad of the app
        self.assertIn('EhKey', q)
        self.assertRegex(q, r"stepSize:\s*Share\.STEP")

    def test_who_page(self):
        q = _read('EhHeirWhoPage.qml')
        self.assertIn('Share.summaryKind(page.total)', q)
        self.assertIn("qsTr('(already 5)')", q)
        self.assertRegex(q, r"enabled: !page\.busy && page\.heirs\.length > 0 && page\.total === 100")
        self.assertIsNone(re.search(r"visible: page\.heirs\.length < page\.maxHeirs", q))


if __name__ == '__main__':
    unittest.main()
