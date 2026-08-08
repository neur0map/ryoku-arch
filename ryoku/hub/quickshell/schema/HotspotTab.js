.pragma library

// HotspotTab as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "Hotspot",
        "group": "OTHER",
        "key": "",
        "label": "Hotspot",
        "desc": "Shares this machine's connection over Wi-Fi; generates a password if unset",
        "ctl": "sw",
        "src": "down); nothing is written to any Ryoku config file"
    },
    {
        "tab": "Hotspot",
        "group": "DETAILS",
        "key": "802-11-wireless.ssid",
        "label": "Network name",
        "desc": "Name nearby devices see; edits take effect at once if the hotspot is live",
        "ctl": "text",
        "src": "RyokuHotspot.nmconnection (written via `nmcli connection add|modify`, read back via `nmcli -t -s -g 802-11-wireless.ssid,802-11-wireless-security.psk connection show RyokuHotspot`)"
    },
    {
        "tab": "Hotspot",
        "group": "DETAILS",
        "key": "802-11-wireless-security.psk",
        "label": "Password",
        "desc": "WPA2 key for joining; entries under 8 characters are silently dropped",
        "ctl": "text",
        "src": "RyokuHotspot.nmconnection (written via `nmcli connection add|modify`, read back via `nmcli -t -s -g \u2026802-11-wireless-security.psk connection show RyokuHotspot` \u2014 the -s secrets flag is required)",
        "lo": 8.0,
        "unit": "characters"
    }
];
