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

var rows = [
    {
        "tab": "frame",
        "group": "SHAPE",
        "key": "frameEnabled",
        "label": "Enable frame",
        "desc": "Draw the rounded border around the screen",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "frame",
        "group": "SHAPE",
        "key": "frameBorder",
        "label": "Border thickness",
        "desc": "How far the frame intrudes on each edge",
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
        "desc": "Corner rounding of OSDs and toasts",
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
        "desc": "Toast surface opacity over the wallpaper",
        "ctl": "slid",
        "src": "shell",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "global",
        "group": "LANGUAGE",
        "key": "language",
        "label": "Language",
        "desc": "The language for Ryoku's menus and settings; Auto follows your system locale",
        "ctl": "chips",
        "src": "shell",
        "opts": ["Auto", "English", "Español", "Français", "Português", "Português (BR)"]
    },
    {
        "tab": "global",
        "group": "LANGUAGE",
        "key": "i18nGenerate",
        "label": "AI translation",
        "desc": "Generate higher-quality translations, or a language Ryoku doesn't ship, with an LLM. Ryoku creates ~/.config/ryoku/i18n-llm.json on login; paste your Anthropic (console.anthropic.com) or OpenAI (platform.openai.com/api-keys) key into it, then Generate. Results layer over the built-in translations for the selected language.",
        "ctl": "action",
        "actionLabel": "Generate with AI",
        "src": "none"
    },
    {
        "tab": "global",
        "group": "SURFACE",
        "key": "surfaceColor",
        "label": "Colour",
        "desc": "The one colour the frame, bar and island share",
        "ctl": "color",
        "src": "shell"
    },
    {
        "tab": "global",
        "group": "SURFACE",
        "key": "frameOpacity",
        "label": "Opacity",
        "desc": "Frame surface opacity over the wallpaper",
        "ctl": "slid",
        "src": "shell",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "global",
        "group": "SURFACE",
        "key": "grainStrength",
        "label": "Grain",
        "desc": "Film-grain matte over the shell and the apps behind it; 0 turns it off",
        "ctl": "slid",
        "src": "shell",
        "lo": 0.0,
        "hi": 0.2,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "global",
        "group": "ROUNDNESS",
        "key": "roundness",
        "label": "Inner roundness",
        "desc": "Inner corner rounding, shell wide",
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
        "desc": "Corner rounding of the frame itself",
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
        "desc": "How softly the frame melts into a popout",
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
        "desc": "How dark the drop shadow under a surface sits",
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
        "desc": "How far the shadow spreads",
        "ctl": "step",
        "src": "shell",
        "lo": 0.0,
        "hi": 80.0,
        "unit": "px"
    },
    {
        "tab": "global",
        "group": "TEXT",
        "key": "fontFamily",
        "label": "Font",
        "desc": "The face the shell sets its text in",
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
        "desc": "Text size across the shell",
        "ctl": "slid",
        "src": "shell",
        "lo": 0.7,
        "hi": 1.6,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "desktop",
        "group": "BRAND",
        "key": "name",
        "label": "Name",
        "desc": "The name the shell calls this desktop",
        "ctl": "text",
        "src": "brand"
    },
    {
        "tab": "desktop",
        "group": "BRAND",
        "key": "markText",
        "label": "Text mark",
        "desc": "The glyph the shell uses as its mark",
        "ctl": "text",
        "src": "brand"
    },
    {
        "tab": "desktop",
        "group": "BRAND",
        "key": "markImage",
        "label": "Logo image",
        "desc": "Pick an image to use as the mark instead of the glyph",
        "ctl": "image",
        "src": "brand"
    },
    {
        "tab": "desktop",
        "group": "BRAND",
        "key": "markTint",
        "label": "Tint image to accent",
        "desc": "Tint the mark image to the accent",
        "ctl": "sw",
        "src": "brand"
    },
    {
        "tab": "desktop",
        "group": "WEATHER",
        "key": "weatherLocation",
        "label": "Location",
        "desc": "Search a city; empty reads it from your IP",
        "ctl": "location",
        "src": "shell"
    },
    {
        "tab": "desktop",
        "group": "WEATHER",
        "key": "weatherUnit",
        "label": "Units",
        "desc": "Temperature units",
        "ctl": "seg",
        "src": "shell",
        "opts": [
            "auto",
            "celsius",
            "fahrenheit"
        ]
    },
    {
        "tab": "desktop",
        "group": "WIDGET BOARD",
        "key": "ryolayerEnabled",
        "label": "Enable widget board",
        "desc": "The Super+G board of drag-and-drop instrument widgets (RyoLayer); off frees it and its pins entirely",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "bar",
        "group": "BAR",
        "key": "barEnabled",
        "label": "Enable bar",
        "desc": "Show the module bar on the frame",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "bar",
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
    },
    {
        "tab": "bar",
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
    },
    {
        "tab": "bar",
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
    },
    {
        "tab": "bar",
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
    },
    {
        "tab": "bar",
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
    },
    {
        "tab": "bar",
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
    },
    {
        "tab": "bar",
        "group": "CONTENT",
        "key": "barShowTitle",
        "styles": BANDFLAT,
        "label": "Focused window title",
        "desc": "Show the focused window's title",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "bar",
        "group": "CONTENT",
        "key": "barShowMedia",
        "styles": BANDFLAT,
        "label": "Now playing",
        "desc": "Show what is playing",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "bar",
        "group": "CONTENT",
        "key": "barShowWeather",
        "styles": BANDFLAT,
        "label": "Weather",
        "desc": "Show the condition glyph + temperature",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "bar",
        "group": "CONTENT",
        "key": "barShowSpecialWs",
        "styles": BANDFLAT,
        "label": "Special workspace cue",
        "desc": "Flag a Hyprland scratchpad while one is open",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "bar",
        "group": "CONTENT",
        "key": "barShowStatus",
        "styles": BANDFLAT,
        "label": "Status glyphs (network, battery, inbox)",
        "desc": "Show the status glyphs",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "bar",
        "group": "CONTENT",
        "key": "barOccupiedWorkspaces",
        "styles": WSHOSTS,
        "label": "Only occupied workspaces",
        "desc": "Only show workspaces that have windows",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "bar",
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
    },
    {
        "tab": "bar",
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
    },
    {
        "tab": "bar",
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
    },
    {
        "tab": "bar",
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
    },
    {
        "tab": "bar",
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
    },
    {
        "tab": "bar",
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
    },
    {
        "tab": "bar",
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
    },
    {
        "tab": "sidebar",
        "group": "LEFT SIDEBAR",
        "key": "sidebarLeftEnabled",
        "label": "Enable left sidebar",
        "desc": "Show the Features sidebar on the left edge",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "sidebar",
        "group": "LEFT SIDEBAR",
        "key": "sidebarLeftPanes",
        "label": "Left sidebar panes",
        "desc": "Which panes the Features sidebar carries",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "stash"
        ]
    },
    {
        "tab": "sidebar",
        "group": "RIGHT SIDEBAR",
        "key": "sidebarRightEnabled",
        "label": "Enable right sidebar",
        "desc": "Show the System sidebar on the right edge",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "sidebar",
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
    },
    {
        "tab": "sidebar",
        "group": "BEHAVIOUR",
        "key": "sidebarClickless",
        "label": "Open on hover",
        "desc": "Open a sidebar on hover instead of a click",
        "ctl": "sw",
        "src": "shell"
    },
    {
        "tab": "sidebar",
        "group": "SIZE",
        "key": "sidebarWidth",
        "label": "Width",
        "desc": "How wide a sidebar opens",
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
        "desc": "How large the corner you hover to summon it is",
        "ctl": "step",
        "src": "shell",
        "lo": 16.0,
        "hi": 80.0,
        "unit": "px"
    },
    {
        "tab": "visualizer",
        "group": "STYLE",
        "key": "enabled",
        "label": "Enabled",
        "desc": "Paint the audio spectrum on the desktop",
        "ctl": "sw",
        "src": "viz"
    },
    {
        "tab": "visualizer",
        "group": "STYLE",
        "key": "style",
        "label": "Style",
        "desc": "How the spectrum is drawn",
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
        "group": "STYLE",
        "key": "position",
        "label": "Position",
        "desc": "Which screen edge the spectrum sits on",
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
        "group": "STYLE",
        "key": "shape",
        "label": "Shape",
        "desc": "The shape of a single bar",
        "ctl": "seg",
        "src": "viz",
        "opts": [
            "rounded",
            "flat"
        ]
    },
    {
        "tab": "visualizer",
        "group": "STYLE",
        "key": "mirror",
        "label": "Mirror",
        "desc": "Mirror the spectrum around its centre",
        "ctl": "sw",
        "src": "viz"
    },
    {
        "tab": "visualizer",
        "group": "SPECTRUM",
        "key": "bars",
        "label": "Bars",
        "desc": "How many bars the spectrum is cut into",
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
        "desc": "How many segments a bar is cut into",
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
        "desc": "Hold a mark at each bar's peak",
        "ctl": "sw",
        "src": "viz"
    },
    {
        "tab": "visualizer",
        "group": "SPECTRUM",
        "key": "height",
        "label": "Height",
        "desc": "How tall the spectrum stands",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.1,
        "hi": 0.6,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "visualizer",
        "group": "SPECTRUM",
        "key": "thickness",
        "label": "Bar width",
        "desc": "How wide each bar is against its gap",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "visualizer",
        "group": "SPECTRUM",
        "key": "bloom",
        "label": "Bloom",
        "desc": "How much the spectrum glows",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "visualizer",
        "group": "SPECTRUM",
        "key": "reflection",
        "label": "Reflection",
        "desc": "How much of the spectrum mirrors below it",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.0,
        "hi": 0.3,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "visualizer",
        "group": "MOTION",
        "key": "smoothing",
        "label": "Smoothing",
        "desc": "How much motion is smoothed between frames",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "visualizer",
        "group": "MOTION",
        "key": "gain",
        "label": "Sensitivity",
        "desc": "Input sensitivity",
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
        "desc": "How often the spectrum redraws",
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
        "desc": "Drop the frame rate when nothing is playing",
        "ctl": "sw",
        "src": "viz"
    },
    {
        "tab": "visualizer",
        "group": "MOTION",
        "key": "idleWave",
        "label": "Idle wave",
        "desc": "Keep a slow wave moving when nothing is playing",
        "ctl": "sw",
        "src": "viz"
    }

];
