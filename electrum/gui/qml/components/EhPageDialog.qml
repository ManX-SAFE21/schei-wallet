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
    // owner 13/11: one can open above another (e.g. a "How ... works" link inside a page that is
    // already here): closing it gives the stack back to the one below
    property var _prevStack: null
    property var _prevDialog: null
    onOpened: { _prevStack = app._ehStackOverride; _prevDialog = app._ehStackDialog; app._ehStackOverride = sv; app._ehStackDialog = dlg }
    onClosed: {
        if (app._ehStackOverride === sv) { app._ehStackOverride = _prevStack; app._ehStackDialog = _prevDialog }
    }
}
