// Easy Heirs (schȅi): banknotes and coins of the currencies that have them in the app
// (owner 12/11: euro and US dollar). Values in cents; real sizes in millimetres.
.pragma library

var TABLE = {
    'EUR': {
        notes: [10000, 5000, 2000, 1000, 500],
        coins: [200, 100, 50, 20, 10, 5, 1],          // owner: no 2 cent coin
        noteMm: { 10000: [147, 82], 5000: [140, 77], 2000: [133, 72], 1000: [127, 67], 500: [120, 62] },
        coinMm: { 200: 25.75, 100: 23.25, 50: 24.25, 20: 22.25, 10: 19.75, 5: 21.25, 1: 16.25 }
    },
    'USD': {
        notes: [10000, 5000, 2000, 1000, 500, 100],
        coins: [25, 10, 5, 1],
        noteMm: { 10000: [156, 66], 5000: [156, 66], 2000: [156, 66], 1000: [156, 66], 500: [156, 66], 100: [156, 66] },
        coinMm: { 25: 24.26, 10: 17.91, 5: 21.21, 1: 19.05 }
    }
}

function hasCash(ccy) { return TABLE[ccy] !== undefined }
function table(ccy) { return TABLE[ccy] || TABLE['EUR'] }
function isNote(ccy, c) { return table(ccy).notes.indexOf(c) >= 0 }
function maxNoteW(ccy) { var t = table(ccy), m = 0; for (var k in t.noteMm) m = Math.max(m, t.noteMm[k][0]); return m }
function maxNoteH(ccy) { var t = table(ccy), m = 0; for (var k in t.noteMm) m = Math.max(m, t.noteMm[k][1]); return m }
function maxCoinMm(ccy) { var t = table(ccy), m = 0; for (var k in t.coinMm) m = Math.max(m, t.coinMm[k]); return m }
