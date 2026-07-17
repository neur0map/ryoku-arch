.pragma library

// PluginPlacementEditor as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "Installed",
        "group": "OTHER",
        "key": "<pluginId>.framePopout.edge",
        "label": "Edge",
        "desc": "",
        "ctl": "seg",
        "src": "plugins.json) via `ryoku-plugins-place <id> framePopout <edge> <align> <hoverW> <hoverH>`",
        "opts": [
            "top",
            "right",
            "bottom",
            "left"
        ]
    },
    {
        "tab": "Installed",
        "group": "OTHER",
        "key": "<pluginId>.framePopout.align",
        "label": "Align (drag the \"popout\" chip along the chosen edge)",
        "desc": "",
        "ctl": "seg",
        "src": "plugins.json via `ryoku-plugins-place <id> framePopout <edge> <align> <hoverW> <hoverH>`",
        "opts": [
            "start",
            "end"
        ]
    },
    {
        "tab": "Installed",
        "group": "OTHER",
        "key": "<pluginId>.framePopout.hoverW",
        "label": "(no label \u2014 hover-zone width, carried through, not editable here)",
        "desc": "",
        "ctl": "step",
        "src": "plugins.json via `ryoku-plugins-place <id> framePopout <edge> <align> <hoverW> <hoverH>`",
        "unit": "px"
    },
    {
        "tab": "Installed",
        "group": "OTHER",
        "key": "<pluginId>.framePopout.hoverH",
        "label": "(no label \u2014 hover-zone thickness, carried through, not editable here)",
        "desc": "",
        "ctl": "step",
        "src": "plugins.json via `ryoku-plugins-place <id> framePopout <edge> <align> <hoverW> <hoverH>`",
        "unit": "px"
    }
];
