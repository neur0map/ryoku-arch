pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// The middle content of a status RevealerRow (network / bluetooth / power):
// one bold 16px label that takes the row slack and elides (contract 16 sec
// 2.5, contract 06 sec 2.4).
Text {
    property string label: ""

    text: label
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignLeft
    verticalAlignment: Text.AlignVCenter
    color: Theme.ink(Theme.effectiveSurface)
    font.family: Theme.fontPrimary
    font.pixelSize: Theme.fontMd
    font.weight: Font.Bold
}
