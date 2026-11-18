// Easy Heirs (schȅi): the letter keyboard for the SEED words, used by the restore page
// (wizard/WCEasyHaveSeed.qml) and by "Forgot the PIN?" (EhForgotPinDialog.qml).
// QWERTY like the phone keyboard (owner 17/11, before: alphabetical, 7 keys per row):
// 10 / 9 / 7 keys + delete (a long press on delete clears everything).
// Keys with the EhKey look (paper, hard shadow, letter Lexend bold), 48 high (with the shadow).
import QtQuick
import QtQuick.Controls

import "EhStyle.js" as S

Rectangle {
    id: kbd

    signal letter(string ch)
    signal deleteOne()
    signal deleteAll()

    readonly property var rows: ['qwertyuiop', 'asdfghjkl', 'zxcvbnm']
    readonly property real gap: 4
    readonly property real keyW: Math.floor((width - 8 - 9 * gap) / 10)
    readonly property real keyH: 48

    implicitHeight: rows.length * keyH + (rows.length - 1) * 6 + 12
    radius: 16
    color: S.sand

    Column {
        anchors.centerIn: parent
        spacing: 6
        Repeater {
            model: kbd.rows
            delegate: Row {
                id: krow
                required property string modelData
                required property int index
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: kbd.gap
                Repeater {
                    model: krow.modelData.split('')
                    delegate: EhKey {
                        id: kk
                        required property string modelData
                        width: kbd.keyW
                        height: kbd.keyH
                        letter: true
                        fontSize: app.ehFsStrong
                        keyRadius: 10
                        text: kk.modelData
                        onActivated: kbd.letter(kk.modelData)
                    }
                }
                // delete key at the end of the last row, two keys wide
                Item {
                    visible: krow.index === kbd.rows.length - 1
                    width: 2 * kbd.keyW + kbd.gap
                    height: kbd.keyH
                    Rectangle { visible: !bt.pressed; y: 3; width: parent.width; height: parent.height - 3; radius: 10; color: S.edgeShadow }
                    Rectangle {
                        id: delFace
                        y: bt.pressed ? 2 : 0
                        width: parent.width
                        height: parent.height - 3
                        radius: 10
                        color: bt.pressed ? Qt.darker(S.sandDel, 1.08) : S.sandDel
                        border.width: 1.5
                        border.color: S.edge
                        EhBackspaceIcon { anchors.centerIn: parent; width: 38; height: 27; ink: S.wine; fill: delFace.color }
                    }
                    TapHandler { id: bt; onTapped: kbd.deleteOne(); onLongPressed: kbd.deleteAll() }
                }
            }
        }
    }
}
