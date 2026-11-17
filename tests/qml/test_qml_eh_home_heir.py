# Schȅi, owner 17/11:
# - wallet carousel: every wallet is the leather card (not open: last balance, "○ ultimo saldo",
#   no badge); the card grows while it slides to the middle (no jump after loading)
# - inheritance badge: always "EREDITÀ"; not made / not read yet: faint, no dot
# - Settings › Inheritance switch per wallet, on by default; question about every 3 months
# - no pocket-amount sentences; warning "words on one device"; testnet4 shows euro too
import os
from unittest import TestCase

from electrum.gui.qml import qeapp

COMP = os.path.join(os.path.dirname(qeapp.__file__), 'components')


def _read(*p):
    return open(os.path.join(COMP, *p), encoding='utf-8').read()


class TestCarousel(TestCase):

    def test_every_wallet_is_the_leather_card(self):
        s = _read('controls', 'EhWalletCarousel.qml')
        self.assertNotIn('id: otherCard', s)
        self.assertNotIn("qsTr('tap to open it')", s)
        self.assertIn("idleName: d.isCurrent ? '' : (d.model.name || '')", s)
        self.assertIn('visible: !d.isAdd', s)

    def test_card_grows_with_its_position_not_after_loading(self):
        s = _read('controls', 'EhWalletCarousel.qml')
        self.assertIn('scale: 1 - 0.1 * away', s)
        self.assertNotIn('Behavior on scale', s)
        self.assertNotIn('scale: isCurrent', s)

    def test_idle_card_shows_last_balance_and_no_badge(self):
        s = _read('controls', 'EhBalanceCard.qml')
        self.assertIn("property string idleName: ''", s)
        self.assertIn("Config.ehGet('bal_' + root.idleName)", s)
        self.assertIn("root.idle ? '○ ' + qsTr('last balance')", s)
        self.assertIn('!root.watch && !root.idle', s)


class TestBadge(TestCase):

    def test_always_inheritance_faint_when_not_made(self):
        s = _read('controls', 'EhBalanceCard.qml')
        self.assertNotIn("qsTr('TO DO')", s)
        self.assertIn("text: qsTr('INHERITANCE')", s)
        self.assertIn("readonly property bool heirFaint: root.heirOff || root.heirPhase === ''", s)
        self.assertIn('opacity: root.heirFaint ? 0.42 : 1', s)


class TestSwitchAndQuestion(TestCase):

    def test_switch_on_by_default_per_wallet(self):
        m = _read('main.qml')
        self.assertIn("return Config.ehGet('heir_on_' + ehWalletKey()) !== false", m)
        self.assertIn('&& app.ehHeirEnabled()', _read('controls', 'EhBalanceCard.qml'))

    def test_switch_cannot_hide_an_existing_inheritance(self):
        s = _read('EhSettings.qml')
        self.assertIn("readonly property bool exists: col.heirPhase !== 'none' && col.heirPhase !== 'draft'", s)
        self.assertIn('switchEnabled: !exists || !app.ehHeirEnabled()', s)

    def test_question_rules(self):
        m = _read('main.qml')
        body = m[m.index('function ehHeirMaybeOffer'):m.index('function ehHeirUpdate')]
        for rule in ("w.isWatchOnly || !ehHeirEnabled()", "phase !== 'none' && phase !== 'draft'",
                     'w.ehTotal.satsInt <= 0', 'if (!next) { Config.ehSet(k, now + ehHeirOfferEvery); return false }',
                     'if (now < next) return false'):
            self.assertIn(rule, body)
        self.assertIn('readonly property real ehHeirOfferEvery: 90 * 24 * 3600 * 1000', m)
        sheet = _read('EhHeirOfferSheet.qml')
        self.assertIn("qsTr(\"Yes, let's make it\")", sheet)
        self.assertIn("qsTr('Later')", sheet)


class TestTexts(TestCase):

    def test_no_pocket_amounts(self):
        for name in ('EhHeirIntroPage.qml', 'EhHeirHowPage.qml'):
            self.assertNotIn('pocket amounts', _read(name), name)

    def test_one_device_warning(self):
        self.assertIn('Use your words (SEED) on one phone or computer only', _read('EhHeirHowPage.qml'))

    def test_testnet_shows_euro(self):
        m = _read('main.qml')
        self.assertIn("function ehBtcOnly() { ehOptRev; return Config.ehGet('opt_btc_only') === true }", m)


class TestStateOfTheWalletOpen(TestCase):
    # Samsung 17/11: right after a switch the card showed the previous wallet's green dot

    def test_state_says_whose_it_is(self):
        p = os.path.join(os.path.dirname(qeapp.__file__), '..', '..', 'plugins', 'bal', 'qml.py')
        src = open(p, encoding='utf-8').read()
        self.assertIn("s['wallet'] = wallet.basename()", src)
        from electrum.plugins.bal.qml import _empty_state
        self.assertEqual('', _empty_state()['wallet'])

    def test_card_and_decisions_ignore_another_wallets_state(self):
        card = _read('controls', 'EhBalanceCard.qml')
        self.assertIn('root.heirBal.state.wallet === Daemon.currentWallet.name', card)
        m = _read('main.qml')
        body = m[m.index('function ehHeirDecide'):m.index('function _ehHeirOpenSheet')]
        self.assertIn('if (s.wallet !== Daemon.currentWallet.name)', body)
