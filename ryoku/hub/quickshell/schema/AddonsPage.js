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
    }
];
