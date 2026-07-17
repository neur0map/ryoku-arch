.pragma library

// RashinPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "ENABLE",
        "key": "enabled",
        "label": "Start Rashin with the desktop and keep the dashboard available",
        "desc": "Applies immediately; greyed out until ryoku-rashin is installed",
        "ctl": "sw",
        "src": "rashin.json)"
    },
    {
        "tab": "",
        "group": "STATUS",
        "key": "",
        "label": "Daemon",
        "desc": "",
        "ctl": "readout",
        "src": " o.enabled), not a file"
    },
    {
        "tab": "",
        "group": "STATUS",
        "key": "",
        "label": "Vault files",
        "desc": "",
        "ctl": "readout",
        "src": " o.vault.files)",
        "unit": "files"
    },
    {
        "tab": "",
        "group": "STATUS",
        "key": "",
        "label": "Hermes agent",
        "desc": "",
        "ctl": "readout",
        "src": " o.hermes.configured)"
    },
    {
        "tab": "",
        "group": "STATUS",
        "key": "",
        "label": "Agents wired",
        "desc": "",
        "ctl": "readout",
        "src": " .wired)"
    },
    {
        "tab": "",
        "group": "HERMES",
        "key": "",
        "label": "Set up Hermes agent",
        "desc": "",
        "ctl": "action",
        "src": "Quickshell.execDetached([\"kitty\", \"--class\", \"ryoku-rashin-setup\", \"-e\", \"ryoku-rashin\", \"setup\"])"
    },
    {
        "tab": "",
        "group": "DASHBOARD",
        "key": "",
        "label": "Open dashboard",
        "desc": "",
        "ctl": "action",
        "src": "127.0.0.1:3600\"])"
    }
];
