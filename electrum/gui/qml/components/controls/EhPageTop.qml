// Easy Heirs (schèi): top of a wizard page in the "Colline del vino" style:
// thin hills band, step label ("PASSO 1 DI 3") and the page title.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ColumnLayout {
    id: root
    property string step
    property string title
    property var steps: []        // steps bar over the hills (EhStepsBar), empty = none
    property int stepNow: 1
    property bool stepsBack: true
    signal stepClicked(int n)

    Layout.fillWidth: true
    spacing: 2

    EhHills {
        band: true
        Layout.fillWidth: true
        Layout.preferredHeight: (root.steps.length > 0 ? 92 : 62) + app.statusBarHeight
        showSun: root.steps.length === 0
        // T2/T5: fixed small sun right under the status bar (it was sized and placed
        // as a share of the band, so with a tall status bar it covered the battery)
        sunSize: 40
        sunTop: app.statusBarHeight + 6
        sunRight: 38
        Layout.leftMargin: -22
        Layout.rightMargin: -22
        EhStepsBar {
            visible: root.steps.length > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 26
            anchors.rightMargin: 26
            y: app.statusBarHeight + 6
            steps: root.steps
            current: root.stepNow
            allowBack: root.stepsBack
            onStepClicked: (n) => root.stepClicked(n)
        }
    }

    Label {
        visible: root.step !== ''
        Layout.fillWidth: true
        Layout.topMargin: 4
        text: root.step
        color: '#45541f'
        font.pixelSize: 15
        font.bold: true
        font.letterSpacing: 0.5
    }

    Label {
        visible: root.title !== ''
        Layout.fillWidth: true
        text: root.title
        color: '#3f0f21'
        font.family: TitleFont ? TitleFont : font.family
        font.weight: Font.Black
        font.pixelSize: 32
        wrapMode: Text.WordWrap
    }
}
