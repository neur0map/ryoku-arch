.pragma library

// ShellSettingsPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "frame",
        "group": "SHAPE",
        "key": "frameEnabled",
        "label": "Enable frame",
        "desc": "",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "frame",
        "group": "SHAPE",
        "key": "frameBorder",
        "label": "Border thickness",
        "desc": "",
        "ctl": "step",
        "src": "shell",
        "lo": 24.0,
        "hi": 140.0,
        "unit": "px"
    },
    {
        "tab": "frame",
        "group": "NOTIFICATIONS",
        "key": "osdRadius",
        "label": "OSD & toast corner",
        "desc": "",
        "ctl": "step",
        "src": "shell",
        "lo": 0.0,
        "hi": 40.0,
        "unit": "px"
    },
    {
        "tab": "frame",
        "group": "NOTIFICATIONS",
        "key": "osdOpacity",
        "label": "Opacity",
        "desc": "",
        "ctl": "slid",
        "src": "shell",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "global",
        "group": "ROUNDNESS",
        "key": "roundness",
        "label": "Inner roundness",
        "desc": "",
        "ctl": "step",
        "src": "shell",
        "lo": 0.0,
        "hi": 24.0,
        "unit": "px"
    },
    {
        "tab": "global",
        "group": "ROUNDNESS",
        "key": "frameRadius",
        "label": "Frame corner",
        "desc": "",
        "ctl": "step",
        "src": "shell",
        "lo": 0.0,
        "hi": 60.0,
        "unit": "px"
    },
    {
        "tab": "global",
        "group": "ROUNDNESS",
        "key": "frameSmoothing",
        "label": "Edge melt",
        "desc": "",
        "ctl": "step",
        "src": "shell",
        "lo": 1.0,
        "hi": 60.0
    },
    {
        "tab": "global",
        "group": "SHADOW",
        "key": "shadowStrength",
        "label": "Strength",
        "desc": "",
        "ctl": "slid",
        "src": "shell",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "global",
        "group": "SHADOW",
        "key": "shadowSize",
        "label": "Size",
        "desc": "",
        "ctl": "step",
        "src": "shell",
        "lo": 0.0,
        "hi": 80.0,
        "unit": "px"
    },
    {
        "tab": "global",
        "group": "BRAND",
        "key": "name",
        "label": "Name",
        "desc": "",
        "ctl": "text",
        "src": "brand"
    },
    {
        "tab": "global",
        "group": "BRAND",
        "key": "markText",
        "label": "Text mark",
        "desc": "",
        "ctl": "text",
        "src": "brand"
    },
    {
        "tab": "global",
        "group": "BRAND",
        "key": "markImage",
        "label": "(logo image path \u2014 no label; row of readout + Choose image + Clear)",
        "desc": "",
        "ctl": "text",
        "src": "brand"
    },
    {
        "tab": "global",
        "group": "BRAND",
        "key": "markTint",
        "label": "Tint image to accent",
        "desc": "",
        "ctl": "sw",
        "src": "brand"
    },
    {
        "tab": "global",
        "group": "SURFACE",
        "key": "surfaceColor",
        "label": "Colour",
        "desc": "",
        "ctl": "color",
        "src": "shell"
    },
    {
        "tab": "global",
        "group": "SURFACE",
        "key": "frameOpacity",
        "label": "Opacity",
        "desc": "",
        "ctl": "slid",
        "src": "shell",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "global",
        "group": "TEXT",
        "key": "fontFamily",
        "label": "Font",
        "desc": "",
        "ctl": "pick",
        "src": "shell",
        "opts": [
            "JetBrainsMono",
            "FiraCode",
            "Hack",
            "CaskaydiaCove",
            "Iosevka",
            "MesloLGS",
            "SauceCodePro",
            "UbuntuMono",
            "RobotoMono",
            "BlexMono",
            "GeistMono",
            "CommitMono",
            "Terminess",
            "DejaVuSansMono",
            "Maple",
            "Inter",
            "Roboto",
            "Ubuntu",
            "Cantarell",
            "Lexend",
            "Fira",
            "Noto",
            "Noto",
            "Space",
            "Fraunces",
            "<current"
        ]
    },
    {
        "tab": "global",
        "group": "TEXT",
        "key": "fontScale",
        "label": "Size",
        "desc": "",
        "ctl": "slid",
        "src": "shell",
        "lo": 0.7,
        "hi": 1.6,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "global",
        "group": "WEATHER",
        "key": "weatherLocation",
        "label": "Location",
        "desc": "",
        "ctl": "text",
        "src": "shell"
    },
    {
        "tab": "global",
        "group": "WEATHER",
        "key": "weatherUnit",
        "label": "Units",
        "desc": "",
        "ctl": "seg",
        "src": "shell",
        "opts": [
            "auto",
            "celsius",
            "fahrenheit"
        ]
    },
    {
        "tab": "bar",
        "group": "BAR",
        "key": "barEnabled",
        "label": "Enable bar",
        "desc": "",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "bar",
        "group": "BAR",
        "key": "barPosition",
        "label": "Position",
        "desc": "",
        "ctl": "seg",
        "src": "shell",
        "opts": [
            "top",
            "bottom"
        ]
    },
    {
        "tab": "bar",
        "group": "BAR",
        "key": "barStyle",
        "label": "Style",
        "desc": "",
        "ctl": "pick",
        "src": "shell",
        "opts": [
            "noctalia",
            "caelestia",
            "aegis",
            "stele",
            "triptych",
            "delos",
            "nacre",
            "inir",
            "aurora",
            "angel"
        ]
    },
    {
        "tab": "bar",
        "group": "BAR",
        "key": "barHeight",
        "label": "Thickness",
        "desc": "",
        "ctl": "step",
        "src": "shell",
        "lo": 18.0,
        "hi": 48.0,
        "unit": "px"
    },
    {
        "tab": "bar",
        "group": "CONTENT",
        "key": "barShowTitle",
        "label": "Focused window title",
        "desc": "",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "bar",
        "group": "CONTENT",
        "key": "barShowMedia",
        "label": "Now playing",
        "desc": "",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "bar",
        "group": "CONTENT",
        "key": "barShowStatus",
        "label": "Status glyphs (network, battery, inbox)",
        "desc": "",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "bar",
        "group": "CONTENT",
        "key": "barOccupiedWorkspaces",
        "label": "Only occupied workspaces",
        "desc": "",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "bar",
        "group": "ISLAND",
        "key": "islandRadius",
        "label": "Roundness",
        "desc": "",
        "ctl": "step",
        "src": "shell",
        "lo": 0.0,
        "hi": 40.0,
        "unit": "px"
    },
    {
        "tab": "bar",
        "group": "ISLAND",
        "key": "islandModules",
        "label": "islandModules",
        "desc": "",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "workspaces",
            "clock",
            "date",
            "media",
            "title",
            "status",
            "tray"
        ]
    },
    {
        "tab": "(none",
        "group": "(none)",
        "key": "islandEdge",
        "label": "(no visible label) island edge",
        "desc": "",
        "ctl": "seg",
        "src": "shell",
        "opts": [
            "top"
        ]
    },
    {
        "tab": "(none",
        "group": "(none)",
        "key": "islandAlong",
        "label": "(no visible label) island position along edge",
        "desc": "",
        "ctl": "step",
        "src": "shell"
    },
    {
        "tab": "(none",
        "group": "(none)",
        "key": "islandHidden",
        "label": "(no visible label) island hidden",
        "desc": "",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "sidebar",
        "group": "LEFT \u00b7 FEATURES",
        "key": "sidebarLeftEnabled",
        "label": "Enable left sidebar",
        "desc": "",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "sidebar",
        "group": "LEFT \u00b7 FEATURES",
        "key": "sidebarLeftPanes",
        "label": "sidebarLeftPanes",
        "desc": "",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "stash"
        ]
    },
    {
        "tab": "sidebar",
        "group": "BEHAVIOUR",
        "key": "sidebarClickless",
        "label": "Open on hover",
        "desc": "",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "sidebar",
        "group": "RIGHT \u00b7 SYSTEM",
        "key": "sidebarRightEnabled",
        "label": "Enable right sidebar",
        "desc": "",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "sidebar",
        "group": "RIGHT \u00b7 SYSTEM",
        "key": "sidebarRightPanes",
        "label": "sidebarRightPanes",
        "desc": "",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "notifications",
            "calendar",
            "media",
            "weather",
            "recording"
        ]
    },
    {
        "tab": "sidebar",
        "group": "SIZE",
        "key": "sidebarWidth",
        "label": "Width",
        "desc": "",
        "ctl": "step",
        "src": "shell",
        "lo": 240.0,
        "hi": 520.0,
        "unit": "px"
    },
    {
        "tab": "sidebar",
        "group": "SIZE",
        "key": "sidebarCornerSize",
        "label": "Corner hotspot",
        "desc": "",
        "ctl": "step",
        "src": "shell",
        "lo": 16.0,
        "hi": 80.0,
        "unit": "px"
    },
    {
        "tab": "visualizer",
        "group": "STYLE",
        "key": "style",
        "label": "Style",
        "desc": "",
        "ctl": "chips",
        "src": "viz",
        "opts": [
            "bars",
            "dots",
            "line",
            "wave",
            "segments",
            "radial",
            "circle"
        ]
    },
    {
        "tab": "visualizer",
        "group": "LAYOUT",
        "key": "position",
        "label": "Position",
        "desc": "",
        "ctl": "seg",
        "src": "viz",
        "opts": [
            "bottom",
            "top",
            "center"
        ]
    },
    {
        "tab": "visualizer",
        "group": "LAYOUT",
        "key": "shape",
        "label": "Shape",
        "desc": "",
        "ctl": "seg",
        "src": "viz",
        "opts": [
            "rounded",
            "flat"
        ]
    },
    {
        "tab": "visualizer",
        "group": "LAYOUT",
        "key": "mirror",
        "label": "Mirror",
        "desc": "",
        "ctl": "sw",
        "src": "viz"
    },
    {
        "tab": "visualizer",
        "group": "SPECTRUM",
        "key": "enabled",
        "label": "Enabled",
        "desc": "",
        "ctl": "sw",
        "src": "viz"
    },
    {
        "tab": "visualizer",
        "group": "SPECTRUM",
        "key": "bars",
        "label": "Bars",
        "desc": "",
        "ctl": "step",
        "src": "viz",
        "lo": 16.0,
        "hi": 128.0
    },
    {
        "tab": "visualizer",
        "group": "SPECTRUM",
        "key": "segments",
        "label": "Segments",
        "desc": "",
        "ctl": "step",
        "src": "viz",
        "lo": 4.0,
        "hi": 16.0
    },
    {
        "tab": "visualizer",
        "group": "SPECTRUM",
        "key": "peaks",
        "label": "Peak caps",
        "desc": "",
        "ctl": "sw",
        "src": "viz"
    },
    {
        "tab": "visualizer",
        "group": "SIZE",
        "key": "height",
        "label": "Height",
        "desc": "",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.1,
        "hi": 0.6,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "visualizer",
        "group": "SIZE",
        "key": "thickness",
        "label": "Bar width",
        "desc": "",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "visualizer",
        "group": "GLOW",
        "key": "bloom",
        "label": "Bloom",
        "desc": "",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "visualizer",
        "group": "GLOW",
        "key": "reflection",
        "label": "Reflection",
        "desc": "",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.0,
        "hi": 0.3,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "visualizer",
        "group": "FEEL",
        "key": "smoothing",
        "label": "Smoothing",
        "desc": "",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "visualizer",
        "group": "FEEL",
        "key": "gain",
        "label": "Sensitivity",
        "desc": "",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.5,
        "hi": 2.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "visualizer",
        "group": "MOTION",
        "key": "fps",
        "label": "Frame rate",
        "desc": "",
        "ctl": "seg",
        "src": "viz",
        "opts": [
            "30",
            "45",
            "60"
        ]
    },
    {
        "tab": "visualizer",
        "group": "MOTION",
        "key": "adaptive",
        "label": "Adaptive quality",
        "desc": "",
        "ctl": "sw",
        "src": "viz"
    },
    {
        "tab": "visualizer",
        "group": "AT REST",
        "key": "idleWave",
        "label": "Idle wave",
        "desc": "",
        "ctl": "sw",
        "src": "viz"
    }
];
