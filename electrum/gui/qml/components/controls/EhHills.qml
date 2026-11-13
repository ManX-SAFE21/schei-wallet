// Easy Heirs (schèi): hills background with the gold Bitcoin sun.
// The hills stretch to any width; the sun is drawn on top so it stays round.
// band: true = thin strip used at the top of pages, false = big landscape.
import QtQuick

Item {
    id: root
    property bool band: false
    property bool fade: true      // "luce colorata": the hills melt into the page
    property real sunSize: -1     // >0: fixed sun size (home: small sun next to the logo)
    property real sunTop: -1      // >=0: sun top edge
    property real sunRight: 16    // gap between the sun and the right edge, with sunSize
    property bool showSun: true   // pages with the steps bar: no sun behind the last step
    property string art: ''       // other drawing (home "Bottega": eh_hills_bottega.svg)
    property bool rays: false     // home "Bottega": gold rays behind the sun
    property color fadeColor: '#faf7ef'
    // "Bottega" page band (WP1): the drawing starts topInset px down (so it keeps its own
    // proportions under any status bar); above it the same sky colour
    property real topInset: 0
    property color skyColor: '#f8eed6'
    // big landscape (no sunTop given): the sun never goes up under the status bar / test band
    readonly property real _safeTop: (typeof app !== 'undefined' && app) ? app.statusBarHeight + 4 : 0

    Rectangle {
        visible: root.topInset > 0
        width: parent.width
        height: root.topInset + 1
        color: root.skyColor
    }

    Image {
        anchors.fill: parent
        anchors.topMargin: root.topInset
        source: Qt.resolvedUrl(root.art !== '' ? '../../../icons/' + root.art
                               : (root.band ? '../../../icons/eh_band.svg' : '../../../icons/eh_hills.svg'))
        sourceSize.width: 1080
        fillMode: Image.Stretch
    }

    Image {
        // home "Bottega": thin gold rays round the sun
        visible: root.showSun && root.rays
        width: sunImg.d * 2.7
        height: width
        x: sunImg.cx - width / 2
        y: sunImg.cy - height / 2
        source: Qt.resolvedUrl('../../../icons/eh_sun_rays.svg')
        sourceSize.width: 256
        sourceSize.height: 256
    }

    Image {
        id: sunImg
        // same place as the sun in the original drawings (viewBox 340x250 / 340x74)
        readonly property real d: root.sunSize > 0 ? root.sunSize : (root.band ? root.height * 0.62 : root.height * 0.5)
        readonly property real cx: root.sunSize > 0 ? root.width - root.sunRight - d / 2 : root.width * (root.band ? 290 : 250) / 340
        readonly property real cy: root.sunTop >= 0 ? root.sunTop + d / 2
                                   : Math.max(root.height * (root.band ? 26 : 78) / (root.band ? 74 : 250), root.band ? 0 : root._safeTop + d / 2)
        visible: root.showSun
        x: cx - d / 2
        y: cy - d / 2
        width: d
        height: d
        source: Qt.resolvedUrl('../../../icons/eh_sun.svg')
        sourceSize.width: 256
        sourceSize.height: 256
        smooth: true
    }

    Rectangle {
        visible: root.fade
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * (root.band ? 0.42 : 0.3)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(root.fadeColor.r, root.fadeColor.g, root.fadeColor.b, 0) }
            GradientStop { position: 1.0; color: root.fadeColor }
        }
    }
}
