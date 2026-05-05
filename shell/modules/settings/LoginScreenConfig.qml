import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: root
    settingsPageIndex: -1   // set by integration in shell/settings.qml (Task 11)
    settingsPageName: Translation.tr("Login screen")

    // Provider data. The qylock bundledThemes list is populated in
    // Task 7 once upstream theme captures land in
    // shell/assets/sddm-providers/qylock/themes/.
    property var providers: [
        ({
            providerId: "ii-pixel",
            kind: "builtin",
            displayName: "ii-pixel",
            author: "Ryoku project",
            repoUrl: "",
            description: "Built-in pixel-art SDDM theme that ships with Ryoku. Material You dynamic colors driven by your wallpaper palette.",
            accentColor: "",
            licenseLabel: "MIT",
            installRoot: "",
            themesPath: "",
            bundledAssetDir: "assets/sddm-providers/ii-pixel",
            heroAsset: "hero.png",
            themesAssetDir: "themes",
            placeholderAsset: "../_placeholder.png",
            bundledThemes: ["ii-pixel"]
        }),
        ({
            providerId: "qylock",
            kind: "external",
            displayName: "qylock",
            author: "Darkkal44",
            repoUrl: "https://github.com/Darkkal44/qylock",
            description: "Optional bundle of animated, video-capable SDDM themes by Darkkal44. Cloned to ~/.local/share/qylock and copied into the system SDDM themes dir on demand.",
            accentColor: "#8f1d21",
            licenseLabel: "GPL-3.0",
            installRoot: Quickshell.env("HOME") + "/.local/share/qylock",
            themesPath: "themes",
            bundledAssetDir: "assets/sddm-providers/qylock",
            heroAsset: "hero.png",
            themesAssetDir: "themes",
            placeholderAsset: "../_placeholder.png",
            bundledThemes: []
        })
    ]

    // Active theme: last `Current=` line from /etc/sddm.conf.d/*.conf
    // in alphabetical order (matches SDDM's own merge semantics).
    property string activeTheme: ""

    Process {
        id: readActiveThemeProc
        command: ["/usr/bin/bash", "-c",
            "shopt -s nullglob; " +
            "current=''; " +
            "for f in /etc/sddm.conf.d/*.conf; do " +
            "  v=$(grep -E '^\\s*Current\\s*=' \"$f\" | tail -n1 | cut -d= -f2 | tr -d '[:space:]') || true; " +
            "  [[ -n $v ]] && current=\"$v\"; " +
            "done; " +
            "echo \"$current\""
        ]
        stdout: SplitParser {
            onRead: data => {
                root.activeTheme = data.trim() || "breeze"
            }
        }
    }

    function readActiveTheme() {
        readActiveThemeProc.running = true
    }

    // Provider install state. Tracked separately so the future UI can
    // decide pre/post install presentation per provider without
    // re-running probes on every binding evaluation.
    QtObject {
        id: providerInstallProbe
        property var presence: ({})
        function has(id) { return presence[id] === true }
        function set(id, value) {
            var p = Object.assign({}, presence)
            p[id] = value === true
            presence = p
        }
    }

    Process {
        id: probeQylockProc
        command: ["/usr/bin/bash", "-c",
            "test -d \"$HOME/.local/share/qylock/.git\" && echo yes || echo no"]
        stdout: SplitParser {
            onRead: data => providerInstallProbe.set("qylock", data.trim() === "yes")
        }
    }

    function providerInstalled(provider) {
        if (provider.kind === "builtin") return true
        return providerInstallProbe.has(provider.providerId)
    }

    function refreshProviderState() {
        probeQylockProc.running = true
    }

    Component.onCompleted: {
        readActiveTheme()
        refreshProviderState()
    }

    onVisibleChanged: if (visible) {
        readActiveTheme()
        refreshProviderState()
    }

    // Placeholder body. Real banner + cards land in Task 8.
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        StyledText {
            text: Translation.tr("Login screen page (under construction). Active: %1").arg(root.activeTheme)
        }
    }
}
