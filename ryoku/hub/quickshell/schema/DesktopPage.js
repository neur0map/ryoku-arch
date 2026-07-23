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
        "tab": "General",
        "group": "BRAND",
        "key": "name",
        "label": "Name",
        "desc": "The name the shell calls this desktop",
        "ctl": "text",
        "src": "brand"
    },{
        "tab": "General",
        "group": "BRAND",
        "key": "markText",
        "label": "Text mark",
        "desc": "The glyph the shell uses as its mark",
        "ctl": "text",
        "src": "brand"
    },{
        "tab": "General",
        "group": "BRAND",
        "key": "markImage",
        "label": "Logo image",
        "desc": "Pick an image to use as the mark instead of the glyph",
        "ctl": "image",
        "src": "brand"
    },{
        "tab": "General",
        "group": "BRAND",
        "key": "markTint",
        "label": "Tint image to accent",
        "desc": "Tint the mark image to the accent",
        "ctl": "sw",
        "src": "brand"
    },{
        "tab": "General",
        "group": "WEATHER",
        "key": "weatherLocation",
        "label": "Location",
        "desc": "Search a city; empty reads it from your IP",
        "ctl": "location",
        "src": "shell"
    },{
        "tab": "General",
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
    },{
        "tab": "General",
        "group": "WIDGET BOARD",
        "key": "ryolayerEnabled",
        "label": "Enable widget board",
        "desc": "The Super+G board of drag-and-drop instrument widgets (RyoLayer); off frees it and its pins entirely",
        "ctl": "sw",
        "src": "shell"
    },{
        "tab": "Visualizer",
        "group": "STYLE",
        "key": "enabled",
        "label": "Enabled",
        "desc": "Paint the audio spectrum on the desktop",
        "ctl": "sw",
        "src": "viz"
    },{
        "tab": "Visualizer",
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
    },{
        "tab": "Visualizer",
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
    },{
        "tab": "Visualizer",
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
    },{
        "tab": "Visualizer",
        "group": "STYLE",
        "key": "mirror",
        "label": "Mirror",
        "desc": "Mirror the spectrum around its centre",
        "ctl": "sw",
        "src": "viz"
    },{
        "tab": "Visualizer",
        "group": "SPECTRUM",
        "adv": true,
        "key": "bars",
        "label": "Bars",
        "desc": "How many bars the spectrum is cut into",
        "ctl": "step",
        "src": "viz",
        "lo": 16.0,
        "hi": 128.0
    },{
        "tab": "Visualizer",
        "group": "SPECTRUM",
        "adv": true,
        "key": "segments",
        "label": "Segments",
        "desc": "How many segments a bar is cut into",
        "ctl": "step",
        "src": "viz",
        "lo": 4.0,
        "hi": 16.0
    },{
        "tab": "Visualizer",
        "group": "SPECTRUM",
        "adv": true,
        "key": "peaks",
        "label": "Peak caps",
        "desc": "Hold a mark at each bar's peak",
        "ctl": "sw",
        "src": "viz"
    },{
        "tab": "Visualizer",
        "group": "SPECTRUM",
        "adv": true,
        "key": "height",
        "label": "Height",
        "desc": "How tall the spectrum stands",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.1,
        "hi": 0.6,
        "unit": "%",
        "pct": true
    },{
        "tab": "Visualizer",
        "group": "SPECTRUM",
        "adv": true,
        "key": "thickness",
        "label": "Bar width",
        "desc": "How wide each bar is against its gap",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },{
        "tab": "Visualizer",
        "group": "SPECTRUM",
        "adv": true,
        "key": "bloom",
        "label": "Bloom",
        "desc": "How much the spectrum glows",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },{
        "tab": "Visualizer",
        "group": "SPECTRUM",
        "adv": true,
        "key": "reflection",
        "label": "Reflection",
        "desc": "How much of the spectrum mirrors below it",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.0,
        "hi": 0.3,
        "unit": "%",
        "pct": true
    },{
        "tab": "Visualizer",
        "group": "MOTION",
        "adv": true,
        "key": "smoothing",
        "label": "Smoothing",
        "desc": "How much motion is smoothed between frames",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },{
        "tab": "Visualizer",
        "group": "MOTION",
        "adv": true,
        "key": "gain",
        "label": "Sensitivity",
        "desc": "Input sensitivity",
        "ctl": "slid",
        "src": "viz",
        "lo": 0.5,
        "hi": 2.0,
        "unit": "%",
        "pct": true
    },{
        "tab": "Visualizer",
        "group": "MOTION",
        "adv": true,
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
    },{
        "tab": "Visualizer",
        "group": "MOTION",
        "adv": true,
        "key": "adaptive",
        "label": "Adaptive quality",
        "desc": "Drop the frame rate when nothing is playing",
        "ctl": "sw",
        "src": "viz"
    },{
        "tab": "Visualizer",
        "group": "MOTION",
        "adv": true,
        "key": "idleWave",
        "label": "Idle wave",
        "desc": "Keep a slow wave moving when nothing is playing",
        "ctl": "sw",
        "src": "viz"
    }
];
