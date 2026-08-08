.pragma library

// UpdatesPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "AUTOMATIC CHECKS",
        "key": "update_interval",
        "label": "Automatic checks",
        "desc": "How often the hub checks for updates by itself: off means manual only",
        "ctl": "seg",
        "src": "hub.toml), TOML table [ui], field update_interval",
        "opts": [
            "off",
            "hourly",
            "daily",
            "weekly"
        ]
    }
];
