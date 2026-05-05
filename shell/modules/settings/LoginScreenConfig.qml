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

    property var qylockThemes: []

    Process {
        id: listQylockThemesProc
        command: ["/usr/bin/bash", "-c",
            "dir=\"$HOME/.local/share/qylock/themes\"; " +
            "[[ -d $dir ]] || exit 0; " +
            "(cd \"$dir\" && for d in */; do echo \"${d%/}\"; done)"
        ]
        property var _accum: []
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length > 0) listQylockThemesProc._accum.push(line)
            }
        }
        onExited: exitCode => {
            // Assign a NEW array reference so QML binding picks up the change
            // (in-place push on a `var` array does not trigger property updates).
            root.qylockThemes = listQylockThemesProc._accum.slice()
            listQylockThemesProc._accum = []
        }
    }

    function refreshQylockThemes() {
        listQylockThemesProc._accum = []
        listQylockThemesProc.running = true
    }

    function refreshProviderState() {
        probeQylockProc.running = true
        refreshQylockThemes()
    }

    Component.onCompleted: {
        readActiveTheme()
        refreshProviderState()
    }

    onVisibleChanged: if (visible) {
        readActiveTheme()
        refreshProviderState()
    }

    // Page handlers (stubs; real Process wiring in Task 10)
    function applyTheme(provider, themeName) {
        console.log("applyTheme stub:", provider.providerId, themeName)
    }
    function installProvider(provider) {
        console.log("installProvider stub:", provider.providerId)
    }
    function confirmUninstall(provider) {
        console.log("confirmUninstall stub:", provider.providerId)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // Active-theme banner
        SettingsCardSection {
            Layout.fillWidth: true
            expanded: true
            icon: "login"
            title: Translation.tr("Active SDDM theme")

            SettingsGroup {
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    StyledText {
                        text: root.activeTheme || "breeze"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 16
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: Translation.tr("Greeter shown before login. Reboot or run 'systemctl restart sddm' to apply.")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.maximumWidth: 360
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // Provider cards
        Repeater {
            model: root.providers
            delegate: ProviderCard {
                provider: modelData
                installed: root.providerInstalled(modelData)
                activeTheme: root.activeTheme
                onApplyTheme: themeName => root.applyTheme(modelData, themeName)
                onInstallProvider: root.installProvider(modelData)
                onUninstallProvider: root.confirmUninstall(modelData)
            }
        }
    }

    component ProviderCard: SettingsCardSection {
        id: providerCardRoot
        property var provider
        property bool installed: false
        property string activeTheme: ""

        signal applyTheme(string themeName)
        signal installProvider()
        signal uninstallProvider()

        Layout.fillWidth: true
        expanded: true
        icon: provider.kind === "builtin" ? "verified" : "extension"
        title: provider.displayName

        SettingsGroup {
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                // Hero strip
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Appearance.rounding.normal
                    color: "transparent"
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: Quickshell.shellPath(provider.bundledAssetDir + "/" + provider.heroAsset)
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                    }
                }

                // Name + author + status pill
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: provider.displayName + (provider.author ? "  ·  by " + provider.author : "")
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        visible: provider.kind === "builtin"
                        radius: 999
                        color: Appearance.colors.colPrimary
                        opacity: 0.18
                        implicitWidth: builtinPillText.implicitWidth + 16
                        implicitHeight: builtinPillText.implicitHeight + 6
                        StyledText {
                            id: builtinPillText
                            anchors.centerIn: parent
                            text: Translation.tr("Built-in")
                            color: Appearance.colors.colPrimary
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    Rectangle {
                        visible: provider.kind === "external" && !providerCardRoot.installed
                        radius: 999
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.colSubtext
                        implicitWidth: notInstalledPillText.implicitWidth + 16
                        implicitHeight: notInstalledPillText.implicitHeight + 6
                        StyledText {
                            id: notInstalledPillText
                            anchors.centerIn: parent
                            text: Translation.tr("Not installed")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        visible: provider.kind === "external" && providerCardRoot.installed
                        radius: 999
                        color: provider.accentColor
                        opacity: 0.18
                        implicitWidth: installedPillText.implicitWidth + 16
                        implicitHeight: installedPillText.implicitHeight + 6
                        StyledText {
                            id: installedPillText
                            anchors.centerIn: parent
                            text: Translation.tr("Installed")
                            color: provider.accentColor
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }

                // Repo link (external only)
                StyledText {
                    visible: provider.kind === "external" && provider.repoUrl
                    text: "<a href=\"" + provider.repoUrl + "\">" + provider.repoUrl + "</a>"
                    onLinkActivated: link => Qt.openUrlExternally(link)
                    font.pixelSize: 12
                    color: Appearance.colors.colPrimary
                    textFormat: Text.RichText
                }

                // Description
                StyledText {
                    Layout.fillWidth: true
                    text: provider.description
                    wrapMode: Text.WordWrap
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 13
                }

                // Theme tiles (full grid lands in Task 9)
                ThemeTileStrip {
                    provider: providerCardRoot.provider
                    installed: providerCardRoot.installed
                    activeTheme: providerCardRoot.activeTheme
                    onApplyTheme: themeName => providerCardRoot.applyTheme(themeName)
                }

                // Action row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        visible: provider.kind === "external" && providerCardRoot.installed
                        buttonText: Translation.tr("Update")
                        onClicked: providerCardRoot.applyTheme(providerCardRoot.activeTheme)
                    }

                    RippleButton {
                        visible: provider.kind === "external" && providerCardRoot.installed
                        buttonText: Translation.tr("Uninstall")
                        colBackground: "transparent"
                        colBackgroundHover: Qt.rgba(Appearance.colors.colError.r,
                                                    Appearance.colors.colError.g,
                                                    Appearance.colors.colError.b, 0.18)
                        onClicked: providerCardRoot.uninstallProvider()
                    }

                    RippleButton {
                        visible: provider.kind === "external" && !providerCardRoot.installed
                        buttonText: Translation.tr("Install %1").arg(provider.displayName)
                        colBackground: provider.accentColor
                        colBackgroundHover: provider.accentColor
                        onClicked: providerCardRoot.installProvider()
                    }
                }
            }
        }
    }

    component ThemeTileStrip: ColumnLayout {
        id: stripRoot
        property var provider
        property bool installed: false
        property string activeTheme: ""
        signal applyTheme(string themeName)

        Layout.fillWidth: true
        spacing: 8

        // Build the list of theme entries to render.
        property var themeList: {
            if (provider.kind === "builtin") {
                return provider.bundledThemes.map(name => ({
                    name: name,
                    source: Quickshell.shellPath(provider.bundledAssetDir + "/" + provider.themesAssetDir + "/" + name + ".png")
                }))
            }
            if (!stripRoot.installed) {
                if (provider.bundledThemes.length === 0) {
                    return [{
                        name: "preview-after-install",
                        source: Quickshell.shellPath("assets/sddm-providers/_placeholder.png")
                    }]
                }
                return provider.bundledThemes.map(name => ({
                    name: name,
                    source: Quickshell.shellPath(provider.bundledAssetDir + "/" + provider.themesAssetDir + "/" + name + ".png")
                }))
            }
            // External post-install: live themes from disk; preview source
            // resolves bundled or placeholder fallback in the delegate.
            return root.qylockThemes.map(name => ({
                name: name,
                source: ""
            }))
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: stripRoot.themeList
                delegate: ThemeTile {
                    provider: stripRoot.provider
                    themeName: modelData.name
                    presetSource: modelData.source
                    isActive: stripRoot.activeTheme === modelData.name
                    clickable: stripRoot.provider.kind === "builtin" || stripRoot.installed
                    onClicked: stripRoot.applyTheme(themeName)
                }
            }
        }
    }

    component ThemeTile: Rectangle {
        id: tileRoot
        property var provider
        property string themeName: ""
        property string presetSource: ""
        property bool isActive: false
        property bool clickable: true
        signal clicked()

        Layout.preferredWidth: 200
        Layout.preferredHeight: 112
        radius: Appearance.rounding.small
        color: "transparent"
        clip: true

        border.width: isActive ? 2 : 0
        border.color: provider.kind === "builtin"
                      ? Appearance.colors.colPrimary
                      : provider.accentColor

        function previewSource() {
            if (presetSource) return presetSource
            var live = Quickshell.env("HOME")
                       + "/.local/share/qylock/themes/" + themeName + "/preview.png"
            return "file://" + live
        }

        Image {
            id: previewImage
            anchors.fill: parent
            source: tileRoot.previewSource()
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true

            onStatusChanged: {
                if (status === Image.Error) {
                    var bundled = Quickshell.shellPath(
                        tileRoot.provider.bundledAssetDir + "/"
                        + tileRoot.provider.themesAssetDir + "/"
                        + tileRoot.themeName + ".png")
                    if (source.toString() !== bundled) {
                        source = bundled
                        return
                    }
                    source = Quickshell.shellPath("assets/sddm-providers/_placeholder.png")
                }
            }
        }

        Rectangle {
            visible: tileRoot.isActive
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6
            radius: 999
            color: tileRoot.provider.kind === "builtin"
                   ? Appearance.colors.colPrimary
                   : tileRoot.provider.accentColor
            implicitWidth: activeChipText.implicitWidth + 14
            implicitHeight: activeChipText.implicitHeight + 4
            StyledText {
                id: activeChipText
                anchors.centerIn: parent
                text: Translation.tr("Active")
                color: "white"
                font.pixelSize: 10
                font.bold: true
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 24
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: "#cc000000" }
            }
            StyledText {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 8
                anchors.bottomMargin: 4
                text: tileRoot.themeName
                color: "white"
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font Mono"
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: tileRoot.clickable
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: tileRoot.clicked()
        }
    }
}
