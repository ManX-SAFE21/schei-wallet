// Easy Heirs (schèi): top of a page: thin hills band, step label ("PASSO 1 DI 3") and the
// page title. "Bottega" (WP1): the band is the home's B landscape (olive hills, wine bell
// tower, cypresses, bitcoin sun with gold rays) ending in the parchment; the title is
// Fraunces 30 wine with the double gold rule under it (titleColor: S.oliveInk on Receive).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "EhStyle.js" as S

ColumnLayout {
    id: root
    property string step
    property string title
    property color titleColor: S.wine
    property var steps: []        // steps bar over the hills (EhStepsBar), empty = none
    property int stepNow: 1
    property bool stepsBack: true
    signal stepClicked(int n)

    Layout.fillWidth: true
    spacing: 2

    EhHills {
        band: true
        fade: false                // the drawing itself ends in the parchment
        // the drawing (393 x 86) keeps its proportions under any status bar: the 24 px of sky
        // it has above the hills stay, the rest of the status bar is plain sky
        topInset: Math.max(0, app.statusBarHeight - 24)
        Layout.fillWidth: true
        Layout.preferredHeight: (root.steps.length > 0 ? 92 : 62) + app.statusBarHeight
        showSun: root.steps.length === 0
        rays: true
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
        Layout.topMargin: 6
        text: root.step
        color: S.olive
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 16
        font.bold: true
        font.letterSpacing: 0.5
        wrapMode: Text.WordWrap
    }

    EhTitle {
        visible: root.title !== ''
        text: root.title
        color: root.titleColor
    }
}
