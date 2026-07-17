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
        "desc": "Screen edge the popout grows from, right when unset",
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
        "desc": "Which end of the edge, the centre is reserved for island, mixer, power",
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
        "label": "Hover zone width",
        "desc": "Width of the strip that opens the popout on hover, 320 when unset",
        "ctl": "step",
        "src": "plugins.json via `ryoku-plugins-place <id> framePopout <edge> <align> <hoverW> <hoverH>`",
        "unit": "px"
    },
    {
        "tab": "Installed",
        "group": "OTHER",
        "key": "<pluginId>.framePopout.hoverH",
        "label": "Hover zone thickness",
        "desc": "How far the hover strip reaches out from the edge, 16 when unset",
        "ctl": "step",
        "src": "plugins.json via `ryoku-plugins-place <id> framePopout <edge> <align> <hoverW> <hoverH>`",
        "unit": "px"
    }
];
