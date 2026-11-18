// Easy Heirs (schȅi), owner 17/11 (Samsung): a Canvas that paints itself again when it could have
// lost its drawing. A Canvas paints once into an image; on Android that image can be lost (app long
// in the background, the system frees memory) and Qt does not paint it again by itself: the
// stitching and the flap of a wallet vanished. Use EhCanvas instead of Canvas in Schȅi pages.
import QtQuick

Canvas {
    id: cv
    // shown again (e.g. the wallet card when you come back to that wallet)
    onVisibleChanged: if (visible) requestPaint()
    // the app is in front again
    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive)
                cv.requestPaint()
        }
    }
    // the drawing memory of the window was made again
    Connections {
        target: cv.Window.window
        ignoreUnknownSignals: true
        function onSceneGraphInitialized() { cv.requestPaint() }
    }
}
