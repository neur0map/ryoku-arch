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
    settingsPageIndex: 13
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
            themesAssetExt: ".png",
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
            themesAssetExt: ".gif",
            placeholderAsset: "../_placeholder.png",
            bundledThemes: [
                "clockwork", "dog-samurai", "enfield", "forest", "Genshin",
                "last-of-us", "minecraft", "nier-automata", "ninja_gaiden",
                "osu", "pixel-coffee", "pixel-dusk-city", "pixel-hollowknight",
                "pixel-munchlax", "pixel-night-city", "pixel-rainyroom",
                "R1999_1", "R1999_2", "windows_7", "winter", "wuwa"
            ]
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

    // ── Toast plumbing ───────────────────────────────────────────────
    property string toastText: ""
    Timer {
        id: toastTimer
        interval: 4000
        onTriggered: root.toastText = ""
    }
    function toast(text) {
        root.toastText = text
        toastTimer.restart()
    }

    // ── Workflow processes ───────────────────────────────────────────
    property string busyMessage: ""
    property string busyProviderId: ""
    property bool reopenSettingsOverlayAfterPolkit: false
    readonly property bool workflowRunning: applyProc.running || installProc.running || uninstallProc.running

    function clearBusyState() {
        busyMessage = ""
        busyProviderId = ""
    }

    Process {
        id: applyProc
        property string targetTheme: ""
        onExited: code => {
            if (code === 0) {
                root.refreshProviderState()
                root.readActiveTheme()
                root.toast(Translation.tr("Theme applied. Reboot or run 'systemctl restart sddm'."))
            } else if (code === 126 || code === 127) {
                // user cancelled polkit dialog
            } else {
                root.toast(Translation.tr("Apply failed (exit %1).").arg(code))
            }
            root.clearBusyState()
            root.restoreSettingsOverlayAfterPolkit()
        }
    }

    Process {
        id: installProc
        onExited: code => {
            if (code === 0) {
                root.refreshProviderState()
                root.readActiveTheme()
                root.toast(Translation.tr("qylock installed. Reboot or run 'systemctl restart sddm'."))
            } else if (code === 126 || code === 127) {
                root.toast(Translation.tr("Install did not start (exit %1).").arg(code))
            } else {
                root.toast(Translation.tr("Install failed (exit %1). Run ryoku-install-qylock in a terminal to see output.").arg(code))
            }
            root.clearBusyState()
            root.restoreSettingsOverlayAfterPolkit()
        }
    }

    Process {
        id: uninstallProc
        onExited: code => {
            if (code === 0) {
                root.refreshProviderState()
                root.readActiveTheme()
                root.toast(Translation.tr("qylock removed. ii-pixel is now active. Reboot or run 'systemctl restart sddm'."))
            } else if (code === 126 || code === 127) {
                // user cancelled polkit dialog
            } else {
                root.toast(Translation.tr("Uninstall failed (exit %1).").arg(code))
            }
            root.clearBusyState()
            root.restoreSettingsOverlayAfterPolkit()
        }
    }

    Component.onCompleted: {
        readActiveTheme()
        refreshProviderState()
    }

    onVisibleChanged: if (visible) {
        readActiveTheme()
        refreshProviderState()
    }

    // Page handlers
    // pkexec sanitizes PATH to a system-only set, so ~/.local/share/ryoku/bin
    // helpers must be invoked via absolute path or pkexec returns 127.
    function helperPath(name) {
        var ryokuPath = Quickshell.env("RYOKU_PATH")
        if (!ryokuPath || ryokuPath.length === 0) {
            ryokuPath = Quickshell.env("HOME") + "/.local/share/ryoku"
        }
        return ryokuPath + "/bin/" + name
    }

    function yieldSettingsOverlayForPolkit() {
        reopenSettingsOverlayAfterPolkit = GlobalStates.settingsOverlayOpen
        if (reopenSettingsOverlayAfterPolkit) {
            GlobalStates.settingsOverlayOpen = false
        }
    }

    function restoreSettingsOverlayAfterPolkit() {
        if (reopenSettingsOverlayAfterPolkit) {
            reopenSettingsOverlayAfterPolkit = false
            GlobalStates.settingsOverlayOpen = true
        }
    }

    function applyTheme(provider, themeName) {
        if (workflowRunning) return
        applyProc.targetTheme = themeName
        if (provider.kind === "builtin") {
            applyProc.command = ["pkexec", helperPath("ryoku-set-sddm-theme"), themeName]
        } else {
            applyProc.command = ["pkexec", helperPath("ryoku-install-qylock"), "--theme", themeName]
        }
        busyMessage = Translation.tr("Applying %1...").arg(themeName)
        busyProviderId = provider.providerId
        yieldSettingsOverlayForPolkit()
        applyProc.running = true
    }

    function installProvider(provider) {
        if (workflowRunning) return
        if (provider.providerId !== "qylock") return
        installProc.command = ["pkexec", helperPath("ryoku-install-qylock"), "--default"]
        busyMessage = Translation.tr("Installing %1...").arg(provider.displayName)
        busyProviderId = provider.providerId
        yieldSettingsOverlayForPolkit()
        installProc.running = true
    }

    function confirmUninstall(provider) {
        if (provider.providerId !== "qylock") return
        uninstallDialog.providerToRemove = provider
        uninstallDialog.open()
    }

    // ContentPage manages its own ColumnLayout (see modules/common/widgets/ContentPage.qml).
    // Children below are added directly via the default contentData alias.

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
    Rectangle {
        id: busyStatus
        visible: root.busyMessage.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: 50
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            StyledText {
                text: Translation.tr("Working")
                color: Appearance.colors.colPrimary
                font.pixelSize: 12
                font.bold: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    Layout.fillWidth: true
                    text: root.busyMessage
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                StyledIndeterminateProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                }
            }
        }
    }

    Repeater {
        model: root.providers
        delegate: ProviderCard {
            provider: modelData
            installed: root.providerInstalled(modelData)
            activeTheme: root.activeTheme
            busy: root.busyProviderId === modelData.providerId
            busyMessage: root.busyMessage
            onApplyTheme: themeName => root.applyTheme(modelData, themeName)
            onInstallProvider: root.installProvider(modelData)
            onUninstallProvider: root.confirmUninstall(modelData)
        }
    }

    Rectangle {
        visible: root.toastText.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        StyledText {
            anchors.centerIn: parent
            text: root.toastText
            font.pixelSize: 12
        }
    }

    Dialog {
        id: uninstallDialog
        property var providerToRemove
        modal: true
        title: providerToRemove ? Translation.tr("Remove %1?").arg(providerToRemove.displayName) : ""
        standardButtons: Dialog.Cancel | Dialog.Ok
        Component.onCompleted: {
            var okBtn = standardButton(Dialog.Ok)
            if (okBtn) {
                okBtn.text = Translation.tr("Remove")
            }
        }

        contentItem: ColumnLayout {
            spacing: 12
            StyledText {
                Layout.maximumWidth: 480
                wrapMode: Text.WordWrap
                text: Translation.tr("This removes the qylock theme bundle and all qylock-installed SDDM themes from your system. Your active greeter will fall back to the built-in ii-pixel theme.")
            }
            StyledText {
                Layout.maximumWidth: 480
                wrapMode: Text.WordWrap
                color: Appearance.colors.colSubtext
                font.pixelSize: 12
                text: Translation.tr("Stock SDDM themes (elarun, maldives, maya) and the built-in ii-pixel theme are not affected. This cannot be undone, but you can re-install qylock at any time from this page.")
            }
        }

        onAccepted: {
            if (root.workflowRunning) return
            uninstallProc.command = ["pkexec", root.helperPath("ryoku-uninstall-qylock")]
            root.busyMessage = Translation.tr("Removing %1...").arg(providerToRemove.displayName)
            root.busyProviderId = providerToRemove.providerId
            root.yieldSettingsOverlayForPolkit()
            uninstallProc.running = true
        }
    }

    component ProviderCard: SettingsCardSection {
        id: providerCardRoot
        property var provider
        property bool installed: false
        property string activeTheme: ""
        property bool busy: false
        property string busyMessage: ""

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
                        color: Qt.rgba(Appearance.colors.colPrimary.r,
                                       Appearance.colors.colPrimary.g,
                                       Appearance.colors.colPrimary.b, 0.18)
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
                        readonly property color _accent: provider.accentColor && provider.accentColor.length > 0
                                                         ? Qt.color(provider.accentColor)
                                                         : Appearance.colors.colPrimary
                        color: Qt.rgba(_accent.r, _accent.g, _accent.b, 0.18)
                        implicitWidth: installedPillText.implicitWidth + 16
                        implicitHeight: installedPillText.implicitHeight + 6
                        StyledText {
                            id: installedPillText
                            anchors.centerIn: parent
                            text: Translation.tr("Installed")
                            color: parent._accent
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
                    busy: providerCardRoot.busy
                    onApplyTheme: themeName => providerCardRoot.applyTheme(themeName)
                }

                RowLayout {
                    visible: providerCardRoot.busy
                    Layout.fillWidth: true
                    spacing: 10

                    StyledIndeterminateProgressBar {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 4
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: providerCardRoot.busyMessage
                        color: Appearance.colors.colSubtext
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }

                // Action row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        visible: provider.kind === "external" && providerCardRoot.installed
                        enabled: !providerCardRoot.busy
                        buttonText: Translation.tr("Update")
                        onClicked: providerCardRoot.installProvider()
                    }

                    RippleButton {
                        visible: provider.kind === "external" && providerCardRoot.installed
                        enabled: !providerCardRoot.busy
                        buttonText: Translation.tr("Uninstall")
                        colBackground: "transparent"
                        colBackgroundHover: Qt.rgba(Appearance.colors.colError.r,
                                                    Appearance.colors.colError.g,
                                                    Appearance.colors.colError.b, 0.18)
                        onClicked: providerCardRoot.uninstallProvider()
                    }

                    RippleButton {
                        visible: provider.kind === "external" && !providerCardRoot.installed
                        enabled: !providerCardRoot.busy
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
        property bool busy: false
        signal applyTheme(string themeName)

        Layout.fillWidth: true
        spacing: 8

        // Build the list of theme entries to render.
        property var themeList: {
            if (provider.kind === "builtin") {
                return provider.bundledThemes.map(name => ({
                    name: name,
                    source: Quickshell.shellPath(provider.bundledAssetDir + "/" + provider.themesAssetDir + "/" + name + (provider.themesAssetExt || ".png"))
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
                    source: Quickshell.shellPath(provider.bundledAssetDir + "/" + provider.themesAssetDir + "/" + name + (provider.themesAssetExt || ".png"))
                }))
            }
            // External post-install: live themes from disk; preview source
            // resolves bundled or placeholder fallback in the delegate.
            return root.qylockThemes.map(name => ({
                name: name,
                source: ""
            }))
        }

        Flow {
            // Flow wraps items based on the parent's available width
            // and respects each tile's natural width (no fillWidth
            // stretching that would happen in a GridLayout). Each tile
            // is a fixed 200x112; Flow places as many per row as fit.
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: stripRoot.themeList
                delegate: ThemeTile {
                    provider: stripRoot.provider
                    themeName: modelData.name
                    presetSource: modelData.source
                    isActive: stripRoot.activeTheme === modelData.name
                    clickable: !stripRoot.busy && (stripRoot.provider.kind === "builtin" || stripRoot.installed)
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
        property var previewCandidates: buildPreviewCandidates()
        property int previewCandidateIndex: 0
        signal clicked()

        width: 200
        height: 112
        radius: Appearance.rounding.small
        color: "transparent"
        clip: true

        border.width: isActive ? 2 : 0
        border.color: provider.kind === "builtin"
                      ? Appearance.colors.colPrimary
                      : provider.accentColor

        function uniqueStrings(values) {
            const seen = new Set()
            const result = []
            for (let value of values) {
                if (!value || value.length === 0 || seen.has(value))
                    continue
                seen.add(value)
                result.push(value)
            }
            return result
        }

        function fileUrl(path) {
            return encodeURI("file://" + path)
        }

        function bundledPreviewSource() {
            return Quickshell.shellPath(
                tileRoot.provider.bundledAssetDir + "/"
                + tileRoot.provider.themesAssetDir + "/"
                + tileRoot.themeName
                + (tileRoot.provider.themesAssetExt || ".png"))
        }

        function qylockAssetBaseNames(name) {
            const original = name ?? ""
            const lower = original.toLowerCase()
            const snake = lower.replace(/-/g, "_")
            const kebab = lower.replace(/_/g, "-")
            const special = ({
                "dog-samurai": ["dog_samurai"],
                "genshin": ["genshin"],
                "last-of-us": ["the_last_of_us"],
                "nier-automata": ["nier_automata"],
                "pixel-skyscrapers": ["pixel_skyscrapers"],
                "star-rail": ["star_rail"],
                "windows_7": ["win7"]
            })
            return uniqueStrings([original, lower, snake, kebab].concat(special[lower] ?? []))
        }

        function buildPreviewCandidates() {
            const candidates = []
            if (presetSource)
                candidates.push(presetSource)

            if (provider.kind === "external") {
                const qylockRoot = Quickshell.env("HOME") + "/.local/share/qylock"
                const qylockAssetsRoot = Quickshell.env("HOME") + "/.local/share/qylock/Assets"
                candidates.push(fileUrl(qylockRoot + "/themes/" + themeName + "/preview.png"))

                for (let base of qylockAssetBaseNames(themeName)) {
                    for (let ext of ["gif", "png", "jpg", "jpeg", "webp"]) {
                        candidates.push(fileUrl(qylockAssetsRoot + "/" + base + "." + ext))
                    }
                }

                candidates.push(fileUrl(qylockRoot + "/themes/" + themeName + "/bg.png"))
                candidates.push(fileUrl(qylockRoot + "/themes/" + themeName + "/background.png"))
                candidates.push(fileUrl(qylockRoot + "/themes/" + themeName + "/background/A Glow.jpg"))
            }

            candidates.push(bundledPreviewSource())
            candidates.push(Quickshell.shellPath("assets/sddm-providers/_placeholder.png"))
            return uniqueStrings(candidates)
        }

        function previewSource() {
            if (previewCandidates.length === 0)
                return ""
            return previewCandidates[Math.min(previewCandidateIndex, previewCandidates.length - 1)]
        }

        onThemeNameChanged: previewCandidateIndex = 0
        onPresetSourceChanged: previewCandidateIndex = 0

        AnimatedImage {
            id: previewImage
            anchors.fill: parent
            source: tileRoot.previewSource()
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            playing: true
            paused: false

            onStatusChanged: {
                if (status === Image.Error) {
                    if (tileRoot.previewCandidateIndex + 1 < tileRoot.previewCandidates.length) {
                        tileRoot.previewCandidateIndex += 1
                    }
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
