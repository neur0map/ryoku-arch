// SddmShim.qml - Quickshell shim for Ryoku in-session lock
//
// Exposes the same API as a real SDDM greeter (login, reboot, powerOff,
// suspend, userModel, sessionModel, keyboard) so themes work unchanged,
// plus fingerprint state properties the theme reads for the sensor hint.
//
// Fingerprint flow:
//   1. lock_shell.qml sets armWhenReady = true once WlSessionLock.secure
//   2. The shim probes fprintd-list + ~/.config/qylock/fingerprint
//   3. Stale fprintd-verify processes are cleared, then a PAM conversation
//      starts against the ryoku-lock service (grosshack pair)
//   4. grosshack forks fprintd-verify at conversation start: the sensor
//      scans while pam_unix waits for a password; first success wins
//   5. A failed scan re-arms after 1s

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Item {
    id: shim

    // ── theme configuration ────────────────────────────────────────────────
    property string themePath: ""
    property var config: ({})
    property bool configReady: false
    property string hostName: "localhost"

    // ── fingerprint unlock state ────────────────────────────────────────────
    // These properties are read at lock start and updated live. The theme
    // binds to sddm.fingerprintHint, sddm.fingerprintReady,
    // sddm.fingerprintState, and sddm.fingerprintUnlock to show the sensor
    // hint and play the reveal flourish.
    property bool fpEnabled: true            // from ~/.config/qylock/fingerprint
    property bool fpHasFingers: false        // fprintd-list reports >= 1 finger
    readonly property bool fingerprintReady: fpEnabled && fpHasFingers
    property string fingerprintState: "idle" // idle | scanning | success | fail
    property bool fingerprintUnlock: false   // true if sensor won (not typed)
    property bool armWhenReady: false        // lock surface is secured, arm now
    property bool armPending: false          // an armPrep run is in flight
    property bool fpTyped: false             // a key was fed to the conversation

    // arm the moment the lock secures; probes alone race and lose it.
    onArmWhenReadyChanged: {
        if (shim.armWhenReady)
            shim.maybeArm();
    }

    // orphaned verifiers hold the sensor claim; clear them before arming.
    Process {
        id: armPrepProc
        command: ["bash", "-c", "pkill -u \"$USER\" -x fprintd-verify 2>/dev/null; sleep 0.2"]
        onExited: () => {
            if (!shim.armPending)
                return;
            shim.armPending = false;
            shim.armFingerprintNow();
        }
    }

    // ── theme config loader ─────────────────────────────────────────────────
    // Parses theme.conf (key=value format) from the theme directory.
    function loadConfig(path) {
        if (!path) {
            config = { background: "bg.png" };
            configReady = true;
            return;
        }
        var url = "file://" + path + "/theme.conf";
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var newConfig = {};
                if ((xhr.status === 200 || xhr.status === 0) && xhr.responseText) {
                    var lines = xhr.responseText.split("\n");
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim();
                        if (line.startsWith("[") || line === "" || line.startsWith("#")) continue;
                        var parts = line.split("=");
                        if (parts.length === 2) {
                            newConfig[parts[0].trim()] = parts[1].trim();
                        }
                    }
                }
                if (!newConfig.background) {
                    newConfig.background = "bg.png";
                }
                config = newConfig;
                configReady = true;
            }
        };
        try {
            xhr.open("GET", url, true);
            xhr.send();
        } catch (e) {
            console.warn("SddmShim: failed to load theme.conf:", e);
            config = { background: "bg.png" };
            configReady = true;
        }
    }

    // ── user model ──────────────────────────────────────────────────────────
    // Single-user model for the lock screen. The real SDDM greeter enumerates
    // all system users; the in-session lock only needs the current user.
    property var userModel: ListModel {
        id: internalUserModel
        property string lastUser: Quickshell.env("USER") || "traveler"
        property int lastIndex: 0
        function rowCount() { return count; }
        function index(row, col) { return row; }
        function data(row, role) {
            var item = get(row);
            if (!item) return "";
            if (role === (Qt.UserRole + 1)) return item.name;
            if (role === (Qt.UserRole + 2)) return item.realName;
            return item.name;
        }
        Component.onCompleted: {
            append({
                name: Quickshell.env("USER") || "traveler",
                realName: Quickshell.env("USER") || "Traveler",
                icon: "",
                homeDir: "/home/" + (Quickshell.env("USER") || "traveler")
            })
        }
    }

    // ── session model ───────────────────────────────────────────────────────
    // Enumerates available desktop sessions from /usr/share/*-sessions/.
    property var sessionModel: ListModel {
        id: internalSessionModel
        property int lastIndex: 0
        function rowCount() { return count; }
        function index(row, col) { return row; }
        function data(row, role) {
            var item = get(row);
            if (!item) return "";
            return item.name;
        }
        Component.onCompleted: {
            append({ name: "Session", file: "" });
        }
    }

    Process {
        id: sessionEnumerator
        command: [
            "bash", "-c",
            "for f in /usr/share/wayland-sessions/*.desktop /usr/share/xsessions/*.desktop; do " +
            "if [ -f \"$f\" ]; then " +
            "NAME=$(grep -m1 '^Name=' \"$f\" | cut -d'=' -f2); " +
            "FILE=$(basename \"$f\"); " +
            "echo \"$NAME|||$FILE\"; " +
            "fi; done"
        ]
        stdout: StdioCollector {
            onStreamFinished: { shim.parseSessions(this.text); }
        }
        onExited: (exitCode, exitStatus) => {
            if (internalSessionModel.count === 0) {
                internalSessionModel.append({ name: "Unknown", file: "unknown.desktop" });
            }
        }
    }

    function parseSessions(output) {
        if (!output || output.trim() === "") {
            internalSessionModel.clear();
            internalSessionModel.append({ name: "Session", file: "unknown.desktop" });
            return;
        }
        internalSessionModel.clear();
        var lines = output.trim().split("\n");
        var currentDesktop = (Quickshell.env("XDG_SESSION_DESKTOP") || Quickshell.env("DESKTOP_SESSION") || "").toLowerCase();
        var bestIndex = 0;
        var added = 0;
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "") continue;
            var parts = line.split("|||");
            if (parts.length === 2 && parts[0] !== "" && parts[1] !== "") {
                internalSessionModel.append({ name: parts[0], file: parts[1] });
                var fileName = parts[1].toLowerCase();
                if (currentDesktop !== "" && (fileName.indexOf(currentDesktop) !== -1 || currentDesktop.indexOf(fileName.replace(".desktop", "")) !== -1)) {
                    bestIndex = added;
                }
                added++;
            }
        }
        if (added === 0) {
            internalSessionModel.append({ name: "Unknown", file: "unknown.desktop" });
        } else {
            internalSessionModel.lastIndex = bestIndex;
        }
    }

    // ── SDDM-compatible interface ───────────────────────────────────────────
    // Themes bind to sddm.login(), sddm.hostName, sddm.loginSucceeded,
    // sddm.loginFailed, etc. Under a real SDDM greeter these are provided by
    // the greeter; under the lock screen this shim provides them.
    property var sddm: QtObject {
        property string hostName: shim.hostName
        signal loginFailed()
        signal loginSucceeded()

        // Fingerprint properties exposed to the theme. Under a real SDDM
        // greeter these are undefined, so theme gates on them evaluate false
        // and the greeter is visually untouched. Under this shim they drive
        // the sensor hint.
        readonly property bool fingerprintHint: true
        property bool fingerprintReady: shim.fingerprintReady
        property string fingerprintState: shim.fingerprintState
        property bool fingerprintUnlock: shim.fingerprintUnlock

        // login() is called by the theme when the user submits a password.
        // If a grosshack conversation is already active (the sensor is live),
        // the typed key is fed into it instead of starting a new conversation.
        function login(user, password, sessionIndex) {
            pam.user = user;
            if (pam.active) {
                // Already inside an armed grosshack conversation: feed this
                // key instead of restarting the scan. The open prompt may
                // already be waiting, so respond immediately; otherwise stash
                // it and onResponseRequiredChanged sends it on arrival.
                if (pam.responseRequired) {
                    shim.fpTyped = true;
                    pam.respond(password);
                    pam.pendingPassword = "";
                } else {
                    pam.pendingPassword = password;
                }
                return;
            }
            shim.fpTyped = false;
            shim.fingerprintState = "idle";
            pam.pendingPassword = password;
            pam.start();
        }

        function reboot() { Quickshell.execDetached(["bash", "-c", "if [ -d /run/systemd/system ]; then systemctl reboot; else loginctl reboot; fi"]); }
        function powerOff() { Quickshell.execDetached(["bash", "-c", "if [ -d /run/systemd/system ]; then systemctl poweroff; else loginctl poweroff; fi"]); }
        function suspend() { Quickshell.execDetached(["bash", "-c", "if [ -d /run/systemd/system ]; then systemctl suspend; else loginctl suspend; fi"]); }
    }

    // SDDM exposes a writable `keyboard` carrying the lock-key state; skins
    // set `keyboard.numLock = true` so the numpad works. Provide it so the
    // assignment resolves instead of raising a ReferenceError.
    property var keyboard: QtObject {
        property bool numLock: false
        property bool capsLock: false
    }

    // ── hostname resolver ───────────────────────────────────────────────────
    // Resolve the real hostname for sddm.hostName; the "localhost" default
    // above keeps the isQuickshell test correct until this returns.
    Process {
        id: hostnameProc
        command: ["cat", "/etc/hostname"]
        stdout: StdioCollector {
            onStreamFinished: {
                var h = this.text.trim();
                if (h !== "") shim.hostName = h;
            }
        }
    }

    // ── fingerprint readiness probes ────────────────────────────────────────
    // Two independent probes determine if the sensor is available:
    //   1. fpToggleProc reads ~/.config/qylock/fingerprint (the Settings toggle)
    //   2. fpListProc runs fprintd-list to check for enrolled fingers
    // Both call maybeArm() when done, which starts the PAM conversation if
    // all conditions are met.

    // Read the Settings toggle (missing file = enabled).
    Process {
        id: fpToggleProc
        command: [
            "bash", "-c",
            "if [ -f \"$HOME/.config/qylock/fingerprint\" ]; then cat \"$HOME/.config/qylock/fingerprint\"; else printf 'on'; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = this.text.trim().toLowerCase();
                shim.fpEnabled = !(v === "off" || v === "0" || v === "false");
                shim.maybeArm();
            }
        }
    }

    // Probe enrolled fingers; the lock only offers the sensor when this user
    // actually has one stored. fprintd itself is D-Bus activated, so right at
    // lock time the daemon (and the device) may not be up yet -- a failed or
       // finger-less probe is retried a few times while the lock is held.
    Process {
        id: fpListProc
        command: ["fprintd-list", Quickshell.env("USER") || "traveler"]
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = this.text || "";
                var hasDev = txt.indexOf("Using device") !== -1 || txt.indexOf("Device at") !== -1 || txt.indexOf("found ") !== -1;
                var n = 0;
                var lines = txt.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].trim().indexOf("- #") === 0)
                        n++;
                }
                shim.fpHasFingers = hasDev && n > 0;
                shim.maybeArm();
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                shim.fpHasFingers = false;
                shim.maybeArm();
            }
            listRetry.restart();
        }
    }

    // bounded re-probe: three tries, two and a half seconds apart, only while
    // the lock is actually held and we still have no fingers on record.
    Timer {
        id: listRetry
        interval: 2500
        property int tries: 0
        onTriggered: {
            if (shim.fpHasFingers || !shim.armWhenReady || tries >= 3)
                return;
            tries++;
            fpListProc.running = true;
        }
    }

    // ── PAM conversation ────────────────────────────────────────────────────
    // The core of the fingerprint unlock: a single PamContext using the
    // ryoku-lock PAM service. This service contains the grosshack pair:
    //   - pam_fprintd_grosshack.so forks fprintd-verify at conversation start
    //   - pam_unix.so waits for a typed password
    //   - Either success unlocks within the SAME conversation
    //
    // The config is a relative path ("ryoku-lock"), resolved against
    // configDirectory which points to <lock_dir>/assets/pam/. This means
    // no root edit of /etc/pam.d is needed -- the PAM service ships with
    // the lock screen itself.
    PamContext {
        id: pam
        property string pendingPassword: ""

        config: "ryoku-lock"
        configDirectory: Quickshell.shellDir + "/assets/pam"

        // When PAM asks for a password (the pam_unix prompt), feed it the
        // stashed password if we have one, or mark it as required so the
        // theme's login() handler sends it on the next keypress.
        onResponseRequiredChanged: {
            if (responseRequired && pendingPassword !== "") {
                shim.fpTyped = true;
                respond(pendingPassword);
                pendingPassword = "";
            }
        }

        // PAM conversation completed. Success = unlock; failure = re-arm.
        onCompleted: (result) => {
            if (result === PamResult.Success) {
                // A scan that ended without a typed key means the sensor won.
                shim.fingerprintUnlock = (shim.fingerprintState === "scanning" && !shim.fpTyped);
                shim.fingerprintState = "success";
                shim.sddm.loginSucceeded();
                Quickshell.execDetached(["loginctl", "unlock-session"]);
            } else {
                shim.fingerprintState = "fail";
                shim.fpTyped = false;
                shim.sddm.loginFailed();
                // Conversation is over; re-arm so the next touch scans again.
                rearmTimer.restart();
            }
        }

        // A conversation can also die without completing -- config missing,
        // internal PAM error, subprocess killed. Left unhandled, the theme
        // would keep claiming the sensor is listening while no scan exists.
        onError: (error) => {
            if (!shim.armWhenReady)
                return;
            shim.fingerprintState = "fail";
            shim.fpTyped = false;
            rearmTimer.restart();
        }
    }

    // settle before rescanning so the old verifier releases the claim.
    Timer {
        id: rearmTimer
        interval: 1000
        onTriggered: {
            if (!shim.armWhenReady || pam.active)
                return;
            if (shim.fingerprintReady)
                shim.armFingerprint();
        }
    }

    // ── fingerprint control functions ───────────────────────────────────────

    function armFingerprint() {
        if (!shim.fingerprintReady || pam.active || shim.armPending)
            return;
        shim.armPending = true;
        armPrepProc.running = true;
    }

    function armFingerprintNow() {
        if (!shim.fingerprintReady || pam.active)
            return;
        pam.user = Quickshell.env("USER") || "traveler";
        pam.pendingPassword = "";
        shim.fpTyped = false;
        shim.fingerprintUnlock = false;
        shim.fingerprintState = "scanning";
        // start() returns false when the config dir/file or user cannot be
        // resolved; surface that instead of failing silently.
        var started = pam.start();
        if (!started)
            console.warn("[fp] pam.start() failed: config=", pam.config,
                "dir=", pam.configDirectory, "user=", pam.user);
    }

    // resetAuth: aborts any active PAM conversation and resets state.
    // Called when the lock surface is unlocked.
    function resetAuth() {
        shim.fingerprintUnlock = false;
        shim.fpTyped = false;
        pam.abort();
        if (shim.fingerprintState !== "idle")
            shim.fingerprintState = "idle";
    }

    function maybeArm() {
        if (shim.armWhenReady && shim.fingerprintReady && !pam.active)
            shim.armFingerprint();
    }

    // ── initialization ──────────────────────────────────────────────────────
    onThemePathChanged: loadConfig(themePath)
    Component.onCompleted: {
        sessionEnumerator.running = true;
        hostnameProc.running = true;
        fpToggleProc.running = true;
        fpListProc.running = true;
    }
}
