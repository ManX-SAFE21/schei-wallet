# Schȅi text sizes (owner 16/11): one rule for every text. Only 6 named sizes, defined once in
# main.qml (app.ehFsSmall/Text/Strong/Box/Title/Figure), following the phone width (412 dp = 100%,
# narrower down to 90%, never under 13). A size written by hand in a Schȅi page breaks the order.
import glob
import os
import re
from unittest import TestCase

from electrum.gui.qml import qeapp

COMP = os.path.join(os.path.dirname(qeapp.__file__), 'components')
# owner 17/11 (anteprima/testi-piu-piccoli.png): about 12% smaller, floor 12
ROLES = {'ehFsSmall': 12, 'ehFsText': 14, 'ehFsStrong': 16, 'ehFsBox': 23, 'ehFsTitle': 28, 'ehFsFigure': 37}


def _eh_files():
    files = glob.glob(os.path.join(COMP, 'Eh*.qml')) + glob.glob(os.path.join(COMP, 'controls', 'Eh*.qml'))
    for p in glob.glob(os.path.join(COMP, 'wizard', '**', '*.qml'), recursive=True):
        if 'EhStyle.js' in open(p, encoding='utf-8').read():
            files.append(p)
    return sorted(set(files))


def _width_factor(width):
    return max(0.9, min(1.0, width / 412))


class TestTextSizes(TestCase):

    def test_six_sizes_defined_once_in_main(self):
        qml = open(os.path.join(COMP, 'main.qml'), encoding='utf-8').read()
        self.assertIn('readonly property real ehFs: Math.max(0.9, Math.min(1.0, width / 412))', qml)
        for name, base in ROLES.items():
            m = re.search(r'readonly property int %s: (.*)' % name, qml)
            self.assertIsNotNone(m, name)
            self.assertIn('Math.round(%d * ehFs)' % base, m.group(1))
        self.assertNotIn('Math.max(13,', qml[qml.index('ehFsSmall'):qml.index('ehFsFigure')])

    def test_no_size_written_by_hand(self):
        bad = []
        for p in _eh_files():
            for i, ln in enumerate(open(p, encoding='utf-8').read().split('\n'), 1):
                if 'minimumPixelSize' in ln:
                    continue  # lower limit of a text that shrinks to fit
                for m in re.finditer(r'\b(?:pixelSize|fontSize):\s*([^;}\n]*)', ln):
                    for n in re.findall(r'(?<![\w.])(\d+)(?![\w.])', m.group(1)):
                        if int(n) >= 13 and '*' not in m.group(1):
                            bad.append(f'{os.path.relpath(p, COMP)}:{i}: {ln.strip()[:90]}')
        self.assertEqual([], bad)

    def test_sizes_on_three_phones(self):
        # what the rule gives: Pixel 7 (412), Samsung A15 (384), narrow phone (360)
        def size(base, width, floor=True):
            v = round(base * _width_factor(width))
            return max(12, v) if floor else v
        self.assertEqual([12, 14, 16, 23, 28, 37], [size(b, 412) for b in ROLES.values()])
        self.assertEqual([12, 13, 15, 21, 26, 34], [size(b, 384) for b in ROLES.values()])
        self.assertEqual([12, 13, 14, 21, 25, 33], [size(b, 360) for b in ROLES.values()])


class TestBigEuroAmount(TestCase):
    # Samsung 17/11: «Mandati» broke on two lines next to −€ 1.227.181,61

    def test_euro_amount_shrinks_to_leave_the_words_room(self):
        s = open(os.path.join(COMP, 'controls', 'EhHistoryPanel.qml'), encoding='utf-8').read()
        self.assertIn('(width - 48 - 72 - 8) / Math.max(1, tmE.advanceWidth)', s)
        self.assertEqual(2, s.count('font.pixelSize: row.amtSize'))
