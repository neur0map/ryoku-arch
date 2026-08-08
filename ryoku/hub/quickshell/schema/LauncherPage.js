.pragma library

// LauncherPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "LAUNCHER",
        "key": "variant",
        "label": "Style",
        "desc": "Selects Main, Hero, or OkShell for Super+Space",
        "ctl": "seg",
        "src": "launcher.json"
    },
    {
        "tab": "",
        "group": "SHAPE",
        "key": "radius",
        "label": "Corner radius",
        "desc": "Rounds the palette window corners, inner cards follow 4 px tighter",
        "ctl": "step",
        "src": "launcher.json",
        "lo": 0.0,
        "hi": 28.0,
        "unit": "px"
    },
    {
        "tab": "",
        "group": "BACKGROUND",
        "key": "bgBlur",
        "label": "Local frost",
        "desc": "Softens the frozen card-local desktop snapshot captured as the launcher opens",
        "ctl": "step",
        "src": "launcher.json",
        "lo": 0.0,
        "hi": 30.0,
        "unit": "px"
    },
    {
        "tab": "",
        "group": "RESULT MOTION",
        "key": "resultSettleMs",
        "label": "Type settle",
        "desc": "Waits for a pause before the finished result deck fades in; higher values feel calmer",
        "ctl": "step",
        "src": "launcher.json",
        "lo": 120.0,
        "hi": 700.0,
        "unit": "ms"
    },
    {
        "tab": "",
        "group": "HERO",
        "key": "weatherUnit",
        "label": "Weather units",
        "desc": "Temperature scale on the hero, Auto follows your locale",
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
        "group": "HERO",
        "key": "showWeather",
        "label": "Show weather",
        "desc": "Current conditions and temperature on the hero; off shows the date",
        "ctl": "sw",
        "src": "launcher.json"
    },
    {
        "tab": "",
        "group": "HERO",
        "key": "showGreeting",
        "label": "Show greeting",
        "desc": "Time-of-day greeting above the hero clock",
        "ctl": "sw",
        "src": "launcher.json"
    },
    {
        "tab": "",
        "group": "HERO IMAGE",
        "key": "heroImage",
        "label": "Hero image",
        "desc": "Image behind the launcher controls; empty falls back to the shipped art",
        "ctl": "text",
        "src": "launcher.json"
    },
    {
        "tab": "",
        "group": "HERO IMAGE",
        "key": "heroStrength",
        "label": "Strength",
        "desc": "How visible the hero image is; 0 hides it completely",
        "ctl": "slid",
        "src": "launcher.json",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "",
        "group": "HERO IMAGE",
        "key": "heroPosX",
        "label": "Hero focal point X",
        "desc": "Horizontal crop position, 0 left edge to 1 right; drag the preview",
        "ctl": "slid",
        "src": "launcher.json",
        "lo": 0.0,
        "hi": 1.0
    },
    {
        "tab": "",
        "group": "HERO IMAGE",
        "key": "heroPosY",
        "label": "Hero focal point Y",
        "desc": "Vertical crop position, 0 top edge to 1 bottom; drag the preview",
        "ctl": "slid",
        "src": "launcher.json",
        "lo": 0.0,
        "hi": 1.0
    }
];
