import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 16
    settingsPageName: Translation.tr("Applications")

    // ── Helpers shared across application-related cards ─────────────
    function ryokuBinPath(name) {
        var ryokuPath = Quickshell.env("RYOKU_PATH")
        if (!ryokuPath || ryokuPath.length === 0) {
            ryokuPath = Quickshell.env("HOME") + "/.local/share/ryoku"
        }
        return ryokuPath + "/bin/" + name
    }

    function safeTerminal() {
        const configured = (Config.options?.apps?.terminal ?? "").trim()
        if (configured.length === 0) return "kitty"
        if (!/^[A-Za-z0-9._+-]+$/.test(configured)) return "kitty"
        return configured
    }

    // ── rmpc install detection ──────────────────────────────────────
    // Probe `command -v rmpc` once on load and again every time the
    // page becomes visible. If exit code is 0, rmpc is on PATH.
    property bool rmpcInstalled: false
    Process {
        id: rmpcProbe
        command: ["/usr/bin/bash", "-lc", "command -v rmpc >/dev/null 2>&1"]
        onExited: code => { root.rmpcInstalled = (code === 0) }
    }
    function probeRmpc() {
        if (!rmpcProbe.running) rmpcProbe.running = true
    }
    Component.onCompleted: probeRmpc()
    onVisibleChanged: if (visible) probeRmpc()

    // ── Music daemon control ────────────────────────────────────────
    Process {
        id: musicDaemonProc
        property string desiredMode: ""
        onExited: code => {
            if (code !== 0) console.warn("[ApplicationsConfig] daemon-set", musicDaemonProc.desiredMode, "exit:", code)
        }
    }
    function applyMusicDaemon(enable) {
        Config.setNestedValue("apps.musicDaemonEnabled", enable)
        musicDaemonProc.desiredMode = enable ? "on" : "off"
        musicDaemonProc.command = [root.ryokuBinPath("ryoku-music-daemon-set"), musicDaemonProc.desiredMode]
        musicDaemonProc.running = true
    }

    // ── Music library folder picker ─────────────────────────────────
    Process {
        id: musicDirProc
        property string targetDir: ""
        onExited: code => {
            if (code !== 0) console.warn("[ApplicationsConfig] set-music-dir exit:", code)
        }
    }
    function applyMusicDir(dir) {
        if (!dir || dir.length === 0) return
        Config.setNestedValue("apps.musicDir", dir)
        musicDirProc.targetDir = dir
        musicDirProc.command = [root.ryokuBinPath("ryoku-mpd-set-music-dir"), dir]
        musicDirProc.running = true
    }
    FolderDialog {
        id: musicDirDialog
        title: Translation.tr("Choose music library folder")
        onAccepted: {
            const local = FileUtils.trimFileProtocol(String(selectedFolder))
            if (local && local.length > 0) root.applyMusicDir(local)
        }
    }

    // ── Music Player card ───────────────────────────────────────────
    SettingsCardSection {
        expanded: true
        icon: "library_music"
        title: Translation.tr("Music Player (rmpc)")

        // Install hint banner — visible only when rmpc isn't on PATH.
        SettingsGroup {
            visible: !root.rmpcInstalled

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Music (rmpc + MPD) isn't installed yet. Install the profile from Extras to enable these controls.")
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RippleButton {
                        implicitHeight: 36
                        implicitWidth: extrasJumpRow.implicitWidth + 20
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        colRipple: Appearance.colors.colPrimaryActive
                        contentItem: RowLayout {
                            id: extrasJumpRow
                            anchors.centerIn: parent
                            spacing: 8
                            MaterialSymbol {
                                text: "extension"
                                iconSize: 18
                                color: Appearance.colors.colOnPrimary
                                Layout.alignment: Qt.AlignVCenter
                            }
                            StyledText {
                                text: Translation.tr("Open Extras → Music")
                                font.pixelSize: 13
                                color: Appearance.colors.colOnPrimary
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                        downAction: () => {
                            // SettingsOverlay watches GlobalStates.settingsOverlayRequestedPage
                            // and switches overlayCurrentPage to match (page 15 = Extras).
                            GlobalStates.settingsOverlayRequestedPage = 15
                        }
                        StyledToolTip { text: Translation.tr("Jump to Settings → Extras to install the Music (rmpc + MPD) profile.") }
                    }

                    RippleButton {
                        implicitHeight: 36
                        implicitWidth: probeRow.implicitWidth + 20
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colLayer1
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        colRipple: Appearance.colors.colLayer1Active
                        contentItem: RowLayout {
                            id: probeRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                text: "refresh"
                                iconSize: 16
                                color: Appearance.colors.colOnLayer1
                                Layout.alignment: Qt.AlignVCenter
                            }
                            StyledText {
                                text: Translation.tr("Re-check")
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                        downAction: () => root.probeRmpc()
                    }
                }
            }
        }

        // Active controls — visible only once rmpc is installed.
        SettingsGroup {
            visible: root.rmpcInstalled

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("rmpc is a TUI client for MPD. The in-shell media widget surfaces MPD tracks via MPRIS once the daemon is on.")
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13
                }

                ConfigSwitch {
                    buttonIcon: "play_arrow"
                    text: Translation.tr("Enable music daemon (MPD)")
                    checked: Config.options?.apps?.musicDaemonEnabled ?? false
                    onCheckedChanged: {
                        if (checked !== (Config.options?.apps?.musicDaemonEnabled ?? false)) {
                            root.applyMusicDaemon(checked)
                        }
                    }
                    StyledToolTip {
                        text: Translation.tr("Starts and enables mpd.socket under systemctl --user. Off stops and disables the unit so no music daemon runs at login.")
                    }
                }

                ConfigSwitch {
                    buttonIcon: "palette"
                    text: Translation.tr("Auto-theme rmpc")
                    checked: Config.options?.appearance?.wallpaperTheming?.enableRmpc ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.enableRmpc", checked)
                    StyledToolTip {
                        text: Translation.tr("Regenerate ~/.config/rmpc/themes/ryoku.ron on every wallpaper change.")
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: Translation.tr("Music library folder")
                        font.pixelSize: 13
                        color: Appearance.colors.colOnLayer1
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledText {
                            Layout.fillWidth: true
                            text: Config.options?.apps?.musicDir ?? (Quickshell.env("HOME") + "/Music")
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: 12
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideMiddle
                        }

                        RippleButton {
                            implicitHeight: 32
                            implicitWidth: browseRow.implicitWidth + 16
                            buttonRadius: Appearance.rounding.small
                            colBackground: Appearance.colors.colLayer1
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            colRipple: Appearance.colors.colLayer1Active
                            contentItem: RowLayout {
                                id: browseRow
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialSymbol {
                                    text: "folder_open"
                                    iconSize: 16
                                    color: Appearance.colors.colOnLayer1
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                StyledText {
                                    text: Translation.tr("Choose...")
                                    font.pixelSize: 12
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                            downAction: () => musicDirDialog.open()
                            StyledToolTip { text: Translation.tr("Writes music_directory to ~/.config/mpd/mpd.conf and triggers mpc rescan.") }
                        }
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol {
                            text: "play_circle"
                            iconSize: 18
                            color: Appearance.colors.colOnLayer1
                            Layout.alignment: Qt.AlignVCenter
                        }
                        StyledText {
                            text: Translation.tr("Open rmpc")
                            font.pixelSize: 13
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                    downAction: () => {
                        const terminal = root.safeTerminal()
                        if (terminal === "wezterm") {
                            Quickshell.execDetached([terminal, "start", "--always-new-process", "--", "rmpc"])
                        } else {
                            Quickshell.execDetached([terminal, "-e", "rmpc"])
                        }
                    }
                    StyledToolTip { text: Translation.tr("Launches rmpc in your configured terminal.") }
                }
            }
        }
    }
}
