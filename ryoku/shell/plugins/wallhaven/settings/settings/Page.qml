import QtQuick
import "../../../../../Work/ryoku-arch/ryoku/hub/quickshell/Singletons" as Hub

/**
 * Wallhaven options, authored in the hub dialect so it sits natively inside Ryoku
 * Settings -> Plugins -> Wallhaven. The host (the Plugins page) loads this with
 * `pluginApi` set and calls saveSettings() on Apply. One field today: the
 * optional Wallhaven API key (raises rate limits and unlocks account NSFW).
 *
 * Note: when shipped, the Plugins page provides the hub Theme on the import path;
 * the dev path above points at the in-repo hub Singletons for the live loop.
 */
Column {
    id: root

    property var pluginApi
    spacing: 16

    function saveSettings() {
        if (pluginApi && pluginApi.pluginSettings) {
            pluginApi.pluginSettings.apiKey = keyEntry.text.trim();
            pluginApi.saveSettings();
        }
    }

    // Section header (mono uppercase + hairline), the hub's group idiom.
    Item {
        width: root.width
        height: 16
        Text {
            id: head
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "WALLHAVEN"
            color: Hub.Theme.dim
            font.family: Hub.Theme.mono
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 2
        }
        Rectangle {
            anchors.left: head.right; anchors.leftMargin: 14
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            height: 1; color: Hub.Theme.lineSoft
        }
    }

    Item {
        width: root.width
        height: 38
        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "API key"
            color: Hub.Theme.cream
            font.family: Hub.Theme.font
            font.pixelSize: 14
            font.weight: Font.Medium
        }
        Rectangle {
            id: box
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 280; height: 30; radius: 9
            color: Hub.Theme.surfaceLo
            border.width: 1
            border.color: keyEntry.activeFocus ? Hub.Theme.ember : Hub.Theme.line
            Behavior on border.color { ColorAnimation { duration: Hub.Theme.quick } }
            TextInput {
                id: keyEntry
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                text: (root.pluginApi && root.pluginApi.pluginSettings ? root.pluginApi.pluginSettings.apiKey : "") || ""
                color: Hub.Theme.bright
                font.family: Hub.Theme.font
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: keyEntry.text === "" && !keyEntry.activeFocus
                    text: "Optional, from wallhaven.cc/settings/account"
                    color: Hub.Theme.faint
                    font: keyEntry.font
                }
            }
        }
    }

    Text {
        width: root.width
        text: "Anonymous search works without a key. A key raises rate limits and unlocks NSFW per your account."
        color: Hub.Theme.dim
        font.family: Hub.Theme.font
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
}
