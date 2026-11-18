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

    def __init__(self, fees, answering, welist=()):
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
            return {u: {'ok': u in self.answering} for u in args[0]}
        if name == 'bal_willexecutors_download':
            for u, we in self.welist.items():
                self.wes.setdefault(u, dict(we))
            return None
        raise AssertionError(name)

    def selected(self):
        return sorted(u for u, we in self.wes.items() if we.get('selected'))


def _bridge(net, cap=None, mine=None, wanted=3):
    cfg = _Config()
    if cap is not None:
        cfg[_m().KEEPER_MAX_KEY] = cap
    if mine is not None:
        cfg[_m().KEEPERS_MINE_KEY] = mine
    me = SimpleNamespace(plugin=SimpleNamespace(config=cfg), _cmd=net.cmd,
                         _step_to=lambda s: None, _keepers_wanted=lambda: wanted)
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

    def test_the_list_with_the_prices(self, monkeypatch):
        from electrum.plugins.bal.core import willexecutors
        wes = {'https://z': {'base_fee': 15000, 'welist_rank': 1, 'status': 'OK'},
               'https://y': {'base_fee': 80000, 'welist_rank': 0},
               'https://k': {'base_fee': 1000, 'status': 'KO'},
               'http://abc.onion': {'base_fee': 1000, 'welist_rank': 2}}
        monkeypatch.setattr(willexecutors.Willexecutors, 'get_willexecutors', staticmethod(lambda p: wes))
        me = SimpleNamespace(plugin=SimpleNamespace(config=_Config({_m().KEEPERS_MINE_KEY: ['https://z']})))
        me._keepers_mine = _m().QEBal._keepers_mine.__get__(me)
        rows = _m().QEBal.keeperChoices(me)
        assert [(r['name'], r['feeSats'], r['mine'], r['ok']) for r in rows] == [
            ('y', 80000, False, True), ('z', 15000, True, True), ('k', 1000, False, False)]


def test_the_slots_save_the_settings():
    # the slots run their job on the worker (_start): here the job is run at once
    cfg = _Config()
    me = SimpleNamespace(plugin=SimpleNamespace(config=cfg), ran=[])
    me._start = lambda op, job: me.ran.append((op, job()))
    _m().QEBal.setKeeperMax(me, 30000)
    assert me.ran[-1] == ('setKeeperMax', {'keeperMax': 30000}) and cfg[_m().KEEPER_MAX_KEY] == 30000
    with pytest.raises(_m()._Fail) as e:
        _m().QEBal.setKeeperMax(me, 700000)
    assert e.value.code == 'user' and cfg[_m().KEEPER_MAX_KEY] == 30000
    _m().QEBal.setKeepersMine(me, ['https://c', 'https://c', B, ''])
    assert cfg[_m().KEEPERS_MINE_KEY] == ['https://c', B]
    _m().QEBal.keepersStandard(me)
    assert cfg[_m().KEEPER_MAX_KEY] == 50000 and cfg[_m().KEEPERS_MINE_KEY] == []


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
        assert "outcome = ('failed', _fail_code(e), str(e))" in open(_m().__file__, encoding='utf-8').read()

    def test_texts(self):
        t = _read('controls', 'EhHeirTop.qml')
        for code in ('too_low', 'dust', 'keeper_fee'):
            assert "case '%s':" % code in t
        assert 'three post-dated cheques' in t and "they are called «dust»" in t
        assert 'or choose them yourself at the EXPERT level' in t
        # never an English technical text
        assert 'return message || code' not in t
        assert "return t && t !== message ? t : qsTr('Something did not work. Your money is safe; try again later.')" in t

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
        assert "readonly property bool dear: modelData.feeSats > page.cap" in c
        assert "switchEnabled: !dear || page.isOn(modelData.url)" in c
        assert "page.bal.setKeepersMine(page.mine)" in c

    def test_your_keepers_says_where_to_choose(self):
        assert "visible: app.ehLevel() !== 'esperto'" in _read('EhHeirKeeperListSheet.qml')

    def test_out_of_expert_back_to_the_standard(self):
        m = _read('main.qml')
        body = m[m.index('    function ehSetLevel(to) {'):]
        body = body[:body.index('\n    }\n')]
        assert "if (to !== 'esperto') {" in body and 'bal.keepersStandard()' in body
