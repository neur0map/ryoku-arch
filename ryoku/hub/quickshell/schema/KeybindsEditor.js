.pragma library

// KeybindsEditor as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "Custom",
        "group": "OTHER",
        "key": "keybinds",
        "label": "Custom shortcuts (list)",
        "desc": "Empties the list in one go; Revert can bring it back until you Save",
        "ctl": "list",
        "src": "settings.lua as hl.bind(...) lines on Save"
    },
    {
        "tab": "Custom",
        "group": "OTHER",
        "key": "keybinds",
        "label": "keybinds",
        "desc": "Empties the list in one go; Revert can bring it back until you Save",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "(row) key combo \u2014 placeholder \"SUPER + J\"",
            "exec",
            "(row) command \u2014 placeholder \"command to run\""
        ]
    },
    {
        "tab": "Custom",
        "group": "OTHER",
        "key": "keybinds",
        "label": "Add shortcut",
        "desc": "Empties the list in one go; Revert can bring it back until you Save",
        "ctl": "action",
        "src": "hypr.json"
    },
    {
        "tab": "Custom",
        "group": "OTHER",
        "key": "keybinds",
        "label": "(row) delete",
        "desc": "Empties the list in one go; Revert can bring it back until you Save",
        "ctl": "action",
        "src": "hypr.json"
    },
    {
        "tab": "Custom",
        "group": "OTHER",
        "key": "keybinds",
        "label": "Clear all",
        "desc": "Empties the list in one go; Revert can bring it back until you Save",
        "ctl": "action",
        "src": "hypr.json"
    }
];
