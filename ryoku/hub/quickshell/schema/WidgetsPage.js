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
        "desc": "Shows the clock on your wallpaper; settings are kept while off",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "WIDGET",
        "key": "clockDesign",
        "label": "Face",
        "desc": "How the time is drawn: digits, analog hands, flip cards or rings",
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
        "desc": "Highlight colour: wallust follows the wallpaper, mono stays greyscale",
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
        "desc": "Shows 14:30 rather than 2:30 pm on the face",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "FORMAT",
        "key": "clockSeconds",
        "label": "Show seconds",
        "desc": "Adds seconds to the readout, the face updates every second",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "DATE",
        "key": "dateShow",
        "label": "Show date",
        "desc": "Adds today's date beside or under the time, styled by Date style",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "DATE",
        "key": "dateDesign",
        "label": "Date style",
        "desc": "How the date sits with the time: inline, as a badge, or stacked below",
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
        "desc": "Multiplies the widget's base size, 1.00 is the designed size",
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
        "desc": "Panel drawn behind the widget; pick none to sit right on the wallpaper",
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
        "desc": "Rounds the panel corners; only applies with a card or glass background",
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
        "desc": "Fades the whole widget; 20% is the floor so it never fully disappears",
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
        "desc": "Snaps the widget to a screen edge or corner; free uses X/Y or dragging",
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
        "desc": "Pixels from the left edge; only used when Anchor is set to free",
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
        "desc": "Pixels from the top edge; only used when Anchor is set to free",
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
        "desc": "Stops drags on the wallpaper so the widget cannot be moved by accident",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "weather",
        "group": "WIDGET",
        "key": "weatherEnabled",
        "label": "Enabled",
        "desc": "Shows the weather widget on your wallpaper; settings are kept while off",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "weather",
        "group": "WIDGET",
        "key": "weatherDesign",
        "label": "Design",
        "desc": "Layout: a full card, a small minimal readout, or a slim strip",
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
        "desc": "Shows temperatures in Celsius or Fahrenheit",
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
        "desc": "How far ahead the widget forecasts: just today or the whole week",
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
        "desc": "Animates the weather art; off shows a still picture of the conditions",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "weather",
        "group": "SIZE & SHAPE",
        "key": "weatherScale",
        "label": "Size",
        "desc": "Multiplies the widget's base size, 1.00 is the designed size",
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
        "desc": "Panel drawn behind the widget; pick none to sit right on the wallpaper",
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
        "desc": "Rounds the panel corners; only applies with a card or glass background",
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
        "desc": "Fades the whole widget; 20% is the floor so it never fully disappears",
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
        "desc": "Snaps the widget to a screen edge or corner; free uses X/Y or dragging",
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
        "desc": "Pixels from the left edge; only used when Anchor is set to free",
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
        "desc": "Pixels from the top edge; only used when Anchor is set to free",
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
        "desc": "Stops drags on the wallpaper so the widget cannot be moved by accident",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "WIDGET",
        "key": "calEnabled",
        "label": "Enabled",
        "desc": "Shows the calendar widget; day notes sync both ways with the pill",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "WIDGET",
        "key": "calDesign",
        "label": "Design",
        "desc": "Layout: full month grid, minimal, agenda list, week view, or heatmap",
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
        "desc": "Highlight colour: wallust follows the wallpaper, mono stays greyscale",
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
        "desc": "Which day leads each week row, Monday or Sunday",
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
        "desc": "Multiplies the widget's base size, 1.00 is the designed size",
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
        "desc": "Panel drawn behind the widget; pick none to sit right on the wallpaper",
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
        "desc": "Rounds the panel corners; only applies with a card or glass background",
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
        "desc": "Fades the whole widget; 20% is the floor so it never fully disappears",
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
        "desc": "Snaps the widget to a screen edge or corner; free uses X/Y or dragging",
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
        "desc": "Pixels from the left edge; only used when Anchor is set to free",
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
        "desc": "Pixels from the top edge; only used when Anchor is set to free",
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
        "desc": "Stops drags on the wallpaper so the widget cannot be moved by accident",
        "ctl": "sw",
        "src": "widgets.json"
    }
];
