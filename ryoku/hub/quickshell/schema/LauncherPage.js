.pragma library

// LauncherPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "SHAPE",
        "key": "radius",
        "label": "Corner radius",
        "desc": "Rounds the palette window corners, inner cards follow 4 px tighter",
        "ctl": "step",
        "src": ".config)",
        "lo": 0.0,
        "hi": 28.0,
        "unit": "px"
    },
    {
        "tab": "",
        "group": "BACKGROUND",
        "key": "bgBlur",
        "label": "Blur",
        "desc": "Frosts the desktop behind the open palette, even with blur off globally",
        "ctl": "step",
        "src": "launcher.json",
        "lo": 0.0,
        "hi": 30.0,
        "unit": "px"
    },
    {
        "tab": "",
        "group": "HOME CARD",
        "key": "weatherUnit",
        "label": "Weather units",
        "desc": "Temperature scale on the home card, Auto follows your locale",
        "ctl": "seg",
        "src": "launcher.json",
        "opts": [
            "auto",
            "C",
            "F"
        ]
    },
    {
        "tab": "",
        "group": "HOME CARD",
        "key": "showWeather",
        "label": "Show weather",
        "desc": "Current conditions and temperature on the home card; off shows the date",
        "ctl": "sw",
        "src": "launcher.json"
    },
    {
        "tab": "",
        "group": "HOME CARD",
        "key": "showGreeting",
        "label": "Show greeting",
        "desc": "Time-of-day greeting above the home card clock",
        "ctl": "sw",
        "src": "launcher.json"
    },
    {
        "tab": "",
        "group": "BACKDROP",
        "key": "heroImage",
        "label": "Backdrop image",
        "desc": "Banner image behind the home card; empty falls back to the shipped art",
        "ctl": "text",
        "src": "launcher.json"
    },
    {
        "tab": "",
        "group": "BACKDROP",
        "key": "heroStrength",
        "label": "Strength",
        "desc": "How visible the backdrop image is; 0 hides it completely",
        "ctl": "slid",
        "src": "launcher.json",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "",
        "group": "BACKDROP",
        "key": "heroPosX",
        "label": "Backdrop focal point X",
        "desc": "Horizontal crop position, 0 left edge to 1 right; drag the preview",
        "ctl": "slid",
        "src": "launcher.json",
        "lo": 0.0,
        "hi": 1.0
    },
    {
        "tab": "",
        "group": "BACKDROP",
        "key": "heroPosY",
        "label": "Backdrop focal point Y",
        "desc": "Vertical crop position, 0 top edge to 1 bottom; drag the preview",
        "ctl": "slid",
        "src": "launcher.json",
        "lo": 0.0,
        "hi": 1.0
    }
];
