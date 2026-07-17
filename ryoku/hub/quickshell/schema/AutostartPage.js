.pragma library

// AutostartPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "OTHER",
        "key": "autostart",
        "label": "Command",
        "desc": "Shell command line, run verbatim at login; Save alone does not run it",
        "ctl": "list",
        "src": "settings.lua as an hl.on(\"hyprland.start\", ...) hook"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "autostart",
        "label": "Command",
        "desc": "Shell command line, run verbatim at login; Save alone does not run it",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "Command (per-row text field)"
        ]
    }
];
