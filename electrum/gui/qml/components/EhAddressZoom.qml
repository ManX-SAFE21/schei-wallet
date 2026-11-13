// Easy Heirs (schèi): the address in big letters: first 4 (after bc1q) and
// last 4, spaced, to read them aloud and compare with the other person.
// "Bottega": parchment page, the two groups on paper tiles, the whole address on a sheet.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

ElDialog {
    id: dialog
    Material.theme: Material.Light
    Material.foreground: S.ink
    font.family: BodyFont ? BodyFont : Qt.application.font.family

    property string address
    property bool mine: false     // true in Receive (my own address)

    readonly property var parts: app.ehAddressParts(address)

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    background: Rectangle { color: S.parch }

    function spaced(s) { return s.split('').join(' ') }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight
        contentHeight: Math.max(height, col.implicitHeight + 16)
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height + 1
        clip: true

    ColumnLayout {
        id: col
        x: S.margin
        width: flick.width - 2 * S.margin
        height: Math.max(flick.height - 16, implicitHeight)
        spacing: S.gap

        EhPageTop { title: '' }

        EhTitle {
            Layout.topMargin: -2
            text: qsTr('Check the address')
        }

        Repeater {
            model: [
                { k: qsTr('Starts with (after %1)').arg(dialog.parts.prefix), v: dialog.parts.first },
                { k: qsTr('Ends with'), v: dialog.parts.last }
            ]
            delegate: Item {
                id: tile
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: tcol.implicitHeight + 20 + 3
                // hard shadow + paper tile with a 2 px edge
                Rectangle { y: 3; width: parent.width; height: parent.height - 3; radius: 18; color: S.edgeShadow }
                Rectangle {
                    width: parent.width
                    height: parent.height - 3
                    radius: 18
                    color: S.paper
                    border.width: 2
                    border.color: S.edge
                    ColumnLayout {
                        id: tcol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        anchors.leftMargin: 14
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: tile.modelData.k
                            font.pixelSize: 16
                            font.bold: true
                            color: S.muted
                        }
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: dialog.spaced(tile.modelData.v)
                            font.family: FixedFont
                            font.bold: true
                            font.pixelSize: 46
                            color: S.wineDark
                        }
                    }
                }
            }
        }

        EhSheet {
            topPadding: 10
            bottomPadding: 10
            Label {
                id: full
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                text: app.ehAddressRich(dialog.address, S.wineDark, S.highlight)
                font.family: FixedFont
                font.bold: true
                font.pixelSize: 19
                lineHeight: 1.3
                color: S.ink
            }
        }

        EhInfoBox {
            kind: 'warn'
            text: dialog.mine
                  ? qsTr('<b>Read them aloud</b> to the person sending you bitcoin, letter by letter.')
                  : qsTr('<b>Read them aloud</b> to the person receiving, letter by letter: they must be the same as theirs.')
        }

        Item { Layout.fillHeight: true }

        EhStitchButton {
            kind: 'wine'
            text: qsTr('Close')
            icon: 'eh_check_white.svg'
            onClicked: dialog.doClose()
        }
    }
    }
}
