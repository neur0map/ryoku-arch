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
        "desc": "Highlight colour: palette follows the wallpaper, mono stays greyscale",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "palette",
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
        "tab": "calendar",
        "group": "WIDGET",
        "key": "calendarEnabled",
        "label": "Enabled",
        "desc": "Shows the calendar on the wallpaper; settings are kept while off",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "WIDGET",
        "key": "calendarStyle",
        "label": "Style",
        "desc": "Wallpaper Glass follows the wallpaper tint; Ryoku Paper is opaque paper and ink",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": ["glass", "paper"]
    },
    {
        "tab": "calendar",
        "group": "CALENDAR",
        "key": "calendarWeeks",
        "label": "Minimum weeks",
        "desc": "Prefers four to eight rows; compact views grow when needed so no dates are omitted",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 4,
        "hi": 8
    },
    {
        "tab": "calendar",
        "group": "CALENDAR",
        "key": "calendarWeekNumbers",
        "label": "ISO week numbers",
        "desc": "Adds the week-of-year column to the left of the calendar",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "HOLIDAYS",
        "key": "calendarHolidayRegion",
        "label": "Holiday region",
        "desc": "Blank follows the system locale; use a country or subdivision code such as US or US-CA",
        "ctl": "text",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "SIZE & SHAPE",
        "key": "calendarScale",
        "label": "Size",
        "desc": "Multiplies the calendar's designed size",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.5,
        "hi": 2.0
    },
    {
        "tab": "calendar",
        "group": "SIZE & SHAPE",
        "key": "calendarOpacity",
        "label": "Opacity",
        "desc": "Fades the calendar while keeping it readable",
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
        "key": "calendarAnchor",
        "label": "Anchor",
        "desc": "Snaps the calendar to a screen edge or corner; free uses X/Y or dragging",
        "ctl": "pick",
        "src": "widgets.json",
        "opts": ["top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calendarX",
        "label": "X",
        "desc": "Pixels from the left edge when Anchor is free",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0,
        "hi": 5000,
        "unit": "px"
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calendarY",
        "label": "Y",
        "desc": "Pixels from the top edge when Anchor is free",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0,
        "hi": 5000,
        "unit": "px"
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calendarLocked",
        "label": "Lock on desktop",
        "desc": "Stops accidental moves and resizes",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicEnabled",
        "label": "Enabled",
        "desc": "Shows the now-playing sheet on your wallpaper; settings are kept while off",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicStyle",
        "label": "Style",
        "desc": "Cover wears the album's own colour; Glass is a frosted wallpaper pane",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": ["cover", "glass"]
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicLyrics",
        "label": "Lyrics",
        "desc": "Shows the synced lyric sheet beside the album when a match is found",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicApp",
        "label": "Music app",
        "desc": "The app the corner button opens; blank uses ryotunes (YouTube Music)",
        "ctl": "app",
        "src": "widgets.json"
    },
    {
        "tab": "music",
        "group": "SIZE & SHAPE",
        "key": "musicScale",
        "label": "Size",
        "desc": "Multiplies the sheet's designed size",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.5,
        "hi": 2.0
    },
    {
        "tab": "music",
        "group": "SIZE & SHAPE",
        "key": "musicOpacity",
        "label": "Opacity",
        "desc": "Fades the sheet while keeping it readable",
        "ctl": "slid",
        "src": "widgets.json",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "music",
        "group": "PLACEMENT",
        "key": "musicAnchor",
        "label": "Anchor",
        "desc": "Snaps the sheet to a screen edge or corner; free uses X/Y or dragging",
        "ctl": "pick",
        "src": "widgets.json",
        "opts": ["top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "music",
        "group": "PLACEMENT",
        "key": "musicX",
        "label": "X",
        "desc": "Pixels from the left edge when Anchor is free",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0,
        "hi": 5000,
        "unit": "px"
    },
    {
        "tab": "music",
        "group": "PLACEMENT",
        "key": "musicY",
        "label": "Y",
        "desc": "Pixels from the top edge when Anchor is free",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0,
        "hi": 5000,
        "unit": "px"
    },
    {
        "tab": "music",
        "group": "PLACEMENT",
        "key": "musicLocked",
        "label": "Lock on desktop",
        "desc": "Stops accidental moves and resizes",
        "ctl": "sw",
        "src": "widgets.json"
    }
];
