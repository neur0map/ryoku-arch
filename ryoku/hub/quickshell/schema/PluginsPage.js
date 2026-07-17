.pragma library

// PluginsPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "Installed",
        "group": "(none \u2014 this page uses NO SettingSection at all; every control is a bespoke inline Rectangle + TapHandler inside the per-plugin card)",
        "key": "<pluginId>.enabled",
        "label": "Enabled",
        "desc": "Loads the plugin into the running shell; applies live, no restart",
        "ctl": "sw",
        "src": "plugins.json"
    },
    {
        "tab": "Installed",
        "group": "(none)",
        "key": "<pluginId>.host",
        "label": "Show as",
        "desc": "Popouts dock to a screen edge; widgets are dragged loose on the desktop",
        "ctl": "seg",
        "src": "plugins.json",
        "opts": [
            "framePopout",
            "desktopWidget"
        ]
    },
    {
        "tab": "Installed",
        "group": "(none \u2014 inside the embedded PluginPlacementEditor, visible only when card.on && card.host === \"framePopout\")",
        "key": "<pluginId>.framePopout.edge",
        "label": "Edge",
        "desc": "Screen edge the popout opens from (right until first placed)",
        "ctl": "seg",
        "src": "plugins.json",
        "opts": [
            "top",
            "right",
            "bottom",
            "left"
        ]
    },
    {
        "tab": "Installed",
        "group": "(none \u2014 inside PluginPlacementEditor)",
        "key": "<pluginId>.framePopout.align",
        "label": "Position along edge",
        "desc": "Which end of the edge the popout docks at; the centre is always reserved",
        "ctl": "seg",
        "src": "plugins.json",
        "opts": [
            "start",
            "end"
        ]
    },
    {
        "tab": "Installed",
        "group": "(none \u2014 inside PluginPlacementEditor)",
        "key": "<pluginId>.framePopout.hoverW",
        "label": "Hover strip length",
        "desc": "Length of the hover strip that opens the popout; unset saves as 320",
        "ctl": "step",
        "src": "plugins.json",
        "unit": "px"
    },
    {
        "tab": "Installed",
        "group": "(none \u2014 inside PluginPlacementEditor)",
        "key": "<pluginId>.framePopout.hoverH",
        "label": "Hover strip depth",
        "desc": "How far the hover strip reaches in from the edge; unset saves as 16",
        "ctl": "step",
        "src": "plugins.json",
        "unit": "px"
    }
];
