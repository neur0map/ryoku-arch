pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs
import RyoMotion

// Contextual panel beside the rail: the controls for the current tool.
Flickable {
    id: insp
    contentWidth: width
    contentHeight: col.implicitHeight + 32
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    component Caption: Text {
        color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
        wrapMode: Text.WordWrap; width: parent ? parent.width : 0
    }
    component Swatches: Flow {
        id: sw
        property var colors: []
        property var sel: ""
        property bool gradient: false
        signal picked(int i)
        width: parent ? parent.width : 0
        spacing: 8
        Repeater {
            model: sw.colors
            delegate: Rectangle {
                required property int index
                required property var modelData
                width: 28; height: 28; radius: 14
                color: sw.gradient ? "transparent" : modelData
                readonly property bool on: sw.gradient ? (sw.sel === index) : (("" + sw.sel).toLowerCase() === ("" + modelData).toLowerCase())
                border.width: on ? 2.5 : 1
                border.color: on ? Theme.bright : Theme.hair
                gradient: sw.gradient ? gr : null
                Gradient {
                    id: gr
                    orientation: Gradient.Vertical
                    GradientStop { position: 0; color: sw.gradient ? modelData.a : "transparent" }
                    GradientStop { position: 1; color: sw.gradient ? modelData.b : "transparent" }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.picked(index) }
            }
        }
    }
    component Field: Rectangle {
        property alias text: ti.text
        signal edited(string t)
        width: parent ? parent.width : 0
        height: 34; radius: Theme.radiusSm; color: Theme.field
        border.width: 1; border.color: ti.activeFocus ? Theme.ember : Theme.hair
        TextInput {
            id: ti
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.bright; font.family: Theme.font; font.pixelSize: 13
            selectByMouse: true; selectionColor: Theme.ember
            onEditingFinished: parent.edited(text)
        }
    }
    component RowRemove: TopBtn {
        label: "Remove region"
        onTapped: Project.removeRegion(Project.selKind, Project.selId)
    }

    FileDialog {
        id: imgDialog
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.avif)"]
        onAccepted: { Project.bgImage = selectedFile.toString().replace(/^file:\/\//, ""); Project.bgKind = "image"; Project.dirty(); }
    }
    FileDialog {
        id: musicDialog
        nameFilters: ["Audio (*.mp3 *.flac *.wav *.ogg *.m4a *.opus)"]
        onAccepted: { Project.musicPath = selectedFile.toString().replace(/^file:\/\//, ""); Project.dirty(); }
    }
    FileDialog {
        id: ovDialog
        nameFilters: ["Video (*.mp4 *.mkv *.mov *.webm)"]
        onAccepted: Project.addOverlay(selectedFile.toString().replace(/^file:\/\//, ""))
    }

    readonly property var aspects: ["auto", "16:9", "9:16", "4:3", "1:1"]
    readonly property var solids: ["#20303f", "#111827", "#0e0d0b", "#2b2b2b", "#3e6868", "#4b607f", "#7b4397", "#c94e44", "#e2342a", "#f5b53f"]
    readonly property var inks: ["#ffffff", "#1b1610", "#000000", "#e2342a", "#f5b53f", "#7fbf6a", "#4facfe"]

    function dfmt(ms) {
        var s = Math.max(0, ms) / 1000, m = Math.floor(s / 60), r = Math.round(s - m * 60);
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    Column {
        id: col
        x: 16; y: 16
        width: insp.width - 32
        spacing: 20

        Text {
            text: ({ canvas: "Canvas", frame: "Frame", zoom: "Zoom", cut: "Cut", speed: "Speed", text: "Text", overlay: "Overlay", music: "Music", export: "Export" })[Project.tool]
            color: Theme.bright; font.family: Theme.display; font.pixelSize: 21; font.weight: Font.DemiBold
        }

        // CANVAS
        Group {
            visible: Project.tool === "canvas"
            title: "ASPECT"
            Segmented {
                width: parent.width; options: ["Auto", "16:9", "9:16", "4:3", "1:1"]
                current: insp.aspects.indexOf(Project.aspect)
                onPicked: (i) => { Project.aspect = insp.aspects[i]; Project.dirty(); }
            }
        }
        Group {
            visible: Project.tool === "canvas"
            title: "BACKGROUND"
            Segmented {
                width: parent.width; options: ["Gradient", "Solid", "Image"]
                current: Project.bgKind === "gradient" ? 0 : Project.bgKind === "solid" ? 1 : 2
                onPicked: (i) => { Project.bgKind = ["gradient", "solid", "image"][i]; Project.dirty(); }
            }
            Swatches { visible: Project.bgKind === "gradient"; gradient: true; colors: Project.presets; sel: Project.bgPreset; onPicked: (i) => { Project.bgPreset = i; Project.dirty(); } }
            Swatches { visible: Project.bgKind === "solid"; colors: insp.solids; sel: Project.bgSolid; onPicked: (i) => { Project.bgSolid = insp.solids[i]; Project.dirty(); } }
            TopBtn { visible: Project.bgKind === "image"; label: Project.bgImage ? "Change image…" : "Choose image…"; onTapped: imgDialog.open() }
            Caption { visible: Project.bgKind === "image" && Project.bgImage !== ""; text: ("" + Project.bgImage).split("/").pop() }
        }

        // FRAME
        Group {
            visible: Project.tool === "frame"
            title: "FRAMING"
            Slider { width: parent.width; label: "Padding"; from: 0; to: 20; value: Project.padding * 100; suffix: "%"; onMoved: (v) => { Project.padding = v / 100; Project.dirty(); } }
            Slider { width: parent.width; label: "Roundness"; from: 0; to: 64; value: Project.roundness; onMoved: (v) => { Project.roundness = v; Project.dirty(); } }
            Slider { width: parent.width; label: "Shadow"; from: 0; to: 100; value: Project.shadow * 100; suffix: "%"; onMoved: (v) => { Project.shadow = v / 100; Project.dirty(); } }
            Slider { width: parent.width; label: "Border"; from: 0; to: 8; value: Project.borderW; suffix: "px"; onMoved: (v) => { Project.borderW = v; Project.dirty(); } }
            Swatches { visible: Project.borderW > 0; colors: insp.inks; sel: Project.borderColor; onPicked: (i) => { Project.borderColor = insp.inks[i]; Project.dirty(); } }
        }

        // ZOOM
        Group {
            visible: Project.tool === "zoom"
            title: "AUTO-ZOOM"
            Item {
                width: parent.width; height: 24
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Follow the cursor"; color: Theme.cream; font.family: Theme.font; font.pixelSize: 13 }
                Toggle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; on: Project.autoZoom; onToggled: (v) => { Project.autoZoom = v; Project.dirty(); } }
            }
            Caption { text: "Auto-generates smooth zoom-ins wherever the cursor settles, at export." }
            Caption { visible: !Project.hasCursor; text: "This clip has no cursor track -- record with Ryoku Motion to use auto-zoom."; color: Theme.gold }
        }
        Group {
            visible: Project.tool === "zoom"
            title: "ADD ZOOM"
            Slider { width: parent.width; label: "Depth"; from: 1; to: 6; value: Project.zoomDepth; onMoved: (v) => Project.zoomDepth = Math.round(v) }
            Caption { text: "= " + Project.depthScale(Project.zoomDepth).toFixed(2) + "× magnification" }
            TopBtn { label: "Add zoom at playhead"; on: Project.hasClip; onTapped: Project.addZoom() }
        }
        Group {
            visible: Project.tool === "zoom" && Project.selKind === "zoom" && Project.selected() !== null
            title: "SELECTED ZOOM"
            Slider { width: parent.width; label: "Depth"; from: 1; to: 6; value: Project.selected() ? (Project.depthScales.indexOf(Project.depthScale(Project.selected().depth)) + 1) : 3; onMoved: (v) => Project.updateSel({ depth: Math.round(v) }) }
            Caption { text: "Drag the ember dot on the preview to aim the zoom." }
            RowRemove {}
        }

        // CUT (direct)
        Group {
            visible: Project.tool === "cut"
            title: "CUT"
            Caption { text: "Drag the in/out handles on the clip lane to mark a section, then remove it. It vanishes from the video and the timeline closes the gap on export." }
            TopBtn { label: "Remove selected section"; on: Project.selStart >= 0 && Project.selEnd > Project.selStart; onTapped: Project.removeSelection() }
            Caption { visible: Project.cuts.length > 0; text: Project.cuts.length + " cut" + (Project.cuts.length === 1 ? "" : "s") + " · click a gap on the clip to restore it" }
        }

        // SPEED
        Group {
            visible: Project.tool === "speed"
            title: "SPEED"
            Caption { text: "Speed up or slow down a span. Add one at the playhead, then set its rate." }
            TopBtn { label: "Add speed region"; on: Project.hasClip; onTapped: Project.addSpeed() }
            Slider {
                visible: Project.selKind === "speed" && Project.selected() !== null
                width: parent.width; label: "Rate"; from: 0.25; to: 5; value: Project.selected() ? Project.selected().speed : 2; decimals: 2; suffix: "×"
                onMoved: (v) => Project.updateSel({ speed: v })
            }
            RowRemove { visible: Project.selKind === "speed" && Project.selected() !== null }
        }

        // TEXT
        Group {
            visible: Project.tool === "text"
            title: "TEXT"
            TopBtn { label: "Add text at playhead"; on: Project.hasClip; onTapped: Project.addText() }
            Field { visible: Project.selKind === "text" && Project.selected() !== null; text: Project.selected() ? Project.selected().text : ""; onEdited: (t) => Project.updateSel({ text: t }) }
            Slider {
                visible: Project.selKind === "text" && Project.selected() !== null
                width: parent.width; label: "Size"; from: 2; to: 15; value: (Project.selected() ? Project.selected().size : 0.06) * 100; suffix: "%"
                onMoved: (v) => Project.updateSel({ size: v / 100 })
            }
            Swatches { visible: Project.selKind === "text" && Project.selected() !== null; colors: insp.inks; sel: Project.selected() ? Project.selected().color : "#ffffff"; onPicked: (i) => Project.updateSel({ color: insp.inks[i] }) }
            Caption { visible: Project.selKind === "text" && Project.selected() !== null; text: "Drag the gold box on the preview to place it." }
            RowRemove { visible: Project.selKind === "text" && Project.selected() !== null }
        }

        // OVERLAY
        Group {
            visible: Project.tool === "overlay"
            title: "OVERLAY"
            Caption { text: "Drop another clip on top -- a webcam, a reaction, a logo loop. Drag the blue box on the preview to place it." }
            TopBtn { label: "Add video overlay…"; on: Project.hasClip; onTapped: ovDialog.open() }
            Caption { visible: Project.selKind === "overlay" && Project.selected() !== null; text: Project.selected() ? Project.selected().name : "" }
            Slider {
                visible: Project.selKind === "overlay" && Project.selected() !== null
                width: parent.width; label: "Size"; from: 10; to: 80; value: (Project.selected() ? Project.selected().scale : 0.34) * 100; suffix: "%"
                onMoved: (v) => Project.updateSel({ scale: v / 100 })
            }
            RowRemove { visible: Project.selKind === "overlay" && Project.selected() !== null }
        }

        // MUSIC
        Group {
            visible: Project.tool === "music"
            title: "MUSIC"
            Caption { text: "Lay a music track under the video; set the level to taste." }
            TopBtn { label: Project.musicPath ? "Change track…" : "Choose track…"; onTapped: musicDialog.open() }
            Caption { visible: Project.musicPath !== ""; text: ("" + Project.musicPath).split("/").pop() }
            Slider { visible: Project.musicPath !== ""; width: parent.width; label: "Volume"; from: 0; to: 100; value: Project.musicVolume * 100; suffix: "%"; onMoved: (v) => Project.musicVolume = v / 100 }
            TopBtn { visible: Project.musicPath !== ""; label: "Remove music"; onTapped: Project.musicPath = "" }
        }

        // EXPORT
        Group {
            visible: Project.tool === "export"
            title: "FORMAT"
            Segmented { width: parent.width; options: ["MP4", "GIF"]; current: Project.format === "mp4" ? 0 : 1; onPicked: (i) => Project.format = i === 0 ? "mp4" : "gif" }
        }
        Group {
            visible: Project.tool === "export"
            title: "QUALITY"
            Segmented { width: parent.width; options: ["Source", "1080p", "720p"]; current: Project.quality === "source" ? 0 : Project.quality === "good" ? 1 : 2; onPicked: (i) => Project.quality = ["source", "good", "medium"][i] }
            Slider { visible: Project.format === "gif"; width: parent.width; label: "GIF fps"; from: 15; to: 30; value: Project.gifFps; onMoved: (v) => Project.gifFps = Math.round(v) }
        }
        Group {
            visible: Project.tool === "export"
            title: "DETAILS"
            Caption {
                text: (Project.hasClip ? "Duration  " + insp.dfmt(Project.durationMs) + "\n" : "")
                    + "Aspect  " + Project.aspect + "\n"
                    + "Zoom " + Project.zooms.length + " · Cut " + Project.cuts.length + " · Speed " + Project.speeds.length + " · Text " + Project.texts.length
            }
        }
        Group {
            visible: Project.tool === "export"
            title: ""
            TopBtn {
                width: parent.width; accent: true
                label: Project.rendering ? "Rendering…" : "Export " + Project.format.toUpperCase()
                on: Project.hasClip && !Project.rendering
                onTapped: exportRequested()
            }
            Caption { visible: Project.lastExport !== ""; text: "Saved  " + ("" + Project.lastExport).split("/").pop() }
        }
    }

    signal exportRequested()
}
