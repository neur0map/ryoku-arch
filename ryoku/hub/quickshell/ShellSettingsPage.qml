pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "Singletons"

// Shell Settings: live editor for the Ryoku shell's look. every edit hits the
// running shell at once via ~/.config/ryoku/shell.json (throttled, atomic),
// which the shell watches. preview = your actual desktop (the frame around
// this window, the bar riding it). Save keeps it; Revert and leaving the
// section put the saved look back. controls match the value: steppers for
// exact pixels, sliders for opacity/feel, swatch for colour.
Item {
    id: page

    readonly property var shellKeys: [
        "frameRadius", "roundness", "frameBorder", "frameSmoothing", "frameOpacity",
        "shadowStrength", "shadowSize", "surfaceColor",
        "osdRadius", "osdOpacity",
        "barEnabled", "barPosition", "barStyle", "barHeight",
        "barShowTitle", "barShowMedia", "barShowStatus", "barOccupiedWorkspaces",
        "islandEdge", "islandAlong", "islandHidden", "islandModules", "islandRadius",
        "fontFamily", "fontScale",
        "weatherLocation", "weatherUnit",
        "sidebarLeftEnabled", "sidebarRightEnabled", "sidebarLeftPanes", "sidebarRightPanes",
        "sidebarClickless", "sidebarWidth", "sidebarCornerSize"
    ]
    readonly property var vizKeys: [
        "enabled", "bars", "height", "thickness", "bloom", "reflection", "idleWave",
        "style", "shape", "position", "mirror", "segments",
        "fps", "adaptive", "smoothing", "gain", "peaks"
    ]
    // brand identity (~/.config/ryoku/brand.json), edited in the Global tab and
    // shared with doctor: the desktop mark + name. Ryoku's own apps
    // keep their brand and ignore these.
    readonly property var brandKeys: ["markText", "markImage", "markTint", "name"]
    readonly property var keys: page.shellKeys.concat(page.vizKeys).concat(page.brandKeys)

    // fonts offered in the Global tab: the popular set people rice with, keyed by
    // the family name fontconfig reports. only the ones actually installed
    // (fontScan below) show, and the list grows as you add your own. curated on
    // purpose, not every family on the system.
    readonly property var fontCatalog: [
        { "key": "JetBrainsMono Nerd Font", "label": "JetBrains Mono", "hint": "nerd" },
        { "key": "FiraCode Nerd Font", "label": "Fira Code", "hint": "nerd" },
        { "key": "Hack Nerd Font", "label": "Hack", "hint": "nerd" },
        { "key": "CaskaydiaCove Nerd Font", "label": "Cascadia Code", "hint": "nerd" },
        { "key": "Iosevka Nerd Font", "label": "Iosevka", "hint": "nerd" },
        { "key": "MesloLGS Nerd Font", "label": "Meslo", "hint": "nerd" },
        { "key": "SauceCodePro Nerd Font", "label": "Source Code Pro", "hint": "nerd" },
        { "key": "UbuntuMono Nerd Font", "label": "Ubuntu Mono", "hint": "nerd" },
        { "key": "RobotoMono Nerd Font", "label": "Roboto Mono", "hint": "nerd" },
        { "key": "BlexMono Nerd Font", "label": "IBM Plex Mono", "hint": "nerd" },
        { "key": "GeistMono Nerd Font", "label": "Geist Mono", "hint": "nerd" },
        { "key": "CommitMono Nerd Font", "label": "Commit Mono", "hint": "nerd" },
        { "key": "Terminess Nerd Font", "label": "Terminus", "hint": "nerd" },
        { "key": "DejaVuSansMono Nerd Font", "label": "DejaVu Sans Mono", "hint": "nerd" },
        { "key": "Maple Mono NF", "label": "Maple Mono", "hint": "nerd" },
        { "key": "Inter", "label": "Inter", "hint": "sans" },
        { "key": "Roboto", "label": "Roboto", "hint": "sans" },
        { "key": "Ubuntu", "label": "Ubuntu", "hint": "sans" },
        { "key": "Cantarell", "label": "Cantarell", "hint": "sans" },
        { "key": "Lexend", "label": "Lexend", "hint": "sans" },
        { "key": "Fira Sans", "label": "Fira Sans", "hint": "sans" },
        { "key": "Noto Sans", "label": "Noto Sans", "hint": "sans" },
        { "key": "Noto Sans CJK JP", "label": "Noto Sans JP", "hint": "cjk" },
        { "key": "Space Grotesk", "label": "Space Grotesk", "hint": "display" },
        { "key": "Fraunces", "label": "Fraunces", "hint": "display" }
    ]
    // families fontconfig reports as installed. seeded with what Ryoku ships so
    // the picker is sane before the scan returns; fontScan replaces it.
    property var installedFonts: ["JetBrainsMono Nerd Font", "Inter", "Noto Sans", "Noto Sans CJK JP", "Fraunces", "Space Grotesk"]
    // the catalog filtered to installed, with the current selection always kept
    // (a hand-set custom family still shows and stays selected).
    readonly property var fontOptions: {
        var out = [];
        var curInCatalog = false;
        for (var i = 0; i < page.fontCatalog.length; i++) {
            var f = page.fontCatalog[i];
            if (f.key === draft.fontFamily) { curInCatalog = true; out.push(f); continue; }
            if (page.installedFonts.indexOf(f.key) >= 0) out.push(f);
        }
        if (!curInCatalog && draft.fontFamily && draft.fontFamily.length > 0)
            out.unshift({ "key": draft.fontFamily, "label": draft.fontFamily, "hint": "custom" });
        return out;
    }

    // mirror of the shells' canonical defaults (pill Singletons/Config.qml +
    // visualizer Singletons/Config.qml). only used for "Reset to defaults".
    readonly property var defaults: ({
        "frameRadius": 9, "roundness": 10, "frameBorder": 59, "frameSmoothing": 8, "frameOpacity": 1,
        "shadowStrength": 0.63, "shadowSize": 12, "surfaceColor": "#0f1115",
        "osdRadius": 28, "osdOpacity": 1,
        "barEnabled": true, "barPosition": "top", "barStyle": "noctalia", "barHeight": 30,
        "barShowTitle": true, "barShowMedia": true, "barShowStatus": true, "barOccupiedWorkspaces": true,
        "islandEdge": "top", "islandAlong": -1, "islandHidden": false, "islandModules": ["workspaces", "clock", "date", "media"], "islandRadius": 17,
        "fontFamily": "JetBrainsMono Nerd Font", "fontScale": 1.3,
        "weatherLocation": "", "weatherUnit": "auto",
        "sidebarLeftEnabled": true, "sidebarRightEnabled": true, "sidebarLeftPanes": ["stash"], "sidebarRightPanes": ["notifications", "calendar", "media", "weather", "recording"],
        "sidebarClickless": true, "sidebarWidth": 340, "sidebarCornerSize": 34,
        "enabled": true, "bars": 64, "height": 0.42, "thickness": 0.58,
        "bloom": 0.6, "reflection": 0.1, "idleWave": true,
        "style": "bars", "shape": "rounded", "position": "bottom", "mirror": false,
        "segments": 10, "fps": 30, "adaptive": true, "smoothing": 0.5, "gain": 1.0, "peaks": false,
        "markText": "\u529b", "markImage": "", "markTint": true, "name": "Ryoku"
    })

    property string group: "frame"
    property bool shellLoaded: false
    property bool vizLoaded: false
    property bool brandLoaded: false
    readonly property bool ready: page.shellLoaded && page.vizLoaded && page.brandLoaded
    // last saved look. compare against it for dirty state; Revert and
    // leave-without-save restore from this.
    property var committedVals: ({})

    QtObject {
        id: draft
        property real frameRadius: 9
        property real roundness: 10
        property real frameBorder: 59
        property real frameSmoothing: 8
        property real frameOpacity: 1
        property real shadowStrength: 0.63
        property real shadowSize: 12
        property color surfaceColor: "#0f1115"
        property real osdRadius: 28
        property real osdOpacity: 1
        property bool barEnabled: true
        property string barPosition: "top"
        property string barStyle: "noctalia"
        property real barHeight: 30
        property bool barShowTitle: true
        property bool barShowMedia: true
        property bool barShowStatus: true
        property bool barOccupiedWorkspaces: true
        property string islandEdge: "top"
        property real islandAlong: -1
        property bool islandHidden: false
        property var islandModules: ["workspaces", "clock", "date", "media"]
        property real islandRadius: 17
        property string fontFamily: "JetBrainsMono Nerd Font"
        property real fontScale: 1.3
        property string weatherLocation: ""
        property string weatherUnit: "auto"
        property bool sidebarLeftEnabled: true
        property bool sidebarRightEnabled: true
        property var sidebarLeftPanes: ["stash"]
        property var sidebarRightPanes: ["notifications", "calendar", "media", "weather", "recording"]
        property bool sidebarClickless: true
        property real sidebarWidth: 340
        property real sidebarCornerSize: 34
        property bool enabled: true
        property int bars: 64
        property real height: 0.42
        property real thickness: 0.58
        property real bloom: 0.6
        property real reflection: 0.1
        property bool idleWave: true
        property string style: "bars"
        property string shape: "rounded"
        property string position: "bottom"
        property bool mirror: false
        property int segments: 10
        property int fps: 30
        property bool adaptive: true
        property real smoothing: 0.5
        property real gain: 1.0
        property bool peaks: false
        property string markText: "\u529b"
        property string markImage: ""
        property bool markTint: true
        property string name: "Ryoku"
    }

    function sameVal(a, b) { return String(a) === String(b); }

    readonly property bool dirty: {
        if (!page.ready)
            return false;
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            if (!page.sameVal(draft[k], page.committedVals[k]))
                return true;
        }
        return false;
    }

    // pull a file's keys into draft + the committed baseline (fresh object
    // each time so bindings on the baseline re-evaluate).
    function adopt(keyset, adptr) {
        var c = {};
        for (var k in page.committedVals)
            c[k] = page.committedVals[k];
        for (var i = 0; i < keyset.length; i++) {
            var kk = keyset[i];
            draft[kk] = adptr[kk];
            c[kk] = adptr[kk];
        }
        page.committedVals = c;
    }

    // a later external write (the shell deck flipping the visualizer on/off)
    // reloaded into the adapter. pull it into any key the user hasn't locally
    // edited and move that key's baseline forward, leaving edited keys' drafts
    // and baselines untouched.
    function adoptExternal(keyset, adptr) {
        var c = {};
        for (var k in page.committedVals)
            c[k] = page.committedVals[k];
        for (var i = 0; i < keyset.length; i++) {
            var kk = keyset[i];
            if (page.sameVal(draft[kk], page.committedVals[kk])) {
                draft[kk] = adptr[kk];
                c[kk] = adptr[kk];
            }
        }
        page.committedVals = c;
    }

    function flush() {
        var i, k;
        for (i = 0; i < page.shellKeys.length; i++) { k = page.shellKeys[i]; shellA[k] = draft[k]; }
        cfgShell.writeAdapter();
        for (i = 0; i < page.vizKeys.length; i++) { k = page.vizKeys[i]; vizA[k] = draft[k]; }
        cfgViz.writeAdapter();
        for (i = 0; i < page.brandKeys.length; i++) { k = page.brandKeys[i]; brandA[k] = draft[k]; }
        cfgBrand.writeAdapter();
    }

    // throttle live writes: apply immediately, then at most once per interval
    // while the value keeps changing, with a trailing write. drag stays smooth
    // without thrashing the files.
    property bool writePending: false
    Timer {
        id: throttle
        interval: 70
        onTriggered: {
            if (page.writePending) {
                page.writePending = false;
                page.flush();
                throttle.restart();
            }
        }
    }
    function edit(k, v) {
        draft[k] = v;
        if (throttle.running) {
            page.writePending = true;
        } else {
            page.flush();
            throttle.start();
        }
    }

    // islandModules is a list; toggle a module's membership and write it back.
    function toggleIslandModule(id, on) {
        var l = (draft.islandModules || []).slice();
        var i = l.indexOf(id);
        if (on && i < 0) l.push(id);
        else if (!on && i >= 0) l.splice(i, 1);
        page.edit("islandModules", l);
    }

    // each sidebar's panes is an ordered list; toggle a pane's membership on
    // that side and write it back (enable appends to the end, disable removes).
    function toggleSidebarPane(sideKey, id, on) {
        var l = (draft[sideKey] || []).slice();
        var i = l.indexOf(id);
        if (on && i < 0) l.push(id);
        else if (!on && i >= 0) l.splice(i, 1);
        page.edit(sideKey, l);
    }

    function snapshotDraft() {
        var s = {};
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            s[k] = draft[k];
        }
        return s;
    }
    function save() {
        throttle.stop();
        page.writePending = false;
        page.flush();
        page.committedVals = page.snapshotDraft();
    }
    function revert() {
        throttle.stop();
        page.writePending = false;
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            draft[k] = page.committedVals[k];
        }
        page.flush();
    }
    function resetDefaults() {
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            page.edit(k, page.defaults[k]);
        }
    }

    // enumerate installed font families so the picker only offers fonts that will
    // actually render. one fc-list pass on open; the family is the token before
    // the first comma on each line.
    Process {
        id: fontScan
        command: ["fc-list", ":", "family"]
        Component.onCompleted: running = true
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var seen = ({});
                var list = [];
                for (var i = 0; i < lines.length; i++) {
                    var fam = lines[i].split(",")[0].trim();
                    if (fam.length > 0 && !seen[fam]) { seen[fam] = true; list.push(fam); }
                }
                if (list.length > 0)
                    page.installedFonts = list;
            }
        }
    }

    FileView {
        id: cfgShell
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
        blockLoading: true
        watchChanges: false
        printErrors: false
        atomicWrites: true
        onLoaded: { if (!page.shellLoaded) { page.adopt(page.shellKeys, shellA); page.shellLoaded = true; } }
        onLoadFailed: { if (!page.shellLoaded) { page.adopt(page.shellKeys, shellA); page.shellLoaded = true; } }

        JsonAdapter {
            id: shellA
            property real frameRadius: 9
            property real roundness: 10
            property real frameBorder: 59
            property real frameSmoothing: 8
            property real frameOpacity: 1
            property real shadowStrength: 0.63
            property real shadowSize: 12
            property color surfaceColor: "#0f1115"
            property real osdRadius: 28
            property real osdOpacity: 1
            property bool barEnabled: true
            property string barPosition: "top"
            property string barStyle: "noctalia"
            property real barHeight: 30
            property bool barShowTitle: true
            property bool barShowMedia: true
            property bool barShowStatus: true
            property bool barOccupiedWorkspaces: true
            property string islandEdge: "top"
            property real islandAlong: -1
            property bool islandHidden: false
            property var islandModules: ["workspaces", "clock", "date", "media"]
            property real islandRadius: 17
            property string fontFamily: "JetBrainsMono Nerd Font"
            property real fontScale: 1.3
            property string weatherLocation: ""
            property string weatherUnit: "auto"
            property bool sidebarLeftEnabled: true
            property bool sidebarRightEnabled: true
            property var sidebarLeftPanes: ["stash"]
            property var sidebarRightPanes: ["notifications", "calendar", "media", "weather", "recording"]
            property bool sidebarClickless: true
            property real sidebarWidth: 340
            property real sidebarCornerSize: 34
        }
    }

    FileView {
        id: cfgViz
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/visualizer.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: { if (!page.vizLoaded) { page.adopt(page.vizKeys, vizA); page.vizLoaded = true; } else { page.adoptExternal(page.vizKeys, vizA); } }
        onLoadFailed: { if (!page.vizLoaded) { page.adopt(page.vizKeys, vizA); page.vizLoaded = true; } }

        JsonAdapter {
            id: vizA
            property bool enabled: true
            property int bars: 64
            property real height: 0.42
            property real thickness: 0.58
            property real bloom: 0.6
            property real reflection: 0.1
            property bool idleWave: true
            property string style: "bars"
            property string shape: "rounded"
            property string position: "bottom"
            property bool mirror: false
            property int segments: 10
            property int fps: 30
            property bool adaptive: true
            property real smoothing: 0.5
            property real gain: 1.0
            property bool peaks: false
        }
    }

    // brand identity master, edited live like the shell/viz configs; the running
    // shell reads it. Ryoku's own apps ignore it and keep their brand.
    FileView {
        id: cfgBrand
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/brand.json"
        blockLoading: true
        watchChanges: false
        printErrors: false
        atomicWrites: true
        onLoaded: { if (!page.brandLoaded) { page.adopt(page.brandKeys, brandA); page.brandLoaded = true; } }
        onLoadFailed: { if (!page.brandLoaded) { page.adopt(page.brandKeys, brandA); page.brandLoaded = true; } }

        JsonAdapter {
            id: brandA
            property string markText: "\u529b"
            property string markImage: ""
            property bool markTint: true
            property string name: "Ryoku"
        }
    }

    // OS file picker for a custom logo image (SVG or raster).
    FileDialog {
        id: logoPicker
        title: "Choose a logo image"
        nameFilters: ["Images (*.svg *.png *.jpg *.jpeg *.webp)", "All files (*)"]
        onAccepted: page.edit("markImage", "" + logoPicker.selectedFile)
    }

    // leaving the section (or closing the hub) with unsaved edits puts the
    // saved look back, so a preview is never left applied by accident.
    Component.onDestruction: {
        if (page.ready && page.dirty) {
            var i, k;
            for (i = 0; i < page.shellKeys.length; i++) { k = page.shellKeys[i]; shellA[k] = page.committedVals[k]; }
            cfgShell.writeAdapter();
            for (i = 0; i < page.vizKeys.length; i++) { k = page.vizKeys[i]; vizA[k] = page.committedVals[k]; }
            cfgViz.writeAdapter();
            for (i = 0; i < page.brandKeys.length; i++) { k = page.brandKeys[i]; brandA[k] = page.committedVals[k]; }
            cfgBrand.writeAdapter();
        }
    }

    // --- top: section tabs + live hint -------------------------------------
    Segmented {
        id: tabs
        anchors.left: parent.left
        anchors.top: parent.top
        model: [
            { "key": "frame", "label": "Frame" },
            { "key": "global", "label": "Global" },
            { "key": "bar", "label": "Bar" },
            { "key": "sidebar", "label": "Sidebar" },
            { "key": "visualizer", "label": "Visualizer" }
        ]
        current: page.group
        onSelected: (k) => page.group = k
    }

    Text {
        anchors.left: tabs.right
        anchors.leftMargin: 18
        anchors.verticalCenter: tabs.verticalCenter
        text: "Edits show on your desktop as you make them"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    // --- controls ----------------------------------------------------------
    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: tabs.bottom
        anchors.topMargin: 26
        anchors.bottom: bar.top
        anchors.bottomMargin: 18
        contentWidth: width
        contentHeight: Math.max(loader.height, height)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: sb
            policy: ScrollBar.AsNeeded
            width: 7
            contentItem: Rectangle {
                implicitWidth: 4
                radius: Theme.radius
                color: Theme.line
                opacity: sb.pressed ? 0.9 : (sb.hovered ? 0.7 : 0.4)
                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
            }
        }

        Loader {
            id: loader
            width: flick.width - 12
            height: item ? item.implicitHeight : 0
        sourceComponent: page.group === "frame" ? frameComp : (page.group === "global" ? globalComp : (page.group === "bar" ? barComp : (page.group === "sidebar" ? sidebarComp : vizComp)))
            onLoaded: {
                if (!item)
                    return;
                item.opacity = 0;
                fade.restart();
            }
        }

        NumberAnimation { id: fade; target: loader.item; property: "opacity"; to: 1; duration: Theme.medium; easing.type: Theme.ease }
    }

    Component {
        id: frameComp
        Row {
            id: frameRow
            spacing: 56
            readonly property real colW: (width - spacing) / 2

            Column {
                width: frameRow.colW
                spacing: 30

                SettingSection {
                    width: parent.width
                    title: "SHAPE"
                    NumberField {
                        width: parent.width; label: "Border thickness"; unit: "px"
                        from: 24; to: 140; value: draft.frameBorder
                        onModified: (v) => page.edit("frameBorder", v)
                    }
                }
            }

            Column {
                width: frameRow.colW
                spacing: 30

                SettingSection {
                    width: parent.width
                    title: "NOTIFICATIONS"
                    NumberField {
                        width: parent.width; label: "OSD & toast corner"; unit: "px"
                        from: 0; to: 40; value: draft.osdRadius
                        onModified: (v) => page.edit("osdRadius", v)
                    }
                    SliderRow {
                        width: parent.width; label: "Opacity"; percent: true
                        from: 0.2; to: 1; step: 0.01; value: draft.osdOpacity
                        onModified: (v) => page.edit("osdOpacity", v)
                    }
                }
            }
        }
    }

    Component {
        id: globalComp
        Row {
            id: globalRow
            spacing: 56
            readonly property real colW: (width - spacing) / 2

            Column {
                width: globalRow.colW
                spacing: 30

                SettingSection {
                    width: parent.width
                    title: "ROUNDNESS"
                    NumberField {
                        width: parent.width; label: "Inner roundness"; unit: "px"
                        from: 0; to: 24; value: draft.roundness
                        onModified: (v) => page.edit("roundness", v)
                    }
                    NumberField {
                        width: parent.width; label: "Frame corner"; unit: "px"
                        from: 0; to: 60; value: draft.frameRadius
                        onModified: (v) => page.edit("frameRadius", v)
                    }
                    SliderRow {
                        width: parent.width; label: "Edge melt"
                        from: 1; to: 60; step: 1; decimals: 0; value: draft.frameSmoothing
                        onModified: (v) => page.edit("frameSmoothing", v)
                    }
                }

                SettingSection {
                    width: parent.width
                    title: "SHADOW"
                    SliderRow {
                        width: parent.width; label: "Strength"; percent: true
                        from: 0; to: 1; step: 0.01; value: draft.shadowStrength
                        onModified: (v) => page.edit("shadowStrength", v)
                    }
                    NumberField {
                        width: parent.width; label: "Size"; unit: "px"
                        from: 0; to: 80; value: draft.shadowSize
                        onModified: (v) => page.edit("shadowSize", v)
                    }
                }

                SettingSection {
                    width: parent.width
                    title: "BRAND"
                    Row {
                        width: parent.width
                        spacing: 14
                        Rectangle {
                            width: 46; height: 46; radius: Theme.radius
                            color: Theme.surface
                            border.width: 1; border.color: Theme.line
                            Text {
                                visible: draft.markImage === ""
                                anchors.centerIn: parent
                                text: draft.markText.length > 0 ? draft.markText : "\u529b"
                                color: Theme.brand
                                font.family: Theme.fontJp
                                font.pixelSize: 26
                            }
                            Image {
                                id: prevImg
                                visible: draft.markImage !== "" && !draft.markTint
                                anchors.centerIn: parent
                                width: 30; height: 30
                                source: draft.markImage === "" ? "" : (draft.markImage.startsWith("file:") ? draft.markImage : "file://" + draft.markImage)
                                fillMode: Image.PreserveAspectFit
                                sourceSize.width: 60; sourceSize.height: 60
                                smooth: true
                            }
                            ColorOverlay {
                                anchors.fill: prevImg
                                visible: draft.markImage !== "" && draft.markTint
                                source: prevImg
                                color: Theme.brand
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Preview"
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                    SettingField {
                        width: parent.width; label: "Name"
                        fieldWidth: 200
                        placeholder: "Ryoku"
                        value: draft.name
                        onCommitted: (v) => page.edit("name", v)
                    }
                    SettingField {
                        width: parent.width; label: "Text mark"
                        fieldWidth: 200
                        placeholder: "\u529b"
                        value: draft.markText
                        onCommitted: (v) => page.edit("markText", v)
                    }
                    Row {
                        width: parent.width
                        spacing: 12
                        Text {
                            width: parent.width - chooseLogo.width - clearLogo.width - 24
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideMiddle
                            text: draft.markImage === "" ? "No image (using the text mark)" : draft.markImage
                            color: draft.markImage === "" ? Theme.faint : Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                        HubButton {
                            id: chooseLogo
                            anchors.verticalCenter: parent.verticalCenter
                            label: "Choose image"
                            icon: "image"
                            onClicked: logoPicker.open()
                        }
                        HubButton {
                            id: clearLogo
                            anchors.verticalCenter: parent.verticalCenter
                            label: "Clear"
                            icon: "close"
                            enabled: draft.markImage !== ""
                            onClicked: page.edit("markImage", "")
                        }
                    }
                    ToggleRow {
                        width: parent.width; label: "Tint image to accent"
                        checked: draft.markTint
                        onToggled: (v) => page.edit("markTint", v)
                    }
                    Text {
                        width: Math.min(parent.width, 620)
                        wrapMode: Text.WordWrap
                        text: "Swaps the \u529b mark and \"Ryoku\" name across the desktop shell: the bar, launcher, and the rest of the chrome. Ryoku's own apps (this one, ryowalls, ryovm) keep their brand. For an image: a square SVG (crisp at any size) or a PNG at least 256\u00d7256, transparent background. A single-colour mark tints to your accent; turn tint off to show a full-colour logo as-is. It renders as small as ~14px, so keep it simple. Leave the image empty to use the text mark."
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }
            }

            Column {
                width: globalRow.colW
                spacing: 30

                SettingSection {
                    width: parent.width
                    title: "SURFACE"
                    ColorField {
                        width: parent.width; label: "Colour"
                        value: draft.surfaceColor
                        onModified: (v) => page.edit("surfaceColor", v)
                    }
                    SliderRow {
                        width: parent.width; label: "Opacity"; percent: true
                        from: 0.2; to: 1; step: 0.01; value: draft.frameOpacity
                        onModified: (v) => page.edit("frameOpacity", v)
                    }
                }

                SettingSection {
                    width: parent.width
                    title: "TEXT"
                    Dropdown {
                        width: parent.width; label: "Font"
                        fieldWidth: 200
                        options: page.fontOptions
                        current: draft.fontFamily
                        onChosen: (k) => page.edit("fontFamily", k)
                    }
                    SliderRow {
                        width: parent.width; label: "Size"; percent: true
                        from: 0.7; to: 1.6; step: 0.05; value: draft.fontScale
                        onModified: (v) => page.edit("fontScale", v)
                    }
                }
                SettingSection {
                    width: parent.width
                    title: "WEATHER"
                    SettingField {
                        width: parent.width; label: "Location"
                        fieldWidth: 200
                        placeholder: "Auto (from IP)"
                        value: draft.weatherLocation
                        onCommitted: (v) => page.edit("weatherLocation", v)
                    }
                    ChoiceRow {
                        width: parent.width; label: "Units"
                        options: [{ "key": "auto", "label": "Auto" }, { "key": "celsius", "label": "\u00b0C" }, { "key": "fahrenheit", "label": "\u00b0F" }]
                        current: draft.weatherUnit
                        onChosen: (k) => page.edit("weatherUnit", k)
                    }
                }
            }
        }
    }

    Component {
        id: barComp
        Row {
            id: barRow
            spacing: 56
            readonly property real colW: (width - spacing) / 2

            Column {
                width: barRow.colW
                spacing: 30

                SettingSection {
                    width: parent.width
                    title: "BAR"
                    ToggleRow {
                        width: parent.width; label: "Enable bar"
                        checked: draft.barEnabled
                        onToggled: (v) => page.edit("barEnabled", v)
                    }
                    ChoiceRow {
                        width: parent.width; label: "Position"
                        options: [
                            { "key": "top", "label": "Top" },
                            { "key": "bottom", "label": "Bottom" },
                        ]
                        current: draft.barPosition
                        onChosen: (k) => page.edit("barPosition", k)
                    }
                    Dropdown {
                        width: parent.width; label: "Style"
                        fieldWidth: 170
                        options: [
                            { "key": "noctalia", "label": "Noctalia", "hint": "pill · dot" },
                            { "key": "caelestia", "label": "Caelestia", "hint": "cell strip" },
                            { "key": "aegis", "label": "Aegis", "hint": "instrument" },
                            { "key": "stele", "label": "Stele", "hint": "engraved" },
                            { "key": "triptych", "label": "Triptych", "hint": "islands" },
                            { "key": "delos", "label": "Delos", "hint": "one island" }
                        ]
                        current: draft.barStyle
                        onChosen: (k) => page.edit("barStyle", k)
                    }
                    NumberField {
                        width: parent.width; label: "Thickness"; unit: "px"
                        from: 18; to: 48; value: draft.barHeight
                        onModified: (v) => page.edit("barHeight", v)
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "A bar riding the top or bottom edge of the frame. Noctalia (pill and dot) and Caelestia (numbered cell strip) are carried from their namesake shells; Aegis is a flat instrument panel with hairline accent underlines, Stele an engraved strip of bracketed cells, and Triptych groups the modules into three rounded islands riding the band. Panels grow from the bar edge at whichever module you click or hover, and windows tuck in against the band."
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }
            }

            Column {
                width: barRow.colW
                spacing: 30

                SettingSection {
                    width: parent.width
                    title: "CONTENT"
                    ToggleRow {
                        width: parent.width; label: "Focused window title"
                        checked: draft.barShowTitle
                        onToggled: (v) => page.edit("barShowTitle", v)
                    }
                    ToggleRow {
                        width: parent.width; label: "Now playing"
                        checked: draft.barShowMedia
                        onToggled: (v) => page.edit("barShowMedia", v)
                    }
                    ToggleRow {
                        width: parent.width; label: "Status glyphs (network, battery, inbox)"
                        checked: draft.barShowStatus
                        onToggled: (v) => page.edit("barShowStatus", v)
                    }
                    ToggleRow {
                        width: parent.width; label: "Only occupied workspaces"
                        checked: draft.barOccupiedWorkspaces
                        onToggled: (v) => page.edit("barOccupiedWorkspaces", v)
                    }
                }

                SettingSection {
                    width: parent.width
                    visible: draft.barStyle === "delos"
                    title: "ISLAND"
                    NumberField {
                        width: parent.width; label: "Roundness"; unit: "px"
                        from: 0; to: 40; value: draft.islandRadius
                        onModified: (v) => page.edit("islandRadius", v)
                    }
                    ToggleRow { width: parent.width; label: "Workspaces"; checked: (draft.islandModules || []).indexOf("workspaces") >= 0; onToggled: (v) => page.toggleIslandModule("workspaces", v) }
                    ToggleRow { width: parent.width; label: "Clock"; checked: (draft.islandModules || []).indexOf("clock") >= 0; onToggled: (v) => page.toggleIslandModule("clock", v) }
                    ToggleRow { width: parent.width; label: "Date"; checked: (draft.islandModules || []).indexOf("date") >= 0; onToggled: (v) => page.toggleIslandModule("date", v) }
                    ToggleRow { width: parent.width; label: "Now playing"; checked: (draft.islandModules || []).indexOf("media") >= 0; onToggled: (v) => page.toggleIslandModule("media", v) }
                    ToggleRow { width: parent.width; label: "Window title"; checked: (draft.islandModules || []).indexOf("title") >= 0; onToggled: (v) => page.toggleIslandModule("title", v) }
                    ToggleRow { width: parent.width; label: "Status glyphs"; checked: (draft.islandModules || []).indexOf("status") >= 0; onToggled: (v) => page.toggleIslandModule("status", v) }
                    ToggleRow { width: parent.width; label: "Tray"; checked: (draft.islandModules || []).indexOf("tray") >= 0; onToggled: (v) => page.toggleIslandModule("tray", v) }
                }
            }
        }
    }

    Component {
        id: sidebarComp
        Row {
            id: sbRow
            spacing: 56
            readonly property real colW: (width - spacing) / 2

            Column {
                width: sbRow.colW
                spacing: 30

                SettingSection {
                    width: parent.width
                    title: "LEFT \u00b7 FEATURES"
                    ToggleRow {
                        width: parent.width; label: "Enable left sidebar"
                        checked: draft.sidebarLeftEnabled
                        onToggled: (v) => page.edit("sidebarLeftEnabled", v)
                    }
                    ToggleRow { width: parent.width; label: "Stash"; checked: (draft.sidebarLeftPanes || []).indexOf("stash") >= 0; onToggled: (v) => page.toggleSidebarPane("sidebarLeftPanes", "stash", v) }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Melts out of the frame's left edge when you hover (or click) the top-left corner, carrying your chosen feature panes as tabs in the order you enable them."
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }

                SettingSection {
                    width: parent.width
                    title: "BEHAVIOUR"
                    ToggleRow {
                        width: parent.width; label: "Open on hover"
                        checked: draft.sidebarClickless
                        onToggled: (v) => page.edit("sidebarClickless", v)
                    }
                }
            }

            Column {
                width: sbRow.colW
                spacing: 30

                SettingSection {
                    width: parent.width
                    title: "RIGHT \u00b7 SYSTEM"
                    ToggleRow {
                        width: parent.width; label: "Enable right sidebar"
                        checked: draft.sidebarRightEnabled
                        onToggled: (v) => page.edit("sidebarRightEnabled", v)
                    }
                    ToggleRow { width: parent.width; label: "Notifications"; checked: (draft.sidebarRightPanes || []).indexOf("notifications") >= 0; onToggled: (v) => page.toggleSidebarPane("sidebarRightPanes", "notifications", v) }
                    ToggleRow { width: parent.width; label: "Calendar"; checked: (draft.sidebarRightPanes || []).indexOf("calendar") >= 0; onToggled: (v) => page.toggleSidebarPane("sidebarRightPanes", "calendar", v) }
                    ToggleRow { width: parent.width; label: "Media"; checked: (draft.sidebarRightPanes || []).indexOf("media") >= 0; onToggled: (v) => page.toggleSidebarPane("sidebarRightPanes", "media", v) }
                    ToggleRow { width: parent.width; label: "Weather"; checked: (draft.sidebarRightPanes || []).indexOf("weather") >= 0; onToggled: (v) => page.toggleSidebarPane("sidebarRightPanes", "weather", v) }
                    ToggleRow { width: parent.width; label: "Recording"; checked: (draft.sidebarRightPanes || []).indexOf("recording") >= 0; onToggled: (v) => page.toggleSidebarPane("sidebarRightPanes", "recording", v) }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Melts out of the frame's right edge when you hover (or click) the top-right corner, carrying your chosen system panes as tabs in the order you enable them."
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }

                SettingSection {
                    width: parent.width
                    title: "SIZE"
                    NumberField {
                        width: parent.width; label: "Width"; unit: "px"
                        from: 240; to: 520; value: draft.sidebarWidth
                        onModified: (v) => page.edit("sidebarWidth", v)
                    }
                    NumberField {
                        width: parent.width; label: "Corner hotspot"; unit: "px"
                        from: 16; to: 80; value: draft.sidebarCornerSize
                        onModified: (v) => page.edit("sidebarCornerSize", v)
                    }
                }
            }
        }
    }

    Component {
        id: vizComp
        Column {
            id: vizCol
            spacing: 22

            // live preview window. the styles hide behind your windows on the
            // real desktop, so the viz tab previews them here instead.
            Rectangle {
                width: vizCol.width
                height: 150
                radius: Theme.radius
                color: Theme.surfaceLo
                border.width: 1
                border.color: Theme.line
                clip: true

                VizPreview {
                    anchors.fill: parent
                    anchors.margins: 1
                    style: draft.style
                    shape: draft.shape
                    position: draft.position
                    mirror: draft.mirror
                    bars: draft.bars
                    heightFrac: draft.height
                    thickness: draft.thickness
                    bloom: draft.bloom
                    reflection: draft.reflection
                    enabled: draft.enabled
                    peaks: draft.peaks
                    segments: draft.segments
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 12
                    width: previewTag.width + 18
                    height: 20
                    radius: Theme.radius
                    color: Qt.rgba(0, 0, 0, 0.4)
                    Text {
                        id: previewTag
                        anchors.centerIn: parent
                        text: draft.enabled ? "LIVE PREVIEW" : "OFF"
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2
                    }
                }
            }

            SettingSection {
                width: vizCol.width
                title: "STYLE"
                ChoiceRow {
                    width: parent.width; label: "Style"
                    options: [{ "key": "bars", "label": "Bars" }, { "key": "dots", "label": "Dots" }, { "key": "line", "label": "Line" }, { "key": "wave", "label": "Wave" }, { "key": "segments", "label": "Segments" }, { "key": "radial", "label": "Radial" }, { "key": "circle", "label": "Circle" }]
                    current: draft.style
                    onChosen: (k) => page.edit("style", k)
                }
            }

            Row {
                id: vizRow
                width: vizCol.width
                spacing: 56
                readonly property real colW: (width - spacing) / 2

                Column {
                    width: vizRow.colW
                    spacing: 30

                    SettingSection {
                        width: parent.width
                        title: "LAYOUT"
                        ChoiceRow {
                            width: parent.width; label: "Position"
                            options: [{ "key": "bottom", "label": "Bottom" }, { "key": "top", "label": "Top" }, { "key": "center", "label": "Centre" }]
                            current: draft.position
                            onChosen: (k) => page.edit("position", k)
                        }
                        ChoiceRow {
                            width: parent.width; label: "Shape"
                            options: [{ "key": "rounded", "label": "Rounded" }, { "key": "flat", "label": "Flat" }]
                            current: draft.shape
                            onChosen: (k) => page.edit("shape", k)
                        }
                        ToggleRow {
                            width: parent.width; label: "Mirror"
                            checked: draft.mirror
                            onToggled: (v) => page.edit("mirror", v)
                        }
                    }

                    SettingSection {
                        width: parent.width
                        title: "SPECTRUM"
                        ToggleRow {
                            width: parent.width; label: "Enabled"
                            checked: draft.enabled
                            onToggled: (v) => page.edit("enabled", v)
                        }
                        NumberField {
                            width: parent.width; label: "Bars"
                            from: 16; to: 128; step: 4; value: draft.bars
                            onModified: (v) => page.edit("bars", v)
                        }
                        NumberField {
                            width: parent.width; label: "Segments"
                            from: 4; to: 16; value: draft.segments
                            onModified: (v) => page.edit("segments", v)
                        }
                        ToggleRow {
                            width: parent.width; label: "Peak caps"
                            checked: draft.peaks
                            onToggled: (v) => page.edit("peaks", v)
                        }
                    }
                }

                Column {
                    width: vizRow.colW
                    spacing: 30

                    SettingSection {
                        width: parent.width
                        title: "SIZE"
                        SliderRow {
                            width: parent.width; label: "Height"; percent: true
                            from: 0.1; to: 0.6; step: 0.01; value: draft.height
                            onModified: (v) => page.edit("height", v)
                        }
                        SliderRow {
                            width: parent.width; label: "Bar width"; percent: true
                            from: 0.2; to: 1; step: 0.01; value: draft.thickness
                            onModified: (v) => page.edit("thickness", v)
                        }
                    }

                    SettingSection {
                        width: parent.width
                        title: "GLOW"
                        SliderRow {
                            width: parent.width; label: "Bloom"; percent: true
                            from: 0; to: 1; step: 0.01; value: draft.bloom
                            onModified: (v) => page.edit("bloom", v)
                        }
                        SliderRow {
                            width: parent.width; label: "Reflection"; percent: true
                            from: 0; to: 0.3; step: 0.01; value: draft.reflection
                            onModified: (v) => page.edit("reflection", v)
                        }
                    }

                    SettingSection {
                        width: parent.width
                        title: "FEEL"
                        SliderRow {
                            width: parent.width; label: "Smoothing"; percent: true
                            from: 0; to: 1; step: 0.01; value: draft.smoothing
                            onModified: (v) => page.edit("smoothing", v)
                        }
                        SliderRow {
                            width: parent.width; label: "Sensitivity"; percent: true
                            from: 0.5; to: 2; step: 0.01; value: draft.gain
                            onModified: (v) => page.edit("gain", v)
                        }
                    }

                    SettingSection {
                        width: parent.width
                        title: "MOTION"
                        ChoiceRow {
                            width: parent.width; label: "Frame rate"
                            options: [{ "key": "30", "label": "30" }, { "key": "45", "label": "45" }, { "key": "60", "label": "60" }]
                            current: String(draft.fps)
                            onChosen: (k) => page.edit("fps", parseInt(k))
                        }
                        ToggleRow {
                            width: parent.width; label: "Adaptive quality"
                            checked: draft.adaptive
                            onToggled: (v) => page.edit("adaptive", v)
                        }
                    }

                    SettingSection {
                        width: parent.width
                        title: "AT REST"
                        ToggleRow {
                            width: parent.width; label: "Idle wave"
                            checked: draft.idleWave
                            onToggled: (v) => page.edit("idleWave", v)
                        }
                    }
                }
            }
        }
    }

    // --- bottom: status + actions ------------------------------------------
    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        height: 60
        radius: Theme.radius
        color: page.dirty ? Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.08) : Theme.surfaceLo
        border.width: 1
        border.color: page.dirty ? Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.4) : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.medium } }
        Behavior on border.color { ColorAnimation { duration: Theme.medium } }

        Rectangle {
            id: statusDot
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 9
            height: 9
            radius: 4.5
            color: page.dirty ? Theme.ember : Theme.ok
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }

        Text {
            anchors.left: statusDot.right
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: page.dirty ? "Previewing unsaved changes" : "Saved \u00b7 live on your desktop"
            color: page.dirty ? Theme.bright : Theme.dim
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Reset to defaults"
                icon: "refresh"
                onClicked: page.resetDefaults()
            }
            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Revert"
                icon: "close"
                enabled: page.dirty
                onClicked: page.revert()
            }
            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Save"
                icon: "check"
                primary: true
                enabled: page.dirty
                onClicked: page.save()
            }
        }
    }
}
