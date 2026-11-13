import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import "controls"
import "controls/EhStyle.js" as S

// Easy Heirs (schèi): information: logo, version, "few schei" note,
// credit to Electrum (MIT licence, as the licence requires).
// Look: "Bottega" (paper sheets, warn box, stitched paper buttons for the links).
Item {
    id: page
    property bool ehHideHeader: true
    Material.theme: Material.Light
    Material.foreground: S.ink
    Rectangle { anchors.fill: parent; color: S.parch }

    // a paragraph of a sheet
    component Para: Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.StyledText
        color: S.ink
        font.family: BodyFont ? BodyFont : font.family
        font.pixelSize: 16
        lineHeight: 1.1
    }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: app.navigationBarHeight  // T9
        contentHeight: col.implicitHeight + 30
        clip: true
        ColumnLayout {
            id: col
            width: parent.width - 32
            x: 16
            spacing: 12
            EhPageTop { title: ''; Layout.leftMargin: 6; Layout.rightMargin: 6 }
            EhBackLink { text: '‹ ' + qsTr('Settings'); Layout.topMargin: -18; onClicked: app.stack.pop() }
            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 170
                Layout.preferredHeight: 170 * 345 / 756
                source: Qt.resolvedUrl('../../icons/eh_logo_wine.png')
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: 'Bitcoin Wallet · ' + qsTr('version %1').arg('1.0') + ' (Electrum ' + BUILD.electrum_version + ')'
                color: S.muted
                font.family: BodyFont ? BodyFont : font.family
                font.pixelSize: 16
            }
            EhInfoBox {
                kind: 'warn'
                icon: 'eh_wallet.svg'
                text: '<b>' + qsTr('Schèi is like the wallet in your pocket:') + '</b> ' + qsTr('keep only a few schei in it, the ones for spending. It is not a safe: for big savings use a safer system.')
            }
            EhSheet {
                topPadding: 12
                bottomPadding: 12
                spacing: 8
                Para {
                    text: '<b>' + qsTr('Based on Electrum') + '</b>, ' + qsTr('the open source Bitcoin wallet created by Thomas Voegtlin and the Electrum developers.')
                }
                EhDotLine {}
                Para {
                    color: S.muted
                    text: qsTr('MIT licence') + ' · Copyright © 2011-2024 The Electrum developers, Thomas Voegtlin.'
                }
            }
            EhSheet {
                topPadding: 12
                bottomPadding: 12
                Para {
                    text: qsTr('The code of Schèi is free and public on GitHub. Nobody, not even who made the app, can see your 12 words or touch your money.')
                }
            }

            // what Schèi changes and what stays Electrum's (owner 2026-11-11)
            EhSheet {
                topPadding: 4
                bottomPadding: 12
                spacing: 8
                EhCaption { text: qsTr('WHAT SCHÈI CHANGES'); rule: true; Layout.topMargin: 8; Layout.bottomMargin: 0 }
                Para {
                    text: qsTr('Schèi is a <b>new look</b> of the Electrum mobile wallet, made simpler for everyone: screens, words, big buttons.')
                }
                Para {
                    text: qsTr('All the parts that protect your money are the <b>original ones of Electrum</b>, not changed: the cryptography, the creation of the 12 words, the signature of the payments, the keys.')
                }
                Para {
                    color: S.muted
                    text: qsTr('Schèi only adds the PIN and keeps the wallet password in the safe of the phone (Android Keystore), the same way Electrum does with the fingerprint.')
                }
            }

            // support: e-mail and GitHub
            EhCaption { text: qsTr('HELP AND PROBLEMS'); Layout.topMargin: 6; Layout.bottomMargin: -6 }
            EhSheet {
                topPadding: 12
                bottomPadding: 15
                spacing: 10
                Para {
                    text: qsTr('Something does not work, or you have an idea? Write to us. Never send your 12 words or your PIN: nobody will ever ask for them.')
                }
                Repeater {
                    model: [
                        { 'icon': 'eh_mail.svg', 'title': qsTr('Write an e-mail'), 'sub': 'schei@safe21.io',
                          'url': 'mailto:schei@safe21.io?subject=' + encodeURIComponent('Schèi Wallet ' + BUILD.electrum_version) },
                        { 'icon': 'eh_github.svg', 'title': qsTr('Report a problem on GitHub'), 'sub': 'github.com/ManX-SAFE21/schei-wallet',
                          'url': 'https://github.com/ManX-SAFE21/schei-wallet/issues' }
                    ]
                    EhStitchButton {
                        id: sp
                        required property var modelData
                        kind: 'paper'
                        icon: sp.modelData.icon
                        text: sp.modelData.title
                        // the button has one line of title when it has a sub-line: the long GitHub
                        // title needs its two lines, so only the e-mail shows its address under it
                        sub: sp.modelData.icon === 'eh_mail.svg' ? sp.modelData.sub : ''
                        endIcon: 'open'
                        onClicked: Qt.openUrlExternally(sp.modelData.url)
                    }
                }
            }
        }
    }
}
