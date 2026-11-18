# Schȅi, owner 18/11 evening: the fixes found by the phone test of build63.
import os
from types import SimpleNamespace

import pytest

from electrum.gui.qml import qeapp

COMP = os.path.join(os.path.dirname(qeapp.__file__), "components")


def _read(*p):
    return open(os.path.join(COMP, *p), encoding="utf-8").read()


def _m():
    # imported only when a test runs (see test_qml_eh_heir_keeper_price)
    from electrum.plugins.bal import qml
    return qml


class TestEmptyWallet:
    """1: an empty wallet says «non bastano», never the generic sentence."""

    def test_build_codes(self):
        from electrum.util import UserFacingException
        code = lambda t: _m()._fail_code(UserFacingException(t))
        base = "The will was not built ({}): check the heirs, the amounts, the delivery date and the will-executors."
        assert code(base.format("NO_UTXO")) == "too_low"
        assert code(base.format("FIXED_EXCEEDS_BALANCE")) == "too_low"
        assert code(base.format("WILLEXECUTOR_FEE")) == "too_low"
        assert code(base.format("WILLEXECUTOR_FEE_TOO_HIGH")) == "keeper_fee"
        assert code(base.format("?")) == "user"

    def test_review_stops_before_building_on_an_empty_wallet(self):
        q = _m()
        me = SimpleNamespace(_local=SimpleNamespace(wallet=object()))
        me._need_network = lambda w: None
        me._kind_ok = lambda w: None
        me._period_change = lambda w: ("new", 24, 0, 0)
        me._keepers = lambda: [{"url": "k", "ok": True, "feeSats": 1000}]
        me._coins = lambda w: {}
        calls = []
        me._cmd = lambda name, *a, **k: (calls.append(name) or ({"Carla": ["x", "100%"]} if name == "bal_heirs_list" else {}))
        me._prepare = lambda: pytest.fail("built with an empty wallet")
        with pytest.raises(q._Fail) as e:
            q.QEBal._job_review(me)
        assert e.value.code == "too_low"


class TestTexts:

    def test_keepers_never_say_there_are_no_others(self):
        s = _read("EhHeirKeeperListSheet.qml")
        assert "on this network there are no others" not in s
        assert "qsTr(\x27We use 1 keeper: the one you chose.\x27)" in s
        assert "app.ehSatsAndEuro(k.feeSats || 0)" in s

    def test_update_after_a_payment_that_spent_the_envelope(self):
        u = _read("EhHeirUpdateSheet.qml")
        assert "? ((root.st.newDelivery || 0) > 0 ? root.st.newDelivery : (root.st.delivery || 0))" in u
        assert "Something in the inheritance was changed." not in u
        assert "for example the heirs changed, or a keeper no longer has the envelope" in u

    def test_status_after_the_envelope_was_spent(self):
        s = _read("EhHeirStatusPage.qml")
        i = s.index("if (phase === \x27needs_update\x27 && page.st.updateReason === \x27spent\x27) return qsTr(\x27the envelope must be made again\x27)")
        assert i < s.index("return qsTr(\x27envelope safe\x27)")

    def test_back_to_home_is_the_home(self):
        assert "onClicked: { dialog.doAccept(); app.stack.pop(null) }" in _read("EhInvoiceDialog.qml")

    def test_same_language_does_not_ask_to_reopen(self):
        m = _read("main.qml")
        body = m[m.index("    function ehChangeLanguage() {"):]
        body = body[:body.index("\n    }\n")]
        assert "if (Config.language !== before)" in body

    def test_italian(self):
        from electrum.eh_strings import STRINGS
        it = STRINGS["it_IT"]
        assert it["the envelope must be made again"] == "la busta va rifatta"
        assert it["We use 1 keeper: the one you chose."] == "Usiamo 1 custode: quello che hai scelto tu."


