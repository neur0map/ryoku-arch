.pragma library

// DisplaysPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "<selected monitor name> (SettingSection title is dynamic: page.sel.name; literal fallback \"DISPLAY\" when no selection)",
        "key": "disabled",
        "label": "Enabled",
        "desc": "",
        "ctl": "sw",
        "src": "<name>.json (RYOKU_MONITORS_DIR) on Save"
    },
    {
        "tab": "",
        "group": "<selected monitor name> (dynamic; fallback \"DISPLAY\")",
        "key": "mode",
        "label": "Resolution",
        "desc": "",
        "ctl": "chips",
        "src": "<name>.json (Save)",
        "opts": [
            "DYNAMIC",
            "Option",
            "Option",
            "Parsed",
            "De-duplicated",
            "Sorted:",
            "Fallback",
            "Related"
        ]
    },
    {
        "tab": "",
        "group": "<selected monitor name> (dynamic; fallback \"DISPLAY\")",
        "key": "scale",
        "label": "Scale",
        "desc": "",
        "ctl": "step",
        "src": "<name>.json (Save)",
        "lo": 0.5,
        "hi": 3.0
    },
    {
        "tab": "",
        "group": "<selected monitor name> (dynamic; fallback \"DISPLAY\")",
        "key": "transform",
        "label": "Rotation",
        "desc": "",
        "ctl": "seg",
        "src": "<name>.json (Save)",
        "opts": [
            "0",
            "1",
            "2",
            "3"
        ]
    },
    {
        "tab": "",
        "group": "<selected monitor name> (dynamic; fallback \"DISPLAY\")",
        "key": "vrr",
        "label": "Adaptive sync",
        "desc": "",
        "ctl": "seg",
        "src": "<name>.json (Save)",
        "opts": [
            "0",
            "1",
            "2"
        ]
    },
    {
        "tab": "",
        "group": "<selected monitor name> (dynamic; fallback \"DISPLAY\")",
        "key": "mirror",
        "label": "Mirror of",
        "desc": "",
        "ctl": "seg",
        "src": "<name>.json (Save)",
        "opts": [
            "\"\"",
            "DYNAMIC:",
            "Excluded"
        ]
    },
    {
        "tab": "",
        "group": "POSITION",
        "key": "position (serialised jointly as \"<x>x<y>\", e.g. \"2560x0\" \u2014 X and Y are NOT separate disk keys)",
        "label": "X",
        "desc": "",
        "ctl": "step",
        "src": "<name>.json (Save)",
        "lo": 0.0,
        "hi": 20000.0,
        "unit": "px"
    },
    {
        "tab": "",
        "group": "POSITION",
        "key": "position (serialised jointly as \"<x>x<y>\" \u2014 X and Y are NOT separate disk keys)",
        "label": "Y",
        "desc": "",
        "ctl": "step",
        "src": "<name>.json (Save)",
        "lo": 0.0,
        "hi": 20000.0,
        "unit": "px"
    },
    {
        "tab": "",
        "group": "PROFILES",
        "key": "filename \u2014 becomes ~/.config/ryoku/monitors/<name>.json",
        "label": "Profile name\u2026 (placeholder; the row has no visible label)",
        "desc": "",
        "ctl": "text",
        "src": "<name>.json (RYOKU_MONITORS_DIR)"
    },
    {
        "tab": "",
        "group": "PROFILES",
        "key": "",
        "label": "Save (profile)",
        "desc": "",
        "ctl": "action",
        "src": "monitors.lua"
    },
    {
        "tab": "",
        "group": "(header quick-actions Row \u2014 outside any SettingSection, top-right, aligned to the \"N displays detected\" text)",
        "key": "",
        "label": "Mirror (quick action)",
        "desc": "",
        "ctl": "action",
        "src": "monitors.lua (via cmd_mirror \u2192 cmd_persist)"
    },
    {
        "tab": "",
        "group": "(header quick-actions Row \u2014 outside any SettingSection)",
        "key": "",
        "label": "Extend (quick action)",
        "desc": "",
        "ctl": "action",
        "src": "monitors-applied.json"
    },
    {
        "tab": "",
        "group": "(header quick-actions Row \u2014 outside any SettingSection)",
        "key": "",
        "label": "DPI auto-scale (quick action)",
        "desc": "",
        "ctl": "action",
        "src": "monitors-applied.json"
    },
    {
        "tab": "",
        "group": "(bottom action bar \u2014 outside any SettingSection)",
        "key": "",
        "label": "Apply (action bar)",
        "desc": "",
        "ctl": "action",
        "src": "monitors-applied.json"
    },
    {
        "tab": "",
        "group": "(bottom action bar \u2014 outside any SettingSection)",
        "key": "",
        "label": "Revert (action bar)",
        "desc": "",
        "ctl": "action",
        "src": "shell"
    }
];
