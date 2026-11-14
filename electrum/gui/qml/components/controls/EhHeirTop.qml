// Easy Heirs (schȅi): top of the inheritance wizard pages (screens 2-5): the hills band with
// the 4 steps Who / When / Check / Done (icons eh_st_people, eh_st_cal, eh_st_eye, eh_st_flag).
// It also gives the pages the words for the bridge's step and failure codes, so the 4 pages
// say them the same way.
//   EhHeirTop { stepNow: 2; onStepClicked: (n) => ... }
//   Label { text: top.stepText(bal.step) }      EhInfoBox { text: top.failText(code, message) }
import QtQuick
import QtQuick.Layouts

EhPageTop {
    id: root
    title: ''
    steps: [
        { icon: 'people', word: qsTr('Who'), title: qsTr('Who'), text: qsTr('Who receives?') },
        { icon: 'cal', word: qsTr('When'), title: qsTr('When'), text: qsTr('In how long?') },
        { icon: 'eye', word: qsTr('Check'), title: qsTr('Check'), text: qsTr('All right?') },
        { icon: 'flag', word: qsTr('Done'), title: qsTr('Done'), text: qsTr('If you no longer answer, on the date the heirs receive.') }
    ]

    // what the bridge is doing now (bal.step), '' = nothing to say
    function stepText(step) {
        switch (step) {
        case 'ping':
        case 'check':
            return qsTr('I ask the keepers…')
        case 'prepare':
        case 'wait':
            return qsTr('I prepare the envelope…')
        case 'sign':
            return qsTr('I sign…')
        case 'send':
            return qsTr('I send it to the keepers…')
        case 'invalidate':
        case 'broadcast':
            return qsTr('I cancel the old envelope…')
        }
        return ''
    }

    // a failed(op, code, message) of the bridge, in the app's words
    function failText(code, message) {
        switch (code) {
        case 'offline':
            return qsTr('Internet is needed for the inheritance. Try again when you are connected.')
        case 'custodians':
            return qsTr('No keeper answered. Your money is safe; try again later.')
        case 'percent':
            return qsTr('The total must be 100%.')
        case 'address':
            return qsTr('This is not a bitcoin address.')
        case 'not_synced':
            return qsTr('Schȅi is still updating. Try again in a little while.')
        case 'no_heirs':
            return qsTr('First add at least one person.')
        case 'needs_renew':
            return qsTr('First the inheritance must be renewed.')
        case 'not_sent':
            return qsTr('The envelope is ready but no keeper took it. Try again in a little while.')
        case 'internal':
            return qsTr('Something did not work. Your money is safe; try again later.')
        }
        return message || code
    }
}
