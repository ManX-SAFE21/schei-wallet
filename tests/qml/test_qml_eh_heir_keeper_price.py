# Schȅi, owner 18/11 (mainnet test: inheritance with an empty wallet -> English "Fixed amount(0.0) >= 0"):
# - the plugin's money errors in Schȅi's words (too little money, dust, keepers too dear, generic);
# - the keepers' maximum price: 50 000 sats standard, changed only at the EXPERT level
#   (4 buttons or typed, 1 000 … 500 000); keepers chosen by hand only at the EXPERT level;
#   out of ESPERTO both go back to the standard.
import os
from types import SimpleNamespace

import pytest

from electrum.gui.qml import qeapp
COMP = os.path.join(os.path.dirname(qeapp.__file__), 'components')
A, B = 'https://we.bitcoin-after.life', 'https://we.safe21.io'     # the fixed pair (_m().KEEPERS)


def _m():
    """electrum.plugins.bal.qml, imported only when a test runs: imported while collecting
    would register the bal_* commands before tests/schei_bridge imports the plugin as `bal`."""
    from electrum.plugins.bal import qml
    return qml


def _read(*p):
    return open(os.path.join(COMP, *p), encoding='utf-8').read()


class _Config(dict):
    def get(self, k, default=None):
        return dict.get(self, k, default)

    def set_key(self, k, v, save=True):
        self[k] = v


class _Net:
    """The keepers' list (bal_willexecutors_*) of the plugin, without network."""

    def __init__(self, fees, answering, welist=(), real=None):
        self.real = dict(real or {})     # the price a keeper gives when asked
        self.wes = {u: {'base_fee': f, 'selected': False} for u, f in fees.items() if u not in welist}
        self.welist = {u: {'base_fee': fees[u], 'selected': False, 'welist_rank': i}
                       for i, u in enumerate(welist)}
        self.answering = set(answering)
        self.pinged = []

    def cmd(self, name, *args, **kw):
        if name == 'bal_willexecutors_list':
            return {u: dict(we) for u, we in self.wes.items()}
        if name == 'bal_willexecutors_add':
            self.wes.setdefault(args[0], {'base_fee': 0, 'selected': False})
            return None
        if name == 'bal_willexecutors_select':
            self.wes[args[0]]['selected'] = kw.get('value', True)
            return None
        if name == 'bal_willexecutors_ping':
            self.pinged.append(list(args[0]))
            for u in args[0]:
                if u in self.answering and u in self.real and u in self.wes:
                    self.wes[u]['base_fee'] = self.real[u]
            return {u: {'ok': u in self.answering} for u in args[0]}
        if name == 'bal_willexecutors_download':
            for u, we in self.welist.items():
                self.wes.setdefault(u, dict(we))
            return None
        raise AssertionError(name)

    def selected(self):
        return sorted(u for u, we in self.wes.items() if we.get('selected'))


def _bridge(net, cap=None, mine=None, wanted=3, online=True):
    cfg = _Config()
    if cap is not None:
        cfg[_m().KEEPER_MAX_KEY] = cap
    if mine is not None:
        cfg[_m().KEEPERS_MINE_KEY] = mine
    me = SimpleNamespace(plugin=SimpleNamespace(config=cfg), _cmd=net.cmd,
                         _step_to=lambda s: None, _keepers_wanted=lambda: wanted,
                         _online_now=lambda: online)
    for f in ('_keeper_max', '_keepers_mine', '_keepers_mine_only'):
        setattr(me, f, getattr(_m().QEBal, f).__get__(me))
    return me


def _urls(res):
    return [k['url'] for k in res]


