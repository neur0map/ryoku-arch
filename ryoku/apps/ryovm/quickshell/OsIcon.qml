import QtQuick
import Quickshell.Io
import "Singletons"

// An OS brand logo: the real SVG/PNG mark when one exists (resolved and cached to
// disk by the engine, then drawn from that local file, never the network);
// otherwise a deterministic colored monogram of the name. Only ~37 of the ~93
// catalogue OSes ship art upstream, so the monogram (not a generic glyph) keeps
// every tile looking intentional. `label` drives the monogram; `slug` keys the
// cache; the Library passes only the slug and resolves the cached file.
Item {
    id: root

    property string slug: ""
    property string label: ""
    property real size: 40
    property color glyphTint: Theme.cream      // kept for callers; unused by the monogram

    // local cached file for this slug (reactive on iconRev). The engine resolves
    // and disk-caches every logo, negative-caching the ~57 of 93 OSes with no
    // upstream art, so we never touch the network here: no per-tile 404 flood.
    readonly property string localPath: Vm.iconFor(root.slug)
    readonly property string imgSource: localPath.length > 0 ? ("file://" + localPath) : ""
    readonly property bool hasArt: img.status === Image.Ready

    readonly property string _initial: {
        var s = (root.label.length > 0 ? root.label : root.slug).trim();
        return s.length > 0 ? s.charAt(0).toUpperCase() : "?";
    }

    function resolve() {
        if (Vm.beginIcon(root.slug)) {
            iconProc.command = ["ryovm", "icon", root.slug];
            iconProc.running = true;
        }
    }
    Component.onCompleted: resolve()
    onSlugChanged: resolve()
    // once the catalogue cache lands, slugs that couldn't resolve yet can. A
    // mirror property with its own change handler fires reliably, where a
    // Connections onCatalogReadyChanged on the singleton did not.
    readonly property bool catReady: Vm.catalogReady
    onCatReadyChanged: resolve()

    // monogram fallback: a stamped cream initial on a keycap plate — the same
    // ink as the mono marks, so a missing logo still belongs to the set.
    Rectangle {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        antialiasing: false
        visible: !root.hasArt
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.keyTop }
            GradientStop { position: 1.0; color: Theme.keyBot }
        }
        border.width: 1
        border.color: Theme.line
        Text {
            anchors.centerIn: parent
            text: root._initial
            color: Theme.cream
            font.family: Theme.display
            font.pixelSize: root.size * 0.52
            font.weight: Font.Bold
        }
    }

    Image {
        id: img
        anchors.fill: parent
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(Math.ceil(root.size * 2), Math.ceil(root.size * 2))
        source: root.imgSource
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.medium } }
    }

    Process {
        id: iconProc
        stdout: StdioCollector { onStreamFinished: Vm.setIcon(root.slug, this.text.trim()) }
        onExited: (code) => { if (code !== 0) Vm.setIcon(root.slug, ""); }
    }
}
