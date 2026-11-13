// Easy Heirs (schèi): shows our pages (coins list, crucible, coin detail…) ABOVE a dialog, e.g.
// from the coin choice of a payment. It has its own StackView; while it is open app.ehPush /
// app.ehPop act on it, so the pages work the same here and on the main stack.
import QtQuick
import QtQuick.Controls

import "controls"
import "controls/EhStyle.js" as S

ElDialog {
    id: dlg
    property url page
    property var props: ({})

    width: parent.width
    height: parent.height
    padding: 0
    topPadding: 0
    header: null
    needsSystemBarPadding: false
    background: Rectangle { color: S.parch }

    StackView {
        id: sv
        anchors.fill: parent
        Component.onCompleted: sv.push(dlg.page, dlg.props)
    }
    onOpened: { app._ehStackOverride = sv; app._ehStackDialog = dlg }
    onClosed: {
        if (app._ehStackOverride === sv) { app._ehStackOverride = null; app._ehStackDialog = null }
    }
}
