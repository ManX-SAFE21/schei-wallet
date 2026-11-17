// Easy Heirs (schȅi), owner 17/11: "Cerco i tuoi soldi". Replaces Electrum's technical page
// (WCScriptAndDerivation: script type + derivation path) after the words of another wallet (BIP39).
// It does by itself what Electrum's "Detect Existing Accounts" button does (EhFindFunds,
// qeehfindfunds.py): read only, nothing is signed or sent.
// - nothing found: the modern kind (native segwit, first account), as Electrum proposes;
// - found in one place: that one;
// - found in more places: the person chooses (a Schȅi wallet opens only one of them);
// - no internet / no answer: say it, "Try again" or go on with the modern kind.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "../controls"
import "../controls/EhStyle.js" as S

WizardComponent {
    id: root
    Material.theme: Material.Light
    Material.foreground: '#2a2220'
    Material.accent: '#5e1a33'
    valid: chosen !== null
    property bool hideWizardButtons: true

    property var chosen: null        // the account to open: { derivation_path, script_type, kind, ... }
    property int chosenIndex: -1     // when the person chooses among more

    background: Rectangle { color: S.parch }
    topPadding: 0
    leftPadding: 16
    rightPadding: 16
    bottomPadding: 14   // the wizard (ElDialog) already leaves room for the Android keys

    function apply() {
        if (!chosen)   // the wizard asks also while the search is running
            return
        wizard_data['script_type'] = chosen.script_type
        wizard_data['derivation_path'] = chosen.derivation_path
    }

    function kindName(kind) {
        return kind === 'modern' ? qsTr('Modern') : kind === 'compat' ? qsTr('Compatible') : kind === 'old' ? qsTr('Old') : qsTr('Other')
    }
    function kindStart(kind) {
        return kind === 'modern' ? qsTr('addresses that start with %1').arg(Network.isTestNet ? 'tb1q' : 'bc1q')
             : kind === 'compat' ? qsTr('addresses that start with %1').arg(Network.isTestNet ? '2' : '3')
             : qsTr('addresses that start with %1').arg(Network.isTestNet ? 'm / n' : '1')
    }
    function accountDetail(a) {
        if (!a.standard)
            return qsTr('special path %1').arg(a.derivation_path)
        return a.account > 0 ? qsTr('account %1').arg(a.account + 1) : ''
    }

    function search() {
        chosen = null
        chosenIndex = -1
        finder.start(wizard_data['seed'])
    }
    function settle() {
        if (finder.state !== 'done')
            return
        var p = finder.pick
        if (!p.mustChoose)
            chosen = p.choice
    }
    function goOn() {
        if (!valid)
            return
        checkIsLast()   // put the choice in wizard_data and ask again if more pages follow
        if (root.last)
            wizard.pages.finish()
        else
            wizard.pages.next()
    }

    EhFindFunds {
        id: finder
        onStateChanged: root.settle()
    }
    Component.onCompleted: search()
    Component.onDestruction: finder.cancel()

    readonly property bool scanning: finder.state === 'scanning' || finder.state === 'idle'
    readonly property bool failed: finder.state === 'failed'
    readonly property bool mustChoose: finder.state === 'done' && finder.pick.mustChoose === true

    Flickable {
        id: ehFlick
        anchors.fill: parent
        anchors.leftMargin: -16
        anchors.rightMargin: -16
        contentHeight: ehCol.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
    ColumnLayout {
        id: ehCol
        x: 16
        width: ehFlick.width - 32
        height: Math.max(implicitHeight, ehFlick.height)
        spacing: 10

        EhPageTop {
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            title: root.scanning ? qsTr('Looking for your money')
                 : root.failed ? qsTr('I cannot look for your money')
                 : root.mustChoose ? qsTr('Your money is in more places')
                 : finder.pick.found ? qsTr('I found your money') : qsTr('No movements found')
        }

        EhInfoBox {
            visible: root.scanning
            kind: 'warn'
            text: qsTr('The words of another wallet can use different kinds of addresses. I check all of them: it takes about a minute.')
        }

        // ---- the 3 kinds: checking / used / nothing ----
        Rectangle {
            visible: !root.failed
            Layout.fillWidth: true
            implicitHeight: kindsCol.implicitHeight + 8
            radius: 16
            color: S.paper
            border.width: 2
            border.color: S.edge
            ColumnLayout {
                id: kindsCol
                anchors.fill: parent
                anchors.margins: 4
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 0
                Repeater {
                    model: ['modern', 'compat', 'old']
                    delegate: ColumnLayout {
                        id: krow
                        required property string modelData
                        required property int index
                        readonly property string st: finder.kinds[modelData] || ''
                        Layout.fillWidth: true
                        spacing: 0
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                            spacing: 10
                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                Rectangle {
                                    visible: krow.st !== 'scanning'
                                    anchors.fill: parent
                                    radius: 14
                                    color: krow.st === 'used' ? S.olive : S.sand
                                    Label {
                                        anchors.centerIn: parent
                                        text: krow.st === 'used' ? '✓' : '–'
                                        color: krow.st === 'used' ? S.ivory : S.muted
                                        font.bold: true
                                        font.pixelSize: app.ehFsText
                                    }
                                }
                                BusyIndicator { anchors.fill: parent; visible: krow.st === 'scanning'; running: visible }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label {
                                    text: root.kindName(krow.modelData)
                                    color: S.ink
                                    font.family: BodyFont ? BodyFont : font.family
                                    font.pixelSize: app.ehFsText
                                    font.bold: true
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: root.kindStart(krow.modelData)
                                    color: S.muted
                                    wrapMode: Text.WordWrap
                                    font.family: BodyFont ? BodyFont : font.family
                                    font.pixelSize: app.ehFsSmall
                                }
                            }
                            Label {
                                text: krow.st === 'used' ? qsTr('used') : krow.st === 'scanning' ? qsTr('checking…') : qsTr('nothing')
                                color: krow.st === 'used' ? S.oliveInk : S.muted
                                font.family: BodyFont ? BodyFont : font.family
                                font.pixelSize: app.ehFsText
                                font.bold: krow.st === 'used'
                            }
                        }
                        EhDotLine { visible: krow.index < 2; Layout.fillWidth: true }
                    }
                }
            }
        }

        // ---- result: one place or nothing ----
        EhInfoBox {
            visible: finder.state === 'done' && !root.mustChoose && root.chosen !== null
            kind: 'tip'
            text: finder.pick.found
                  ? '<b>' + qsTr('I use the kind «%1»: your money is there.').arg(root.chosen ? root.kindName(root.chosen.kind) : '') + '</b>'
                    + (root.chosen && root.accountDetail(root.chosen) !== '' ? ' (' + root.accountDetail(root.chosen) + ')' : '')
                  : qsTr('If the wallet is new that is fine: I use the kind «%1», the one of today’s wallets.').arg(qsTr('Modern'))
        }

        // owner 17/11 (controllo-mainnet M5): the inheritance works only with the modern kind
        // (native segwit, bal core/heirs.py only_native_segwit): say it here, not at the end
        EhInfoBox {
            visible: finder.state === 'done' && root.chosen !== null && root.chosen.script_type !== 'p2wpkh'
            kind: 'warn'
            text: '<b>' + qsTr('With this kind of addresses the inheritance cannot be made.') + '</b> '
                  + qsTr('To use it, later send the money to a new Schȅi wallet (kind «%1»).').arg(qsTr('Modern'))
        }

        // ---- result: more places, the person chooses ----
        EhInfoBox {
            visible: root.mustChoose
            kind: 'warn'
            text: qsTr('A Schȅi wallet opens <b>only one</b> of them: choose which. The others can be opened later with the same words, in another wallet.')
        }
        Repeater {
            model: root.mustChoose ? finder.accounts : []
            delegate: Item {
                id: opt
                required property var modelData
                required property int index
                readonly property bool on: root.chosenIndex === index
                Layout.fillWidth: true
                // the height comes from the texts only (not from the box around them): a loop
                // between the two froze the app when an option was chosen
                Layout.preferredHeight: Math.max(54, optText.implicitHeight + 23)
                Rectangle { y: 3; width: parent.width; height: parent.height - 3; radius: 14; color: S.edgeShadow }
                Rectangle {
                    width: parent.width
                    height: parent.height - 3
                    radius: 14
                    color: opt.on ? S.leatherWine2 : S.paper
                    border.width: 2
                    border.color: opt.on ? S.wineDark : S.edge
                    RowLayout {
                        id: optRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        // a drawn round choice (a font symbol changed the row height when chosen)
                        Rectangle {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            radius: 11
                            color: 'transparent'
                            border.width: 2
                            border.color: opt.on ? S.ivory : S.wine
                            Rectangle {
                                visible: opt.on
                                anchors.centerIn: parent
                                width: 10
                                height: 10
                                radius: 5
                                color: S.ivory
                            }
                        }
                        ColumnLayout {
                            id: optText
                            Layout.fillWidth: true
                            spacing: 0
                            Label {
                                Layout.fillWidth: true
                                text: root.kindName(opt.modelData.kind) + (root.accountDetail(opt.modelData) !== '' ? ' · ' + root.accountDetail(opt.modelData) : '')
                                color: opt.on ? S.ivory : S.ink
                                wrapMode: Text.WordWrap
                                font.family: BodyFont ? BodyFont : font.family
                                font.pixelSize: app.ehFsText
                                font.bold: true
                            }
                            Label {
                                Layout.fillWidth: true
                                text: root.kindStart(opt.modelData.kind)
                                color: opt.on ? S.ivory : S.muted
                                wrapMode: Text.WordWrap
                                font.family: BodyFont ? BodyFont : font.family
                                font.pixelSize: app.ehFsSmall
                            }
                        }
                    }
                }
                // a MouseArea takes the tap for itself (with a TapHandler the tap reached also the
                // page background and the app stopped)
                MouseArea { anchors.fill: parent; onClicked: { root.chosenIndex = opt.index; root.chosen = opt.modelData } }
            }
        }

        // ---- no internet / no answer ----
        EhInfoBox {
            visible: root.failed
            kind: 'danger'
            text: '<b>' + (finder.error === 'offline'
                  ? qsTr('There is no internet connection, so I cannot check where your money is.')
                  : qsTr('The server did not answer, so I cannot check where your money is.')) + '</b> '
                  + qsTr('Try again, or go on with the kind «%1», the one of today’s wallets.').arg(qsTr('Modern'))
        }

        Item { Layout.fillHeight: true; Layout.minimumHeight: 4 }

        EhStitchButton {
            visible: root.failed || (finder.state === 'done' && !finder.pick.found)
            kind: 'paper'
            text: qsTr('Check again')
            onClicked: root.search()
        }
        EhStitchButton {
            visible: root.failed
            kind: 'wine'
            text: qsTr('Go on with «%1»').arg(qsTr('Modern'))
            endIcon: 'next'
            onClicked: { root.chosen = finder.fallback; root.goOn() }
        }
        EhStitchButton {
            visible: !root.failed
            enabled: root.valid
            kind: 'wine'
            text: root.scanning ? qsTr('Checking…') : root.mustChoose && !root.valid ? qsTr('Choose one above') : qsTr('Next')
            endIcon: 'next'
            onClicked: root.goOn()
        }
    }
    }
}
