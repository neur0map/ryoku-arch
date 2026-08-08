.pragma library

// LayerRulesPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "OTHER",
        "key": "layerRules",
        "label": "Custom layer rules",
        "desc": "Blur, dim, or restyle shell surfaces per namespace; applied only on Save",
        "ctl": "list",
        "src": "settings.lua"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "layerRules[i].namespace",
        "label": "Namespace",
        "desc": "Layer-shell name to match, e.g. launcher; no match means no effect",
        "ctl": "text",
        "src": "settings.lua"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "layerRules[i].action",
        "label": "Action",
        "desc": "What the rule does to matched surfaces; changing it resets the value",
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
        "label": "Value",
        "desc": "Only Ignore alpha takes a value: alpha cutoff 0.0 to 1.0, seeded to 0.5",
        "ctl": "text",
        "src": "settings.lua",
        "unit": "alpha"
    }
];
