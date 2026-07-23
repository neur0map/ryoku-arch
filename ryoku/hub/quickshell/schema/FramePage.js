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
        "tab": "Frame",
        "group": "SHAPE",
        "key": "frameEnabled",
        "label": "Enable frame",
        "desc": "Draw the rounded border around the screen",
        "ctl": "sw",
        "src": "shell"
    },{
        "tab": "Frame",
        "group": "SHAPE",
        "key": "frameBorder",
        "label": "Border thickness",
        "desc": "How far the frame intrudes on each edge",
        "ctl": "step",
        "src": "shell",
        "lo": 24.0,
        "hi": 140.0,
        "unit": "px"
    },{
        "tab": "Frame",
        "group": "ROUNDNESS",
        "key": "roundness",
        "label": "Inner roundness",
        "desc": "Inner corner rounding, shell wide",
        "ctl": "step",
        "src": "shell",
        "lo": 0.0,
        "hi": 24.0,
        "unit": "px"
    },{
        "tab": "Frame",
        "group": "ROUNDNESS",
        "key": "frameRadius",
        "label": "Frame corner",
        "desc": "Corner rounding of the frame itself",
        "ctl": "step",
        "src": "shell",
        "lo": 0.0,
        "hi": 60.0,
        "unit": "px"
    },{
        "tab": "Frame",
        "group": "ROUNDNESS",
        "key": "frameSmoothing",
        "label": "Edge melt",
        "desc": "How softly the frame melts into a popout",
        "ctl": "step",
        "src": "shell",
        "lo": 1.0,
        "hi": 60.0
    },{
        "tab": "Surface",
        "group": "SURFACE",
        "key": "surfaceColor",
        "label": "Colour",
        "desc": "The one colour the frame, bar and island share",
        "ctl": "color",
        "src": "shell"
    },{
        "tab": "Surface",
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
    },{
        "tab": "Surface",
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
    },{
        "tab": "Surface",
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
    },{
        "tab": "Surface",
        "group": "SHADOW",
        "key": "shadowSize",
        "label": "Size",
        "desc": "How far the shadow spreads",
        "ctl": "step",
        "src": "shell",
        "lo": 0.0,
        "hi": 80.0,
        "unit": "px"
    },{
        "tab": "Notifications",
        "group": "NOTIFICATIONS",
        "key": "osdRadius",
        "label": "OSD & toast corner",
        "desc": "Corner rounding of OSDs and toasts",
        "ctl": "step",
        "src": "shell",
        "lo": 0.0,
        "hi": 40.0,
        "unit": "px"
    },{
        "tab": "Notifications",
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
    },{
        "tab": "Global",
        "group": "LANGUAGE",
        "key": "language",
        "label": "Language",
        "desc": "The language for Ryoku's menus and settings; Auto follows your system locale",
        "ctl": "chips",
        "src": "shell",
        "opts": ["Auto", "English", "Español", "Français", "Português", "Português (BR)"]
    },{
        "tab": "Global",
        "group": "LANGUAGE",
        "key": "i18nGenerate",
        "label": "AI translation",
        "desc": "Generate higher-quality translations, or a language Ryoku doesn't ship, with an LLM. Ryoku creates ~/.config/ryoku/i18n-llm.json on login; paste your Anthropic (console.anthropic.com) or OpenAI (platform.openai.com/api-keys) key into it, then Generate. Results layer over the built-in translations for the selected language.",
        "ctl": "action",
        "actionLabel": "Generate with AI",
        "src": "none"
    },{
        "tab": "Global",
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
    },{
        "tab": "Global",
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
    }
];
