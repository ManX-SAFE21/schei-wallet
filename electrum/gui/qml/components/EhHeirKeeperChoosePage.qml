// Easy Heirs (schȅi), owner 18/11: Settings › Inheritance › "Choose the keepers" (EXPERT level).
// On opening, the keepers are asked now (bal.loadKeeperChoices): only those that answer, with
// their real price; the ones turned on get the envelope from the next one (new, update or
// renewal). None on = automatic. A keeper over the maximum price cannot be turned on.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

Item {
    id: page
    property bool ehHideHeader: true
    property bool ehHeirPage: true
    Material.theme: Material.Light
    Material.foreground: S.ink

    readonly property var bal: AppController.plugin('bal')
    readonly property var st: app.ehHeirState(bal)
    readonly property int cap: st.keeperMax || 50000
    property var rows: []
    property bool loading: true
    property string error: ''
    property var mine: (st.keepersMine || []).slice()

    function load() {
        if (!bal) return
        loading = true; error = ''
        bal.loadKeeperChoices()
    }
    Component.onCompleted: load()
    Connections {
        target: page.bal
        function onDone(op, result) {
            if (op !== 'loadKeeperChoices') return
            page.rows = result.keepers || []
            page.loading = false
        }
        function onFailed(op, code, message) {
            if (op !== 'loadKeeperChoices') return
            page.loading = false
            page.error = code === 'busy' ? qsTr('Schȅi is busy with the inheritance. Try again in a moment.')
                                         : app.ehHeirErrorText(code, message)
        }
    }

    function isOn(url) { return mine.indexOf(url) >= 0 }
    function setOn(url, on) {
        var m = mine.filter(function(u) { return u !== url })
        if (on) m.push(url)
        mine = m
    }

    Rectangle { anchors.fill: parent; color: S.parch }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.height + 12
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 2 * S.margin
            x: S.margin
            height: Math.max(implicitHeight, flick.height - 12)
            spacing: S.gap

            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            EhBackLink { onClicked: app.stack.pop() }
            EhTitle { text: qsTr('Choose the keepers'); icon: 'eh_shield_olive.svg' }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: -4
                text: qsTr('Turn on the keepers you want to give the envelope to. If none is on, Schȅi chooses them by itself.')
                wrapMode: Text.WordWrap
                color: S.ink
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                lineHeight: 1.1
            }

            EhCaption { text: qsTr('Price at the delivery'); Layout.topMargin: 2; Layout.bottomMargin: -6 }
            EhSheet {
                visible: !page.loading && page.rows.length > 0
                Repeater {
                    model: page.rows
                    delegate: EhRow {
                        required property var modelData
                        required property int index
                        readonly property bool dear: modelData.ok && modelData.feeSats > page.cap
                        icon: 'eh_shield_olive.svg'; iconColor: dear || !modelData.ok ? S.muted : S.olive
                        text: modelData.name
                        hint: !modelData.ok ? qsTr('does not answer now')
                              : app.ehSatsAndEuro(modelData.feeSats)
                                + (dear ? ' · ' + qsTr('over your maximum') : '')
                        showSwitch: true
                        checked: page.isOn(modelData.url)
                        switchEnabled: (modelData.ok && !dear) || page.isOn(modelData.url)
                        last: index === page.rows.length - 1
                        onToggled: (on) => page.setOn(modelData.url, on)
                    }
                }
            }
            Label {
                visible: page.loading || (page.rows.length === 0 && page.error === '')
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                text: page.loading ? qsTr('I am asking the keepers their price…') : qsTr('No keeper answered. Try again later.')
            }
            EhInfoBox {
                visible: page.error !== ''
                kind: 'danger'
                text: page.error
            }
            EhInfoBox {
                kind: 'tip'
                text: qsTr('Each keeper keeps a copy of the envelope: at the delivery <b>only one</b> is paid. Maximum price: <b>%1</b>.').arg(app.ehSatsText(page.cap))
            }

            Item { Layout.fillHeight: true; Layout.minimumHeight: 4 }

            EhStitchButton {
                kind: 'olive'
                icon: 'eh_check_white.svg'
                enabled: !(page.bal && page.bal.busy) && !page.loading
                text: page.mine.length === 1 ? qsTr('Save (1 chosen)')
                    : page.mine.length > 1 ? qsTr('Save (%1 chosen)').arg(page.mine.length) : qsTr('Save (automatic)')
                onClicked: { if (page.bal) page.bal.setKeepersMine(page.mine); app.stack.pop() }
            }
        }
    }
}
