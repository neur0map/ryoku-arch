pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons

// Welcome-local values only. The look -- paper, ink, type, geometry, motion --
// is Ryoku.Ui's Tokens and nothing here duplicates it (the one-look rule; the
// eleven drifted Theme copies are the cautionary tale). What remains is the
// brand-identity plumbing this once-per-login window reads for itself, and the
// one scrim tint the threshold art needs.
Singleton {
    // content backing over the art: the paper flooding back in so copy stays
    // legible while the backdrop breathes around it. Derived from Tokens.paper,
    // never a second black.
    readonly property color panel: Qt.rgba(Tokens.paper.r, Tokens.paper.g, Tokens.paper.b, 0.66)

    // brand mark + name, user-overridable via ~/.config/ryoku/brand.json (Shell ->
    // Global). defaults to the 力 seal / "Ryoku". BrandMark renders `mark`, or
    // `markSource` (an image) when set. Ryoku's own apps never read these.
    readonly property string mark: brandAdapter.markText.length > 0 ? brandAdapter.markText : "\u529b"
    readonly property string markSource: brandAdapter.markImage
    readonly property bool markTint: brandAdapter.markTint
    readonly property string brandName: brandAdapter.name.length > 0 ? brandAdapter.name : "Ryoku"

    // brand identity master (mark + name), the same ~/.config/ryoku/brand.json the
    // rest of the shell and the Hub read. read-only here: the always-on
    // pill seeds the file, so this once-per-login window just falls back to the
    // adapter defaults when it is absent.
    FileView {
        id: brandFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/brand.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: brandAdapter
            property string markText: "力"
            property string markImage: ""
            property bool markTint: true
            property string name: "Ryoku"
        }
    }
}
