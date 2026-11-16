// Easy Heirs (schȅi): inheritance wizard, screen 2 "Who receives?" (step 1 of 4).
// The heirs of the Àncòra plugin (bal bridge, state.heirs) on a paper sheet: name, short
// address, percent. A row opens the person (EhHeirPersonPage); "Add a person" up to 5;
// the total must be 100 to go on to "In how long?" (EhHeirWhenPage).
// "Bottega" look as the preview anteprima/eredita-semplice.html, screen 2.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S
import "controls/EhShare.js" as Share

Item {
    id: page
    property bool ehHideHeader: true
    property bool ehHeirPage: true
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.wine

    readonly property var bal: AppController.plugin('bal')
    readonly property var st: bal ? bal.state : ({})
    readonly property var heirs: st && st.heirs ? st.heirs : []
    readonly property int total: st && st.total !== undefined ? st.total : 0
    readonly property bool busy: bal ? bal.busy : false
    readonly property int maxHeirs: 5
    property string error: ''

    Rectangle { anchors.fill: parent; color: S.parch }

    Connections {
        target: page.bal
        function onFailed(op, code, message) {
            if (code === 'busy' || op !== 'refresh') return
            page.error = top.failText(code, message)
        }
        function onDone(op, result) { if (op === 'refresh') page.error = '' }
    }
    Component.onCompleted: if (bal && !bal.busy) bal.refresh()
    // owner Q7: the total and its message (what is left to give) must be seen: on a phone they
    // can fall under the fold, so the list scrolls to its end when the heirs change
    onHeirsChanged: endScroll.restart()
    onTotalChanged: endScroll.restart()
    Timer {
        id: endScroll
        interval: 120
        onTriggered: flick.contentY = Math.max(0, flick.contentHeight - flick.height)
    }

    function openPerson(h) {
        app.stack.push(Qt.resolvedUrl('EhHeirPersonPage.qml'), h
            ? { oldName: h.name, oldAddress: h.address, oldPercent: h.percent }
            : {})
    }

    // one heir: person ring, name and short address, percent, chevron
    component HeirRow: Item {
        id: hr
        property var heir
        property bool last: false
        readonly property var parts: app.ehAddressParts(heir.address)
        Layout.fillWidth: true
        implicitHeight: Math.max(64, line.implicitHeight + 16)
        Layout.preferredHeight: implicitHeight
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            radius: 10
            color: S.sand
            opacity: hrTap.pressed ? 0.4 : 0
        }
        RowLayout {
            id: line
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            EhIconRing { icon: 'eh_person.svg' }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    text: hr.heir.name
                    color: S.ink
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: app.ehFsText
                    font.bold: true
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    textFormat: Text.RichText
                    // prefix, first 4 and last 4 highlighted, as everywhere in the app
                    text: hr.parts.prefix
                          + '<span style="background-color:' + S.highlight + '"><font color="' + S.wineDark + '">' + hr.parts.first + '</font></span>'
                          + '…'
                          + '<span style="background-color:' + S.highlight + '"><font color="' + S.wineDark + '">' + hr.parts.last + '</font></span>'
                    color: S.muted
                    font.family: FixedFont
                    font.bold: true
                    font.pixelSize: app.ehFsText
                    elide: Text.ElideRight
                }
            }
            Label {
                text: hr.heir.percent + '%'
                color: S.oliveInk
                font.family: SerifFont ? SerifFont : font.family
                font.weight: Font.ExtraBold
                font.pixelSize: app.ehFsStrong
            }
            Label {
                text: '›'
                color: S.wine
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsBox
                font.bold: true
            }
        }
        EhDotLine {
            visible: !hr.last
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: parent.width
        }
        TapHandler { id: hrTap; enabled: !page.busy; onTapped: page.openPerson(hr.heir) }
    }

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: foot.top
        anchors.bottomMargin: 8
        contentHeight: col.implicitHeight + 10
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height + 1
        clip: true

        ColumnLayout {
            id: col
            x: S.margin
            width: flick.width - 2 * S.margin
            spacing: 10

            EhHeirTop { id: top; stepNow: 1 }

            EhBackLink { onClicked: app.stack.pop() }

            EhTitle { text: qsTr('Who receives?') }

            EhCaption {
                visible: page.heirs.length > 0
                text: qsTr('Your heirs')
                tail: qsTr('(or backup wallet)')     // owner 15/11, point 5
                Layout.topMargin: 0
                Layout.bottomMargin: -4
            }
            EhSheet {
                visible: page.heirs.length > 0
                Repeater {
                    model: page.heirs
                    delegate: HeirRow {
                        required property var modelData
                        required property int index
                        heir: modelData
                        last: index === page.heirs.length - 1
                    }
                }
            }

            // owner Q7: with 5 heirs it stays in view, off, «(già 5)»
            EhStitchButton {
                readonly property bool full: page.heirs.length >= page.maxHeirs
                Layout.topMargin: 4
                kind: 'paper'
                icon: 'eh_plus.svg'
                text: qsTr('Add a person') + (full ? ' ' + qsTr('(already 5)') : '')
                enabled: !page.busy && !full
                onClicked: page.openPerson(null)
            }

            // the total: 100% in olive, anything else in wine
            EhSheet {
                visible: page.heirs.length > 0
                Layout.topMargin: 4
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(50, totRow.implicitHeight + 10)
                    RowLayout {
                        id: totRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Label {
                            Layout.fillWidth: true
                            textFormat: Text.StyledText
                            text: '<b>' + qsTr('Total') + '</b> <font color="' + S.muted + '" size="2">· ' + qsTr('at most 5 people') + '</font>'
                            color: S.ink
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: app.ehFsText
                            wrapMode: Text.WordWrap
                        }
                        Label {
                            text: page.total + '%'
                            color: page.total === 100 ? S.oliveInk : S.wine
                            font.family: SerifFont ? SerifFont : font.family
                            font.weight: Font.ExtraBold
                            font.pixelSize: app.ehFsStrong
                        }
                    }
                }
            }

            // owner Q7: 100 = go on; less = what is left to give; more (old data) = how much too much
            EhInfoBox {
                visible: page.heirs.length > 0
                readonly property string sk: Share.summaryKind(page.total)
                kind: sk === 'ok' ? 'tip' : 'danger'
                text: sk === 'ok'
                      ? qsTr('The total is 100%: you can go on.')
                      : sk === 'missing'
                        ? qsTr('There is %1 left to give. Add a person or tap an heir to change their share.')
                            .arg('<b>' + (100 - page.total) + '%</b>')
                        : qsTr('There is %1 too much: the total must be 100%. Tap an heir to lower their share.')
                            .arg('<b>' + (page.total - 100) + '%</b>')
            }
            EhInfoBox {
                visible: page.error !== ''
                kind: 'danger'
                text: page.error
            }

        }
    }

    // the foot: always in view, above the Android keys; the page scrolls above it
    ColumnLayout {
        id: foot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: S.margin
        anchors.rightMargin: S.margin
        spacing: 10

        // busy: what the bridge is doing
        RowLayout {
            visible: page.busy && top.stepText(page.bal ? page.bal.step : '') !== ''
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            BusyIndicator { Layout.preferredWidth: 28; Layout.preferredHeight: 28; running: parent.visible }
            Label {
                text: top.stepText(page.bal ? page.bal.step : '')
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
                font.bold: true
            }
        }

        // the foot: a line over the whole width, then the button
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: -S.margin
            Layout.rightMargin: -S.margin
            Layout.preferredHeight: 1.5
            color: S.edge
        }
        EhStitchButton {
            Layout.bottomMargin: 6
            kind: 'wine'
            endIcon: 'next'
            text: qsTr('Next')
            enabled: !page.busy && page.heirs.length > 0 && page.total === 100
            onClicked: app.stack.push(Qt.resolvedUrl('EhHeirWhenPage.qml'))
        }
    }
}
