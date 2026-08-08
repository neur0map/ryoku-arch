.pragma library

// FastfetchPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "EMBLEM",
        "key": "logo.type",
        "label": "Emblem kind",
        "desc": "Art beside the readout: an image, ASCII art, the distro logo, or none",
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
        "label": "Emblem file",
        "desc": "Image or ASCII art file to draw; an SVG is rasterized to PNG on import",
        "ctl": "text",
        "src": "config.jsonc"
    },
    {
        "tab": "",
        "group": "EMBLEM",
        "key": "logo.width",
        "label": "Width",
        "desc": "How many character columns the art spans in the terminal readout",
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
        "desc": "Lines of text the art covers; the col unit here means character cells",
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
        "desc": "Blank columns between the terminal edge and the art",
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
        "desc": "Tints the label column of each info line; stored as an r;g;b triple",
        "ctl": "color",
        "src": "config.jsonc"
    },
    {
        "tab": "",
        "group": "INFO",
        "key": "modules",
        "label": "Info rows",
        "desc": "The lines of the readout: reorder, rename, disable, or remove each one",
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
        "label": "Row name",
        "desc": "Name shown for the row in this list; display only, nothing is stored",
        "ctl": "readout",
        "src": "shell"
    }
];
