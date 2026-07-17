.pragma library

// PluginsPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "Installed",
        "group": "(none \u2014 this page uses NO SettingSection at all; every control is a bespoke inline Rectangle + TapHandler inside the per-plugin card)",
        "key": "<pluginId>.enabled",
        "label": "Enabled (the switch is unlabelled \u2014 it sits at the right of the plugin name/description row)",
        "desc": "",
        "ctl": "sw",
        "src": "plugins.json"
    },
    {
        "tab": "Installed",
        "group": "(none)",
        "key": "<pluginId>.host",
        "label": "Show as",
        "desc": "",
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
        "label": "Edge (chips: Top | Right | Bottom | Left)",
        "desc": "",
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
        "label": "(no label \u2014 set by dragging the \"popout\" chip along the chosen edge of the LIVE PLACEMENT stage)",
        "desc": "",
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
        "label": "(no control anywhere on this page \u2014 carried through on every write)",
        "desc": "",
        "ctl": "step",
        "src": "plugins.json",
        "unit": "px"
    },
    {
        "tab": "Installed",
        "group": "(none \u2014 inside PluginPlacementEditor)",
        "key": "<pluginId>.framePopout.hoverH",
        "label": "(no control anywhere on this page \u2014 carried through on every write)",
        "desc": "",
        "ctl": "step",
        "src": "plugins.json",
        "unit": "px"
    }
];
