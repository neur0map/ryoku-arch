pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "Singletons"

// In-app settings: API key, NSFW, where downloads land.
Item {
    id: sp
    property bool open: false
    signal closed()

    // re-probe on open so a just-installed upscaler flips Install to a live toggle.
    onOpenChanged: if (open) Wallhaven.refreshCaps()

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }

    // the scrim tap co-fires with taps on the card's controls (overlapping
    // TapHandlers all see the tap; a MouseArea would steal it from the toggles
    // instead), so click-out is gated on the cursor not being over the card.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        TapHandler { onTapped: if (!cardHover.hovered) sp.closed() }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 460
        height: col.implicitHeight + 44
        radius: Theme.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }
        border.width: 1
        border.color: Theme.line
        scale: sp.open ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        HoverHandler { id: cardHover }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 22
            spacing: 18

            Item {
                width: parent.width
                height: 28
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Settings"; color: Theme.bright; font.family: Theme.font; font.pixelSize: 18; font.weight: Font.DemiBold }
                Item {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26
                    Icon { anchors.centerIn: parent; name: "close"; size: 15; tint: ch.hovered ? Theme.ember : Theme.faint; Behavior on tint { ColorAnimation { duration: Theme.quick } } }
                    HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: sp.closed() }
                }
            }

            Column {
                width: parent.width
                spacing: 7
                Text { text: "Wallhaven API key"; color: Theme.cream; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                Rectangle {
                    width: parent.width
                    height: 38
                    radius: Theme.radius
                    color: Theme.surfaceLo
                    border.width: 1
                    border.color: keyInput.activeFocus ? Theme.ember : Theme.line
                    Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                    TextInput {
                        id: keyInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.bright
                        font.family: Theme.mono
                        font.pixelSize: 12
                        selectByMouse: true
                        selectionColor: Theme.frameBg
                        clip: true
                        text: Wallhaven.settings.apiKey
                        onTextEdited: Wallhaven.settings.apiKey = text
                        onEditingFinished: Wallhaven.saveSettings()
                        Text { anchors.fill: parent; visible: keyInput.text.length === 0; verticalAlignment: Text.AlignVCenter; text: "paste your key"; color: Theme.faint; font: keyInput.font }
                    }
                }
                Text { width: parent.width; wrapMode: Text.WordWrap; text: "Optional, from wallhaven.cc/settings/account. Raises rate limits and unlocks NSFW."; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11 }
            }

            Item {
                width: parent.width
                height: 24
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Show NSFW"; color: Theme.cream; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                Toggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: Wallhaven.apiKey.length > 0
                    on: Wallhaven.settings.nsfw
                    onToggled: (v) => {
                        Wallhaven.settings.nsfw = v;
                        Wallhaven.saveSettings();
                        if (!Wallhaven.searching) Wallhaven.searchTop(Wallhaven.topRange);
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.line }

            Item {
                width: parent.width
                height: 24
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Pause live wallpaper when covered"; color: Theme.cream; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                Toggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: Wallhaven.settings.pauseWhenCovered
                    onToggled: (v) => {
                        Wallhaven.settings.pauseWhenCovered = v;
                        Wallhaven.saveSettings();
                        Quickshell.execDetached(["ryoku-shell", "wallpaper", "pause-sync"]);
                    }
                }
            }

            // shown when the GPU can upscale; Install pulls the one tool that does it.
            Column {
                width: parent.width
                spacing: 5
                visible: Wallhaven.upscaleSupported
                Item {
                    width: parent.width
                    height: 30
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Enhance on save (AI upscale)"; color: Theme.cream; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        HubButton {
                            visible: !Wallhaven.upscaler
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "download"
                            label: "Install"
                            onClicked: Wallhaven.installUpscaler()
                        }
                        Toggle {
                            visible: Wallhaven.upscaler
                            anchors.verticalCenter: parent.verticalCenter
                            on: Wallhaven.settings.upscale
                            onToggled: (v) => { Wallhaven.settings.upscale = v; Wallhaven.saveSettings(); }
                        }
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: Wallhaven.upscaler
                        ? "Sharpens low-res wallpapers on your GPU when you save them, images and video alike. Looks noticeably better, but saving takes longer and the file gets bigger (a lot for video)."
                        : "Needs a Vulkan upscaler (waifu2x). Install opens gpk: pick the package and confirm."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.line }

            Item {
                width: parent.width
                height: 38
                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: "Downloads"; color: Theme.cream; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                    Text { text: "~/Pictures/Wallpapers"; color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11 }
                }
                HubButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "folder"
                    label: "Open"
                    onClicked: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/Pictures/Wallpapers"])
                }
            }
        }
    }
}
