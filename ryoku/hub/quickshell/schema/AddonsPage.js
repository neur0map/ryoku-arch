.pragma library

// AddonsPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "detail",
        "group": "Placement",
        "key": "<pluginId>.enabled",
        "label": "Enabled",
        "desc": "Runs the add-on on your desktop; off keeps it installed but inactive",
        "ctl": "sw",
        "src": "plugins.json (via `ryoku-plugins-place <id> enabled <true|false>`)"
    },
    {
        "tab": "detail",
        "group": "Placement",
        "key": "<pluginId>.host",
        "label": "Show as",
        "desc": "Where it appears: a frame popout, or a movable tile on the wallpaper",
        "ctl": "seg",
        "src": "plugins.json (via `ryoku-plugins-place <id> host <hostName>`)",
        "opts": [
            "framePopout",
            "desktopWidget",
            "<any"
        ]
    },
    {
        "tab": "detail",
        "group": "(plugin-declared, from manifest.metadata.settings[].group \u2014 group headers are rendered by PluginSettingsForm itself, one per distinct `group` string, in schema order; fields with group \"\" get no header)",
        "key": "<pluginId>.settings.<field.key>",
        "label": "(plugin-declared, field.label, falling back to field.key)",
        "desc": "Each add-on defines its own; changes apply to the desktop live",
        "ctl": "custom",
        "src": "plugins.json (via `ryoku-plugins-place <id> settings <json>`, one single-key object per change, jq-merged into the existing settings object)",
        "unit": "none"
    },
    {
        "tab": "Plugins",
        "group": "Management",
        "key": "",
        "label": "Update / Remove",
        "desc": "Refreshes or removes an installed plugin while placement remains in plugins.json",
        "ctl": "action",
        "src": "ryostore internal install-guest|remove-guest plugins <id>"
    },
    {
        "tab": "Bundles",
        "group": "Management",
        "key": "",
        "label": "Remove component / bundle",
        "desc": "Shows every component state and opens the extras actuator in a terminal for removal",
        "ctl": "action",
        "src": "ryoku-extras-install remove item|bundle"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Browse RyoStore",
        "desc": "Opens the matching plugin or bundle catalogue",
        "ctl": "action",
        "src": "ryostore open plugins|bundles"
    }
];
