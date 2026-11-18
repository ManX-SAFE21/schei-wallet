// Easy Heirs (schȅi), owner Q7 (16/11): the rules of «Quanto riceve» (EhHeirPersonPage) and of
// the summary «Chi riceve?» (EhHeirWhoPage), apart so that tests can run them (tests/qml).
//  - the slider goes 0-100 % in steps of 5; the part of the OTHER heirs is grey and not reachable:
//    max = 100 - others (editing an heir, its own old share is free again)
//  - a number typed by hand (1-100, also 33) is kept; above the max Save is off
//  - a new heir starts from what is left (the last one is already right: 33 + 33 -> 34);
//    the first heir (nothing given yet) starts from 0; editing keeps the heir's value
.pragma library

var STEP = 5

// what the OTHER heirs have (the one being changed, oldName, does not count)
function othersTotal(heirs, oldName) {
    var t = 0
    var h = heirs || []
    for (var i = 0; i < h.length; i++)
        if (h[i].name !== oldName) t += Number(h[i].percent) || 0
    return t
}

// the most this heir can have (0 = nothing left)
function maxFor(others) {
    return Math.max(0, Math.min(100, 100 - others))
}

// the starting value: editing keeps the heir's share; a new heir gets what is left,
// the first one (nothing given yet) 0
function startFor(editing, oldPercent, others) {
    if (editing) return oldPercent
    if (others <= 0) return 0
    return maxFor(others)
}

// where the slider stops when moved: a step of 5, never over the max
function snap(value, max) {
    var v = Math.round(value / STEP) * STEP
    return Math.max(0, Math.min(max, v))
}

// what remains after this heir (never below 0)
function remaining(max, percent) {
    return Math.max(0, max - percent)
}

// Save: at least 1 % and not over the max
function canSave(percent, max) {
    return percent >= 1 && percent <= max
}

// the keypad: the typed text after key k ('0'-'9' or 'del'); a whole number 0-100
function press(typed, k) {
    var t = typed || ''
    if (k === 'del') return t.slice(0, -1)
    if (k < '0' || k > '9' || k.length !== 1) return t
    if (t === '0') t = ''
    var n = t + k
    if (Number(n) > 100) return t
    return n
}

// the number of a typed text (0 when empty)
function typedValue(typed) {
    var n = parseInt(typed, 10)
    return isNaN(n) ? 0 : n
}

// the summary: 'ok' (100), 'missing' (less: total + missing), 'over' (more, old data)
function summaryKind(total) {
    return total === 100 ? 'ok' : (total < 100 ? 'missing' : 'over')
}