class TestMaximumPrice:

    def test_standard_and_range(self):
        assert _m().KEEPER_MAX_DEFAULT == 50000
        assert _m().KEEPER_MAX_CHOICES == (25000, 50000, 100000, 200000)
        assert (_m().KEEPER_MAX_MIN, _m().KEEPER_MAX_TOP) == (1000, 500000)
        read = lambda v: _m().QEBal._keeper_max(SimpleNamespace(plugin=SimpleNamespace(config=_Config(
            {} if v is None else {_m().KEEPER_MAX_KEY: v}))))
        assert read(None) == 50000
        assert [read(v) for v in (1000, 30000, 500000)] == [1000, 30000, 500000]     # typed by hand
        assert [read(v) for v in (999, 500001, 'x', -5)] == [50000] * 4

    def test_the_mainnet_keepers_of_today_are_all_under_it(self):
        # welist 18/11: 15 000 … 16 000 sats
        net = _Net({A: 15627, B: 16000, 'https://c': 15000, 'https://d': 15000},
                   answering={A, B, 'https://c', 'https://d'}, welist=('https://c', 'https://d'))
        res = _m().QEBal._keepers(_bridge(net))
        assert _urls(res) == [A, B, 'https://c']
        assert [k['feeSats'] for k in res] == [15627, 16000, 15000]

    def test_a_dear_keeper_is_left_out_and_another_found(self):
        # testnet4 18/11: the fixed keeper asks 100 000
        net = _Net({A: 100000, B: 16000, 'https://c': 15000, 'https://d': 90000},
                   answering={A, B, 'https://c', 'https://d'}, welist=('https://d', 'https://c'))
        res = _m().QEBal._keepers(_bridge(net))
        assert _urls(res) == [B, 'https://c']
        assert net.selected() == sorted([B, 'https://c'])         # the dear ones are not kept

    def test_a_higher_maximum_takes_it_back(self):
        net = _Net({A: 100000, B: 16000}, answering={A, B})
        assert _urls(_m().QEBal._keepers(_bridge(net, cap=100000))) == [A, B]

    def test_all_too_dear_says_so(self):
        net = _Net({A: 100000, B: 60000}, answering={A, B})
        with pytest.raises(_m()._Fail) as e:
            _m().QEBal._keepers(_bridge(net))
        assert e.value.code == 'keeper_fee'
        assert net.selected() == []

    def test_none_answering_is_still_custodians(self):
        net = _Net({A: 1000, B: 1000}, answering=())
        with pytest.raises(_m()._Fail) as e:
            _m().QEBal._keepers(_bridge(net))
        assert e.value.code == 'custodians'


class TestChosenByHand:

    def test_only_the_chosen_ones(self):
        net = _Net({A: 15627, B: 16000, 'https://c': 15000}, answering={A, B, 'https://c'})
        net.wes[A]['selected'] = True
        res = _m().QEBal._keepers(_bridge(net, mine=['https://c', B]))
        assert _urls(res) == ['https://c', B]
        assert net.selected() == sorted(['https://c', B])        # the fixed pair is not forced
        assert net.pinged == [['https://c', B]]

    def test_a_chosen_one_over_the_maximum_is_not_used(self):
        net = _Net({A: 15627, 'https://c': 80000}, answering={A, 'https://c'})
        assert _urls(_m().QEBal._keepers(_bridge(net, mine=[A, 'https://c']))) == [A]
        with pytest.raises(_m()._Fail) as e:
            _m().QEBal._keepers(_bridge(_Net({'https://c': 80000}, answering={'https://c'}), mine=['https://c']))
        assert e.value.code == 'keeper_fee'

    def test_the_chosen_ones_not_answering(self):
        with pytest.raises(_m()._Fail) as e:
            _m().QEBal._keepers(_bridge(_Net({'https://c': 1000}, answering=()), mine=['https://c']))
        assert e.value.code == 'custodians'

    def test_the_list_asks_the_keepers_now(self):
        # owner 18/11: never the placeholder price (100 000) of a keeper never contacted: the page
        # shows only the keepers that answer now, with their price; a chosen one that does not
        # answer is listed without price, to turn it off
        net = _Net({A: 100000, 'https://c': 15000, 'https://dead': 100000, 'http://abc.onion': 1000},
                   answering={A, 'https://c', 'http://abc.onion'}, welist=('https://c',), real={A: 1000})
        rows = _m().QEBal._job_keeper_choices(_bridge(net, mine=[A, 'https://gone']))['keepers']
        assert [(r['name'], r['feeSats'], r['mine'], r['ok']) for r in rows] == [
            ('c', 15000, False, True), ('we.bitcoin-after.life', 1000, True, True), ('gone', 0, True, False)]
        assert 'http://abc.onion' not in net.pinged[0]

    def test_the_list_offline(self):
        net = _Net({A: 100000}, answering=())
        with pytest.raises(_m()._Fail) as e:
            _m().QEBal._job_keeper_choices(_bridge(net, online=False))
        assert e.value.code == 'offline'
        assert _m().QEBal._job_keeper_choices(_bridge(_Net({A: 100000}, answering=())))['keepers'] == []


def _saver(cfg):
    plug = SimpleNamespace(v=500000)
    plug.get = lambda: plug.v
    plug.set = lambda v, save=True: setattr(plug, "v", v)
    me = SimpleNamespace(plugin=SimpleNamespace(config=cfg, MAX_WILLEXECUTOR_FEE=plug), _state={}, out=[])
    me.done = SimpleNamespace(emit=lambda op, r: me.out.append(("done", op)))
    me.failed = SimpleNamespace(emit=lambda op, c, m: me.out.append(("failed", op, c)))
    me.stateChanged = SimpleNamespace(emit=lambda: None)
    for f in ("_keeper_max", "_keepers_mine", "_sync_cap", "_keeper_settings_saved"):
        setattr(me, f, getattr(_m().QEBal, f).__get__(me))
    return me


