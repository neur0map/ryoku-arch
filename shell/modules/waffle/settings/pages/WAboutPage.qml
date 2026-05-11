pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 10
    pageTitle: Translation.tr("About")
    pageIcon: "info"
    pageDescription: Translation.tr("Project information and links")

    function openShellUpdateDetails(): void {
        if (Config.options?.settingsUi?.overlayMode ?? false) {
            ShellUpdates.openOverlay()
        } else {
            Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "shellUpdate", "open"])
        }
    }

    function checkShellUpdates(): void {
        ShellUpdates.check()
        if (!(Config.options?.settingsUi?.overlayMode ?? false)) {
            Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "shellUpdate", "check"])
        }
    }
    
    // Hero card — project identity
    WSettingsCard {
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            Layout.topMargin: 8
            Layout.bottomMargin: 4
            spacing: 18
            
            Rectangle {
                implicitWidth: 72
                implicitHeight: 72
                radius: Looks.radius.xLarge
                color: Looks.colors.accent
                
                WText {
                    anchors.centerIn: parent
                    text: "iN"
                    font.pixelSize: 30
                    font.weight: Font.Bold
                    color: Looks.colors.accentFg
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                
                WText {
                    text: "Ryoku"
                    font.pixelSize: Looks.font.pixelSize.xlarger * 1.4
                    font.weight: Looks.font.weight.stronger
                }
                
                WText {
                    text: Translation.tr("Quickshell desktop shell for Niri")
                    font.pixelSize: Looks.font.pixelSize.normal
                    color: Looks.colors.subfg
                }
                
                RowLayout {
                    spacing: 8
                    Layout.topMargin: 4
                    
                    // Version badge
                    Rectangle {
                        implicitWidth: versionLabel.implicitWidth + 16
                        implicitHeight: 24
                        radius: Looks.radius.small
                        color: Looks.colors.accent
                        
                        WText {
                            id: versionLabel
                            anchors.centerIn: parent
                            text: "v" + (ShellUpdates.localVersion || "?")
                            font.pixelSize: Looks.font.pixelSize.small
                            font.weight: Looks.font.weight.strong
                            color: Looks.colors.accentFg
                        }
                    }
                    
                    // Compositor badge
                    Rectangle {
                        implicitWidth: compLabel.implicitWidth + 16
                        implicitHeight: 24
                        radius: Looks.radius.small
                        color: Looks.colors.bg2
                        
                        WText {
                            id: compLabel
                            anchors.centerIn: parent
                            text: CompositorService.isNiri ? "Niri" : (CompositorService.isHyprland ? "Hyprland" : "Unknown")
                            font.pixelSize: Looks.font.pixelSize.small
                            color: Looks.colors.subfg
                        }
                    }
                    
                    // Framework badge
                    Rectangle {
                        implicitWidth: fwLabel.implicitWidth + 16
                        implicitHeight: 24
                        radius: Looks.radius.small
                        color: Looks.colors.bg2
                        
                        WText {
                            id: fwLabel
                            anchors.centerIn: parent
                            text: "Qt 6"
                            font.pixelSize: Looks.font.pixelSize.small
                            color: Looks.colors.subfg
                        }
                    }
                }
            }
        }

        WSettingsButton {
            label: ShellUpdates.isChecking ? Translation.tr("Checking for updates") : Translation.tr("Check for updates")
            description: Translation.tr("Fetch the latest Ryoku update status")
            icon: "arrow-sync"
            buttonIcon: "arrow-sync"
            buttonText: ShellUpdates.isChecking ? Translation.tr("Checking...") : Translation.tr("Check")
            enabled: !ShellUpdates.isChecking && !ShellUpdates.isUpdating && !ShellUpdates.managedExternally
            opacity: enabled ? 1.0 : 0.5
            onButtonClicked: checkShellUpdates()
        }

        WSettingsButton {
            visible: ShellUpdates.hasUpdate
            label: Translation.tr("Update available")
            description: Translation.tr("Open the Ryoku update window")
            icon: "arrow-clockwise"
            buttonIcon: "open"
            buttonText: Translation.tr("Open")
            accent: true
            enabled: !ShellUpdates.isUpdating
            opacity: enabled ? 1.0 : 0.5
            onButtonClicked: openShellUpdateDetails()
        }
    }
    
    // Links
    WSettingsCard {
        title: Translation.tr("Links")
        icon: "open"
        
        WSettingsButton {
            label: Translation.tr("GitHub Repository")
            description: "github.com/neur0map/ryoku-arch"
            icon: "globe-search"
            buttonText: Translation.tr("Open")
            onButtonClicked: Qt.openUrlExternally("https://github.com/neur0map/ryoku-arch")
        }

        WSettingsButton {
            label: Translation.tr("Documentation")
            description: "github.com/neur0map/ryoku-arch"
            icon: "library"
            buttonText: Translation.tr("Open")
            onButtonClicked: Qt.openUrlExternally("https://github.com/neur0map/ryoku-arch/tree/main/docs")
        }

        WSettingsButton {
            label: "qylock"
            description: "github.com/Darkkal44/qylock"
            icon: "open"
            buttonText: Translation.tr("Open")
            onButtonClicked: Qt.openUrlExternally("https://github.com/Darkkal44/qylock")
        }
        
        WSettingsButton {
            label: Translation.tr("Quickshell Documentation")
            description: "quickshell.outfoxxed.me"
            icon: "globe-search"
            buttonText: Translation.tr("Open")
            onButtonClicked: Qt.openUrlExternally("https://quickshell.outfoxxed.me")
        }
    }
    
    // Credits
    WSettingsCard {
        title: Translation.tr("Credits")
        icon: "people"
        
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 6
            spacing: 12
            
            WText {
                Layout.fillWidth: true
                text: Translation.tr("Based on illogical-impulse by end-4, adapted for the Niri compositor.")
                wrapMode: Text.WordWrap
                font.pixelSize: Looks.font.pixelSize.normal
                color: Looks.colors.subfg
                lineHeight: 1.3
            }

            WText {
                Layout.fillWidth: true
                text: Translation.tr("Optional SDDM greeter themes are provided by qylock by Darkkal44.")
                wrapMode: Text.WordWrap
                font.pixelSize: Looks.font.pixelSize.normal
                color: Looks.colors.subfg
                lineHeight: 1.3
            }
            
            WText {
                Layout.fillWidth: true
                text: Translation.tr("Special thanks to the Quickshell and Niri communities.")
                wrapMode: Text.WordWrap
                font.pixelSize: Looks.font.pixelSize.normal
                color: Looks.colors.subfg
                lineHeight: 1.3
            }
        }
    }
    
    // System Info
    WSettingsCard {
        title: Translation.tr("System Info")
        icon: "info"
        
        WSettingsRow {
            label: Translation.tr("Config path")
            description: FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/`)
            icon: "folder"
        }
        
        WSettingsRow {
            label: Translation.tr("Shell path")
            description: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ryoku-shell/`)
            icon: "folder"
        }
        
        WSettingsRow {
            label: Translation.tr("Panel family")
            description: Config.options?.panelFamily === "waffle" ? "Waffle (Windows 11)" : "ii (Material)"
            icon: "app-generic"
        }
    }
}
