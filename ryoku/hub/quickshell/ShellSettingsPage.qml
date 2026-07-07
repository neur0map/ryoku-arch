pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
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
        "frameRadius", "frameBorder", "frameSmoothing", "frameOpacity",
        "shadowStrength", "shadowSize", "surfaceColor",
        "osdRadius", "osdOpacity",
        "barEnabled", "barPosition", "barStyle", "barHeight",
        "barShowTitle", "barShowMedia", "barShowStatus", "barOccupiedWorkspaces",
        "fontFamily", "fontScale"
    ]
    readonly property var vizKeys: [
        "enabled", "bars", "height", "thickness", "bloom", "reflection", "idleWave",
        "style", "shape", "position", "mirror"
    ]
    readonly property var keys: page.shellKeys.concat(page.vizKeys)

    // mirror of the shells' canonical defaults (pill Singletons/Config.qml +
    // visualizer Singletons/Config.qml). only used for "Reset to defaults".
    readonly property var defaults: ({
        "frameRadius": 9, "frameBorder": 59, "frameSmoothing": 8, "frameOpacity": 1,
        "shadowStrength": 0.63, "shadowSize": 12, "surfaceColor": "#0f1115",
        "osdRadius": 28, "osdOpacity": 1,
        "barEnabled": true, "barPosition": "top", "barStyle": "noctalia", "barHeight": 30,
        "barShowTitle": true, "barShowMedia": true, "barShowStatus": true, "barOccupiedWorkspaces": true,
        "fontFamily": "JetBrainsMono Nerd Font", "fontScale": 1.3,
        "enabled": true, "bars": 64, "height": 0.42, "thickness": 0.58,
        "bloom": 0.6, "reflection": 0.1, "idleWave": true,
        "style": "bars", "shape": "rounded", "position": "bottom", "mirror": false
    })

    property string group: "frame"
    property bool shellLoaded: false
    property bool vizLoaded: false
    readonly property bool ready: page.shellLoaded && page.vizLoaded
    // last saved look. compare against it for dirty state; Revert and
    // leave-without-save restore from this.
    property var committedVals: ({})

    QtObject {
        id: draft
        property real frameRadius: 9
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
        property string fontFamily: "JetBrainsMono Nerd Font"
        property real fontScale: 1.3
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
            property string fontFamily: "JetBrainsMono Nerd Font"
            property real fontScale: 1.3
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
        }
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
        }
    }

    // --- top: section tabs + live hint -------------------------------------
    Segmented {
        id: tabs
        anchors.left: parent.left
        anchors.top: parent.top
        model: [
            { "key": "frame", "label": "Frame" },
            { "key": "bar", "label": "Bar" },
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
            sourceComponent: page.group === "frame" ? frameComp : (page.group === "bar" ? barComp : vizComp)
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
                        width: parent.width; label: "Corner radius"; unit: "px"
                        from: 0; to: 60; value: draft.frameRadius
                        onModified: (v) => page.edit("frameRadius", v)
                    }
                    NumberField {
                        width: parent.width; label: "Border thickness"; unit: "px"
                        from: 24; to: 140; value: draft.frameBorder
                        onModified: (v) => page.edit("frameBorder", v)
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
            }

            Column {
                width: frameRow.colW
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
                        options: ["Inter", "JetBrainsMono Nerd Font", "Noto Sans", "Noto Sans CJK JP"]
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
                    ChoiceRow {
                        width: parent.width; label: "Style"
                        options: [
                            { "key": "noctalia", "label": "Noctalia" },
                            { "key": "caelestia", "label": "Caelestia" }
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
                        text: "A bar riding the top or bottom edge of the frame. Both skins are carried from their namesake shells: Noctalia is the pill-dot dialect, Caelestia the numbered cell strip. Panels grow from the bar edge at whichever module you click or hover, and windows tuck in against the band."
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
                        title: "STYLE"
                        ChoiceRow {
                            width: parent.width; label: "Style"
                            options: [{ "key": "bars", "label": "Bars" }, { "key": "wave", "label": "Wave" }, { "key": "dots", "label": "Dots" }]
                            current: draft.style
                            onChosen: (k) => page.edit("style", k)
                        }
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
