.pragma library

// LayerRulesPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "OTHER",
        "key": "layerRules",
        "label": "Custom layer rules (the list itself)",
        "desc": "",
        "ctl": "list",
        "src": "settings.lua"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "layerRules[i].namespace",
        "label": "Namespace (per-rule field 1; placeholder \"Namespace\")",
        "desc": "",
        "ctl": "text",
        "src": "settings.lua"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "layerRules[i].action",
        "label": "Action (per-rule field 2)",
        "desc": "",
        "ctl": "chips",
        "src": "settings.lua",
        "opts": [
            "blur",
            "blurpopups",
            "ignorealpha",
            "noanim",
            "dimaround",
            "xray",
            "abovelock"
        ]
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "layerRules[i].value",
        "label": "Value (per-rule field 3; placeholder is the action's valueHint, e.g. \"0.0 - 1.0\")",
        "desc": "",
        "ctl": "text",
        "src": "settings.lua",
        "unit": "alpha"
    }
];
