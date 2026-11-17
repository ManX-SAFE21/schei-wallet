# Schȅi (owner 17/11, Samsung): the stitching of a wallet vanished and never came back. It was a
# Canvas: it paints once into an image, and on Android that image can be lost (app long in the
# background, the system frees memory) without being painted again. Now it is a Shape (geometry the
# scene graph builds again by itself), with the same look (dashes 7/5 in line widths, as the Canvas).
import os
from unittest import TestCase

from electrum.gui.qml import qeapp

COMP = os.path.join(os.path.dirname(qeapp.__file__), 'components')


class TestStitching(TestCase):

    def test_stitching_is_a_shape_not_a_canvas(self):
        s = open(os.path.join(COMP, 'controls', 'EhDashedBorder.qml'), encoding='utf-8').read()
        code = '\n'.join(ln for ln in s.split('\n') if not ln.strip().startswith('//'))
        self.assertIn('import QtQuick.Shapes', code)
        self.assertIn('Shape {', code)
        self.assertNotIn('Canvas', code)
        self.assertIn('strokeStyle: ShapePath.DashLine', code)
        self.assertIn('dashPattern: [7, 5]', code)   # same dashes as before (in line widths)
        for prop in ('property color color', 'property real radius', 'property real lineWidth',
                     'property real inset'):
            self.assertIn(prop, code)

    def test_every_schei_canvas_paints_again(self):
        # every other drawing of the Schȅi pages: EhCanvas (paints again when shown, when the app is
        # in front again and when the window's drawing memory is made again), never a plain Canvas
        import glob
        import re
        bad = []
        files = glob.glob(os.path.join(COMP, 'Eh*.qml')) + glob.glob(os.path.join(COMP, 'controls', 'Eh*.qml'))
        for p in files:
            if os.path.basename(p) == 'EhCanvas.qml':
                continue
            code = '\n'.join(ln for ln in open(p, encoding='utf-8').read().split('\n')
                             if not ln.strip().startswith('//'))
            if re.search(r'(?<![\w.])Canvas \{', code):
                bad.append(os.path.basename(p))
        self.assertEqual([], bad)
        ec = open(os.path.join(COMP, 'controls', 'EhCanvas.qml'), encoding='utf-8').read()
        for k in ('onVisibleChanged: if (visible) requestPaint()', 'Qt.ApplicationActive', 'onSceneGraphInitialized'):
            self.assertIn(k, ec)