def test_the_slots_save_the_settings_at_once():
    # Opus review 18/11: saved on the spot (never a job refused as busy) and given to the plugin
    cfg = _Config()
    me = _saver(cfg)
    _m().QEBal.setKeeperMax(me, 30000)
    assert cfg[_m().KEEPER_MAX_KEY] == 30000 and me.out[-1] == ("done", "setKeeperMax")
    assert me.plugin.MAX_WILLEXECUTOR_FEE.v == 30000
    _m().QEBal.setKeeperMax(me, 700000)
    assert me.out[-1] == ("failed", "setKeeperMax", "user") and cfg[_m().KEEPER_MAX_KEY] == 30000
    _m().QEBal.setKeepersMine(me, ["https://c", "https://c", B, ""])
    assert cfg[_m().KEEPERS_MINE_KEY] == ["https://c", B]
    _m().QEBal.keepersStandard(me)
    assert cfg[_m().KEEPER_MAX_KEY] == 50000 and cfg[_m().KEEPERS_MINE_KEY] == []
    assert me.plugin.MAX_WILLEXECUTOR_FEE.v == 50000
    src = open(_m().__file__, encoding="utf-8").read()
    body = src[src.index("    def keepersStandard(self):"):src.index("    def loadKeeperChoices(self):")]
    assert "_start(" not in body


class TestReplaceKeepers:
    """Opus review 18/11: «Sostituisci» keeps the maximum price and the keepers chosen by hand."""

    def _me(self, net, cap=None, mine=None):
        me = _bridge(net, cap=cap, mine=mine)
        me._local = SimpleNamespace(wallet=object())
        me._need_network = lambda w: None
        me._read_state = lambda w: {"custodians": {"total": 2, "ok": 1}, "phase": "active"}
        me._live_items = lambda w: []
        me._heirs_ready = lambda: None
        me.prepared = []
        me._prepare = lambda: me.prepared.append(1)
        me._sign_and_send = lambda: None
        me._min_locktime = lambda live: 0
        return me

    def test_find_skips_the_dear_ones(self):
        net = _Net({A: 1000, "https://c": 80000, "https://d": 15000},
                   answering={A, "https://c", "https://d"}, welist=("https://c", "https://d"))
        net.wes[A]["selected"] = True
        res = _m().QEBal._job_find_keeper(self._me(net))
        assert res["picks"] == ["https://d"]

    def test_find_all_dear(self):
        net = _Net({A: 1000, "https://c": 80000}, answering={A, "https://c"}, welist=("https://c",))
        net.wes[A]["selected"] = True
        with pytest.raises(_m()._Fail) as e:
            _m().QEBal._job_find_keeper(self._me(net))
        assert e.value.code == "keeper_fee"

    def test_find_only_the_chosen_ones(self):
        net = _Net({A: 1000, "https://c": 1000, "https://d": 1000},
                   answering={A, "https://c", "https://d"}, welist=("https://c", "https://d"))
        net.wes[A]["selected"] = True
        res = _m().QEBal._job_find_keeper(self._me(net, mine=[A, "https://d"]))
        assert res["picks"] == ["https://d"]

    def test_replace_refuses_a_dear_one(self):
        net = _Net({A: 1000, "https://c": 80000}, answering={A, "https://c"}, welist=("https://c",))
        net.cmd("bal_willexecutors_download")
        me = self._me(net)
        with pytest.raises(_m()._Fail) as e:
            _m().QEBal._job_replace_keepers(me, ["https://c"])
        assert e.value.code == "keeper_fee" and me.prepared == []


