.pragma library

var icons = {
    "lan": "\uEB2F",
    "wifi_off": "\uE648",
    "signal_wifi_off": "\uE1DA",
    "signal_wifi_0_bar": "\uF0B0",
    "wifi_1_bar": "\uE4CA",
    "network_wifi_1_bar": "\uEBE4",
    "wifi_2_bar": "\uE4D9",
    "network_wifi_2_bar": "\uEBD6",
    "network_wifi_3_bar": "\uEBE1",
    "signal_wifi_4_bar": "\uF065",
    "bluetooth": "\uE1A7",
    "bluetooth_connected": "\uE1A8",
    "bluetooth_disabled": "\uE1A9",
    "volume_up": "\uE050",
    "volume_down": "\uE04D",
    "volume_mute": "\uE04E",
    "volume_off": "\uE04F",
    "headphones": "\uE8F0",
    "mic": "\uE029",
    "mic_off": "\uE02B",
    "memory": "\uE322",
    "storage": "\uE1DB",
    "speed": "\uE9E4",
    "package_2": "\uF569",
}

function icon(name) {
    return icons[name] || name
}
