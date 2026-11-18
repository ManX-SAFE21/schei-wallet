// Easy Heirs (schȅi): "Your keepers" (owner 15/11, point P1; preview
// anteprima/custode-spento/elenco-custodi.html). Opened by tapping the "Keepers" row of the
// Status page: who holds the envelope (state.custodians.list), what each one takes at the
// delivery and when it was checked, or for how many days it has not answered. Fewer keepers
// than chosen: a note. Too few answer (P6 'low', or none): "Replace the ones that do not
// answer" (EhHeirReplaceSheet); 'some' (at least the chosen minus 1 answer) only shows the row.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "controls"
import "controls/EhStyle.js" as S

EhBottomSheet {
    id: root
    readonly property var bal: AppController.plugin('bal')
    readonly property var st: app.ehHeirState(bal)   // M1: only the wallet open
    readonly property var cust: st.custodians || ({ ok: 0, total: 0, list: [] })
    readonly property var list: cust.list || []
    readonly property int total: cust.total || 0
    readonly property int wanted: cust.wanted || st.keepersWanted || 0
    readonly property int lost: Math.max(0, total - (cust.ok || 0))
    readonly property string kst: cust.status || ''
    onClosed: destroy()

    function day(t) { return Qt.formatDate(new Date(t * 1000), 'yyyyMMdd') }
    function checkedText(t) {
        if (!t) return ''
        var d = new Date(t * 1000)
        var hm = Qt.formatTime(d, 'hh:mm')
        if (day(t) === day(root.st.now || Math.floor(Date.now() / 1000)))
            return qsTr('checked today at %1').arg(hm)
        return qsTr('checked on %1 at %2').arg(Qt.formatDate(d, 'dd/MM')).arg(hm)
    }
    function subText(k) {
        if (!k.ok && k.sent && k.checkedAt) {
            var n = k.downDays || 0
            return n <= 0 ? qsTr('Not answering since today')
                 : n === 1 ? qsTr('Not answering for 1 day') : qsTr('Not answering for %1 days').arg(n)
        }
        var c = checkedText(k.checkedAt || 0)
        return qsTr('At the delivery it takes about %1').arg(app.ehSatsAndEuro(k.feeSats || 0)) + (c !== '' ? ' · ' + c : '')
    }

    EhTitle {
        text: qsTr('Your keepers')
        icon: 'eh_shield_olive.svg'
        fontSize: app.ehFsBox
        Layout.bottomMargin: 0
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: app.ehFsText
        lineHeight: 1.15
        color: S.ink
        text: qsTr('They have a copy of the sealed envelope and send it on the delivery date. One is enough.')
    }
    EhSheet {
        visible: root.list.length > 0
        Repeater {
            model: root.list
            delegate: Item {
                id: kr
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: krCol.implicitHeight + 20
                Layout.preferredHeight: implicitHeight
                ColumnLayout {
                    id: krCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Label {
                            Layout.fillWidth: true
                            text: kr.modelData.name
                            elide: Text.ElideRight
                            color: S.ink
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: app.ehFsText
                            font.bold: true
                        }
                        Label {
                            text: kr.modelData.ok ? '✓ ' + qsTr('has the envelope')
                                : !kr.modelData.sent ? '✕ ' + qsTr('no envelope') : '✕ ' + qsTr('does not answer')
                            color: kr.modelData.ok ? S.oliveInk : S.wine
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: app.ehFsSmall
                            font.bold: true
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: S.muted
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: app.ehFsSmall
                        text: root.subText(kr.modelData)
                    }
                }
                EhDotLine {
                    visible: kr.index < root.list.length - 1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: parent.width
                }
            }
        }
    }
    Label {
        visible: root.total > 0 && root.total < root.wanted
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: app.ehFsSmall
        color: S.muted
        // owner 18/11: never "there are no others" (some may only not answer now, or be chosen by hand)
        text: (root.st.keepersMine || []).length > 0
              ? (root.total === 1 ? qsTr('We use 1 keeper: the one you chose.') : qsTr('We use %1 keepers: the ones you chose.').arg(root.total))
              : root.total === 1 ? qsTr('We use 1 keeper of the %1 chosen: the others do not answer now, or there are no more.').arg(root.wanted)
              : qsTr('We use %1 keepers of the %2 chosen: the others do not answer now, or there are no more.').arg(root.total).arg(root.wanted)
    }
    EhStitchButton {
        visible: root.lost > 0 && ['low', 'none', 'invalid'].indexOf(root.kst) >= 0
        kind: 'wine'
        icon: 'eh_lock_white.svg'
        text: root.kst === 'low' ? qsTr('Replace the ones that do not answer') : qsTr('Send the envelope to other keepers')
        enabled: !(root.bal && root.bal.busy)
        onClicked: { root.close(); app._ehHeirOpenSheet('EhHeirReplaceSheet.qml') }
    }
    // owner 18/11: below EXPERT the keepers are chosen by Schȅi: say where to choose them
    Label {
        visible: app.ehLevel() !== 'esperto'
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: app.ehFsSmall
        color: S.muted
        text: qsTr('Schȅi chooses them by itself, only among those who ask at most %1. To choose them yourself: EXPERT level.')
                  .arg(app.ehSatsText(root.st.keeperMax || 50000))
    }
    EhStitchButton {
        kind: 'paper'
        text: qsTr('Close')
        onClicked: root.close()
    }
}
