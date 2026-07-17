.pragma library

// FastfetchPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "EMBLEM",
        "key": "logo.type",
        "label": "(unlabelled segmented: emblem kind)",
        "desc": "",
        "ctl": "seg",
        "src": "config.jsonc), written by `ryoku-hub fastfetch save <json>`",
        "opts": [
            "image",
            "ascii",
            "builtin",
            "none"
        ]
    },
    {
        "tab": "",
        "group": "EMBLEM",
        "key": "logo.source",
        "label": "(file path readout) + \"Choose image\" / \"Choose .txt\" button",
        "desc": "",
        "ctl": "text",
        "src": "config.jsonc"
    },
    {
        "tab": "",
        "group": "EMBLEM",
        "key": "logo.width",
        "label": "Width",
        "desc": "",
        "ctl": "step",
        "src": "config.jsonc",
        "lo": 0.0,
        "hi": 80.0,
        "unit": "col"
    },
    {
        "tab": "",
        "group": "EMBLEM",
        "key": "logo.height",
        "label": "Height",
        "desc": "",
        "ctl": "step",
        "src": "config.jsonc",
        "lo": 0.0,
        "hi": 60.0,
        "unit": "col"
    },
    {
        "tab": "",
        "group": "EMBLEM",
        "key": "logo.padding.left",
        "label": "Pad",
        "desc": "",
        "ctl": "step",
        "src": "config.jsonc",
        "lo": 0.0,
        "hi": 20.0,
        "unit": "col"
    },
    {
        "tab": "",
        "group": "ACCENT",
        "key": "display.color.keys",
        "label": "Readout accent",
        "desc": "",
        "ctl": "color",
        "src": "config.jsonc"
    },
    {
        "tab": "",
        "group": "INFO",
        "key": "modules",
        "label": "modules",
        "desc": "",
        "ctl": "multi",
        "src": "shell",
        "opts": [
            "(per row) move up / move down",
            "(per row) enable / disable",
            "(per row) inline text / key editor",
            "(per row) remove",
            "__header"
        ]
    },
    {
        "tab": "",
        "group": "INFO",
        "key": "(none \u2014 derived, not persisted)",
        "label": "(per row) row name",
        "desc": "",
        "ctl": "readout",
        "src": "shell"
    }
];
