// lock_shell.qml - Ryoku in-session lock screen
//
// This is the entry point for the lock screen launched by `ryoku-shell lock`.
// It creates a Wayland session lock (or X11 fullscreen window) and loads the
// selected qylock theme (default: clockwork/orbital).
//
// Fingerprint integration:
//   - The SddmShim provides PAM and fingerprint state
//   - When WlSessionLock.secure becomes true, armWhenReady is set
//   - The shim probes fprintd and arms the sensor automatically
//   - On loginSucceeded, loginctl unlock-session is called
//   - On unlock (secure flips false), resetAuth() stops the sensor

import QtQuick
import Quickshell
import Quickshell.Wayland
import QtMultimedia
import "./shim"

ShellRoot {
    id: shellRoot

    // ── theme configuration ────────────────────────────────────────────────
    // QS_THEME and QS_THEME_PATH are set by lock.sh, which reads
    // ~/.config/qylock/theme and resolves the theme directory.
    property string activeTheme: Quickshell.env("QS_THEME") || "clockwork/orbital"
    property string themePath: Quickshell.env("QS_THEME_PATH") || (Quickshell.shellDir + "/themes_link/" + activeTheme)

    // ── shim interface ──────────────────────────────────────────────────────
    // Expose the SddmShim's properties to the theme via the sddm namespace.
    // Themes bind to sddm.login(), sddm.loginSucceeded, sddm.loginFailed,
    // sddm.hostName, sddm.fingerprintHint, etc.
    readonly property var sddm: sddmShim.sddm
    readonly property var config: sddmShim.config
    readonly property var userModel: sddmShim.userModel
    readonly property var sessionModel: sddmShim.sessionModel
    readonly property var keyboard: sddmShim.keyboard
    readonly property bool isWayland: Quickshell.env("XDG_SESSION_TYPE") === "wayland"
    property bool authenticated: false
    property bool sessionLocked: true
    property bool isTesting: Quickshell.env("QS_TESTING") === "1"

    SddmShim {
        id: sddmShim
        themePath: shellRoot.themePath
    }

    // ── login success handler ───────────────────────────────────────────────
    // Called by the shim when PAM authentication succeeds (either via fingerprint
    // or typed password). Unlocks the session and quits the lock screen.
    Connections {
        target: sddmShim.sddm
        function onLoginSucceeded() {
            shellRoot.authenticated = true

            // Hyprland session lock fix: allow the compositor to restore
            // the previous layout after the lock surface is destroyed.
            if (Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland" || Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== "") {
                Quickshell.execDetached(["hyprctl", "keyword", "misc:allow_session_lock_restore", "1"]);
            }
            Quickshell.execDetached(["loginctl", "unlock-session"]);

            // Dynamic exit delay: clockwork themes with windup animation
            // need a longer delay so the reveal animation completes.
            let delay = 100;
            if (activeTheme.includes("clockwork") && sddmShim.config.enableWindup === "true") {
                delay = 500;
            }
            quitTimer.interval = delay;
            quitTimer.start()
        }
    }

    Timer {
        id: quitTimer
        interval: 3000
        onTriggered: {
            shellRoot.sessionLocked = false
            Qt.quit()
        }
    }

    // ── theme loader ────────────────────────────────────────────────────────
    // Loads the selected theme's Main.qml into a fullscreen surface.
    Component {
        id: themeComponent
        Loader {
            anchors.fill: parent
            source: "file://" + shellRoot.themePath + "/Main.qml"
            onLoaded: { item.forceActiveFocus() }
            onStatusChanged: {
                if (status === Loader.Error) {
                    console.error("FAILED to load theme:", source)
                }
            }
        }
    }

    // ── Wayland session lock ────────────────────────────────────────────────
    // Uses Quickshell's WlSessionLock to cover all outputs with a secure
    // surface. The lock is confirmed (secure=true) once the compositor
    // acknowledges every output is covered.
    Loader {
        id: waylandLoader
        active: shellRoot.isWayland
        sourceComponent: Component {
            WlSessionLock {
                id: lock
                locked: shellRoot.sessionLocked

                // onSecureChanged fires when the compositor confirms the lock.
                // We use this to:
                //   1. Write the qylock.locked marker (so ryoku-shell blocks)
                //   2. Arm the fingerprint sensor (armWhenReady = true)
                // On unlock, we clean up the marker and abort any PAM conversation.
                onSecureChanged: {
                    if (lock.secure) {
                        Quickshell.execDetached(["sh", "-c", "umask 077; : > \"${XDG_RUNTIME_DIR:-/tmp}/qylock.locked\""])
                        sddmShim.armWhenReady = true
                    } else {
                        Quickshell.execDetached(["sh", "-c", "rm -f \"${XDG_RUNTIME_DIR:-/tmp}/qylock.locked\""])
                        sddmShim.armWhenReady = false
                        sddmShim.resetAuth()
                    }
                }

                surface: Component {
                    WlSessionLockSurface {
                        color: "black"

                        // Absorb unhandled gestures (scroll, pinch) so they
                        // don't leak through to the desktop underneath.
                        PinchHandler { target: null }
                        WheelHandler { target: null }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.AllButtons
                            hoverEnabled: true
                            onWheel: (wheel) => { wheel.accepted = true }
                        }

                        Loader {
                            anchors.fill: parent
                            sourceComponent: themeComponent
                        }
                    }
                }
            }
        }
    }

    // ── X11 fallback ────────────────────────────────────────────────────────
    // On X11 sessions, use fullscreen windows instead of WlSessionLock.
    // Each screen gets its own lock window.
    Loader {
        id: x11Loader
        active: !shellRoot.isWayland
        sourceComponent: Component {
            Variants {
                model: Quickshell.screens
                delegate: Window {
                    id: window
                    required property var modelData
                    screen: modelData
                    width: isTesting ? 1280 : screen.width
                    height: isTesting ? 720 : screen.height
                    visible: shellRoot.sessionLocked
                    visibility: isTesting ? Window.Windowed : Window.FullScreen
                    onClosing: (close) => {
                        close.accepted = shellRoot.authenticated || shellRoot.isTesting;
                    }
                    flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint | Qt.MaximizeUsingFullscreenGeometryHint
                    color: "black"
                    Loader {
                        anchors.fill: parent
                        sourceComponent: themeComponent
                    }
                }
            }
        }
    }
}