class TestWalletStitching:
    """9: the home wallet has the SEND/RECEIVE bar stitching; its corner follows its own edge."""

    def test_same_as_the_bar(self):
        c = _read("controls", "EhBalanceCard.qml")
        b = _read("controls", "EhSlideBar.qml")
        assert "inset: 6" in b and "lineWidth: 1.6" in b and "color: \x27#e3c57e\x27" in b
        assert "radius: 26" in b and "radius: 20" in b          # bar: 26 - 6
        assert "inset: root.bottega ? 6 : 7" in c
        assert "radius: root.bottega ? Math.max(0, root.radius - 6) : 12" in c
        assert "lineWidth: 1.6" in c and "lineWidth: root.bottega ? 2" not in c
        assert "    radius: 18\n" in c                          # so the corner is 12


def test_no_pencil_symbol_the_font_cannot_draw():
    # owner 18/11 (phone): «tocca ✎ per scriverlo» showed an empty box: say «la matita» in words
    p = _read("EhHeirPersonPage.qml")
    assert "qsTr(\x27· tap the pen to write it\x27)" in p
    for f in os.listdir(COMP):
        if f.endswith(".qml"):
            for t in __import__("re").findall(r"qsTr\(\x27([^\x27]*)\x27\)", _read(f)):
                assert "✎" not in t, f
    from electrum.eh_strings import STRINGS
    assert STRINGS["it_IT"]["· tap the pen to write it"] == "· tocca la matita per scriverlo"


class TestOpusReview1811:

    def test_every_sheet_has_the_money_errors(self):
        m = _read("main.qml")
        body = m[m.index("    function ehHeirErrorText(code, message) {"):m.index("    function ehHeirPlainText(message) {")]
        for code in ("too_low", "dust", "keeper_fee"):
            assert "if (code === '%s')" % code in body

    def test_plain_or_technical(self):
        import re
        m = _read("main.qml")
        rx = m[m.index("if (m && !/") + len("if (m && !/"):]
        rx = rx[:rx.index("/.test(m))")]
        tech = re.compile(rx)
        assert tech.search("Fixed amount(0.0) >= 0")
        assert tech.search("The will was not built (NO_UTXO): check")
        assert tech.search("WillExecutorFeeTooHighException")
        assert not tech.search("Please open Ancora on the computer to finish.")
        assert not tech.search("Apri Àncòra sul computer per finire.")

    def test_never_stuck_busy(self):
        src = open(_m().__file__, encoding="utf-8").read()
        body = src[src.index("    def _work(self, op, job, wallet, fee=None):"):src.index("    @pyqtSlot(str, object)")]
        assert "try:\n                code = _fail_code(e)\n            except Exception:" in body

    def test_cap_reaches_the_plugin_before_every_job(self):
        src = open(_m().__file__, encoding="utf-8").read()
        body = src[src.index("    def _start(self, op, job):"):src.index("    def _work(self, op, job, wallet")]
        assert "self._sync_cap()" in body


def test_a_job_finishing_late_shows_the_saved_price():
    # owner 18/11 (phone, build65): back to BASE, then an older check finished with 100.000
    from types import SimpleNamespace
    cfg = {_m().KEEPER_MAX_KEY: 50000, _m().KEEPERS_MINE_KEY: []}
    conf = SimpleNamespace(get=lambda k, d=None: cfg.get(k, d))
    me = SimpleNamespace(plugin=SimpleNamespace(config=conf), _state={}, emitted=[])
    me._keeper_max = _m().QEBal._keeper_max.__get__(me)
    me._keepers_mine = _m().QEBal._keepers_mine.__get__(me)
    me._set_step = lambda s: None
    me._set_busy = lambda b: None
    me.stateChanged = SimpleNamespace(emit=lambda: me.emitted.append("state"))
    me.done = SimpleNamespace(emit=lambda *a: None)
    me.failed = SimpleNamespace(emit=lambda *a: None)
    old = {"phase": "active", "keeperMax": 100000, "keepersMine": ["https://x"]}
    try:
        _m().QEBal._on_finished(me, "refresh", (("done", {}), old))
    except Exception:
        pass        # what follows the state (signals of other features) is not under test here
    assert me._state["keeperMax"] == 50000 and me._state["keepersMine"] == []
    assert old["keeperMax"] == 100000        # the job's own dict is not changed