class TestMoneyErrorsInSchèiWords:

    @staticmethod
    def _code(cls):
        from electrum.util import UserFacingException
        e = UserFacingException('x')
        e.__cause__ = cls.__new__(cls)
        return _m()._fail_code(e)

    def test_codes(self):
        from electrum.plugins.bal.core import heirs, will
        assert self._code(heirs.WillExecutorFeeTooHighException) == 'keeper_fee'
        assert self._code(heirs.HeirAmountIsDustException) == 'dust'
        assert self._code(heirs.BalanceTooLowException) == 'too_low'
        assert self._code(will.FixedAmountException) == 'too_low'     # the empty wallet of 18/11
        assert self._code(ValueError) == 'user'
        from electrum.util import UserFacingException
        assert _m()._fail_code(UserFacingException('x')) == 'user'
        src = open(_m().__file__, encoding='utf-8').read()
        assert "code = _fail_code(e)" in src and "outcome = ('failed', code, str(e))" in src
        assert self._code(will.PercAmountException) == 'percent'   # Opus review 18/11

    def test_texts(self):
        t = _read('controls', 'EhHeirTop.qml')
        for code in ('too_low', 'dust', 'keeper_fee'):
            assert "case '%s':" % code in t
        assert 'three post-dated cheques' in t and "they are called «dust»" in t
        assert 'or choose them yourself at the EXPERT level' in t
        # never an English technical text
        assert 'return message || code' not in t
        assert "return app.ehHeirPlainText(message)" in t

    def test_italian(self):
        from electrum.eh_strings import STRINGS
        it = STRINGS['it_IT']
        assert it['Today you pay nothing. The inheritance is like an envelope with three post-dated cheques: one for the heir, one for the miners and one for the keeper. It opens only on the day you chose.'] \
            .startswith('Oggi non paghi niente.')
        assert it['Maximum price of a keeper'] == 'Prezzo massimo di un custode'
        assert it['Write an amount from 1.000 to 500.000 sats.'] == 'Scrivi un importo da 1.000 a 500.000 sat.'


class TestPages:

    def test_settings_rows(self):
        s = _read('EhSettings.qml')
        assert "text: qsTr('Maximum price of a keeper')" in s
        assert "onClicked: col.lv >= 2 ? app._ehHeirOpenSheet('EhHeirKeeperMaxSheet.qml')" in s
        assert "visible: app.ehHeirEnabled() && col.heirPhase !== 'foreign' && col.lv >= 2" in s
        assert "app.stack.push(Qt.resolvedUrl('EhHeirKeeperChoosePage.qml'))" in s

    def test_max_sheet(self):
        m = _read('EhHeirKeeperMaxSheet.qml')
        assert "[25000, 50000, 100000, 200000]" in m
        assert "if (root.chosen < 1000 || root.chosen > 500000) {" in m
        assert "inputMethodHints: Qt.ImhDigitsOnly" in m

    def test_choose_page(self):
        c = _read('EhHeirKeeperChoosePage.qml')
        assert "readonly property bool dear: modelData.ok && modelData.feeSats > page.cap" in c
        assert "switchEnabled: (modelData.ok && !dear) || page.isOn(modelData.url)" in c
        assert "Component.onCompleted: load()" in c and "bal.loadKeeperChoices()" in c
        assert "keeperChoices()" not in c
        assert "page.bal.setKeepersMine(page.mine)" in c

    def test_your_keepers_says_where_to_choose(self):
        assert "visible: app.ehLevel() !== 'esperto'" in _read('EhHeirKeeperListSheet.qml')

    def test_out_of_expert_back_to_the_standard(self):
        m = _read('main.qml')
        body = m[m.index('    function ehSetLevel(to) {'):]
        body = body[:body.index('\n    }\n')]
        assert "if (to !== 'esperto') {" in body and 'bal.keepersStandard()' in body


class TestTextsAfterThePhoneTest:
    """owner 18/11, phone test of build62: four texts."""

    def test_one_chosen_is_singular(self):
        from electrum.eh_strings import STRINGS
        it = STRINGS["it_IT"]
        assert it["1 chosen"] == "1 scelto" and it["Save (1 chosen)"] == "Salva (1 scelto)"
        assert "length === 1 ? qsTr(\x271 chosen\x27)" in _read("EhSettings.qml")
        assert "page.mine.length === 1 ? qsTr(\x27Save (1 chosen)\x27)" in _read("EhHeirKeeperChoosePage.qml")

    def test_all_right_with_keepers_chosen_by_hand(self):
        c = _read("EhHeirCheckPage.qml")
        i = c.index("if ((st.keepersMine || []).length > 0)")
        assert i < c.index("qsTr(\x27We use 1: for now there are no others.\x27)")
        assert "qsTr(\x27We use 1: the one you chose.\x27)" in c

    def test_prices_never_twice_in_bitcoin(self):
        m = _read("main.qml")
        assert "function ehSatsAndEuro(sats) { var e = ehHeirEuro(sats); return ehSatsText(sats) + (e !== \x27\x27 ? \x27 · ≈ \x27 + e : \x27\x27) }" in m
        for f in ("EhHeirKeeperChoosePage.qml", "EhHeirKeeperMaxSheet.qml"):
            assert "app.ehHeirSats(" not in _read(f), f

    def test_going_down_from_expert_says_it(self):
        m = _read("main.qml")
        body = m[m.index("    function ehLevelLines(to) {"):]
        body = body[:body.index("\n    }\n")]
        assert "ehLevel() === \x27esperto\x27 && to !== \x27esperto\x27" in body
        assert body.count(") + k") == 2 and "(k !== '' ? " in body
