pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 7
    pageTitle: Translation.tr("Modules")
    pageIcon: "settings-cog-multiple"
    pageDescription: Translation.tr("Panel style and modules")

    property bool isWaffleActive: Config.options?.panelFamily === "waffle"

    // Helper functions for enabledPanels management
    function isPanelEnabled(panelId: string): bool {
        return (Config.options?.enabledPanels ?? []).includes(panelId)
    }

    function setPanelEnabled(panelId: string, enabled: bool): void {
        let panels = [...(Config.options?.enabledPanels ?? [])]
        const idx = panels.indexOf(panelId)

        if (enabled && idx === -1) {
            panels.push(panelId)
        } else if (!enabled && idx !== -1) {
            panels.splice(idx, 1)
        }

        Config.setNestedValue("enabledPanels", panels)
    }

    // Helper functions for Action Center toggles management
    function isToggleEnabled(toggleId: string): bool {
        return (Config.options?.waffles?.actionCenter?.toggles ?? []).includes(toggleId)
    }

    function setToggleEnabled(toggleId: string, enabled: bool): void {
        let toggles = [...(Config.options?.waffles?.actionCenter?.toggles ?? [])]
        const idx = toggles.indexOf(toggleId)

        if (enabled && idx === -1) {
            toggles.push(toggleId)
        } else if (!enabled && idx !== -1) {
            toggles.splice(idx, 1)
        }

        Config.setNestedValue("waffles.actionCenter.toggles", toggles)
    }

    readonly property var rightSidebarWidgetDefaults: ["calendar", "events", "todo", "notepad", "calculator", "sysmon", "timer", "openvpn", "hosts", "netmon", "firewall"]

    function isRightSidebarWidgetEnabled(widgetId: string): bool {
        return (Config.options?.sidebar?.right?.enabledWidgets ?? rightSidebarWidgetDefaults).includes(widgetId)
    }

    function setRightSidebarWidgetEnabled(widgetId: string, enabled: bool): void {
        let widgets = [...(Config.options?.sidebar?.right?.enabledWidgets ?? rightSidebarWidgetDefaults)]
        const idx = widgets.indexOf(widgetId)

        if (enabled && idx === -1) {
            widgets.push(widgetId)
        } else if (!enabled && idx !== -1) {
            widgets.splice(idx, 1)
        }

        Config.setNestedValue("sidebar.right.enabledWidgets", widgets)
    }

    readonly property var allToggles: [
        { id: "network",          label: Translation.tr("Network / Wi-Fi"),   icon: "wifi-4"         },
        { id: "bluetooth",        label: Translation.tr("Bluetooth"),          icon: "bluetooth"      },
        { id: "hotspot",          label: Translation.tr("Hotspot"),            icon: "wifi-tethering" },
        { id: "audio",            label: Translation.tr("Audio output"),       icon: "speaker"        },
        { id: "mic",              label: Translation.tr("Microphone"),         icon: "mic"            },
        { id: "easyEffects",      label: Translation.tr("EasyEffects"),        icon: "device-eq"      },
        { id: "nightLight",       label: Translation.tr("Night Light"),        icon: "weather-moon"   },
        { id: "darkMode",         label: Translation.tr("Dark Mode"),          icon: "dark-theme"     },
        { id: "antiFlashbang",    label: Translation.tr("Anti-Flashbang"),     icon: "flash-off"      },
        { id: "powerProfile",     label: Translation.tr("Power Profile"),      icon: "flash-on"       },
        { id: "idleInhibitor",    label: Translation.tr("Idle Inhibitor"),     icon: "drink-coffee"   },
        { id: "notifications",    label: Translation.tr("Notifications"),      icon: "alert"          },
        { id: "onScreenKeyboard", label: Translation.tr("On-Screen Keyboard"), icon: "keyboard"       },
        { id: "cloudflareWarp",   label: Translation.tr("Cloudflare WARP"),   icon: "cloudflare"     },
        { id: "gameMode",         label: Translation.tr("Game Mode"),          icon: "games"          },
        { id: "musicRecognition", label: Translation.tr("Music Recognition"),  icon: "music-note-2"   },
        { id: "screenSnip",       label: Translation.tr("Screen Snip"),        icon: "cut"            },
        { id: "colorPicker",      label: Translation.tr("Color Picker"),       icon: "eyedropper"     }
    ]

    WSettingsInfoBar {
        visible: !root.isWaffleActive
        severity: WSettingsInfoBar.Severity.Info
        message: Translation.tr("These Waffle modules are currently inactive because another panel family is selected. You can still pre-configure them here before switching.")
    }

    WSettingsCard {
        title: Translation.tr("Panel Style")
        icon: "options"

        WSettingsDropdown {
            label: Translation.tr("Panel family")
            icon: "panel-left-expand"
            description: Translation.tr("Changing this will reload the shell")
            currentValue: Config.options?.panelFamily ?? "waffle"
            options: [
                { value: "ii", displayName: Translation.tr("Material (ii)") },
                { value: "waffle", displayName: Translation.tr("Windows 11 (Waffle)") }
            ]
            onSelected: newValue => {
                if (newValue !== Config.options?.panelFamily) {
                    Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "panelFamily", "set", newValue])
                }
            }
        }
    }

    WSettingsCard {
        title: Translation.tr("Default Terminal")
        icon: "terminal"

        WSettingsDropdown {
            label: Translation.tr("Terminal emulator")
            icon: "terminal"
            description: Translation.tr("Used by shell actions, keybinds, and package commands")
            currentValue: AppLauncher.presetIdFor("terminal")
            options: AppLauncher.presetOptions("terminal")
            onSelected: newValue => {
                if (newValue !== "__custom__")
                    AppLauncher.applyPreset("terminal", newValue)
            }
        }
    }

    // Waffle modules
    WSettingsCard {
        title: Translation.tr("Panels")
        icon: "apps"

        WSettingsRow {
            visible: !root.isWaffleActive
            label: Translation.tr("Waffle family currently inactive")
            icon: "info"
            description: Translation.tr("Changes here will apply when you switch the panel family back to Windows 11 (Waffle).")
        }

        WSettingsSwitch {
            label: Translation.tr("Taskbar")
            icon: "panel-left-expand"
            checked: root.isPanelEnabled("wBar")
            onCheckedChanged: root.setPanelEnabled("wBar", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Background")
            icon: "image"
            checked: root.isPanelEnabled("wBackground")
            onCheckedChanged: root.setPanelEnabled("wBackground", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Start Menu")
            icon: "start-here"
            checked: root.isPanelEnabled("wStartMenu")
            onCheckedChanged: root.setPanelEnabled("wStartMenu", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Action Center")
            icon: "options"
            checked: root.isPanelEnabled("wActionCenter")
            onCheckedChanged: root.setPanelEnabled("wActionCenter", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Notification Center")
            icon: "alert-filled"
            checked: root.isPanelEnabled("wNotificationCenter")
            onCheckedChanged: root.setPanelEnabled("wNotificationCenter", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Notification Popups")
            icon: "alert"
            checked: root.isPanelEnabled("wNotificationPopup")
            onCheckedChanged: root.setPanelEnabled("wNotificationPopup", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("OSD")
            icon: "pulse"
            checked: root.isPanelEnabled("wOnScreenDisplay")
            onCheckedChanged: root.setPanelEnabled("wOnScreenDisplay", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Widgets Panel")
            icon: "widgets"
            checked: root.isPanelEnabled("wWidgets")
            onCheckedChanged: root.setPanelEnabled("wWidgets", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Task View")
            icon: "library"
            description: Translation.tr("Overview of all workspaces and windows. Supports carousel and centered focus modes.")
            checked: root.isPanelEnabled("wTaskView")
            onCheckedChanged: root.setPanelEnabled("wTaskView", checked)
        }
    }

    WSettingsSection {
        title: Translation.tr("Sidebars")
        icon: "panel-left-expand"
        description: Translation.tr("Choose which side panels are loaded and what appears inside the left and right sidebars.")
    }

    WSettingsCard {
        title: Translation.tr("Side Panels")
        icon: "panel-left-expand"

        WSettingsSwitch {
            label: Translation.tr("Left Sidebar")
            icon: "panel-left-expand"
            description: Translation.tr("AI, translator, wallpaper, tools, and widget tabs")
            checked: root.isPanelEnabled("iiSidebarLeft")
            onCheckedChanged: root.setPanelEnabled("iiSidebarLeft", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Right Sidebar")
            icon: "panel-right-expand"
            description: Translation.tr("Quick controls, calendar, notes, system tools, and monitoring widgets")
            checked: root.isPanelEnabled("iiSidebarRight")
            onCheckedChanged: root.setPanelEnabled("iiSidebarRight", checked)
        }
    }

    WSettingsCard {
        title: Translation.tr("Sidebar Behavior")
        icon: "options"
        collapsible: true
        expanded: false

        WSettingsSwitch {
            label: Translation.tr("Card style")
            icon: "apps"
            description: (Appearance.globalStyle === "material" || Appearance.globalStyle === "ryoku-shell")
                ? Translation.tr("Use rounded card styling for both sidebars")
                : Translation.tr("Only available with Material or Ryoku global style")
            enabled: Appearance.globalStyle === "material" || Appearance.globalStyle === "ryoku-shell"
            checked: Config.options?.sidebar?.cardStyle ?? false
            onCheckedChanged: Config.setNestedValue("sidebar.cardStyle", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Keep right sidebar loaded")
            icon: "memory"
            description: Translation.tr("Reduce opening delay by keeping the right sidebar in memory")
            checked: Config.options?.sidebar?.keepRightSidebarLoaded ?? true
            onCheckedChanged: Config.setNestedValue("sidebar.keepRightSidebarLoaded", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Instant sidebar opening")
            icon: "flash-on"
            description: Translation.tr("Disable sidebar slide animation")
            checked: Config.options?.sidebar?.instantOpen ?? false
            onCheckedChanged: Config.setNestedValue("sidebar.instantOpen", checked)
        }

        WSettingsDropdown {
            visible: !(Config.options?.sidebar?.instantOpen ?? false)
            label: Translation.tr("Sidebar animation")
            icon: "arrow-clockwise"
            currentValue: Config.options?.sidebar?.animationType ?? "slide"
            options: [
                { value: "slide", displayName: Translation.tr("Slide") },
                { value: "fade", displayName: Translation.tr("Fade") },
                { value: "pop", displayName: Translation.tr("Pop") },
                { value: "reveal", displayName: Translation.tr("Reveal") },
                { value: "swing", displayName: Translation.tr("Swing") },
                { value: "drop", displayName: Translation.tr("Drop") },
                { value: "elastic", displayName: Translation.tr("Elastic") }
            ]
            onSelected: newValue => Config.setNestedValue("sidebar.animationType", newValue)
        }

        WSettingsSwitch {
            label: Translation.tr("Open folder after wallpaper download")
            icon: "folder"
            checked: Config.options?.sidebar?.openFolderOnDownload ?? false
            onCheckedChanged: Config.setNestedValue("sidebar.openFolderOnDownload", checked)
        }
    }

    WSettingsCard {
        title: Translation.tr("Left Sidebar Tabs")
        icon: "panel-left-expand"

        WSettingsSwitch {
            label: Translation.tr("Widgets")
            icon: "widgets"
            description: Translation.tr("Dashboard with clock, weather, media controls, and quick actions")
            checked: Config.options?.sidebar?.widgets?.enable ?? true
            onCheckedChanged: Config.setNestedValue("sidebar.widgets.enable", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("AI Chat")
            icon: "brain-circuit"
            readonly property int currentAiPolicy: Config.options?.policies?.ai ?? 0
            checked: currentAiPolicy !== 0
            onCheckedChanged: {
                const newValue = checked ? (currentAiPolicy === 2 ? 2 : 1) : 0
                Config.setNestedValue("policies.ai", newValue)
            }
        }

        WSettingsSwitch {
            label: Translation.tr("Translator")
            icon: "translate"
            checked: Config.options?.sidebar?.translator?.enable ?? false
            onCheckedChanged: Config.setNestedValue("sidebar.translator.enable", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Anime")
            icon: "bookmark-heart"
            readonly property int currentWeebPolicy: Config.options?.policies?.weeb ?? 0
            checked: currentWeebPolicy !== 0
            onCheckedChanged: {
                const newValue = checked ? (currentWeebPolicy === 2 ? 2 : 1) : 0
                Config.setNestedValue("policies.weeb", newValue)
            }
        }

        WSettingsSwitch {
            label: Translation.tr("Wallhaven")
            icon: "image"
            checked: Config.options?.sidebar?.wallhaven?.enable ?? true
            onCheckedChanged: Config.setNestedValue("sidebar.wallhaven.enable", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Anime Schedule")
            icon: "calendar"
            checked: Config.options?.sidebar?.animeSchedule?.enable ?? false
            onCheckedChanged: Config.setNestedValue("sidebar.animeSchedule.enable", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Reddit")
            icon: "comment"
            checked: Config.options?.sidebar?.reddit?.enable ?? false
            onCheckedChanged: Config.setNestedValue("sidebar.reddit.enable", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Tools")
            icon: "toolbox"
            checked: Config.options?.sidebar?.tools?.enable ?? false
            onCheckedChanged: Config.setNestedValue("sidebar.tools.enable", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Software")
            icon: "store"
            checked: Config.options?.sidebar?.software?.enable ?? false
            onCheckedChanged: Config.setNestedValue("sidebar.software.enable", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("YT Music")
            icon: "music-note-2"
            checked: Config.options?.sidebar?.ytmusic?.enable ?? false
            onCheckedChanged: Config.setNestedValue("sidebar.ytmusic.enable", checked)
        }
    }

    WSettingsCard {
        title: Translation.tr("Right Sidebar Widgets")
        icon: "panel-right-expand"

        WSettingsSwitch {
            label: Translation.tr("Calendar")
            icon: "calendar"
            checked: root.isRightSidebarWidgetEnabled("calendar")
            onCheckedChanged: root.setRightSidebarWidgetEnabled("calendar", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Events")
            icon: "calendar-agenda"
            checked: root.isRightSidebarWidgetEnabled("events")
            onCheckedChanged: root.setRightSidebarWidgetEnabled("events", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("To Do")
            icon: "checkmark-circle"
            checked: root.isRightSidebarWidgetEnabled("todo")
            onCheckedChanged: root.setRightSidebarWidgetEnabled("todo", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Notepad")
            icon: "notepad"
            checked: root.isRightSidebarWidgetEnabled("notepad")
            onCheckedChanged: root.setRightSidebarWidgetEnabled("notepad", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Calculator")
            icon: "calculator"
            checked: root.isRightSidebarWidgetEnabled("calculator")
            onCheckedChanged: root.setRightSidebarWidgetEnabled("calculator", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("System Monitor")
            icon: "desktop-pulse"
            checked: root.isRightSidebarWidgetEnabled("sysmon")
            onCheckedChanged: root.setRightSidebarWidgetEnabled("sysmon", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Timer")
            icon: "timer"
            checked: root.isRightSidebarWidgetEnabled("timer")
            onCheckedChanged: root.setRightSidebarWidgetEnabled("timer", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("VPN")
            icon: "key"
            checked: root.isRightSidebarWidgetEnabled("openvpn")
            onCheckedChanged: root.setRightSidebarWidgetEnabled("openvpn", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Hosts")
            icon: "server"
            checked: root.isRightSidebarWidgetEnabled("hosts")
            onCheckedChanged: root.setRightSidebarWidgetEnabled("hosts", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Network")
            icon: "network-check"
            checked: root.isRightSidebarWidgetEnabled("netmon")
            onCheckedChanged: root.setRightSidebarWidgetEnabled("netmon", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Firewall")
            icon: "shield"
            checked: root.isRightSidebarWidgetEnabled("firewall")
            onCheckedChanged: root.setRightSidebarWidgetEnabled("firewall", checked)
        }
    }

    WSettingsSection {
        title: Translation.tr("Action Center Toggles")
        icon: "options"
    }

    WSettingsCard {
        title: Translation.tr("Visible toggles")
        icon: "checkmark"

        Repeater {
            model: root.allToggles
            delegate: WSettingsSwitch {
                required property var modelData
                label: modelData.label
                icon: modelData.icon
                checked: root.isToggleEnabled(modelData.id)
                onCheckedChanged: root.setToggleEnabled(modelData.id, checked)
            }
        }
    }
}
