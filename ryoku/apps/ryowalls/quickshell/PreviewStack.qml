import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The right column and the star of the app: the live rice preview — your chosen
// wallpaper wearing the terminal and the cava spectrum in its own colours — kept
// as tall as the column allows, over a slim footer of the candidate palette and
// the pick's identity. The pending-vs-applied verdict lives in the commit bar
// below, so the preview owns this space instead of repeating it.
Item {
    id: stack

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

    // the mock, in a Preview frame. The busy veil is the label swapping to the
    // operation word, not a scrim.
    Preview {
        id: prev
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: foot.top
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
    // rather than a lone mark. Right-click to reframe / swap the specimen.
    Decor {
        anchors.fill: prev
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

    // slim footer: the candidate 16-colour strip (the palette the rice will wear)
    // and the pick's identity line. Nothing here repeats the commit bar.
    Column {
        id: foot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Tokens.s3
        visible: Wallhaven.selected !== null

        PaletteRow {
            id: strip
            width: parent.width
            implicitHeight: 24
            colors: Wallhaven.palette
        }

        Row {
            width: parent.width
            height: 14
            spacing: Tokens.s2

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Wallhaven.selected ? ("" + (Wallhaven.selected.name || Wallhaven.selected.id || "")) : ""
                color: Tokens.inkDim
                font.family: Tokens.mono
                font.pixelSize: 11
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width - 220)
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
    }
}
