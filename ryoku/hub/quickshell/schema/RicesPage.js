.pragma library

// RicesPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "My rices / Browse (mode switch)",
        "desc": "",
        "ctl": "seg",
        "src": "shell",
        "opts": [
            "mine",
            "store"
        ]
    },
    {
        "tab": "My",
        "group": "OTHER",
        "key": "name (\u2192 also derives \"slug\" via backend slugify)",
        "label": "Name this rice (for example, My Setup)",
        "desc": "",
        "ctl": "text",
        "src": "rice.json"
    },
    {
        "tab": "My",
        "group": "OTHER",
        "key": "",
        "label": "Save current setup",
        "desc": "",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "My",
        "group": "OTHER",
        "key": "",
        "label": "Restore original",
        "desc": "",
        "ctl": "action",
        "src": "*.json"
    },
    {
        "tab": "My",
        "group": "OTHER",
        "key": "",
        "label": "Save (commit the capture)",
        "desc": "",
        "ctl": "action",
        "src": "rice.json"
    },
    {
        "tab": "My",
        "group": "OTHER",
        "key": "",
        "label": "Cancel (abandon the capture)",
        "desc": "",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "Browse",
        "group": "OTHER",
        "key": "",
        "label": "Try again (reload the store catalog)",
        "desc": "",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "My",
        "group": "OTHER",
        "key": "",
        "label": "Rice tile (My rices grid)",
        "desc": "",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "Browse",
        "group": "OTHER",
        "key": "",
        "label": "Rice tile (Browse / store grid)",
        "desc": "",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Apply this rice / Applied",
        "desc": "",
        "ctl": "action",
        "src": "settings.lua, wallust colors.json, kitty theme)"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Duplicate",
        "desc": "",
        "ctl": "action",
        "src": "rice.json"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "assets.wallpaper",
        "label": "Set wallpaper",
        "desc": "",
        "ctl": "text",
        "src": "rice.json"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "View config",
        "desc": "",
        "ctl": "readout",
        "src": "rice.json (read-only)"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Export",
        "desc": "",
        "ctl": "action",
        "src": " breakout + README)"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Delete",
        "desc": "",
        "ctl": "action",
        "src": " (removed)"
    },
    {
        "tab": "",
        "group": "EXPORTED TO",
        "key": "",
        "label": "Show in files",
        "desc": "",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Back (to the grid)",
        "desc": "",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "",
        "group": "ALSO SETS",
        "key": "layers",
        "label": "ALSO SETS (behavior layers carried by the rice)",
        "desc": "",
        "ctl": "multi",
        "src": "hypr.json",
        "opts": [
            "input",
            "windowRules",
            "layerRules",
            "appOverrides",
            "keybinds",
            "autostart",
            "env"
        ]
    },
    {
        "tab": "",
        "group": "WHAT IT TOUCHES",
        "key": "",
        "label": "WHAT IT TOUCHES (files this rice writes)",
        "desc": "",
        "ctl": "readout",
        "src": "read from `ryoku-hub rice files <slug>` \u2192 .touches"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Changes \u2026 (summary line)",
        "desc": "",
        "ctl": "readout",
        "src": "shell"
    }
];
