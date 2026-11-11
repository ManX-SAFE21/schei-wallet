// Easy Heirs (schèi): horizontal slide with the bitcoin coin (T24, owner 2026-11-11).
// Push the coin to the right end: it stays there, locked, for lockSeconds and
// waits for the other slide; if nothing happens it goes back by itself.
// Two of them confirm a payment: together with two fingers, or one at a time.
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property string text: qsTr('push to the right')
    property int lockSeconds: 5
    property bool locked: false          // the coin is at the end, waiting
    property bool hold: false            // set by the page: keep it at the end (no timeout)
    signal reached
    signal released                      // went back without reaching the end / timeout

    readonly property real maxX: width - knob.width - 10
    implicitHeight: 68
    radius: height / 2
    color: 'transparent'
    border.width: 2
    border.color: root.locked ? '#e0a21a' : Qt.rgba(0.37, 0.10, 0.20, 0.18)
    opacity: root.enabled ? 1 : 0.5
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Qt.rgba(0.37, 0.10, 0.20, 0.13) }
        GradientStop { position: 1; color: Qt.rgba(0.37, 0.10, 0.20, 0.04) }
    }

    // the waiting time starts whenever the coin is locked at the end
    onLockedChanged: {
        if (root.locked) { waitAnim.restart(); lockTimer.restart() }
        else { lockTimer.stop(); waitAnim.stop() }
    }
    onHoldChanged: if (root.hold) { lockTimer.stop(); waitAnim.stop() }
    function reset() {
        lockTimer.stop()
        root.locked = false
        root.hold = false
        back.start()
    }

    // orange trail behind the coin
    Rectangle {
        x: 2; y: 2
        height: parent.height - 4
        width: knob.x + knob.width
        radius: height / 2
        color: Qt.rgba(0.97, 0.58, 0.10, root.locked ? 0.35 : 0.22)
    }
    Label {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 22
        visible: knob.x < 20
        text: '→ ' + root.text
        color: Qt.rgba(0.37, 0.10, 0.20, 0.7)
        font.pixelSize: 16
        font.bold: true
    }
    // where the coin must arrive
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        width: 52; height: 52; radius: 26
        color: root.locked ? Qt.rgba(0.88, 0.64, 0.10, 0.18) : 'transparent'
        border.width: 2.5
        border.color: root.locked ? '#e0a21a' : Qt.rgba(0.37, 0.10, 0.20, 0.3)
        Image {
            visible: root.locked
            anchors.centerIn: parent
            source: Qt.resolvedUrl('../../../icons/eh_lock.svg')
            sourceSize.width: 22; sourceSize.height: 22
        }
    }
    // the waiting time left, as a thin bar under the coin
    Rectangle {
        visible: root.locked && !root.hold
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        x: 30
        height: 4
        radius: 2
        width: (root.width - 60) * waitLeft.v
        color: '#e0a21a'
        QtObject { id: waitLeft; property real v: 1 }
        NumberAnimation { id: waitAnim; target: waitLeft; property: 'v'; from: 1; to: 0; duration: root.lockSeconds * 1000 }
    }

    // the coin: the same bitcoin coin as in the home
    Image {
        id: knob
        x: 5
        anchors.verticalCenter: parent.verticalCenter
        width: 56; height: 56
        source: Qt.resolvedUrl('../../../icons/eh_bitcoin_logo.svg')
        sourceSize.width: 128; sourceSize.height: 128
        NumberAnimation on x { id: back; to: 5; duration: 220; running: false; easing.type: Easing.OutCubic }
    }

    // review 2026-11-11: a DragHandler (pointer handler) gets its OWN touch point, so two
    // fingers can push the two slides at the same time (a MouseArea only gets one touch).
    DragHandler {
        id: drag
        target: null
        parent: knob
        margin: 14
        enabled: root.enabled && !root.locked
        yAxis.enabled: false
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        property real start: 5
        onActiveChanged: {
            if (active) {
                back.stop()
                start = knob.x
            } else if (!root.locked) {
                back.start()
                root.released()
            }
        }
        onTranslationChanged: {
            if (!active || root.locked) return
            knob.x = Math.max(5, Math.min(root.maxX, start + translation.x))
            if (knob.x >= root.maxX - 2) {
                knob.x = root.maxX
                root.locked = true
                AppController.haptic()
                root.reached()
            }
        }
    }
    // nothing more happened: the coin goes back
    Timer {
        id: lockTimer
        interval: root.lockSeconds * 1000
        onTriggered: if (!root.hold) { root.locked = false; back.start(); root.released() }
    }
}
