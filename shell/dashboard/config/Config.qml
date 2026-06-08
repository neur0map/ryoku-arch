pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.dashboard.modules.globals
import qs.dashboard.modules.theme
import qs.dashboard.modules.services as Services
import "defaults/theme.js" as ThemeDefaults
import "defaults/bar.js" as BarDefaults
import "defaults/workspaces.js" as WorkspacesDefaults
import "defaults/overview.js" as OverviewDefaults
import "defaults/notch.js" as NotchDefaults
import "defaults/compositor.js" as CompositorDefaults
import "defaults/performance.js" as PerformanceDefaults
import "defaults/weather.js" as WeatherDefaults
import "defaults/desktop.js" as DesktopDefaults
import "defaults/lockscreen.js" as LockscreenDefaults
import "defaults/prefix.js" as PrefixDefaults
import "defaults/system.js" as SystemDefaults
import "ConfigValidator.js" as ConfigValidator

Singleton {
    id: root

    property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/dashboard"
    property string presetDir: Qt.resolvedUrl("../assets/presets/Ryoku Default").toString().replace("file://", "")

    property bool pauseAutoSave: false

    property bool themeReady: false
    property bool barReady: false
    property bool workspacesReady: false
    property bool overviewReady: false
    property bool notchReady: false
    property bool compositorReady: false
    property bool performanceReady: false
    property bool weatherReady: false
    property bool desktopReady: false
    property bool lockscreenReady: false
    property bool prefixReady: false
    property bool systemReady: false

    property bool initialLoadComplete: themeReady && barReady && workspacesReady && overviewReady && notchReady && compositorReady && performanceReady && weatherReady && desktopReady && lockscreenReady && prefixReady && systemReady

    property alias loader: themeLoader

    Process {
        id: ensureConfigDir
        running: true
        command: [
            "bash", "-c",
            "mkdir -p '" + root.configDir + "' && " +
            "cp -n '" + root.presetDir + "/theme.json' '" + root.configDir + "/theme.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/bar.json' '" + root.configDir + "/bar.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/workspaces.json' '" + root.configDir + "/workspaces.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/overview.json' '" + root.configDir + "/overview.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/notch.json' '" + root.configDir + "/notch.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/compositor.json' '" + root.configDir + "/compositor.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/performance.json' '" + root.configDir + "/performance.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/desktop.json' '" + root.configDir + "/desktop.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/lockscreen.json' '" + root.configDir + "/lockscreen.json' 2>/dev/null || true; " +
            "cp -n '" + root.presetDir + "/system.json' '" + root.configDir + "/system.json' 2>/dev/null || true; " +
            "echo 'Preset files copied if missing'"
        ]
    }

    Process {
        id: migrateCompositorConfig
        running: true
        command: ["bash", "-c", `test -f '${root.configDir}/hyprland.json' && ! test -f '${root.configDir}/compositor.json' && mv '${root.configDir}/hyprland.json' '${root.configDir}/compositor.json' && echo 'Migrated hyprland.json to compositor.json' || true`]
    }

    FileView {
        id: themeLoader
        path: root.configDir + "/theme.json"
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.themeReady) {
                validateModule("theme", themeLoader, ThemeDefaults.data, () => {
                    root.themeReady = true;
                });
            }
        }
        onLoadFailed: {
            if (error.toString().includes("FileNotFound") && !root.themeReady) {
                handleMissingConfig("theme", themeLoader, ThemeDefaults.data, () => {
                    root.themeReady = true;
                });
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.themeReady && !root.pauseAutoSave) {
                themeLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property bool oledMode: false
            property bool lightMode: false
            property int roundness: 16
            property string font: "Roboto Condensed"
            property int fontSize: 14
            property string monoFont: "Iosevka Nerd Font Mono"
            property int monoFontSize: 14
            property bool tintIcons: false
            property bool enableCorners: true
            property int animDuration: 300
            property real shadowOpacity: 0.5
            property string shadowColor: "shadow"
            property int shadowXOffset: 0
            property int shadowYOffset: 0
            property real shadowBlur: 1

            property JsonObject srBg: JsonObject {
                property string label: "Background"
                property list<var> gradient: [["background", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surface"
                property string halftoneBackgroundColor: "background"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srPopup: JsonObject {
                property string label: "Popup"
                property list<var> gradient: [["background", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surface"
                property string halftoneBackgroundColor: "background"
                property list<var> border: ["surfaceBright", 2]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srInternalBg: JsonObject {
                property string label: "Internal BG"
                property list<var> gradient: [["background", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surface"
                property string halftoneBackgroundColor: "background"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srBarBg: JsonObject {
                property string label: "Bar BG"
                property list<var> gradient: [["surfaceDim", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surface"
                property string halftoneBackgroundColor: "surfaceDim"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 0.0
            }

            property JsonObject srPane: JsonObject {
                property string label: "Pane"
                property list<var> gradient: [["surface", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surfaceBright"
                property string halftoneBackgroundColor: "surface"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srCommon: JsonObject {
                property string label: "Common"
                property list<var> gradient: [["surface", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "background"
                property string halftoneBackgroundColor: "surface"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srFocus: JsonObject {
                property string label: "Focus"
                property list<var> gradient: [["surfaceBright", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "surfaceVariant"
                property string halftoneBackgroundColor: "surfaceBright"
                property list<var> border: ["surfaceBright", 0]
                property string itemColor: "overBackground"
                property real opacity: 1.0
            }

            property JsonObject srPrimary: JsonObject {
                property string label: "Primary"
                property list<var> gradient: [["primary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "overPrimaryContainer"
                property string halftoneBackgroundColor: "primary"
                property list<var> border: ["primary", 0]
                property string itemColor: "overPrimary"
                property real opacity: 1.0
            }

            property JsonObject srPrimaryFocus: JsonObject {
                property string label: "Primary Focus"
                property list<var> gradient: [["overPrimaryContainer", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "primary"
                property string halftoneBackgroundColor: "overPrimaryContainer"
                property list<var> border: ["overBackground", 0]
                property string itemColor: "overPrimary"
                property real opacity: 1.0
            }

            property JsonObject srOverPrimary: JsonObject {
                property string label: "Over Primary"
                property list<var> gradient: [["overPrimary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "primaryContainer"
                property string halftoneBackgroundColor: "overPrimary"
                property list<var> border: ["overPrimary", 0]
                property string itemColor: "primary"
                property real opacity: 1.0
            }

            property JsonObject srSecondary: JsonObject {
                property string label: "Secondary"
                property list<var> gradient: [["secondary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "overSecondaryContainer"
                property string halftoneBackgroundColor: "secondary"
                property list<var> border: ["secondary", 0]
                property string itemColor: "overSecondary"
                property real opacity: 1.0
            }

            property JsonObject srSecondaryFocus: JsonObject {
                property string label: "Secondary Focus"
                property list<var> gradient: [["overSecondaryContainer", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "secondary"
                property string halftoneBackgroundColor: "overSecondaryContainer"
                property list<var> border: ["overBackground", 0]
                property string itemColor: "overSecondary"
                property real opacity: 1.0
            }

            property JsonObject srOverSecondary: JsonObject {
                property string label: "Over Secondary"
                property list<var> gradient: [["overSecondary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "secondaryContainer"
                property string halftoneBackgroundColor: "overSecondary"
                property list<var> border: ["overSecondary", 0]
                property string itemColor: "secondary"
                property real opacity: 1.0
            }

            property JsonObject srTertiary: JsonObject {
                property string label: "Tertiary"
                property list<var> gradient: [["tertiary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "overTertiaryContainer"
                property string halftoneBackgroundColor: "tertiary"
                property list<var> border: ["tertiary", 0]
                property string itemColor: "overTertiary"
                property real opacity: 1.0
            }

            property JsonObject srTertiaryFocus: JsonObject {
                property string label: "Tertiary Focus"
                property list<var> gradient: [["overTertiaryContainer", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "tertiary"
                property string halftoneBackgroundColor: "overTertiaryContainer"
                property list<var> border: ["overBackground", 0]
                property string itemColor: "overTertiary"
                property real opacity: 1.0
            }

            property JsonObject srOverTertiary: JsonObject {
                property string label: "Over Tertiary"
                property list<var> gradient: [["overTertiary", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "tertiaryContainer"
                property string halftoneBackgroundColor: "overTertiary"
                property list<var> border: ["overTertiary", 0]
                property string itemColor: "tertiary"
                property real opacity: 1.0
            }

            property JsonObject srError: JsonObject {
                property string label: "Error"
                property list<var> gradient: [["error", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "overErrorContainer"
                property string halftoneBackgroundColor: "error"
                property list<var> border: ["error", 0]
                property string itemColor: "overError"
                property real opacity: 1.0
            }

            property JsonObject srErrorFocus: JsonObject {
                property string label: "Error Focus"
                property list<var> gradient: [["overBackground", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "error"
                property string halftoneBackgroundColor: "overErrorContainer"
                property list<var> border: ["overBackground", 0]
                property string itemColor: "overError"
                property real opacity: 1.0
            }

            property JsonObject srOverError: JsonObject {
                property string label: "Over Error"
                property list<var> gradient: [["overError", 0.0]]
                property string gradientType: "linear"
                property int gradientAngle: 0
                property real gradientCenterX: 0.5
                property real gradientCenterY: 0.5
                property real halftoneDotMin: 0.0
                property real halftoneDotMax: 2.0
                property real halftoneStart: 0.0
                property real halftoneEnd: 1.0
                property string halftoneDotColor: "errorContainer"
                property string halftoneBackgroundColor: "overError"
                property list<var> border: ["overError", 0]
                property string itemColor: "error"
                property real opacity: 1.0
            }
        }
    }

    FileView {
        id: barLoader
        path: root.configDir + "/bar.json"
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.barReady) {
                validateModule("bar", barLoader, BarDefaults.data, () => {
                    root.barReady = true;
                });
            }
        }
        onLoadFailed: {
            if (error.toString().includes("FileNotFound") && !root.barReady) {
                handleMissingConfig("bar", barLoader, BarDefaults.data, () => {
                    root.barReady = true;
                });
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.barReady && !root.pauseAutoSave) {
                barLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string position: "top"
            property string launcherIcon: ""
            property bool launcherIconTint: true
            property bool launcherIconFullTint: true
            property int launcherIconSize: 24
            property string pillStyle: "default"
            property list<string> screenList: []
            property bool enableFirefoxPlayer: false
            property list<var> barColor: [["surface", 0.0]]
            property bool frameEnabled: false
            property int frameThickness: 6
            property bool pinnedOnStartup: true
            property bool hoverToReveal: true
            property int hoverRegionHeight: 8
            property bool showPinButton: true
            property bool availableOnFullscreen: false
            property bool use12hFormat: false
            property bool containBar: false
            property bool keepBarShadow: false
            property bool keepBarBorder: false
        }
    }

    FileView {
        id: workspacesLoader
        path: root.configDir + "/workspaces.json"
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.workspacesReady) {
                validateModule("workspaces", workspacesLoader, WorkspacesDefaults.data, () => {
                    root.workspacesReady = true;
                });
            }
        }
        onLoadFailed: {
            if (error.toString().includes("FileNotFound") && !root.workspacesReady) {
                handleMissingConfig("workspaces", workspacesLoader, WorkspacesDefaults.data, () => {
                    root.workspacesReady = true;
                });
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.workspacesReady && !root.pauseAutoSave) {
                workspacesLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property int shown: 10
            property bool showAppIcons: true
            property bool alwaysShowNumbers: false
            property bool showNumbers: false
            property bool dynamic: false
        }
    }

    FileView {
        id: overviewLoader
        path: root.configDir + "/overview.json"
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.overviewReady) {
                validateModule("overview", overviewLoader, OverviewDefaults.data, () => {
                    root.overviewReady = true;
                });
            }
        }
        onLoadFailed: {
            if (error.toString().includes("FileNotFound") && !root.overviewReady) {
                handleMissingConfig("overview", overviewLoader, OverviewDefaults.data, () => {
                    root.overviewReady = true;
                });
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.overviewReady && !root.pauseAutoSave) {
                overviewLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property int rows: 2
            property int columns: 5
            property real scale: 0.1
            property real workspaceSpacing: 4
        }
    }

    FileView {
        id: notchLoader
        path: root.configDir + "/notch.json"
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.notchReady) {
                validateModule("notch", notchLoader, NotchDefaults.data, () => {
                    root.notchReady = true;
                });
            }
        }
        onLoadFailed: {
            if (error.toString().includes("FileNotFound") && !root.notchReady) {
                handleMissingConfig("notch", notchLoader, NotchDefaults.data, () => {
                    root.notchReady = true;
                });
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.notchReady && !root.pauseAutoSave) {
                notchLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string theme: "default"
            property string position: "top"
            property int hoverRegionHeight: 8
            property bool keepHidden: false
            property string noMediaDisplay: "userHost"
            property string customText: "Ryoku"
            property bool disableHoverExpansion: true
        }
    }

    FileView {
        id: compositorLoader
        path: root.configDir + "/compositor.json"
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.compositorReady) {
                validateModule("compositor", compositorLoader, CompositorDefaults.data, () => {
                    root.compositorReady = true;
                });
            }
        }
        onLoadFailed: {
            if (error.toString().includes("FileNotFound") && !root.compositorReady) {
                handleMissingConfig("compositor", compositorLoader, CompositorDefaults.data, () => {
                    root.compositorReady = true;
                });
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.compositorReady && !root.pauseAutoSave) {
                compositorLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property var activeBorderColor: ["primary"]
            property int borderAngle: 45
            property var inactiveBorderColor: ["surface"]
            property int inactiveBorderAngle: 45
            property int borderSize: 2
            property int rounding: 16
            property bool syncRoundness: true
            property bool syncBorderWidth: false
            property bool syncBorderColor: false
            property bool syncShadowOpacity: false
            property bool syncShadowColor: false
            property int gapsIn: 2
            property int gapsOut: 4
            property string layout: "dwindle"
            property bool shadowEnabled: true
            property int shadowRange: 8
            property int shadowRenderPower: 3
            property bool shadowSharp: false
            property bool shadowIgnoreWindow: true
            property string shadowColor: "shadow"
            property string shadowColorInactive: "shadow"
            property real shadowOpacity: 0.5
            property string shadowOffset: "0 0"
            property real shadowScale: 1.0
            property bool blurEnabled: true
            property int blurSize: 4
            property int blurPasses: 2
            property bool blurIgnoreOpacity: true
            property bool blurExplicitIgnoreAlpha: false
            property real blurIgnoreAlphaValue: 0.2
            property bool blurNewOptimizations: true
            property bool blurXray: false
            property real blurNoise: 0.0
            property real blurContrast: 1.0
            property real blurBrightness: 1.0
            property real blurVibrancy: 0.0
            property real blurVibrancyDarkness: 0.0
            property bool blurSpecial: true
            property bool blurPopups: false
            property real blurPopupsIgnorealpha: 0.2
            property bool blurInputMethods: false
            property real blurInputMethodsIgnorealpha: 0.2
        }
    }

    FileView {
        id: performanceLoader
        path: root.configDir + "/performance.json"
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.performanceReady) {
                validateModule("performance", performanceLoader, PerformanceDefaults.data, () => {
                    root.performanceReady = true;
                });
            }
        }
        onLoadFailed: {
            if (error.toString().includes("FileNotFound") && !root.performanceReady) {
                handleMissingConfig("performance", performanceLoader, PerformanceDefaults.data, () => {
                    root.performanceReady = true;
                });
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.performanceReady && !root.pauseAutoSave) {
                performanceLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property bool blurTransition: true
            property bool windowPreview: true
            property bool wavyLine: true
            property bool rotateCoverArt: true
            property bool dashboardPersistTabs: true
            property int dashboardMaxPersistentTabs: 2
        }
    }

    FileView {
        id: weatherLoader
        path: root.configDir + "/weather.json"
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.weatherReady) {
                validateModule("weather", weatherLoader, WeatherDefaults.data, () => {
                    root.weatherReady = true;
                });
            }
        }
        onLoadFailed: {
            if (error.toString().includes("FileNotFound") && !root.weatherReady) {
                handleMissingConfig("weather", weatherLoader, WeatherDefaults.data, () => {
                    root.weatherReady = true;
                });
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.weatherReady && !root.pauseAutoSave) {
                weatherLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string location: ""
            property string unit: "C"
        }
    }

    FileView {
        id: desktopLoader
        path: root.configDir + "/desktop.json"
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.desktopReady) {
                validateModule("desktop", desktopLoader, DesktopDefaults.data, () => {
                    root.desktopReady = true;
                });
            }
        }
        onLoadFailed: {
            if (error.toString().includes("FileNotFound") && !root.desktopReady) {
                handleMissingConfig("desktop", desktopLoader, DesktopDefaults.data, () => {
                    root.desktopReady = true;
                });
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.desktopReady && !root.pauseAutoSave) {
                desktopLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property bool enabled: false
            property int iconSize: 40
            property int spacingVertical: 16
            property string textColor: "overBackground"
        }
    }

    FileView {
        id: lockscreenLoader
        path: root.configDir + "/lockscreen.json"
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.lockscreenReady) {
                validateModule("lockscreen", lockscreenLoader, LockscreenDefaults.data, () => {
                    root.lockscreenReady = true;
                });
            }
        }
        onLoadFailed: {
            if (error.toString().includes("FileNotFound") && !root.lockscreenReady) {
                handleMissingConfig("lockscreen", lockscreenLoader, LockscreenDefaults.data, () => {
                    root.lockscreenReady = true;
                });
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.lockscreenReady && !root.pauseAutoSave) {
                lockscreenLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string position: "bottom"
        }
    }

    FileView {
        id: prefixLoader
        path: root.configDir + "/prefix.json"
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.prefixReady) {
                validateModule("prefix", prefixLoader, PrefixDefaults.data, () => {
                    root.prefixReady = true;
                });
            }
        }
        onLoadFailed: {
            if (error.toString().includes("FileNotFound") && !root.prefixReady) {
                handleMissingConfig("prefix", prefixLoader, PrefixDefaults.data, () => {
                    root.prefixReady = true;
                });
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.prefixReady && !root.pauseAutoSave) {
                prefixLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property string clipboard: "cc"
            property string emoji: "ee"
            property string tmux: "tt"
            property string wallpapers: "ww"
            property string notes: "nn"
        }
    }

    FileView {
        id: systemLoader
        path: root.configDir + "/system.json"
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.systemReady) {
                validateModule("system", systemLoader, SystemDefaults.data, () => {
                    root.systemReady = true;
                });
            }
        }
        onLoadFailed: {
            if (error.toString().includes("FileNotFound") && !root.systemReady) {
                handleMissingConfig("system", systemLoader, SystemDefaults.data, () => {
                    root.systemReady = true;
                });
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.systemReady && !root.pauseAutoSave) {
                systemLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property list<string> disks: ["/"]
            property bool updateServiceEnabled: true
            property JsonObject idle: JsonObject {
                property JsonObject general: JsonObject {
                    property string lock_cmd: "loginctl lock-session"
                    property string before_sleep_cmd: "loginctl lock-session"
                    property string after_sleep_cmd: "hyprctl dispatch dpms on"
                }
                property list<var> listeners: [
                    {
                        "timeout": 150,
                        "onTimeout": "brightnessctl set 10% -s",
                        "onResume": "brightnessctl -r"
                    },
                    {
                        "timeout": 300,
                        "onTimeout": "loginctl lock-session"
                    },
                    {
                        "timeout": 330,
                        "onTimeout": "hyprctl dispatch dpms off",
                        "onResume": "hyprctl dispatch dpms on"
                    },
                    {
                        "timeout": 1800,
                        "onTimeout": "systemctl suspend"
                    }
                ]
            }
            property JsonObject ocr: JsonObject {
                property bool eng: true
                property bool spa: true
                property bool lat: false
                property bool jpn: false
                property bool chi_sim: false
                property bool chi_tra: false
                property bool kor: false
            }
            property JsonObject pomodoro: JsonObject {
                property int workTime: 1500
                property int restTime: 300
                property bool autoStart: false
                property bool syncSpotify: false
            }
        }
    }

    property bool pinnedAppsReady: false

    FileView {
        id: pinnedAppsLoader
        path: Quickshell.dataPath("pinnedapps.json")
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.pinnedAppsReady) {
                var raw = text();
                if (!raw || raw.trim().length === 0) {
                    console.log("pinnedapps.json not found, creating with default values...");
                    pinnedAppsLoader.writeAdapter();
                }
                root.pinnedAppsReady = true;
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.pinnedAppsReady && !root.pauseAutoSave) {
                pinnedAppsLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property list<string> apps: ["kitty"]
        }
    }



    function validateModule(name, loader, defaults, onComplete) {
        var raw = loader.text();
        if (!raw || raw.trim().length === 0) {
            console.log(name + ".json missing or empty, creating default...");
            loader.setText(JSON.stringify(defaults, null, 2));
            onComplete();
            return;
        }

        try {
            var current = JSON.parse(raw);
            var validated = ConfigValidator.validate(current, defaults);

            if (JSON.stringify(current) !== JSON.stringify(validated)) {
                console.log("Merging and updating " + name + ".json...");
                loader.setText(JSON.stringify(validated, null, 2));
            }
            onComplete();
        } catch (e) {
            console.log("Error validating " + name + " config (invalid JSON?): " + e);
            console.log("Overwriting with defaults due to error.");
            loader.setText(JSON.stringify(defaults, null, 2));
            onComplete();
        }
    }

    function handleMissingConfig(name, loader, defaults, onComplete) {
        var presetPath = root.presetDir + "/" + name + ".json";
        var targetPath = root.configDir + "/" + name + ".json";
        console.log(name + ".json not found, checking preset: " + presetPath);

        var copyProcess = Qt.createQmlObject(
            "import QtQuick 2.0; Process { running: true; command: ['cp', '" + presetPath + "', '" + targetPath + "']; onFinished: { console.log('Copy finished for " + name + "'); } }",
            root,
            "copyProcess"
        );

        loader.reload();

        Qt.callLater(() => {
            if (!root[name + "Ready"]) {
                console.log("Using defaults for " + name + ".json");
                loader.setText(JSON.stringify(defaults, null, 2));
            }
            onComplete();
        });
    }


    property QtObject theme: themeLoader.adapter
    property bool oledMode: lightMode ? false : theme.oledMode
    property bool lightMode: theme.lightMode

    property int roundness: theme.roundness
    property string defaultFont: theme.font
    property int animDuration: Services.GameModeService.toggled ? 0 : theme.animDuration
    property bool tintIcons: theme.tintIcons

    onLightModeChanged: {
        console.log("lightMode changed to:", lightMode);
        if (GlobalStates.wallpaperManager) {
            var wallpaperManager = GlobalStates.wallpaperManager;
            if (wallpaperManager.currentWallpaper) {
                console.log("Re-running Matugen due to lightMode change");
                wallpaperManager.runMatugenForCurrentWallpaper();
            }
        }
    }

    property QtObject bar: barLoader.adapter
    property bool showBackground: theme.srBarBg.opacity > 0

    property QtObject workspaces: workspacesLoader.adapter

    property QtObject overview: overviewLoader.adapter

    property QtObject notch: notchLoader.adapter
    property string notchTheme: notch.theme
    property string notchPosition: notch.position


    property QtObject compositor: compositorLoader.adapter
    property int compositorRounding: compositor.syncRoundness ? roundness : compositor.rounding
    property int compositorBorderSize: compositor.syncBorderWidth ? (theme.srBg.border[1] || 0) : compositor.borderSize
    property string compositorBorderColor: compositor.syncBorderColor ? (theme.srBg.border[0] || "primary") : (compositor.activeBorderColor.length > 0 ? compositor.activeBorderColor[0] : "primary")
    property real compositorShadowOpacity: compositor.syncShadowOpacity ? theme.shadowOpacity : compositor.shadowOpacity
    property string compositorShadowColor: compositor.syncShadowColor ? theme.shadowColor : compositor.shadowColor

    property QtObject performance: performanceLoader.adapter
    property bool blurTransition: performance.blurTransition

    property QtObject weather: weatherLoader.adapter

    property QtObject desktop: desktopLoader.adapter

    property QtObject lockscreen: lockscreenLoader.adapter

    property QtObject prefix: prefixLoader.adapter

    property QtObject system: systemLoader.adapter

    property QtObject pinnedApps: pinnedAppsLoader.adapter


    function saveBar() {
        barLoader.writeAdapter();
    }
    function saveWorkspaces() {
        workspacesLoader.writeAdapter();
    }
    function saveOverview() {
        overviewLoader.writeAdapter();
    }
    function saveNotch() {
        notchLoader.writeAdapter();
    }
    function saveCompositor() {
        compositorLoader.writeAdapter();
    }
    function savePerformance() {
        performanceLoader.writeAdapter();
    }
    function saveWeather() {
        weatherLoader.writeAdapter();
    }
    function saveDesktop() {
        desktopLoader.writeAdapter();
    }
    function saveLockscreen() {
        lockscreenLoader.writeAdapter();
    }
    function savePrefix() {
        prefixLoader.writeAdapter();
    }
    function saveSystem() {
        systemLoader.writeAdapter();
    }
    function savePinnedApps() {
        pinnedAppsLoader.writeAdapter();
    }

    function isHexColor(colorValue) {
        if (!colorValue || typeof colorValue !== 'string')
            return false;
        const normalized = colorValue.toLowerCase().trim();
        return normalized.startsWith('#') || normalized.startsWith('rgb');
    }

    function resolveColor(colorValue) {
        if (!colorValue) return "transparent";
        
        if (isHexColor(colorValue)) {
            return colorValue;
        }
        
        if (typeof Colors === 'undefined' || !Colors) return "transparent";
        
        return Colors[colorValue] || "transparent"; 
    }

    function resolveColorWithOpacity(colorValue, opacity) {
        if (!colorValue) return Qt.rgba(0,0,0,0);
        
        const color = isHexColor(colorValue) ? Qt.color(colorValue) : (Colors[colorValue] || Qt.color("transparent"));
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }
}
