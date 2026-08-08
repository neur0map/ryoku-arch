pragma Singleton

import QtQuick
import Quickshell

// Backdrop palette. Only the paper colour is needed: the window fill shown in the
// letterbox margins of a Contain / ScaleDown fit and for the instant before the
// first image decodes (contract 08 sec 2.6: the window background is the shell
// surface). It is the Ryoku default paper, the same near-black the shell uses as
// its base, so a wallpaper's aspect margins read as neutral desktop rather than a
// stray colour. The token lives here so the surface never hardcodes it inline.
Singleton {
    readonly property color paper: "#000000"
}
