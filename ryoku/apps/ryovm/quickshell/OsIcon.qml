import QtQuick
import Quickshell.Io
import Ryoku.Ui.Singletons
import "Singletons"

// An OS brand logo: the real SVG/PNG mark when one exists (resolved and cached to
// disk by the engine, then drawn from that local file, never the network);
// otherwise a Fraunces initial in ink on a hairline tile (amendment 4: the
// keycap gradient dies; the monogram becomes the same ink as the rest of the
// set). Only ~37 of the ~93 catalogue OSes ship art upstream. `label` drives the
// monogram; `slug` keys the cache; the Library passes only the slug.
//
// The logo is the catalogue's data, so it keeps its chroma: the one place besides
// the hanko where colour is allowed, and only inside this rect.
Item {
    id: root

    property string slug: ""
    property string label: ""
    property real size: 40

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
    // once the catalogue cache lands, slugs that couldn't resolve yet can.
    readonly property bool catReady: Vm.catalogReady
    onCatReadyChanged: resolve()

    // monogram fallback: a Fraunces initial in ink on a hairline tile.
    Rectangle {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        radius: Tokens.radius
        antialiasing: false
        visible: !root.hasArt
        color: "transparent"
        border.width: Tokens.border
        border.color: Tokens.line
        Text {
            anchors.centerIn: parent
            text: root._initial
            color: Tokens.ink
            font.family: Tokens.display
            font.pixelSize: root.size * 0.5
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
        Behavior on opacity { NumberAnimation { duration: Tokens.swap } }
    }

    Process {
        id: iconProc
        stdout: StdioCollector { onStreamFinished: Vm.setIcon(root.slug, this.text.trim()) }
        onExited: (code) => { if (code !== 0) Vm.setIcon(root.slug, ""); }
    }
}
