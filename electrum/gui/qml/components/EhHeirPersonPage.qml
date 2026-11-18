// Easy Heirs (schȅi): inheritance wizard, screen 3 "New person" (still step 1 of 4).
// Name, bitcoin address (QR or paste, never typed) and the share (owner Q7, 16/11, preview
// anteprima/slider-percentuale-esempi.html): a slider 0-100 % in steps of 5 with a brass knob;
// the part the OTHER heirs already have is grey at the right end and cannot be reached
// (max = 100 - others; editing an heir its own old share is free again). The number box above
// (pen ✎) opens the keypad: any whole number 1-100 (33 too) is kept, the slider goes near it.
// Over the max: red box, Save off. Nothing left: grey slider at 0, Save off. A new heir starts
// from what is left (the first one from 0). Rules in controls/EhShare.js (tests/qml).
// Save = bal.heirSave(); when an existing heir is opened (oldName set) also "Remove this
// person" = bal.heirDelete(). "Bottega" look as the preview anteprima/eredita-semplice.html.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"
import "controls/EhStyle.js" as S
import "controls/EhShare.js" as Share

Item {
    id: page
    property bool ehHideHeader: true
    property bool ehHeirPage: true
    Material.theme: Material.Light
    Material.foreground: S.ink
    Material.accent: S.wine          // the text cursor

    // the heir being changed ('' = a new person)
    property string oldName: ''
    property string oldAddress: ''
    property int oldPercent: 0

    readonly property var bal: AppController.plugin('bal')
    readonly property var st: app.ehHeirState(bal)   // M1: only the wallet open
    readonly property bool busy: bal ? bal.busy : false

    property string address: oldAddress
    property string addrError: ''
    property string error: ''
    property int percent: 0
    // the share: what the others have, the most this heir can have, what is typed on the keypad
    readonly property int others: Share.othersTotal(st && st.heirs ? st.heirs : [], oldName)
    readonly property int maxP: Share.maxFor(others)
    readonly property bool nothingLeft: maxP <= 0
    readonly property bool tooHigh: !nothingLeft && percent > maxP
    property string typed: ''
    property bool padOpen: false
    // the knob never goes into the grey part: a number typed over the max leaves it at the max
    onPercentChanged: if (!slider.pressed) slider.value = Math.min(percent, maxP)
    // the share is under the fold on a phone: bring it into view when the address is chosen,
    // when an heir is opened to be changed and when nothing is left (Save off: say why)
    onAddressChanged: if (address !== '') shareScroll.restart()
    Timer {
        id: shareScroll
        interval: 120
        onTriggered: {
            var want = shareSheet.y + shareSheet.height + 12 - flick.height
            if (want > flick.contentY) flick.contentY = Math.min(want, Math.max(0, flick.contentHeight - flick.height))
        }
    }
    // the keypad: the typed number is kept as it is (33), the slider goes near it
    function press(k) {
        if (k === 'ok') { padOpen = false; return }
        typed = Share.press(typed, k)
        percent = Share.typedValue(typed)
        error = ''
    }
    function togglePad() {
        if (nothingLeft || busy) return
        typed = ''
        padOpen = !padOpen
        if (padOpen) padScroll.restart()
    }
    Timer {      // the keypad opened: scroll so that its last row is in view
        id: padScroll
        interval: 80
        onTriggered: {
            var p = pad.mapToItem(col, 0, 0)
            var want = p.y + pad.height + 10 - flick.height
            if (want > flick.contentY) flick.contentY = Math.min(want, Math.max(0, flick.contentHeight - flick.height))
        }
    }
    // an error appears at the bottom of the page: scroll so that it is in view
    // (after the layout has placed the error box)
    onErrorChanged: if (error !== '') errorScroll.restart()
    Timer {
        id: errorScroll
        interval: 80
        onTriggered: flick.contentY = Math.max(0, flick.contentHeight - flick.height)
    }

    Rectangle { anchors.fill: parent; color: S.parch }

    // a new heir starts from what is left (the first one from 0); editing keeps the share
    Component.onCompleted: {
        percent = Share.startFor(oldName !== '', oldPercent, others)
        slider.value = Math.min(percent, maxP)
        if (oldName !== '' || nothingLeft) shareScroll.restart()
    }

    // another heir already has this name (trimmed, any case): saving it is refused
    function nameTaken(n) {
        var k = n.trim().toLowerCase()
        var h = (st && st.heirs) ? st.heirs : []
        for (var i = 0; i < h.length; i++)
            if (h[i].name !== oldName && ('' + h[i].name).trim().toLowerCase() === k) return true
        return false
    }

    function addrOf(s) { return s.trim().replace(/^bitcoin:/i, '').split('?')[0] }
    function useAddress(s) {
        var a = addrOf(s)
        if (!bitcoin.isAddress(a)) {
            addrError = qsTr('This is not a bitcoin address.')
            return
        }
        if (Daemon.currentWallet && Daemon.currentWallet.isAddressMine(a)) {
            addrError = qsTr('This address is one of yours: the money would stay in this wallet.')
            return
        }
        addrError = ''
        address = a
    }

    readonly property bool canSave: !busy && nameField.text.trim() !== '' && address !== ''
                                    && addrError === '' && Share.canSave(percent, maxP)

    Connections {
        target: page.bal
        function onDone(op, result) {
            if (op === 'heirSave' || op === 'heirDelete') app.stack.pop()
        }
        function onFailed(op, code, message) {
            if (op !== 'heirSave' && op !== 'heirDelete') return
            if (code === 'busy') return
            page.error = top.failText(code, message)
        }
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
        // the page must not steal the finger from the slider
        interactive: !slider.pressed && contentHeight > height + 1
        clip: true

        ColumnLayout {
            id: col
            x: S.margin
            width: flick.width - 2 * S.margin
            spacing: 10

            EhHeirTop {
                id: top
                stepNow: 1
            }

            EhBackLink { onClicked: app.stack.pop() }

            EhTitle { text: page.oldName !== '' ? page.oldName : qsTr('New person') }

            EhCaption { text: qsTr('Name'); Layout.topMargin: 0; Layout.bottomMargin: -4 }
            // the field: paper, wine border while writing
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 63
                Rectangle {      // hard shadow
                    y: 3
                    width: nameBox.width
                    height: nameBox.height
                    radius: nameBox.radius
                    color: S.edgeShadow
                }
                Rectangle {
                    id: nameBox
                    width: parent.width
                    height: 60
                    radius: 16
                    color: S.paper
                    border.width: nameField.activeFocus ? 2.5 : 1.5
                    border.color: nameField.activeFocus ? S.wine : S.edge
                    TextField {
                        id: nameField
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        text: page.oldName
                        topPadding: 0
                        bottomPadding: 0
                        leftPadding: 0
                        rightPadding: 0
                        verticalAlignment: TextInput.AlignVCenter
                        background: null
                        color: S.ink
                        font.family: BodyFont ? BodyFont : font.family
                        font.pixelSize: app.ehFsText
                        font.bold: true
                        maximumLength: 24
                        inputMethodHints: Qt.ImhNoPredictiveText
                        onTextChanged: page.error = ''
                    }
                }
            }

            EhCaption { text: qsTr('Their bitcoin address'); Layout.topMargin: 6; Layout.bottomMargin: -4 }
            EhSheet {
                topPadding: 10
                bottomPadding: 12
                Label {
                    id: addrL
                    visible: page.address !== ''
                    Layout.fillWidth: true
                    Layout.bottomMargin: 10
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.RichText
                    text: app.ehAddressRich(page.address, S.wineDark, S.highlight,
                                            Math.max(1, Math.floor((col.width - 24 + aFm.averageCharacterWidth) / (aFm.averageCharacterWidth * 5))))
                    font.family: FixedFont
                    font.bold: true
                    font.pixelSize: app.ehFsText
                    lineHeight: 1.3
                    color: S.ink
                    FontMetrics { id: aFm; font: addrL.font }
                }
                EhDotLine {
                    visible: page.address !== ''
                    Layout.fillWidth: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: page.address !== '' ? 12 : 2
                    spacing: 10
                    EhStitchButton {
                        Layout.preferredWidth: 1
                        kind: 'paper'
                        compact: true
                        // the QR icon of the preview, in wine
                        icon: 'data:image/svg+xml;base64,' + Qt.btoa('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="#5e1a33" stroke-width="2" stroke-linejoin="round"><rect x="3.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.5"/></g><g fill="#5e1a33"><rect x="13.5" y="13.5" width="3" height="3" rx=".6"/><rect x="18" y="13.5" width="2.5" height="2.5" rx=".6"/><rect x="13.5" y="18" width="2.5" height="2.5" rx=".6"/><rect x="17.5" y="17.5" width="3" height="3" rx=".6"/></g></svg>')
                        text: qsTr('Read QR')
                        enabled: !page.busy
                        onClicked: {
                            var d = app.scanDialog.createObject(app, {})
                            d.onFoundText.connect(function(data) {
                                AppController.haptic()
                                page.useAddress(data)
                                d.close()
                            })
                            d.open()
                        }
                    }
                    EhStitchButton {
                        id: pasteBtn
                        Layout.preferredWidth: 1
                        kind: 'paper'
                        compact: true
                        icon: 'eh_paste.svg'
                        text: qsTr('Paste')
                        enabled: !page.busy
                        onClicked: page.useAddress(AppController.clipboardToText())
                    }
                }
            }
            EhInfoBox {
                visible: page.addrError !== ''
                kind: 'danger'
                text: page.addrError
            }
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                Layout.topMargin: -2
                wrapMode: Text.WordWrap
                text: qsTr('You find it in their wallet, under "Receive".')
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: app.ehFsText
            }

            EhCaption {
                text: qsTr('How much they receive')
                tail: qsTr('· tap the pen to write it')   // owner 18/11: the phone font has no ✎
                Layout.topMargin: 6
                Layout.bottomMargin: -4
            }
            EhSheet {
                id: shareSheet
                topPadding: 10
                bottomPadding: 10
                spacing: 0
                // the number (pen: tap to write it) and, on the right, what remains
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item {
                        id: numBox
                        Layout.preferredWidth: 138
                        Layout.preferredHeight: 57
                        opacity: page.nothingLeft ? 0.55 : 1
                        Rectangle {      // hard shadow
                            y: 3
                            width: numFace.width
                            height: numFace.height
                            radius: numFace.radius
                            color: S.edgeShadow
                        }
                        Rectangle {
                            id: numFace
                            width: parent.width
                            height: 54
                            radius: 14
                            color: page.tooHigh ? S.dangerBg : (numTap.pressed ? S.sand : 'white')
                            border.width: page.padOpen || page.tooHigh ? 2.5 : 2
                            border.color: page.tooHigh ? S.red : S.wine
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 10
                                spacing: 6
                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: 8
                                    color: '#f3e4c4'
                                    Image {
                                        anchors.centerIn: parent
                                        source: Qt.resolvedUrl('../../icons/eh_pen_wine.svg')
                                        sourceSize.width: 20
                                        sourceSize.height: 20
                                    }
                                }
                                Label {
                                    id: numLabel
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignRight
                                    text: (page.padOpen && page.typed !== '' ? page.typed : page.percent) + '%'
                                    color: page.tooHigh ? S.red : S.wineDark
                                    font.family: SerifFont ? SerifFont : font.family
                                    font.weight: Font.ExtraBold
                                    font.pixelSize: app.ehFsBox
                                    fontSizeMode: Text.HorizontalFit
                                    minimumPixelSize: 18
                                }
                            }
                        }
                        TapHandler { id: numTap; onTapped: page.togglePad() }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 0
                        Label {
                            Layout.alignment: Qt.AlignRight
                            text: qsTr('Remaining')
                            color: S.muted
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: app.ehFsText
                        }
                        Label {
                            Layout.alignment: Qt.AlignRight
                            text: Share.remaining(page.maxP, page.percent) + '%'
                            color: S.oliveInk
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: app.ehFsStrong
                            font.bold: true
                        }
                    }
                }
                // 0-100 in steps of 5; the part of the others is grey and cannot be reached
                Slider {
                    id: slider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    Layout.topMargin: 4
                    from: 0
                    to: 100
                    stepSize: Share.STEP
                    snapMode: Slider.SnapAlways
                    touchDragThreshold: 2
                    enabled: !page.nothingLeft && !page.busy
                    readonly property real knob: 44
                    onMoved: {
                        var v = Share.snap(value, page.maxP)
                        if (value !== v) value = v
                        page.padOpen = false
                        page.typed = ''
                        page.error = ''
                        page.percent = v
                    }
                    onPressedChanged: if (!pressed) value = Math.min(page.percent, page.maxP)
                    background: Item {
                        x: slider.leftPadding + slider.knob / 2
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        width: slider.availableWidth - slider.knob
                        height: 12
                        Rectangle {      // the sand track
                            anchors.fill: parent
                            radius: 6
                            color: S.sand
                            border.width: 1
                            border.color: S.edge
                        }
                        Rectangle {      // this heir: olive
                            visible: !page.nothingLeft
                            width: Math.max(0, Math.min(parent.width, parent.width * slider.visualPosition))
                            height: parent.height
                            radius: 6
                            color: S.olive
                        }
                        Rectangle {      // the others: grey, not reachable
                            x: parent.width * page.maxP / 100
                            width: parent.width - x
                            height: parent.height
                            radius: 6
                            color: '#cfc4b2'
                            border.width: 1
                            border.color: '#b9ad99'
                        }
                    }
                    // the brass knob of the app's sliders (fee slider), grey when nothing is left
                    handle: Rectangle {
                        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        width: slider.knob
                        height: slider.knob
                        radius: slider.knob / 2
                        border.width: 2
                        border.color: slider.enabled ? S.brassRing : S.offEdge
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: slider.enabled ? S.brassLight : '#f2eee6' }
                            GradientStop { position: 0.55; color: slider.enabled ? S.brass : S.offBg }
                            GradientStop { position: 1.0; color: slider.enabled ? S.brassDark : '#cfc8bb' }
                        }
                    }
                }
                // 0% 25% 50% 75% 100% under the track
                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: -8
                    Layout.preferredHeight: 18
                    Repeater {
                        model: [0, 25, 50, 75, 100]
                        delegate: Label {
                            required property int modelData
                            readonly property real c: slider.leftPadding + slider.knob / 2
                                                      + (slider.availableWidth - slider.knob) * modelData / 100
                            x: Math.max(0, Math.min(parent.width - width, c - width / 2))
                            text: modelData + '%'
                            color: S.muted
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: app.ehFsSmall
                        }
                    }
                }
                Label {
                    id: shareNote
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    readonly property bool bad: page.nothingLeft || page.tooHigh
                    text: page.nothingLeft
                          ? qsTr("%1: the other heirs already have 100%. Go back and lower someone's share.")
                                .arg('<b>' + qsTr('Nothing is left') + '</b>')
                          : page.tooHigh
                            ? qsTr('At most %1: the other heirs already have %2.')
                                .arg('<b>' + page.maxP + '%</b>').arg(page.others + '%')
                            : page.others <= 0
                              ? qsTr('This is the first heir: they can have up to 100%.')
                              : qsTr('The other heirs already have %1: this one can get at most %2.')
                                  .arg('<b>' + page.others + '%</b>').arg('<b>' + page.maxP + '%</b>')
                    color: bad ? S.wine : S.muted
                    font.family: BodyFont ? BodyFont : font.family
                    font.pixelSize: app.ehFsText
                    font.bold: bad
                }
            }
            // the keypad of the app (as the fee sheet): a whole number 1-100
            GridLayout {
                id: pad
                visible: page.padOpen
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 8
                columnSpacing: 8
                Repeater {
                    model: ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'ok', '0', 'del']
                    delegate: EhKey {
                        required property string modelData
                        implicitHeight: 52
                        text: modelData === 'ok' ? '✓' : modelData
                        letter: modelData === 'ok'
                        fontSize: modelData === 'ok' ? app.ehFsBox : app.ehFsTitle
                        isDelete: modelData === 'del'
                        onActivated: page.press(modelData)
                    }
                }
            }

            EhInfoBox {
                visible: page.error !== ''
                kind: 'danger'
                text: page.error
            }
            EhStitchButton {
                visible: page.oldName !== ''
                Layout.topMargin: 6
                kind: 'paper'
                icon: 'eh_cross.svg'
                text: qsTr('Remove this person')
                enabled: !page.busy
                onClicked: { page.error = ''; page.bal.heirDelete(page.oldName) }
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

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: -S.margin
            Layout.rightMargin: -S.margin
            Layout.preferredHeight: 1.5
            color: S.edge
        }
        EhStitchButton {
            Layout.bottomMargin: 6
            kind: 'olive'
            icon: 'eh_check_white.svg'
            text: qsTr('Save')
            enabled: page.canSave
            onClicked: {
                if (page.nameTaken(nameField.text)) {
                    page.error = qsTr('There is already a person with this name.')
                    return
                }
                page.error = ''
                page.bal.heirSave(page.oldName, nameField.text.trim(), page.address, page.percent)
            }
        }
    }

    Bitcoin { id: bitcoin }
}
