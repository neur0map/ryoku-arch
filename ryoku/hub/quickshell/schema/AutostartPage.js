.pragma library

// AutostartPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "OTHER",
        "key": "autostart",
        "label": "Autostart commands (the list itself)",
        "desc": "",
        "ctl": "list",
        "src": "settings.lua as an hl.on(\"hyprland.start\", ...) hook"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "autostart",
        "label": "autostart",
        "desc": "",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "Command (per-row text field)"
        ]
    }
];
