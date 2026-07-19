import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The right column, pinned across all three lanes: it is the feedback loop every
// control exists to repaint. Top to bottom: the mock in a Preview frame, the
// candidate 16-colour strip, the pending rice diff, and the pick metadata line.
Item {
    id: stack

    // the applied-desktop baseline + dirty state, owned by App and forwarded.
    property bool clean: false
    property bool desktopValid: false
    property string desktopName: ""
    property var desktopColours: []
    property string desktopPaletteName: "dark16"
    property string desktopImage: ""
    property real desktopFrame: 1
    property string candImage: ""
    property bool isVideo: false

    readonly property bool busyNow: Wallhaven.busy || Wallhaven.enhancing
    readonly property string resTag: Wallhaven.selected ? ("" + (Wallhaven.selected.resolution || "")) : ""
    readonly property int resH: {
        var p = stack.resTag.split("x");
        return p.length === 2 ? (parseInt(p[1]) || 0) : 0;
    }
    readonly property bool lowRes: stack.resH > 0 && stack.resH < 1080

    function opWord() {
        if (Wallhaven.enhancing) return "ENHANCING";
        if (Wallhaven.busy) {
            var s = Wallhaven.status;
            return s.length ? s.toUpperCase() : "WORKING";
        }
        return "";
    }

    // 1. the mock, in a Preview frame. The busy veil is the label swapping to
    //    the operation word, not a scrim (2.4).
    Preview {
        id: prev
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: strip.top
        anchors.bottomMargin: Tokens.s3
        visible: Wallhaven.selected !== null || stack.busyNow
        label: stack.busyNow ? stack.opWord() : "LIVE PREVIEW"
        tag: stack.resTag

        MockDesktop {
            anchors.fill: parent
            visible: Wallhaven.selected !== null
        }
    }

    // idle state: with no pick, a decor poster gives the app a face on open
    // rather than a lone mark. Right-click to reframe / swap the specimen, the
    // same as the hub's dead-slot posters; the framing persists per box.
    Decor {
        anchors.top: prev.top
        anchors.left: prev.left
        anchors.right: prev.right
        anchors.bottom: prev.bottom
        visible: Wallhaven.selected === null && !stack.busyNow
        boxId: "ryowalls.preview"
        code: "WALL-01"
        title: "壁紙"
        sub: "プレビュー"
        tate: "壁を選べ"
        caption: "Pick a wallpaper — the live rice preview lands right here."
        seal: "壁"
        images: ["earth.gif", "disc.gif", "wave.gif", "cradle.gif", "spring.gif", "sphere.gif", "torus.gif", "moon.png"]
        seed: 0
    }

    // 2. the candidate strip: the 16 extracted colours, contiguous, 22 tall.
    PaletteRow {
        id: strip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: pending.top
        anchors.bottomMargin: Tokens.s3
        implicitHeight: 22
        colors: Wallhaven.palette
    }

    // 3. the pending rice diff.
    PendingCard {
        id: pending
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: meta.top
        anchors.bottomMargin: Tokens.s3
        clean: stack.clean
        desktopValid: stack.desktopValid
        desktopName: stack.desktopName
        desktopColours: stack.desktopColours
        desktopPaletteName: stack.desktopPaletteName
        desktopImage: stack.desktopImage
        desktopFrame: stack.desktopFrame
        candImage: stack.candImage
        isVideo: stack.isVideo
    }

    // 4. pick metadata: name/id in mono, source tag, low-res flag.
    Row {
        id: meta
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 16
        spacing: Tokens.s2
        visible: Wallhaven.selected !== null

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Wallhaven.selected ? ("" + (Wallhaven.selected.name || Wallhaven.selected.id || "")) : ""
            color: Tokens.inkDim
            font.family: Tokens.mono
            font.pixelSize: 11
            elide: Text.ElideRight
            width: Math.min(implicitWidth, parent.width - 200)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: stack.resTag.length > 0
            text: "· " + stack.resTag
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: 11
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "· " + stack.sourceTag
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: 11
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: stack.lowRes
            text: "· LOW-RES"
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: 11
        }
    }
    // the source tag shown in the metadata line (file truth, mono).
    readonly property string sourceTag: {
        switch (Wallhaven.source) {
        case "wallhaven": return "wallhaven";
        case "moewalls": return "moewalls";
        case "motionbgs": return "motionbgs";
        case "ryoku": return "ryoku";
        case "live": return "livewalls";
        case "local": return "local";
        case "lib": return Wallhaven.libraryName || Wallhaven.libraryRepo;
        }
        return Wallhaven.source;
    }
}
