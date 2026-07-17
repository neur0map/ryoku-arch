.pragma library

// BluetoothTab as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "Connections",
        "group": "(none \u2014 this file uses NO SettingSection at all; the toggle sits bare in the 48px header band, right-aligned in a Row with the Scan pill, spacing 14)",
        "key": "",
        "label": "(empty string \u2014 label: \"\" \u2014 a bare unlabelled switch; the word BLUETOOTH in the header band is separate static Text, not the ToggleRow's label)",
        "desc": "",
        "ctl": "sw",
        "src": "none \u2014 nothing is written to disk. Writes adapter.enabled on the BlueZ D-Bus adapter object via Quickshell.Bluetooth (Bluetooth.defaultAdapter). The blocked path additionally shells out to `rfkill unblock bluetooth`."
    }
];
