// Easy Heirs (schèi): the "Bottega" style tokens (anteprima/stile-bottega-piano.md, section 1).
// Parchment page, paper sheets, stitched leather buttons, brass for what you grab,
// wine = money out, olive = money in.
// Use: import "EhStyle.js" as S   (pages: "controls/EhStyle.js", wizard: "../controls/EhStyle.js")
.pragma library

// ---- colours ----
var parch = '#f4ecda'          // page background
var paper = '#fffdf6'          // sheets, cards, keys, fields, dialogs
var edge = '#d8c69a'           // sheet border, dotted separators, key border
var edgeShadow = '#e2d4b0'     // hard shadow under sheets, keys, paper buttons
var sand = '#e6d8b6'           // segmented track, pressed paper
var sandDel = '#ead9b0'        // "delete" key
var gold = '#d9b25a'           // double rule under titles, warning border
var stitch = '#e3c57e'         // dashed stitching on leather
var brassLight = '#f8e3a2'
var brass = '#d9b25a'
var brassDark = '#b58d32'
var brassRing = '#8a6a1c'      // ring round brass, empty PIN dot, lock icon, word numbers
var wine = '#5e1a33'           // titles, links, money out, focus border
var wineDark = '#3f0f21'       // big figures on paper, text on ivory
var leatherWine1 = '#6a1f3b'
var leatherWine2 = '#4a1228'
var leatherWine3 = '#3f0f21'
var olive = '#45541f'          // captions, money in, switch ON
var oliveInk = '#33400f'       // olive text and figures on paper
var leatherOlive1 = '#55662a'
var leatherOlive2 = '#3d4a1a'
var ivory = '#fbeccb'          // text on leather, warning box background
var ink = '#2a2220'            // body text
var muted = '#5a4c44'          // secondary text
var slot1 = '#2a0a16'
var slot2 = '#1d0710'
var dangerBg = '#f6dfe5'
var tipBg = '#e9eed3'
var tipEdge = '#aab877'
var highlight = '#f0d28a'      // first / last 4 letters of an address (text wineDark)
var waitInk = '#7a4a12'        // "unconfirmed"
var red = '#b3261e'            // only "blocked" and real errors
var bitcoin = '#f7931a'
var switchOff = '#a8977a'
var dim = '#80291f1f' // behind popups
// a button that cannot be used yet (owner 13/11): grey paper, grey stitching, grey text
var offBg = '#e9e5dc'
var offEdge = '#c3bbac'
var offInk = '#8f877b'

// ---- sizes ----
var margin = 16                // page side margin
var gap = 12                   // between blocks
var buttonH = 60
var buttonTallH = 68           // button with a second line
var buttonCompactH = 48        // button inside a field or a row
var keyH = 64
var fieldH = 60
var rowH = 64

// an icon given by file name ('eh_info.svg') lives in gui/icons; a full URL (Qt.resolvedUrl(...)
// made by the page, it has a ':') is used as it is. Never pass a relative path like '../../icons/x.svg'.
// The result is relative to the controls folder: pass it to Qt.resolvedUrl() in a control.
function iconPath(name) {
    if (!name) return ''
    var s = '' + name
    return s.indexOf(':') >= 0 ? s : '../../../icons/' + s
}
