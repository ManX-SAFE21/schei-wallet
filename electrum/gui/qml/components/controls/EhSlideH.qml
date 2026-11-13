// Easy Heirs (schèi): horizontal slide with the bitcoin coin (T24, owner 2026-11-11).
// Push the coin to the right end: it stays there, locked, for lockSeconds and
// waits for the other slide; if nothing happens it goes back by itself.
// Two of them confirm a payment: together with two fingers, or one at a time.
// "Bottega" (WP1): wine leather with gold stitching, a dark slot inside, the coin with a brass
// rim, a dashed gold ring where it must arrive. Behaviour and timings unchanged.
import QtQuick
import QtQuick.Controls

import "EhStyle.js" as S

Item {
    id: root
    property string text: qsTr('push to the right')
    property int lockSeconds: 5
    property bool locked: false          // the coin is at the end, waiting
    property bool hold: false            // set by the page: keep it at the end (no timeout)
    signal reached
    signal released                      // went back without reaching the end / timeout

    readonly property real maxX: width - knob.width - 10
    implicitHeight: 72
    opacity: root.enabled ? 1 : 0.5

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

    // soft shadow under the leather
    Repeater {
        model: 3
        Rectangle {
            required property int index
            anchors.fill: leather
            anchors.margins: -index * 2
            anchors.topMargin: -index * 2 + 4 + index
            radius: leather.radius + index * 2
            color: S.wineDark
            opacity: 0.10 - index * 0.025
        }
    }
    // the leather
    Rectangle {
        id: leather
        anchors.fill: parent
        radius: 24
        gradient: Gradient {
            GradientStop { position: 0.0; color: S.leatherWine1 }
            GradientStop { position: 0.7; color: S.leatherWine2 }
            GradientStop { position: 1.0; color: S.leatherWine3 }
        }
    }
    EhDashedBorder {
        anchors.fill: leather
        inset: 5
        radius: 19
        lineWidth: 1.6
        color: S.stitch
    }
    // the dark slot where the coin runs
    Rectangle {
        id: slot
        anchors.fill: parent
        anchors.margins: 14
        radius: height / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: S.slot1 }
            GradientStop { position: 1.0; color: S.slot2 }
        }
        // a thin light line under it
        Rectangle {
            anchors.top: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * parent.radius
            height: 1
            color: Qt.rgba(1, 1, 1, 0.19)
        }
        // orange trail behind the coin, inside the slot
        Rectangle {
            x: 0
            height: parent.height
            width: Math.max(0, Math.min(parent.width, knob.x + knob.width / 2 - slot.x))
            radius: height / 2
            color: Qt.rgba(0.97, 0.58, 0.10, root.locked ? 0.35 : 0.25)
        }
    }
    Label {
        anchors.centerIn: slot
        anchors.horizontalCenterOffset: 22
        visible: knob.x < 20
        text: '<font color="' + S.gold + '">›››</font>&nbsp;' + root.text
        textFormat: Text.StyledText
        color: S.ivory
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 16
        font.bold: true
        elide: Text.ElideRight
        width: Math.min(implicitWidth, slot.width - 70)
    }
    // where the coin must arrive: a dashed gold ring (gold lock in it when locked)
    Item {
        anchors.right: parent.right
        anchors.rightMargin: 21          // its centre is the coin's centre at the end (maxX)
        anchors.verticalCenter: parent.verticalCenter
        width: 36; height: 36
        Rectangle {
            anchors.fill: parent
            radius: 18
            color: root.locked ? Qt.rgba(0.85, 0.70, 0.35, 0.25) : 'transparent'
        }
        EhDashedBorder {
            anchors.fill: parent
            inset: 1.25
            radius: 17
            lineWidth: 2.5
            color: S.gold
        }
        Image {
            visible: root.locked
            anchors.centerIn: parent
            source: Qt.resolvedUrl('../../../icons/eh_lock_gold.svg')
            sourceSize.width: 20; sourceSize.height: 20
        }
    }
    // the waiting time left, as a thin gold bar in the slot
    Rectangle {
        visible: root.locked && !root.hold
        anchors.bottom: slot.bottom
        anchors.bottomMargin: 3
        x: slot.x + 22
        height: 4
        radius: 2
        width: (slot.width - 44) * waitLeft.v
        color: S.gold
        QtObject { id: waitLeft; property real v: 1 }
        NumberAnimation { id: waitAnim; target: waitLeft; property: 'v'; from: 1; to: 0; duration: root.lockSeconds * 1000 }
    }

    // the coin: the same bitcoin coin as in the home, with a brass rim
    Item {
        id: knob
        x: 5
        anchors.verticalCenter: parent.verticalCenter
        width: 58; height: 58
        Rectangle {   // shadow
            x: 0; y: 3
            width: parent.width; height: parent.height
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.35)
        }
        Rectangle {   // 2 px dark ring + 4 px brass rim
            anchors.fill: parent
            radius: width / 2
            color: '#9c7a25'
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: width / 2
                color: '#e9c768'
            }
        }
        Image {
            anchors.fill: parent
            anchors.margins: 6
            source: Qt.resolvedUrl('../../../icons/eh_bitcoin_logo.svg')
            sourceSize.width: 128; sourceSize.height: 128
        }
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
