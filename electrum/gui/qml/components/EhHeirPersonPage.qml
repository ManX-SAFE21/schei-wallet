// Easy Heirs (schȅi): inheritance wizard, screen 3 "New person" (still step 1 of 4).
// Name, bitcoin address (QR or paste, never typed) and the share: 25 / 40 / 50 % or another
// number 1-100 (the default is what is left to reach 100). Save = bal.heirSave(); when an
// existing heir is opened (oldName set) also "Remove this person" = bal.heirDelete().
// "Bottega" look as the preview anteprima/eredita-semplice.html, screen 3.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"
import "controls/EhStyle.js" as S

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
    readonly property var st: bal ? bal.state : ({})
    readonly property bool busy: bal ? bal.busy : false
    readonly property var fixed: [25, 40, 50]

    property string address: oldAddress
    property string addrError: ''
    property string error: ''
    property int percent: 0
    property bool other: false
    // an error appears at the bottom of the page: scroll so that it is in view
    // (after the layout has placed the error box)
    onErrorChanged: if (error !== '') errorScroll.restart()
    Timer {
        id: errorScroll
        interval: 80
        onTriggered: flick.contentY = Math.max(0, flick.contentHeight - flick.height)
    }

    Rectangle { anchors.fill: parent; color: S.parch }

    // what the others already have: the default share is what is left to reach 100
    function othersTotal() {
        var h = (st && st.heirs) ? st.heirs : []
        var t = 0
        for (var i = 0; i < h.length; i++) if (h[i].name !== oldName) t += h[i].percent
        return t
    }
    Component.onCompleted: {
        var p = oldName !== '' ? oldPercent : Math.max(0, 100 - othersTotal())
        percent = p
        other = fixed.indexOf(p) < 0
        if (other && p > 0) otherField.text = '' + p
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
                                    && addrError === '' && percent >= 1 && percent <= 100

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
        interactive: contentHeight > height + 1
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
                        font.pixelSize: 18
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
                    font.pixelSize: 16
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
                font.pixelSize: 15
            }

            EhCaption { text: qsTr('How much they receive'); Layout.topMargin: 6; Layout.bottomMargin: -4 }
            EhSegmented {
                model: ['25%', '40%', '50%', qsTr('Other')]
                currentIndex: page.other ? 3 : page.fixed.indexOf(page.percent)
                onActivated: (i) => {
                    page.error = ''
                    if (i === 3) {
                        page.other = true
                        var n = parseInt(otherField.text)
                        page.percent = isNaN(n) ? 0 : n
                        otherField.forceActiveFocus()
                    } else {
                        page.other = false
                        page.percent = page.fixed[i]
                    }
                }
            }
            // "Other": a number 1-100
            Item {
                visible: page.other
                Layout.fillWidth: true
                Layout.preferredHeight: 63
                Rectangle {
                    y: 3
                    width: otherBox.width
                    height: otherBox.height
                    radius: otherBox.radius
                    color: S.edgeShadow
                }
                Rectangle {
                    id: otherBox
                    width: parent.width
                    height: 60
                    radius: 16
                    color: S.paper
                    border.width: otherField.activeFocus ? 2.5 : 1.5
                    border.color: otherField.activeFocus ? S.wine : S.edge
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 6
                        TextField {
                            id: otherField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            topPadding: 0
                            bottomPadding: 0
                            leftPadding: 0
                            rightPadding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignRight
                            background: null
                            color: S.ink
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 18
                            font.bold: true
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator { bottom: 1; top: 100 }
                            maximumLength: 3
                            onTextChanged: {
                                var n = parseInt(text)
                                page.percent = isNaN(n) ? 0 : n
                                page.error = ''
                            }
                        }
                        Label {
                            text: '%'
                            color: S.ink
                            font.family: BodyFont ? BodyFont : font.family
                            font.pixelSize: 18
                            font.bold: true
                        }
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
        anchors.bottomMargin: app.navigationBarHeight
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
                font.pixelSize: 16
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
