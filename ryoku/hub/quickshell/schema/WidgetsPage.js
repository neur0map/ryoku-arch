.pragma library

// WidgetsPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "clock",
        "group": "WIDGET",
        "key": "clockEnabled",
        "label": "Enabled",
        "desc": "",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "WIDGET",
        "key": "clockDesign",
        "label": "Face",
        "desc": "",
        "ctl": "chips",
        "src": "widgets.json",
        "opts": [
            "digital",
            "minimal",
            "analog",
            "flip",
            "rings"
        ]
    },
    {
        "tab": "clock",
        "group": "WIDGET",
        "key": "clockAccent",
        "label": "Accent",
        "desc": "",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "wallust",
            "brand",
            "mono"
        ]
    },
    {
        "tab": "clock",
        "group": "FORMAT",
        "key": "clock24h",
        "label": "24-hour clock",
        "desc": "",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "FORMAT",
        "key": "clockSeconds",
        "label": "Show seconds",
        "desc": "",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "DATE",
        "key": "dateShow",
        "label": "Show date",
        "desc": "",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "DATE",
        "key": "dateDesign",
        "label": "Date style",
        "desc": "",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "inline",
            "badge",
            "stacked"
        ]
    },
    {
        "tab": "clock",
        "group": "SIZE & SHAPE",
        "key": "clockScale",
        "label": "Size",
        "desc": "",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.5,
        "hi": 2.5
    },
    {
        "tab": "clock",
        "group": "SIZE & SHAPE",
        "key": "clockBg",
        "label": "Background",
        "desc": "",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "none",
            "card",
            "glass"
        ]
    },
    {
        "tab": "clock",
        "group": "SIZE & SHAPE",
        "key": "clockRadius",
        "label": "Corner radius",
        "desc": "",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 60.0,
        "unit": "px"
    },
    {
        "tab": "clock",
        "group": "SIZE & SHAPE",
        "key": "clockOpacity",
        "label": "Opacity",
        "desc": "",
        "ctl": "slid",
        "src": "widgets.json",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "clock",
        "group": "PLACEMENT",
        "key": "clockAnchor",
        "label": "Anchor",
        "desc": "",
        "ctl": "pick",
        "src": "widgets.json",
        "opts": [
            "top-left",
            "top",
            "top-right",
            "left",
            "center",
            "right",
            "bottom-left",
            "bottom",
            "bottom-right",
            "free"
        ]
    },
    {
        "tab": "clock",
        "group": "PLACEMENT",
        "key": "clockX",
        "label": "X",
        "desc": "",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 5000.0,
        "unit": "px"
    },
    {
        "tab": "clock",
        "group": "PLACEMENT",
        "key": "clockY",
        "label": "Y",
        "desc": "",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 5000.0,
        "unit": "px"
    },
    {
        "tab": "clock",
        "group": "PLACEMENT",
        "key": "clockLocked",
        "label": "Lock on desktop",
        "desc": "",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "weather",
        "group": "WIDGET",
        "key": "weatherEnabled",
        "label": "Enabled",
        "desc": "",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "weather",
        "group": "WIDGET",
        "key": "weatherDesign",
        "label": "Design",
        "desc": "",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "card",
            "minimal",
            "strip"
        ]
    },
    {
        "tab": "weather",
        "group": "READOUT",
        "key": "weatherUnit",
        "label": "Unit",
        "desc": "",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "C",
            "F"
        ]
    },
    {
        "tab": "weather",
        "group": "READOUT",
        "key": "weatherScope",
        "label": "Forecast",
        "desc": "",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "today",
            "week"
        ]
    },
    {
        "tab": "weather",
        "group": "READOUT",
        "key": "weatherAnimate",
        "label": "Live animations",
        "desc": "",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "weather",
        "group": "SIZE & SHAPE",
        "key": "weatherScale",
        "label": "Size",
        "desc": "",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.5,
        "hi": 2.5
    },
    {
        "tab": "weather",
        "group": "SIZE & SHAPE",
        "key": "weatherBg",
        "label": "Background",
        "desc": "",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "none",
            "card",
            "glass"
        ]
    },
    {
        "tab": "weather",
        "group": "SIZE & SHAPE",
        "key": "weatherRadius",
        "label": "Corner radius",
        "desc": "",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 60.0,
        "unit": "px"
    },
    {
        "tab": "weather",
        "group": "SIZE & SHAPE",
        "key": "weatherOpacity",
        "label": "Opacity",
        "desc": "",
        "ctl": "slid",
        "src": "widgets.json",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "weather",
        "group": "PLACEMENT",
        "key": "weatherAnchor",
        "label": "Anchor",
        "desc": "",
        "ctl": "pick",
        "src": "widgets.json",
        "opts": [
            "top-left",
            "top",
            "top-right",
            "left",
            "center",
            "right",
            "bottom-left",
            "bottom",
            "bottom-right",
            "free"
        ]
    },
    {
        "tab": "weather",
        "group": "PLACEMENT",
        "key": "weatherX",
        "label": "X",
        "desc": "",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 5000.0,
        "unit": "px"
    },
    {
        "tab": "weather",
        "group": "PLACEMENT",
        "key": "weatherY",
        "label": "Y",
        "desc": "",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 5000.0,
        "unit": "px"
    },
    {
        "tab": "weather",
        "group": "PLACEMENT",
        "key": "weatherLocked",
        "label": "Lock on desktop",
        "desc": "",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "WIDGET",
        "key": "calEnabled",
        "label": "Enabled",
        "desc": "",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "WIDGET",
        "key": "calDesign",
        "label": "Design",
        "desc": "",
        "ctl": "chips",
        "src": "widgets.json",
        "opts": [
            "month",
            "minimal",
            "agenda",
            "week",
            "heat"
        ]
    },
    {
        "tab": "calendar",
        "group": "WIDGET",
        "key": "calAccent",
        "label": "Accent",
        "desc": "",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "wallust",
            "brand",
            "mono"
        ]
    },
    {
        "tab": "calendar",
        "group": "WEEK",
        "key": "calWeekStart",
        "label": "Starts on",
        "desc": "",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "mon",
            "sun"
        ]
    },
    {
        "tab": "calendar",
        "group": "SIZE & SHAPE",
        "key": "calScale",
        "label": "Size",
        "desc": "",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.5,
        "hi": 2.5
    },
    {
        "tab": "calendar",
        "group": "SIZE & SHAPE",
        "key": "calBg",
        "label": "Background",
        "desc": "",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "none",
            "card",
            "glass"
        ]
    },
    {
        "tab": "calendar",
        "group": "SIZE & SHAPE",
        "key": "calRadius",
        "label": "Corner radius",
        "desc": "",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 60.0,
        "unit": "px"
    },
    {
        "tab": "calendar",
        "group": "SIZE & SHAPE",
        "key": "calOpacity",
        "label": "Opacity",
        "desc": "",
        "ctl": "slid",
        "src": "widgets.json",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calAnchor",
        "label": "Anchor",
        "desc": "",
        "ctl": "pick",
        "src": "widgets.json",
        "opts": [
            "top-left",
            "top",
            "top-right",
            "left",
            "center",
            "right",
            "bottom-left",
            "bottom",
            "bottom-right",
            "free"
        ]
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calX",
        "label": "X",
        "desc": "",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 5000.0,
        "unit": "px"
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calY",
        "label": "Y",
        "desc": "",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 5000.0,
        "unit": "px"
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calLocked",
        "label": "Lock on desktop",
        "desc": "",
        "ctl": "sw",
        "src": "widgets.json"
    }
];
