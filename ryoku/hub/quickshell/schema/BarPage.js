.pragma library

// ShellSettingsPage as data. 67 settings, 57 controls: the 13 hand-wired
// member toggles are three sets, not thirteen switches.

// per bar-style visibility: a bar-tab row with a `styles` list shows only when
// the active barStyle is in it; a row without `styles` is universal. the sets
// mirror which bar components actually read each Config key (verified in-tree).
var BAND4 = ["noctalia", "caelestia", "aegis", "stele"];
var BANDFLAT = BAND4.concat(["triptych", "nacre", "inir", "aurora", "angel"]);
var THICK = BANDFLAT.concat(["atoll"]);
var WSHOSTS = BANDFLAT.concat(["delos"]);

var rows = [{
        "tab": "Bar",
        "group": "BAR",
        "key": "barEnabled",
        "label": "Enable bar",
        "desc": "Show the module bar on the frame",
        "ctl": "sw",
        "src": "shell"
    },{
        "tab": "Bar",
        "group": "BAR",
        "key": "barPosition",
        "styles": THICK,
        "label": "Position",
        "desc": "Which frame edge the bar rides",
        "ctl": "seg",
        "src": "shell",
        "opts": [
            "top",
            "bottom"
        ]
    },{
        "tab": "Bar",
        "group": "BAR",
        "key": "barStyle",
        "label": "Style",
        "desc": "The bar's module vocabulary",
        "ctl": "gallery",
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
            "angel",
            "washi",
            "atoll",
            "dyad"
        ]
    },{
        "tab": "Bar",
        "group": "BAR",
        "key": "washiVariant",
        "styles": ["washi"],
        "label": "Washi look",
        "desc": "The warping pill's aesthetic: Ryoku's own, or faithful to Ricelin",
        "ctl": "seg",
        "src": "shell",
        "opts": [
            "ryoku",
            "ricelin"
        ]
    },{
        "tab": "Bar",
        "group": "BAR",
        "key": "atollVariant",
        "styles": ["atoll"],
        "label": "Atoll look",
        "desc": "Faithful to ilyamiro, or Ryoku-native: the frame wraps square grainy islands",
        "ctl": "seg",
        "src": "shell",
        "opts": [
            "ilyamiro",
            "ryoku"
        ]
    },{
        "tab": "Bar",
        "group": "BAR",
        "key": "dyadVariant",
        "styles": ["dyad"],
        "label": "Dyad look",
        "desc": "Faithful to Jules3182's dark capsules, or Ryoku-native square grainy chips",
        "ctl": "seg",
        "src": "shell",
        "opts": [
            "faithful",
            "ryoku"
        ]
    },{
        "tab": "Bar",
        "group": "BAR",
        "key": "barHeight",
        "styles": THICK,
        "label": "Thickness",
        "desc": "How thick the band the bar rides is",
        "ctl": "step",
        "src": "shell",
        "lo": 18.0,
        "hi": 48.0,
        "unit": "px"
    },{
        "tab": "Bar",
        "group": "CONTENT",
        "key": "barShowTitle",
        "styles": BANDFLAT,
        "label": "Focused window title",
        "desc": "Show the focused window's title",
        "ctl": "sw",
        "src": "shell"
    },{
        "tab": "Bar",
        "group": "CONTENT",
        "key": "barShowMedia",
        "styles": BANDFLAT,
        "label": "Now playing",
        "desc": "Show what is playing",
        "ctl": "sw",
        "src": "shell"
    },{
        "tab": "Bar",
        "group": "CONTENT",
        "key": "barShowWeather",
        "styles": BANDFLAT,
        "label": "Weather",
        "desc": "Show the condition glyph + temperature",
        "ctl": "sw",
        "src": "shell"
    },{
        "tab": "Bar",
        "group": "CONTENT",
        "key": "barShowSpecialWs",
        "styles": BANDFLAT,
        "label": "Special workspace cue",
        "desc": "Flag a Hyprland scratchpad while one is open",
        "ctl": "sw",
        "src": "shell"
    },{
        "tab": "Bar",
        "group": "CONTENT",
        "key": "barShowStatus",
        "styles": BANDFLAT,
        "label": "Status glyphs (network, battery, inbox)",
        "desc": "Show the status glyphs",
        "ctl": "sw",
        "src": "shell"
    },{
        "tab": "Bar",
        "group": "CONTENT",
        "key": "barOccupiedWorkspaces",
        "styles": WSHOSTS,
        "label": "Only occupied workspaces",
        "desc": "Only show workspaces that have windows",
        "ctl": "sw",
        "src": "shell"
    },{
        "tab": "Bar",
        "group": "CONTENT",
        "key": "barToggles",
        "styles": BANDFLAT,
        "label": "Quick toggles",
        "desc": "Which quick-toggles the bar carries. Order follows the strip.",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "wifi",
            "bluetooth",
            "mic",
            "dnd",
            "caffeine",
            "nightlight"
        ]
    },{
        "tab": "Bar",
        "group": "LAYOUT (band skins: noctalia, caelestia, aegis, stele)",
        "key": "barLayoutLeft",
        "styles": BAND4,
        "label": "Left cluster",
        "desc": "Modules in the left group, in order. Empty keeps the classic layout.",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "seal",
            "workspaces",
            "special",
            "title",
            "clock",
            "media",
            "stats",
            "weather",
            "toggles",
            "status",
            "tray",
            "power"
        ]
    },{
        "tab": "Bar",
        "group": "LAYOUT (band skins: noctalia, caelestia, aegis, stele)",
        "key": "barLayoutCentre",
        "styles": BAND4,
        "label": "Centre cluster",
        "desc": "Modules in the centred group, in order. Empty centres the clock.",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "seal",
            "workspaces",
            "special",
            "title",
            "clock",
            "media",
            "stats",
            "weather",
            "toggles",
            "status",
            "tray",
            "power"
        ]
    },{
        "tab": "Bar",
        "group": "LAYOUT (band skins: noctalia, caelestia, aegis, stele)",
        "key": "barLayoutRight",
        "styles": BAND4,
        "label": "Right cluster",
        "desc": "Modules in the right group, in order. Empty keeps the classic layout.",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "seal",
            "workspaces",
            "special",
            "title",
            "clock",
            "media",
            "stats",
            "weather",
            "toggles",
            "status",
            "tray",
            "power"
        ]
    },{
        "tab": "Island",
        "group": "ISLAND",
        "key": "islandRadius",
        "styles": ["delos"],
        "label": "Roundness",
        "desc": "Corner rounding of the island",
        "ctl": "step",
        "src": "shell",
        "lo": 0.0,
        "hi": 40.0,
        "unit": "px"
    },{
        "tab": "Island",
        "group": "ISLAND",
        "key": "islandModules",
        "styles": ["delos"],
        "label": "Island modules",
        "desc": "Which modules the bar carries. Order follows the strip.",
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
    },{
        "tab": "Island",
        "group": "ISLAND",
        "key": "islandEdge",
        "styles": ["delos"],
        "label": "Dock edge",
        "desc": "Which screen edge the island docks to",
        "ctl": "seg",
        "src": "shell",
        "opts": [
            "top",
            "bottom",
            "left",
            "right"
        ]
    },{
        "tab": "Sidebars",
        "group": "LEFT SIDEBAR",
        "key": "sidebarLeftEnabled",
        "label": "Enable left sidebar",
        "desc": "Show the Features sidebar on the left edge",
        "ctl": "sw",
        "src": "shell"
    },{
        "tab": "Sidebars",
        "group": "LEFT SIDEBAR",
        "key": "sidebarLeftPanes",
        "label": "Left sidebar panes",
        "desc": "Which panes the Features sidebar carries",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "stash"
        ]
    },{
        "tab": "Sidebars",
        "group": "RIGHT SIDEBAR",
        "key": "sidebarRightEnabled",
        "label": "Enable right sidebar",
        "desc": "Show the System sidebar on the right edge",
        "ctl": "sw",
        "src": "shell"
    },{
        "tab": "Sidebars",
        "group": "RIGHT SIDEBAR",
        "key": "sidebarRightPanes",
        "label": "Right sidebar panes",
        "desc": "Which panes the System sidebar carries",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "notifications",
            "calendar",
            "media",
            "weather",
            "recording"
        ]
    },{
        "tab": "Sidebars",
        "group": "BEHAVIOUR",
        "key": "sidebarClickless",
        "label": "Open on hover",
        "desc": "Open a sidebar on hover instead of a click",
        "ctl": "sw",
        "src": "shell"
    },{
        "tab": "Sidebars",
        "group": "SIZE",
        "key": "sidebarWidth",
        "label": "Width",
        "desc": "How wide a sidebar opens",
        "ctl": "step",
        "src": "shell",
        "lo": 240.0,
        "hi": 520.0,
        "unit": "px"
    },{
        "tab": "Sidebars",
        "group": "SIZE",
        "key": "sidebarCornerSize",
        "label": "Corner hotspot",
        "desc": "How large the corner you hover to summon it is",
        "ctl": "step",
        "src": "shell",
        "lo": 16.0,
        "hi": 80.0,
        "unit": "px"
    }
];
