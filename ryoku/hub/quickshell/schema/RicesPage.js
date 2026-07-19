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
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
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
        "desc": "Titles the new rice; a slugified form becomes its id and folder name",
        "ctl": "text",
        "src": "rice.json"
    },
    {
        "tab": "My",
        "group": "OTHER",
        "key": "",
        "label": "Save current setup",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "My",
        "group": "OTHER",
        "key": "",
        "label": "Restore original",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "action",
        "src": "*.json"
    },
    {
        "tab": "My",
        "group": "OTHER",
        "key": "",
        "label": "Import (a shared rice folder)",
        "desc": "Installs an exported rice folder as a local rice; the slug is de-duped",
        "ctl": "action",
        "src": "rice.json (copied under ~/.config/ryoku/rices)"
    },
    {
        "tab": "My",
        "group": "OTHER",
        "key": "",
        "label": "Save coverage (preflight readout)",
        "desc": "What a save carries right now: wallpaper kind, decors, widgets, layers",
        "ctl": "readout",
        "src": "ryoku-hub rice preflight (read-only)"
    },
    {
        "tab": "My",
        "group": "OTHER",
        "key": "",
        "label": "Save (commit the capture)",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "action",
        "src": "rice.json"
    },
    {
        "tab": "My",
        "group": "OTHER",
        "key": "",
        "label": "Cancel (abandon the capture)",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "Browse",
        "group": "OTHER",
        "key": "",
        "label": "Try again (reload the store catalog)",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "My",
        "group": "OTHER",
        "key": "",
        "label": "Rice tile (My rices grid)",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "Browse",
        "group": "OTHER",
        "key": "",
        "label": "Rice tile (Browse / store grid)",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Apply this rice / Applied",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "action",
        "src": "settings.lua, wallust colors.json, kitty theme)"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Duplicate",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "action",
        "src": "rice.json"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "assets.wallpaper",
        "label": "Set wallpaper",
        "desc": "Bundles a chosen image into the rice; it also becomes its tile preview",
        "ctl": "text",
        "src": "rice.json"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "View config",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "readout",
        "src": "rice.json (read-only)"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Export",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "action",
        "src": " breakout + README)"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Delete",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "action",
        "src": " (removed)"
    },
    {
        "tab": "",
        "group": "EXPORTED TO",
        "key": "",
        "label": "Show in files",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Back (to the grid)",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "action",
        "src": "shell"
    },
    {
        "tab": "",
        "group": "ALSO SETS",
        "key": "layers",
        "label": "ALSO SETS \u00b7 TAP TO EXCLUDE (behavior toggles)",
        "desc": "Behaviour bundled beyond the look; every chip applies unless tapped off",
        "ctl": "multi",
        "src": "hypr.json (brand \u2192 brand.json)",
        "opts": [
            "input",
            "windowRules",
            "layerRules",
            "appOverrides",
            "keybinds",
            "autostart",
            "env",
            "brand"
        ]
    },
    {
        "tab": "",
        "group": "WHAT IT TOUCHES",
        "key": "",
        "label": "WHAT IT TOUCHES (files this rice writes)",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "readout",
        "src": "read from `ryoku-hub rice files <slug>` \u2192 .touches"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Changes \u2026 (summary line)",
        "desc": "Sums up what applying alters: windows, bar, colours, wallpaper, cursor",
        "ctl": "readout",
        "src": "shell"
    }
];
