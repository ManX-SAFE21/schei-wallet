# Schȅi (owner 16/11, Galaxy A15 = Android 14, not edge-to-edge): the Qt window was 2260 px tall
# in a visible area of 2125 px, its bottom 48 dp under the Android keys, while
# getNavigationBarHeight() said 0, so every page and sheet ended under the keys.
# QEAppController now measures that part and tells QML (navigationBarHeight).
import types
from unittest import TestCase, mock

from electrum.gui.qml import qeapp


class _View:
    def __init__(self, top=0, height=0, children=()):
        self._top, self._h, self._c = top, height, list(children)

    def getTop(self): return self._top
    def getHeight(self): return self._h
    def getChildCount(self): return len(self._c)
    def getChildAt(self, i): return self._c[i]


def _android(content, density=2.8125):
    decor = types.SimpleNamespace(findViewById=lambda _id: content)
    metrics = types.SimpleNamespace(density=density)
    activity = types.SimpleNamespace(getResources=lambda: types.SimpleNamespace(getDisplayMetrics=lambda: metrics))
    return mock.patch.multiple(qeapp, create=True, jview=decor, jpythonActivity=activity, cast=lambda _cls, o: o)


def _me():
    return types.SimpleNamespace(logger=mock.Mock())


class TestNavBarUnderKeys(TestCase):

    def test_galaxy_a15(self):
        # A15: QtRootLayout 2125 px, QtWindow 2260 px, density 450 dpi -> 48 dp under the keys
        content = _View(height=2125, children=[_View(height=2125, children=[_View(0, 2260)])])
        with _android(content):
            self.assertEqual(48, qeapp.QEAppController._qtWindowUnderKeysDp(_me()))

    def test_window_fits(self):
        content = _View(height=2125, children=[_View(height=2125, children=[_View(0, 2125)])])
        with _android(content):
            self.assertEqual(0, qeapp.QEAppController._qtWindowUnderKeysDp(_me()))

    def test_not_laid_out_yet(self):
        with _android(_View()):
            self.assertEqual(0, qeapp.QEAppController._qtWindowUnderKeysDp(_me()))
        with _android(_View(children=[_View(height=0, children=[_View(0, 2260)])])):
            self.assertEqual(0, qeapp.QEAppController._qtWindowUnderKeysDp(_me()))
        with _android(None):
            self.assertEqual(0, qeapp.QEAppController._qtWindowUnderKeysDp(_me()))

    def test_java_error_gives_zero(self):
        decor = types.SimpleNamespace(findViewById=mock.Mock(side_effect=RuntimeError("jni")))
        with mock.patch.multiple(qeapp, create=True, jview=decor, cast=lambda _c, o: o):
            self.assertEqual(0, qeapp.QEAppController._qtWindowUnderKeysDp(_me()))

    def test_recheck_tells_qml_only_on_change(self):
        me = _me()
        me._navBarDp = 0
        me.systemBarsChanged = mock.Mock()
        me._getSystemBarHeight = mock.Mock(return_value=48)
        qeapp.QEAppController.recheckSystemBars(me)
        self.assertEqual(48, me._navBarDp)
        me.systemBarsChanged.emit.assert_called_once()
        qeapp.QEAppController.recheckSystemBars(me)
        me.systemBarsChanged.emit.assert_called_once()

    def test_timer_stops_after_15_s(self):
        me = _me()
        me._barsChecks = 0
        me._barsTimer = mock.Mock()
        me.recheckSystemBars = mock.Mock()
        for _ in range(29):
            qeapp.QEAppController._onBarsTimer(me)
        me._barsTimer.stop.assert_not_called()
        qeapp.QEAppController._onBarsTimer(me)
        me._barsTimer.stop.assert_called_once()
        self.assertEqual(30, me.recheckSystemBars.call_count)

    def test_back_in_the_app_window_fits_again(self):
        # owner 16/11: at the start 48 dp, back in the app the window fits (0): the strip must go
        me = _me()
        me._navBarDp = 48
        me._barsChecks = 30
        me._barsTimer = mock.Mock()
        me.systemBarsChanged = mock.Mock()
        me.isAndroid = lambda: True
        me.enforcesEdgeToEdge = lambda: False
        me._getSystemBarHeight = mock.Mock(return_value=0)
        me.recheckSystemBars = lambda: qeapp.QEAppController.recheckSystemBars(me)
        qeapp.QEAppController.watchSystemBars(me)
        self.assertEqual(0, me._navBarDp)
        me.systemBarsChanged.emit.assert_called_once()
        self.assertEqual(0, me._barsChecks)  # looks again for 15 s
        me._barsTimer.start.assert_called_once()

    def test_watch_does_nothing_on_desktop_or_edge_to_edge(self):
        for android, e2e in ((False, False), (True, True)):
            me = _me()
            me._barsTimer = mock.Mock()
            me.recheckSystemBars = mock.Mock()
            me.isAndroid = lambda a=android: a
            me.enforcesEdgeToEdge = lambda e=e2e: e
            qeapp.QEAppController.watchSystemBars(me)
            me.recheckSystemBars.assert_not_called()
            me._barsTimer.start.assert_not_called()

    def test_qml_asks_again_on_resize_and_resume(self):
        import os
        qml = open(os.path.join(os.path.dirname(qeapp.__file__), 'components', 'main.qml'), encoding='utf-8').read()
        self.assertIn('onHeightChanged: if (AppController) AppController.watchSystemBars()', qml)
        self.assertIn('if (AppController) AppController.watchSystemBars()  // the window may be another size now', qml)

    def test_not_edge_to_edge_android_measures_the_keys(self):
        me = _me()
        me.enforcesEdgeToEdge = lambda: False
        me.isAndroid = lambda: True
        me._qtWindowUnderKeysDp = lambda: 48
        self.assertEqual(48, qeapp.QEAppController._getSystemBarHeight(me, 'navigation'))
        self.assertEqual(0, qeapp.QEAppController._getSystemBarHeight(me, 'status'))
        me.isAndroid = lambda: False  # desktop: no keys
        self.assertEqual(0, qeapp.QEAppController._getSystemBarHeight(me, 'navigation'))


class TestKeysCountedOnce(TestCase):
    # owner 16/11 (Samsung A15): empty space under the leather wallet. The keys were counted twice:
    # main.qml leaves room for them under the page stack, and every page added them again.
    # Pages (root Item) must not add them; windows (ElDialog / Popup, over the whole screen) add them once.

    def _comp(self):
        import os
        return os.path.join(os.path.dirname(qeapp.__file__), 'components')

    def test_pages_do_not_add_the_keys(self):
        import glob
        import os
        import re
        bad = []
        for p in glob.glob(os.path.join(self._comp(), '*.qml')):
            if os.path.basename(p) == 'main.qml':
                continue
            s = open(p, encoding='utf-8').read()
            root = next(ln for ln in s.split('\n') if ln.strip() and not re.match(r'\s*(import|//|\.pragma)', ln))
            if root.strip().startswith('Item') and 'navigationBarHeight' in s:
                bad.append(os.path.basename(p))
        self.assertEqual([], bad)

    def test_room_for_the_keys_left_once_by_the_containers(self):
        import os
        main = open(os.path.join(self._comp(), 'main.qml'), encoding='utf-8').read()
        self.assertIn('Layout.preferredHeight: app.navigationBarHeight', main)
        pd = open(os.path.join(self._comp(), 'EhPageDialog.qml'), encoding='utf-8').read()
        self.assertIn('needsSystemBarPadding: true', pd)
