pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// GRADE lane: edits the image, not the scheme. A look preset, a colour grade,
// vignette, and Enhance. Session-scoped and baked into a sibling .edit file on
// Set, so the cells carry no source tag: their descriptions say so. Video picks
// cannot be graded, so their GRADE surface is the display fit plus Enhance clip.
Item {
    id: sheet

    readonly property bool imageMode: !!Wallhaven.selected && Wallhaven.canAdjust
    readonly property bool videoMode: !!Wallhaven.selected && Wallhaven.selectedVideo

    readonly property var looks: [
        { label: "Original",  brightness: 0,  contrast: 0,   saturation: 0,    warmth: 0,   vignette: false },
        { label: "Vivid",     brightness: 4,  contrast: 14,  saturation: 34,   warmth: 6,   vignette: false },
        { label: "Faded",     brightness: 8,  contrast: -22, saturation: -20,  warmth: 4,   vignette: false },
        { label: "Cinematic", brightness: -4, contrast: 18,  saturation: -8,   warmth: 12,  vignette: true },
        { label: "Noir",      brightness: 0,  contrast: 22,  saturation: -100, warmth: 0,   vignette: true },
        { label: "Warm",      brightness: 3,  contrast: 6,   saturation: 10,   warmth: 46,  vignette: false },
        { label: "Cool",      brightness: 2,  contrast: 8,   saturation: 8,    warmth: -44, vignette: false }
    ]
    function lookActive(l) {
        var a = Wallhaven.adjust;
        return a.brightness === l.brightness && a.contrast === l.contrast
            && a.saturation === l.saturation && a.warmth === l.warmth && a.vignette === l.vignette;
    }
    function currentLook() {
        for (var i = 0; i < looks.length; i++)
            if (lookActive(looks[i])) return looks[i].label;
        return "";
    }
    function signed(v) { return v > 0 ? "+" + v : "" + v; }

    readonly property string phaseWord: {
        switch (Wallhaven.enhancePhase) {
        case "probe": return "READING";
        case "extract": return "EXTRACTING FRAMES";
        case "enhance": return "ENHANCING";
        case "assemble": return "REASSEMBLING";
        case "done": return "ENHANCED";
        case "sharp": return "ALREADY SHARP";
        case "error": return "ENHANCE FAILED";
        case "unsupported": return "NO ENHANCER INSTALLED";
        default: return "";
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollRail {}

        Column {
            id: col
            width: flick.width
            spacing: Tokens.s5

            // ── LOOK: one tap grade ───────────────────────────────────────────
            SheetSection {
                id: lookSec
                width: parent.width
                title: "LOOK"
                visible: sheet.imageMode
                Cell {
                    width: lookSec.span(10)
                    height: 2 * Tokens.cellH + Tokens.s2
                    label: "Look"
                    value: ""
                    block: true
                    changed: Wallhaven.adjustActive
                    desc: "A one-tap grade. Baked into the file when you set it."
                    Chips {
                        width: parent.width
                        options: sheet.looks.map(l => l.label)
                        current: sheet.currentLook()
                        onChose: (k) => { var l = sheet.looks.find(x => x.label === k); if (l) Wallhaven.applyLook(l); }
                    }
                }
            }

            // ── GRADE: the colour axes, with a reset in the header ─────────────
            SheetSection {
                id: gradeSec
                width: parent.width
                title: "GRADE"
                visible: sheet.imageMode
                action: Btn {
                    text: "RESET EDITS"
                    armed: Wallhaven.adjustActive
                    onAct: Wallhaven.resetAdjust()
                }
                Cell {
                    width: gradeSec.span(6)
                    label: "Brightness"
                    value: sheet.signed(Wallhaven.adjust.brightness)
                    def: "0"
                    desc: "Baked into the file when you set it."
                    controlWidth: Spans.inlineWidth("slid", 0, width)
                    Slid {
                        anchors.fill: parent
                        from: -50; to: 50
                        value: Wallhaven.adjust.brightness
                        onModified: (v) => Wallhaven.setAdjust("brightness", v)
                    }
                }
                Cell {
                    width: gradeSec.span(6)
                    label: "Contrast"
                    value: sheet.signed(Wallhaven.adjust.contrast)
                    def: "0"
                    desc: "Baked into the file when you set it."
                    controlWidth: Spans.inlineWidth("slid", 0, width)
                    Slid {
                        anchors.fill: parent
                        from: -50; to: 50
                        value: Wallhaven.adjust.contrast
                        onModified: (v) => Wallhaven.setAdjust("contrast", v)
                    }
                }
                Cell {
                    width: gradeSec.span(6)
                    label: "Saturation"
                    value: sheet.signed(Wallhaven.adjust.saturation)
                    def: "0"
                    desc: "Baked into the file when you set it."
                    controlWidth: Spans.inlineWidth("slid", 0, width)
                    Slid {
                        anchors.fill: parent
                        from: -100; to: 100
                        value: Wallhaven.adjust.saturation
                        onModified: (v) => Wallhaven.setAdjust("saturation", v)
                    }
                }
                Cell {
                    width: gradeSec.span(6)
                    label: "Warmth"
                    value: sheet.signed(Wallhaven.adjust.warmth)
                    def: "0"
                    desc: "Baked into the file when you set it."
                    controlWidth: Spans.inlineWidth("slid", 0, width)
                    Slid {
                        anchors.fill: parent
                        from: -100; to: 100
                        value: Wallhaven.adjust.warmth
                        onModified: (v) => Wallhaven.setAdjust("warmth", v)
                    }
                }
                Cell {
                    width: gradeSec.span(4)
                    label: "Vignette"
                    value: Wallhaven.adjust.vignette ? "ON" : "OFF"
                    def: "OFF"
                    desc: "Darken the edges. Baked in on Set."
                    controlWidth: Spans.inlineWidth("sw", 0, width)
                    Sw {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        on: Wallhaven.adjust.vignette
                        onToggled: (v) => Wallhaven.setAdjust("vignette", v)
                    }
                }
            }

            // ── MOTION: how a live clip fills the screen (video picks) ─────────
            SheetSection {
                id: motionSec
                width: parent.width
                title: "MOTION"
                visible: sheet.videoMode
                Cell {
                    width: motionSec.span(4)
                    label: "Fit"
                    // one immediate-persist control on this lane, so it keeps a tag.
                    source: "ryowalls.json"
                    value: Wallhaven.settings.liveFit === "fit" ? "Fit" : "Fill"
                    def: "Fill"
                    desc: "Cover the screen, or letterbox the clip."
                    controlWidth: Spans.inlineWidth("seg", 2, width)
                    Seg {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        options: ["Fill", "Fit"]
                        current: Wallhaven.settings.liveFit === "fit" ? "Fit" : "Fill"
                        onChose: (k) => Wallhaven.setLiveFit(k.toLowerCase())
                    }
                }
            }

            // ── ENHANCE: a block with phases, a progress bar and a verdict ─────
            SheetSection {
                id: enhSec
                width: parent.width
                title: "ENHANCE"
                visible: !!Wallhaven.selected
                Item {
                    width: enhSec.span(12)
                    implicitHeight: enhCol.implicitHeight
                    Column {
                        id: enhCol
                        width: parent.width
                        spacing: Tokens.s3

                        // no capable GPU: state it, in words, no red.
                        Text {
                            width: parent.width
                            visible: !Wallhaven.upscaleSupported
                            wrapMode: Text.WordWrap
                            text: "AI enhance needs a Vulkan-capable GPU. None detected on this machine."
                            color: Tokens.inkMuted
                            font.family: Tokens.ui
                            font.pixelSize: 12
                        }

                        // capable but the tool is missing: offer the install.
                        Column {
                            width: parent.width
                            spacing: Tokens.s2
                            visible: Wallhaven.upscaleSupported && !Wallhaven.upscaler
                            Btn { text: "INSTALL ENHANCER"; onAct: Wallhaven.installUpscaler() }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Opens gpk to install waifu2x (Vulkan). It doubles resolution and denoises images and, frame by frame, video."
                                color: Tokens.inkMuted
                                font.family: Tokens.ui
                                font.pixelSize: 12
                            }
                        }

                        // ready to run.
                        Column {
                            width: parent.width
                            spacing: Tokens.s3
                            visible: Wallhaven.upscaleSupported && Wallhaven.upscaler

                            // the button stays visible through "sharp": the skip
                            // depends on the screen cap, which changes with a
                            // monitor or scale, so a retry is always one click away.
                            Btn {
                                visible: !Wallhaven.enhancing && Wallhaven.enhancePhase !== "done"
                                primary: true
                                text: sheet.videoMode ? "ENHANCE CLIP" : "ENHANCE IMAGE"
                                armed: !!Wallhaven.selected && !Wallhaven.busy && !Wallhaven.enhancing
                                onAct: Wallhaven.enhance()
                            }

                            // progress: determinate bar + percent, or the 1Hz dot.
                            Column {
                                width: parent.width
                                spacing: Tokens.s2
                                visible: Wallhaven.enhancing
                                    || Wallhaven.enhancePhase === "done"
                                    || Wallhaven.enhancePhase === "sharp"
                                    || Wallhaven.enhancePhase === "error"
                                    || Wallhaven.enhancePhase === "unsupported"
                                Item {
                                    width: parent.width
                                    height: 14
                                    Row {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Tokens.s2
                                        Rectangle {
                                            id: indet
                                            width: 6; height: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: Tokens.ink
                                            visible: Wallhaven.enhancing && Wallhaven.enhanceFrac <= 0
                                            // a 1Hz square-wave blink, not a sweep.
                                            SequentialAnimation on opacity {
                                                running: indet.visible
                                                loops: Animation.Infinite
                                                NumberAnimation { to: 1.0; duration: 0 }
                                                PauseAnimation { duration: 500 }
                                                NumberAnimation { to: 0.15; duration: 0 }
                                                PauseAnimation { duration: 500 }
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: sheet.phaseWord
                                            color: Tokens.inkDim
                                            font.family: Tokens.mono
                                            font.pixelSize: 12
                                        }
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: Wallhaven.enhancing && Wallhaven.enhanceFrac > 0
                                        text: Math.round(Wallhaven.enhanceFrac * 100) + "%"
                                        color: Tokens.ink
                                        font.family: Tokens.ui
                                        font.pixelSize: 12
                                    }
                                }
                                // the shared progress spec: a hairline track with a
                                // square ink fill from zero, no rounding, no sweep.
                                Rectangle {
                                    width: parent.width
                                    height: 4
                                    visible: Wallhaven.enhanceFrac > 0
                                    color: "transparent"
                                    border.width: Tokens.border
                                    border.color: Tokens.line
                                    antialiasing: false
                                    Rectangle {
                                        height: 4
                                        width: Math.max(0, Math.min(1, Wallhaven.enhanceFrac)) * parent.width
                                        color: Tokens.ink
                                        antialiasing: false
                                        Behavior on width { NumberAnimation { duration: Tokens.move; easing.type: Tokens.ease } }
                                    }
                                }
                            }

                            // the verdict: every current sentence, verbatim.
                            Text {
                                width: parent.width
                                visible: !Wallhaven.enhancing && Wallhaven.enhancePhase === "sharp"
                                wrapMode: Text.WordWrap
                                text: {
                                    var kind = Wallhaven.enhanceKind || (sheet.videoMode ? "video" : "image");
                                    if (kind === "video")
                                        return Wallhaven.enhancePx > 0
                                            ? "This clip is already " + Wallhaven.enhancePx + "px wide. The desktop plays live wallpapers at " + Wallhaven.enhanceCap + "px, so upscaling can't add detail you would see."
                                            : "This clip already meets the width the desktop plays it at, so upscaling can't add detail you would see.";
                                    return Wallhaven.enhancePx > 0
                                        ? "This image is already " + Wallhaven.enhancePx + "px tall, 4K class. Enhancing would cost GPU time without making it sharper."
                                        : "This image is already 4K class, sharper than enhancing can improve.";
                                }
                                color: Tokens.inkMuted
                                font.family: Tokens.ui
                                font.pixelSize: 12
                            }
                            Text {
                                width: parent.width
                                visible: !Wallhaven.enhancing && Wallhaven.enhancePhase === "error"
                                wrapMode: Text.WordWrap
                                // blame by cause: pointing every failure at the GPU
                                // sends a user with a truncated download chasing
                                // driver ghosts.
                                text: {
                                    if (Wallhaven.enhanceWhy === "gpu")
                                        return "No GPU produced a clean result; the original file is untouched. Try again, or check the GPU driver if it keeps failing.";
                                    if (Wallhaven.enhanceWhy === "read")
                                        return "The file could not be read: it may be truncated or corrupt. The original is untouched; re-downloading it usually fixes this.";
                                    return "Enhance failed; the original file is untouched. The file may be unreadable, the disk full, or a required tool missing.";
                                }
                                color: Tokens.inkMuted
                                font.family: Tokens.ui
                                font.pixelSize: 12
                            }
                            Text {
                                width: parent.width
                                visible: !Wallhaven.enhancing && Wallhaven.enhancePhase === ""
                                wrapMode: Text.WordWrap
                                text: sheet.videoMode
                                    ? "Doubles the clip's resolution on the GPU, frame by frame. It takes a while and only swaps in if this clip is still your wallpaper when it finishes."
                                    : "Doubles the image resolution and denoises on the GPU, then saves it sharper."
                                color: Tokens.inkMuted
                                font.family: Tokens.ui
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: Tokens.s2 }
        }
    }

    // no-pick state: the whole left column is dead until you choose a wallpaper,
    // so it gets a specimen poster (like the browse grid) rather than one line of
    // grey text. The instruction lives in the caption.
    Placard {
        anchors.fill: parent
        visible: !Wallhaven.selected
        code: "GRADE-00"
        title: "調色"
        sub: "NO PICK"
        quote: "Pick a wallpaper to grade — look, colour, vignette, and Enhance."
        tate: "色を練る"
        seal: "調"
        art: "laocoon.png"
        seed: 5
    }
}
