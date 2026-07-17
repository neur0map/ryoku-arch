.pragma library

// EnvironmentPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "OTHER",
        "key": "env",
        "label": "Environment variables (the list itself)",
        "desc": "",
        "ctl": "list",
        "src": "settings.lua as one `hl.env(\"NAME\", \"value\")` line per entry"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "env",
        "label": "env",
        "desc": "",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "NAME (per-row variable name)",
            "value (per-row variable value)"
        ]
    }
];
