import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.electrum 1.0

import "wizard"

Wizard {
    id: walletwizard

    wizardTitle: qsTr('New Wallet')

    signal walletCreated

    property string path
    // owner 17/11: create / restore with words only when allowed (first wallet, key lost, ESPERTO)
    property bool ehSeedAllowed: false

    wiz: Daemon.newWalletWizard

    Component.onCompleted: {
        var view = wiz.startWizard()
        _loadNextComponent(view)
    }

    onAccepted: {
        console.log('Finished new wallet wizard')
        wiz.createStorage(wizard_data, Daemon.singlePasswordEnabled, Daemon.singlePassword)
    }

    Connections {
        target: wiz
        function onCreateSuccess() {
            walletwizard.path = wiz.path
            walletwizard.walletCreated()
        }
        function onCreateError(error) {
            var dialog = app.messageDialog.createObject(app, {
                title: qsTr('Error'),
                iconSource: Qt.resolvedUrl('../../icons/warning.png'),
                text: error
            })
            dialog.open()
        }
    }
}

