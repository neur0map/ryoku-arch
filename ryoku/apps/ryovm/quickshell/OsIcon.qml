import QtQuick
import Quickshell.Io
import "Singletons"

// An OS brand logo. The real SVG/PNG mark when one exists (shown instantly from
// the catalogue CDN via `remote`, cached to disk by the engine for offline use);
// otherwise a deterministic colored monogram of the name. Only ~37 of the ~93
// catalogue OSes ship art upstream, so the monogram (not a generic glyph) keeps
// every tile looking intentional. `label` drives the monogram; `slug` keys the
// cache; the Library passes only the slug and resolves the cached file.
Item {
    id: root

    property string slug: ""
    property string remote: ""
    property string label: ""
    property real size: 40
    property color glyphTint: Theme.cream      // kept for callers; unused by the monogram

    // local cached file for this slug (reactive on iconRev); else the remote URL.
    readonly property string localPath: Vm.iconFor(root.slug)
    readonly property string imgSource: localPath.length > 0 ? ("file://" + localPath)
        : (root.remote.length > 0 ? root.remote : "")
    readonly property bool hasArt: img.status === Image.Ready

    // a stable hue from the slug, so each OS keeps the same monogram colour.
    readonly property int _hue: {
        var s = root.slug.length > 0 ? root.slug : root.label;
        var h = 0;
        for (var i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) % 360;
        return h;
    }
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

    // monogram fallback: a tinted rounded tile + the name's initial. Shown until
    // (or unless) real art resolves.
    Rectangle {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        radius: root.size * 0.26
        visible: !root.hasArt
        color: Qt.hsla(root._hue / 360, 0.42, 0.34, 1)
        border.width: 1
        border.color: Qt.hsla(root._hue / 360, 0.5, 0.6, 0.5)
        Text {
            anchors.centerIn: parent
            text: root._initial
            color: Qt.hsla(root._hue / 360, 0.55, 0.9, 1)
            font.family: Theme.font
            font.pixelSize: root.size * 0.5
            font.weight: Font.DemiBold
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
