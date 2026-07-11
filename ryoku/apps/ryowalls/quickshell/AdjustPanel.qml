pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Adjust mode: shape the picked wallpaper itself. For an image, a look preset
// plus a colour grade (brightness / contrast / saturation / warmth / vignette),
// baked on Set so the desktop matches the preview. For a live clip, the motion
// controls (max fps, fit). Both offer an on-demand GPU Enhance with progress.
// Every change drives the live rice preview on the right.
Item {
    id: adj

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

    readonly property string phaseText: {
        switch (Wallhaven.enhancePhase) {
        case "probe": return "Reading";
        case "extract": return "Extracting frames";
        case "enhance": return "Enhancing";
        case "assemble": return "Reassembling";
        case "done": return "Enhanced";
        case "error": return "Enhance failed";
        case "unsupported": return "No enhancer installed";
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

        Column {
            id: col
            width: flick.width
            spacing: 16

            // eyebrow: ADJUST + the wallpaper being shaped.
            Item {
                width: parent.width
                height: 16
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Rectangle { width: 5; height: 5; radius: Theme.radius; color: Theme.brand; anchors.verticalCenter: parent.verticalCenter }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Adjust"; color: Theme.faint; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Wallhaven.selected ? Wallhaven.selected.resolution : ""
                    color: Theme.subtle
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
            }

            Text {
                width: parent.width
                visible: !Wallhaven.selected
                wrapMode: Text.WordWrap
                text: "Pick a wallpaper to adjust it."
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 12
            }

            // ---- image: look + grade -------------------------------------------
            SectionHead { text: "Look"; visible: adj.imageMode }
            Flow {
                width: parent.width
                spacing: 8
                visible: adj.imageMode
                Repeater {
                    model: adj.looks
                    delegate: LookChip {
                        required property var modelData
                        look: modelData
                    }
                }
            }

            SectionHead { text: "Grade"; visible: adj.imageMode }
            SliderRow {
                width: parent.width
                visible: adj.imageMode
                label: "Brightness"
                from: -50; to: 50; step: 1; decimals: 0
                value: Wallhaven.adjust.brightness
                onModified: (v) => Wallhaven.setAdjust("brightness", Math.round(v))
            }
            SliderRow {
                width: parent.width
                visible: adj.imageMode
                label: "Contrast"
                from: -50; to: 50; step: 1; decimals: 0
                value: Wallhaven.adjust.contrast
                onModified: (v) => Wallhaven.setAdjust("contrast", Math.round(v))
            }
            SliderRow {
                width: parent.width
                visible: adj.imageMode
                label: "Saturation"
                from: -100; to: 100; step: 1; decimals: 0
                value: Wallhaven.adjust.saturation
                onModified: (v) => Wallhaven.setAdjust("saturation", Math.round(v))
            }
            SliderRow {
                width: parent.width
                visible: adj.imageMode
                label: "Warmth"
                from: -100; to: 100; step: 1; decimals: 0
                value: Wallhaven.adjust.warmth
                onModified: (v) => Wallhaven.setAdjust("warmth", Math.round(v))
            }
            ToggleRow {
                visible: adj.imageMode
                label: "Vignette"
                on: Wallhaven.adjust.vignette
                onToggled: (v) => Wallhaven.setAdjust("vignette", v)
            }
            Item {
                width: parent.width
                height: 20
                visible: adj.imageMode && Wallhaven.adjustActive
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "close"; size: 11; tint: rh.hovered ? Theme.ember : Theme.faint }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Reset edits"; color: rh.hovered ? Theme.ember : Theme.faint; font.family: Theme.font; font.pixelSize: 12; Behavior on color { ColorAnimation { duration: Theme.quick } } }
                }
                HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Wallhaven.resetAdjust() }
            }

            // ---- live: motion --------------------------------------------------
            SectionHead { text: "Motion"; visible: adj.videoMode }
            SliderRow {
                width: parent.width
                visible: adj.videoMode
                label: "Max FPS"
                from: 15; to: 60; step: 5; decimals: 0
                value: Wallhaven.settings.liveFps
                onModified: (v) => Wallhaven.setLiveFps(v)
            }
            SubLabel { text: "Fit"; visible: adj.videoMode }
            Segmented {
                width: parent.width
                visible: adj.videoMode
                segW: (width - 8) / model.length
                model: [{ key: "fill", label: "Fill" }, { key: "fit", label: "Fit" }]
                current: Wallhaven.settings.liveFit
                onSelected: (k) => Wallhaven.setLiveFit(k)
            }

            // ---- enhance (image or live) ---------------------------------------
            SectionHead { text: "Enhance"; visible: !!Wallhaven.selected }
            Column {
                width: parent.width
                spacing: 9
                visible: !!Wallhaven.selected

                Text {
                    width: parent.width
                    visible: !Wallhaven.upscaleSupported
                    wrapMode: Text.WordWrap
                    text: "AI enhance needs a Vulkan-capable GPU. None detected on this machine."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: Wallhaven.upscaleSupported && !Wallhaven.upscaler
                    HubButton { icon: "download"; label: "Install enhancer"; onClicked: Wallhaven.installUpscaler() }
                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "Opens gpk to install waifu2x (Vulkan). It doubles resolution and denoises images and, frame by frame, video."; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11 }
                }

                Column {
                    width: parent.width
                    spacing: 9
                    visible: Wallhaven.upscaleSupported && Wallhaven.upscaler

                    HubButton {
                        visible: !Wallhaven.enhancing && Wallhaven.enhancePhase !== "done"
                        primary: true
                        icon: "sparkles"
                        label: adj.videoMode ? "Enhance clip" : "Enhance image"
                        enabled: !!Wallhaven.selected && !Wallhaven.busy && !Wallhaven.enhancing
                        onClicked: Wallhaven.enhance()
                    }

                    Item {
                        width: parent.width
                        height: 32
                        visible: Wallhaven.enhancing
                            || Wallhaven.enhancePhase === "done"
                            || Wallhaven.enhancePhase === "error"
                            || Wallhaven.enhancePhase === "unsupported"
                        Row {
                            id: statusRow
                            anchors.left: parent.left
                            anchors.top: parent.top
                            spacing: 7
                            Icon {
                                id: spin
                                anchors.verticalCenter: parent.verticalCenter
                                name: "refresh"
                                size: 13
                                tint: Theme.ember
                                visible: Wallhaven.enhancing && Wallhaven.enhanceFrac <= 0
                                RotationAnimation on rotation { running: spin.visible; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: adj.phaseText
                                color: Wallhaven.enhancePhase === "error" ? Theme.bad
                                    : (Wallhaven.enhancePhase === "done" ? Theme.ok : Theme.subtle)
                                font.family: Theme.mono
                                font.pixelSize: 11
                            }
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            visible: Wallhaven.enhanceFrac > 0 && Wallhaven.enhancing
                            text: Math.round(Wallhaven.enhanceFrac * 100) + "%"
                            color: Theme.subtle
                            font.family: Theme.mono
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 4
                            radius: Theme.radius
                            color: Theme.surfaceLo
                            border.width: 1
                            border.color: Theme.line
                            clip: true
                            visible: Wallhaven.enhanceFrac > 0
                            Rectangle {
                                height: parent.height
                                radius: parent.radius
                                width: Math.max(0, Math.min(1, Wallhaven.enhanceFrac)) * parent.width
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: Theme.emberDeep }
                                    GradientStop { position: 1.0; color: Theme.ember }
                                }
                                Behavior on width { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        visible: !Wallhaven.enhancing && Wallhaven.enhancePhase === ""
                        wrapMode: Text.WordWrap
                        text: adj.videoMode
                            ? "Doubles the clip's resolution on the GPU, frame by frame. It takes a while and only swaps in if this clip is still your wallpaper when it finishes."
                            : "Doubles the image resolution and denoises on the GPU, then saves it sharper."
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    // ---- inline components (match TunePanel idioms) ------------------------
    component SectionHead: Row {
        id: sh
        property string text: ""
        spacing: 7
        Rectangle { width: 5; height: 5; radius: Theme.radius; color: Theme.brand; anchors.verticalCenter: parent.verticalCenter }
        Text { anchors.verticalCenter: parent.verticalCenter; text: sh.text; color: Theme.subtle; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase }
    }

    component SubLabel: Text {
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 10
        font.letterSpacing: 1.5
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    component LookChip: Rectangle {
        id: chip
        property var look
        readonly property bool on: adj.lookActive(chip.look)
        implicitWidth: lt.implicitWidth + 22
        height: 30
        radius: height / 2
        color: chip.on ? Theme.frameBg : Theme.surfaceLo
        border.width: 1
        border.color: chip.on ? Theme.ember : (lh.hovered ? Qt.alpha(Theme.ember, 0.5) : Theme.line)
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }
        Text { id: lt; anchors.centerIn: parent; text: chip.look.label; color: chip.on ? Theme.ember : Theme.cream; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium }
        HoverHandler { id: lh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: Wallhaven.applyLook(chip.look) }
    }

    component ToggleRow: Item {
        id: tr
        property string label: ""
        property bool on: false
        signal toggled(bool v)
        width: parent.width
        height: 26
        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: tr.label; color: Theme.cream; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
        Toggle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; on: tr.on; onToggled: (v) => tr.toggled(v) }
    }
}
