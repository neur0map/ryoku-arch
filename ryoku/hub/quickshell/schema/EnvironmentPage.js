.pragma library

// EnvironmentPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "OTHER",
        "key": "env",
        "label": "Variable name and value",
        "desc": "Name and value for one variable, e.g. MOZ_ENABLE_WAYLAND = 1",
        "ctl": "list",
        "src": "settings.lua as one `hl.env(\"NAME\", \"value\")` line per entry"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "env",
        "label": "Variable name and value",
        "desc": "Name and value for one variable, e.g. MOZ_ENABLE_WAYLAND = 1",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "NAME (per-row variable name)",
            "value (per-row variable value)"
        ]
    }
];
