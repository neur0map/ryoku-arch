pragma Singleton

import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

/*
 * Ryoku shell update checker service.
 * Periodically checks the git repo for new commits and exposes
 * update state to UI widgets. Separate from system Updates service.
 *
 * NOTE: The config directory (~/.config/quickshell/ii) is NOT a git repo.
 * Users clone the repo elsewhere, run ./setup install, which copies files.
 * The actual repo location is stored in version.json during installation.
 */
Singleton {
    IpcHandler {
        target: "shellUpdate"
        function toggle(): void { root.overlayOpen ? root.closeOverlay() : root.openOverlay() }
        function open(): void { root.openOverlay() }
        function close(): void { root.closeOverlay() }
        function check(): void { root.check() }
        function refresh(): void { root.refresh() }
        function performUpdate(): void { root.performUpdate() }
        function dismiss(): void { root.dismiss() }
        function undismiss(): void { root.undismiss() }
        function diagnose(): string { return root.getDiagnostics() }
    }
    id: root

    // Public state
    property bool hasUpdate: false
    property int commitsBehind: 0
    property string latestMessage: ""
    property string localCommit: ""
    property string remoteCommit: ""
    property string currentBranch: "main"  // Current git branch
    property string _remoteBranch: "main"  // Resolved remote branch (may differ from currentBranch if not pushed)
    readonly property bool isNonMainBranch: currentBranch.length > 0 && currentBranch !== "main" && currentBranch !== "master"
    property bool isChecking: false
    property bool isUpdating: false
    property string lastError: ""
    property bool available: false  // git is available and repo exists

    // Update progress tracking (populated from status file markers)
    property int updateStep: 0           // Current step (1-based, 0 = not started / unknown)
    property int updateTotalSteps: 0     // Total steps reported by setup
    property string updateStepMessage: "" // Human-readable step label
    property string _lastWatchdogStatus: "" // Staleness detection for watchdog

    function clearUpdateProgressUi(): void {
        updateProgressPoller.running = false
        updateWatchdog.stop()
        root.isUpdating = false
        root.updateStep = 0
        root.updateTotalSteps = 0
        root.updateStepMessage = ""
        root._lastWatchdogStatus = ""
    }

    // Notification tracking (prevent spam)
    property bool initialAvailabilityChecked: false
    property bool initialUpdateCheckDone: false
    property bool unavailableNotificationShown: false
    property int consecutiveFetchErrors: 0
    property bool fetchErrorNotificationShown: false

    // Overlay state
    property bool overlayOpen: false
    property bool isFetchingDetails: false
    property string commitLog: ""         // Full git log HEAD..origin/branch
    property string remoteChangelog: ""   // CHANGELOG.md from remote branch
    property string remoteVersion: ""     // VERSION from remote branch
    property string localVersion: ""      // Current local VERSION
    property var localModifications: []   // Files user modified vs manifest

    // Current system info (always available after first check)
    property string installedCommit: ""   // Commit hash from manifest
    property string installedDate: ""     // Install/update date from manifest
    property string recentLocalLog: ""    // Recent local commit history
    property int _openOverlayDelayMs: 0

    // Derived
    readonly property bool enabled: Config.options?.shellUpdates?.enabled ?? true
    readonly property int checkIntervalMs: (Config.options?.shellUpdates?.checkIntervalMinutes ?? 360) * 60 * 1000
    readonly property string dismissedCommit: Config.options?.shellUpdates?.dismissedCommit ?? ""
    readonly property string lastNotifiedCommit: Config.options?.shellUpdates?.lastNotifiedCommit ?? ""
    readonly property bool showUpdate: hasUpdate && !isDismissed && !isUpdating
    readonly property bool isDismissed: dismissedCommit.length > 0 && remoteCommit === dismissedCommit
    readonly property string releaseBranch: "main"
    readonly property string updateRemoteUrl: Quickshell.env("RYOKU_UPDATE_REMOTE_URL") || "https://github.com/neur0map/ryoku-arch.git"

    // Repo path - try to get from version.json, fallback to config dir
    readonly property string configDir: FileUtils.trimFileProtocol(Quickshell.shellPath("."))
    property string repoPath: configDir  // Will be updated after reading version.json
    property string pendingRepoPath: ""
    property bool repoPathLoaded: false
    readonly property string manifestPath: configDir + "/.ryoku-manifest"
    property string installMode: "unknown"
    property string updateStrategy: "unknown"
    property string installSource: "unknown"
    readonly property bool managedExternally: updateStrategy === "package-manager"
    readonly property bool selfUpdateSupported: updateStrategy === "repo-setup"
    readonly property string unavailableTitle: managedExternally
        ? "Updates Managed Externally"
        : "Updates Unavailable"
    readonly property string unavailableMessage: managedExternally
        ? "This Ryoku installation is managed outside the runtime copy. Use your package manager or installation workflow to update it."
        : "Repository not found. The update system cannot locate the Ryoku git repository."
    readonly property string unavailableHint: managedExternally
        ? "Runtime diagnostics are still available, but in-shell self-update is disabled for this installation mode."
        : "Run './setup doctor' in your terminal to diagnose the issue, or use the diagnose command below."

    // Handler: notify when availability changes to false (after initial check)
    onAvailableChanged: {
        if (initialAvailabilityChecked && !available && !unavailableNotificationShown && !managedExternally) {
            unavailableNotificationShown = true
            Notifications.notify({
                summary: root.unavailableTitle,
                body: root.unavailableHint,
                urgency: NotificationUrgency.Normal,
                timeout: 10000,
                appName: "Ryoku Shell"
            })
            print("[ShellUpdates] Notification sent: Updates unavailable")
        }
        // Reset notification flag when available becomes true again
        if (available) {
            unavailableNotificationShown = false
        }
    }

    // Handler: notify when a new update is detected
    onHasUpdateChanged: {
        if (!hasUpdate || !available || !initialUpdateCheckDone || isDismissed) return
        if (remoteCommit.length === 0 || remoteCommit === lastNotifiedCommit) return

        const version = root.remoteVersion.length > 0 ? (" v" + root.remoteVersion) : ""
        const commits = root.commitsBehind > 0 ? (root.commitsBehind + " commits behind") : "New version available"
        Notifications.notify({
            summary: "Ryoku Update Available" + version,
            body: commits + ". Click the update indicator in the bar or open Settings → Services.",
            urgency: NotificationUrgency.Normal,
            timeout: 15000,
            appName: "Ryoku Shell"
        })
        Config.setNestedValue("shellUpdates.lastNotifiedCommit", remoteCommit)
        print("[ShellUpdates] Notification sent: Update available" + version)
    }

    function check(): void {
        if (!enabled || isChecking || isUpdating || managedExternally) return
        root.isChecking = true
        root.lastError = ""
        root.latestMessage = ""
        normalizeRemoteProc.running = true
    }

    // Force a fresh check + reload the incoming commits list. Used by the
    // overlay's manual refresh button so users don't have to wait for the
    // periodic timer when they're staring at the dialog and want to see
    // commits that landed after it opened.
    property bool _refreshDetailsPending: false
    function refresh(): void {
        if (isUpdating || managedExternally) return
        root._refreshDetailsPending = true
        if (!isChecking) {
            root.check()
        }
    }
    onIsCheckingChanged: {
        if (!isChecking && root._refreshDetailsPending) {
            root._refreshDetailsPending = false
            if (!isFetchingDetails) {
                root.fetchDetails()
            }
        }
    }

    // Fetch detailed info for the overlay (commit log, changelog, local mods)
    function fetchDetails(): void {
        if (isFetchingDetails || managedExternally) return
        root.isFetchingDetails = true
        root.commitLog = ""
        root.remoteChangelog = ""
        root.remoteVersion = ""
        root.localVersion = ""
        root.localModifications = []
        commitLogProc.running = true
    }

    function openOverlay(): void {
        const panels = Config.options?.enabledPanels ?? []
        if (!panels.includes("iiShellUpdate")) {
            Config.setNestedValue("enabledPanels", [...panels, "iiShellUpdate"])
        }
        const panelWasOpen = GlobalStates.controlPanelOpen
        const settingsWasOpen = GlobalStates.settingsOverlayOpen ?? false
        GlobalStates.controlPanelOpen = false
        GlobalStates.settingsOverlayOpen = false
        // Always use a minimum delay to ensure other overlays fully close
        // and release keyboard focus before we open
        root._openOverlayDelayMs = (panelWasOpen || settingsWasOpen) ? 600 : 150
        openOverlayTimer.restart()
    }

    Timer {
        id: openOverlayTimer
        interval: root._openOverlayDelayMs
        repeat: false
        onTriggered: {
            root.overlayOpen = true
            root.fetchDetails()
        }
    }

    function closeOverlay(): void {
        root.overlayOpen = false
    }

    function performUpdate(): void {
        if (isUpdating || !hasUpdate || !available || managedExternally) return
        root.isUpdating = true
        root.lastError = ""
        root.updateStep = 0
        root.updateTotalSteps = 0
        root.updateStepMessage = ""
        root._lastWatchdogStatus = ""
        root.overlayOpen = false
        Config.setNestedValue("shellUpdates.dismissedCommit", "")

        const logPath = Directories.updateLogPath
        const statusPath = Directories.updateStatusPath
        const repoDir = root.repoPath
        const useTerminal = Config.options?.shellUpdates?.openTerminalOnUpdate ?? true

        // Prefer the system-wide `ryoku-update` (pacman + AUR + migrations + shell)
        // when available; fall back to shell-only `./setup update` for dev checkouts.
        // Terminal mode pipes through tee; detached mode redirects to log file only.
        const runner =
            "if command -v ryoku-update >/dev/null 2>&1; then " +
            "  ryoku-update -y; " +
            "elif [[ -x ./setup ]]; then " +
            "  ./setup -y update; " +
            "elif [[ -x ./shell/setup ]]; then " +
            "  (cd shell && ./setup -y update); " +
            "else " +
            "  echo 'No update entry point found (ryoku-update or ./setup)' >&2; exit 127; " +
            "fi"
        const teeCmd = useTerminal
            ? runner + " 2>&1 | tee '" + logPath + "'; rc=${PIPESTATUS[0]}"
            : runner + " > '" + logPath + "' 2>&1; rc=$?"
        const termTail =
            "echo; " +
            "if [ $rc -eq 0 ]; then " +
                "echo 'success' > '" + statusPath + "'; " +
                "echo 'All good — Ryoku updated successfully. The shell will restart on its own.'; " +
                "echo 'You can close this window whenever you want.'; " +
            "else " +
                "echo \"failed:$rc\" > '" + statusPath + "'; " +
                "echo \"Something went wrong (exit $rc). Check the output above for details.\"; " +
                "echo 'You can close this window whenever you want.'; " +
            "fi; " +
            "read -r _"
        const detachedTail =
            "if [ $rc -ne 0 ]; then " +
            "  echo \"failed:$rc\" > '" + statusPath + "'; " +
            "else " +
            "  echo 'success' > '" + statusPath + "'; " +
            "fi"
        const tail = useTerminal ? termTail : detachedTail
        const bashCmd = "echo 'updating' > '" + statusPath + "'; " +
            "cd '" + repoDir + "' && " + teeCmd + "; " + tail

        if (useTerminal) {
            // First token of the configured terminal command (e.g. "kitty -1" -> "kitty").
            // Most supported terminals (foot, kitty, ghostty, alacritty, wezterm, konsole)
            // accept '-e' for "execute this command". WezTerm accepts it via its compat layer.
            const termSlot = (AppLauncher && typeof AppLauncher.commandFor === "function")
                ? AppLauncher.commandFor("terminal") : ""
            const termBin = (termSlot.length > 0 ? termSlot : "kitty").trim().split(/\s+/)[0]
            Quickshell.execDetached([termBin, "-e", "/usr/bin/bash", "-c", bashCmd])
            print("[ShellUpdates] Update launched in terminal (" + termBin + ") from: " + repoDir)
        } else {
            // Detached background — same path as before the terminal toggle existed.
            Quickshell.execDetached(["/usr/bin/bash", "-c", bashCmd])
            print("[ShellUpdates] Update launched (detached) from: " + repoDir)
        }
        print("[ShellUpdates] Log: " + logPath + " | Status: " + statusPath)
        // Start watchdog — if shell hasn't restarted after timeout, check status file
        updateWatchdog.restart()
        // Start progress poller — reads status file every 2s for live progress
        updateProgressPoller.restart()
    }

    function dismiss(): void {
        if (remoteCommit.length > 0) {
            Config.setNestedValue("shellUpdates.dismissedCommit", remoteCommit)
        }
        root.overlayOpen = false
    }

    function undismiss(): void {
        Config.setNestedValue("shellUpdates.dismissedCommit", "")
    }

    function getDiagnostics(): string {
        const diag = {
            available: root.available,
            repoPath: root.repoPath,
            repoPathLoaded: root.repoPathLoaded,
            configDir: root.configDir,
            versionJsonPath: Directories.shellConfig + "/version.json",
            installMode: root.installMode,
            updateStrategy: root.updateStrategy,
            installSource: root.installSource,
            selfUpdateSupported: root.selfUpdateSupported,
            gitAvailable: root.available,
            lastError: root.lastError,
            consecutiveFetchErrors: root.consecutiveFetchErrors,
            hasUpdate: root.hasUpdate,
            commitsBehind: root.commitsBehind,
            localCommit: root.localCommit,
            remoteCommit: root.remoteCommit,
            currentBranch: root.currentBranch,
            localVersion: root.localVersion,
            remoteVersion: root.remoteVersion,
            overlayOpen: root.overlayOpen,
            isFetchingDetails: root.isFetchingDetails
        }
        return JSON.stringify(diag, null, 2)
    }

    // Initial check after startup delay
    Timer {
        id: startupDelay
        interval: 5000  // 5s after shell starts (quick first check)
        repeat: false
        running: root.enabled && Config.ready
        onTriggered: {
            print("[ShellUpdates] Loading repo path from version.json...")
            loadRepoPathProc.running = true
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Resume update display after shell restart
    // ─────────────────────────────────────────────────────────────────────────
    // `setup update` triggers `systemctl --user restart ryoku-shell.service` as its
    // last step, killing the shell mid-flow. The new shell instance must
    // detect the prior state from the status file and either clean up
    // (if the final step was reached) or resume polling so the bar indicator
    // and overlay don't go silent while the update keeps running underneath.
    Timer {
        id: resumeUpdateCheck
        interval: 1000  // 1s — get the indicator back up fast
        repeat: false
        running: true
        onTriggered: updateResumeReader.running = true
    }

    Process {
        id: updateResumeReader
        running: false
        command: ["/usr/bin/bash", "-c", `
            status_file="$1"
            if [ ! -f "$status_file" ]; then exit 1; fi

            now=$(/usr/bin/date +%s)
            if read -r uptime _ < /proc/uptime; then
                uptime_s=$(/usr/bin/printf '%s\n' "$uptime" | /usr/bin/cut -d. -f1)
            else
                uptime_s=0
            fi
            boot_epoch=$((now - uptime_s))
            mtime=$(/usr/bin/stat -c %Y "$status_file" 2>/dev/null || echo 0)

            if [ "$mtime" -lt "$boot_epoch" ]; then
                echo "stale"
            else
                /usr/bin/cat "$status_file"
            fi
        `, "_", Directories.updateStatusPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const status = (text ?? "").trim()
                if (status.length === 0) return

                if (status === "stale") {
                    print("[ShellUpdates] Clearing stale update-status from previous boot")
                    clearStatusFileProc.running = true
                    return
                }

                if (status === "success") {
                    // Previous update finished cleanly — clear stale marker
                    clearStatusFileProc.running = true
                    return
                }

                if (status.startsWith("failed")) {
                    const code = status.split(":")[1] || "unknown"
                    root.lastError = "Last update failed (exit " + code + "). Check " + Directories.updateLogPath + " for details."
                    print("[ShellUpdates] Detected failed update from previous shell: exit " + code)
                    clearStatusFileProc.running = true
                    return
                }

                if (status.startsWith("progress:")) {
                    const parts = status.split(":")
                    const step = parts.length > 1 ? (parseInt(parts[1]) || 0) : 0
                    const total = parts.length > 2 ? (parseInt(parts[2]) || 0) : 0
                    const msg = parts.length > 3 ? parts.slice(3).join(":") : ""

                    // Final step reached — the restart we just survived was
                    // the last action. Mark complete and clear.
                    if (total > 0 && step >= total) {
                        print("[ShellUpdates] Resume detected final step (" + step + "/" + total + "), assuming complete: " + msg)
                        clearStatusFileProc.running = true
                        return
                    }

                    // Mid-flight update — restore visible state and keep polling
                    root.updateStep = step
                    root.updateTotalSteps = total
                    root.updateStepMessage = msg
                    root._lastWatchdogStatus = status
                    root.isUpdating = true
                    updateProgressPoller.restart()
                    updateWatchdog.restart()
                    print("[ShellUpdates] Resuming in-flight update display: " + status)
                    return
                }

                if (status === "updating") {
                    // Initial marker, no granular progress yet
                    root.isUpdating = true
                    updateProgressPoller.restart()
                    updateWatchdog.restart()
                    print("[ShellUpdates] Resuming update display (no granular progress yet)")
                    return
                }

                print("[ShellUpdates] Unknown status file content on resume: '" + status + "'")
            }
        }
    }

    Process {
        id: clearStatusFileProc
        running: false
        command: ["rm", "-f", Directories.updateStatusPath]
    }

    // Load repo path from version.json (stored in shellConfig dir, NOT in quickshell config dir)
    Process {
        id: loadRepoPathProc
        property bool _handledFallback: false
        running: false
        onRunningChanged: if (running) _handledFallback = false
        command: ["cat", Directories.shellConfig + "/version.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const json = JSON.parse(text ?? "{}")
                    // Extract version from version.json (always available even if VERSION file missing)
                    if (json.version && json.version !== "0.0.0") {
                        root.localVersion = json.version
                    }
                    const storedInstallMode = json.installMode ?? json.install_mode ?? ""
                    const storedUpdateStrategy = json.updateStrategy ?? json.update_strategy ?? ""
                    const storedSource = json.installSource ?? json.install_source ?? json.source ?? ""
                    if (storedInstallMode.length > 0) {
                        root.installMode = storedInstallMode
                    }
                    if (storedUpdateStrategy.length > 0) {
                        root.updateStrategy = storedUpdateStrategy
                    }
                    if (storedSource.length > 0) {
                        root.installSource = storedSource
                    }
                    const storedRepoPath = json.repoPath ?? json.repo_path ?? ""
                    if (storedRepoPath.length > 0 && root.installMode === "unknown") {
                        root.installMode = "repo-copy"
                    }
                    if (storedRepoPath.length > 0 && root.updateStrategy === "unknown") {
                        root.updateStrategy = "repo-setup"
                    }
                    if (root.managedExternally) {
                        root.repoPathLoaded = true
                        root.initialAvailabilityChecked = true
                        root.initialUpdateCheckDone = true
                        root.available = false
                        print("[ShellUpdates] Update strategy is managed externally: " + root.updateStrategy)
                        return
                    }
                    if (storedRepoPath.length > 0) {
                        root.pendingRepoPath = storedRepoPath
                        preferConfigRepoProc.running = true
                        return
                    }
                } catch (e) {
                    print("[ShellUpdates] Failed to parse version.json: " + e)
                }
                // No repo_path in version.json, try to find it
                print("[ShellUpdates] No repo_path in version.json, searching for repository...")
                loadRepoPathProc._handledFallback = true
                searchRepoProc.running = true
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && !_handledFallback) {
                print("[ShellUpdates] version.json not found, searching for repository...")
                searchRepoProc.running = true
            }
        }
    }

    // Repo signature for ryoku-arch: .git + (legacy shell shape OR ryoku-arch shape).
    // Exposed as a bash function so all probes share one definition.
    readonly property string _repoSignatureFn:
        "ryoku_repo_match() { " +
        "  local p=\"$1\"; " +
        "  [[ -d \"$p/.git\" ]] || return 1; " +
        "  [[ -f \"$p/setup\" && -f \"$p/shell.qml\" ]] && return 0; " +
        "  [[ -f \"$p/install/ryoku-base.packages\" ]] && return 0; " +
        "  [[ -f \"$p/shell/setup\" && -f \"$p/shell/shell.qml\" ]] && return 0; " +
        "  return 1; " +
        "}; "

    Process {
        id: preferConfigRepoProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            root._repoSignatureFn +
            "p='" + root.configDir + "'; ryoku_repo_match \"$p\" && echo OK || echo ''"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = ((text ?? "").trim() === "OK")
                if (ok) {
                    root.repoPath = root.configDir
                    root.installMode = "repo-link"
                    root.updateStrategy = "repo-setup"
                    root.repoPathLoaded = true
                    print("[ShellUpdates] Using active config checkout as repo path: " + root.repoPath)
                    persistRepoPathProc.running = true
                    availabilityProc.running = true
                } else if (root.pendingRepoPath.length > 0) {
                    root.repoPath = root.pendingRepoPath
                    root.pendingRepoPath = ""
                    print("[ShellUpdates] Using repo path from version.json: " + root.repoPath)
                    root.repoPathLoaded = true
                    validateRepoPathProc.running = true
                } else {
                    searchRepoProc.running = true
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                if (root.pendingRepoPath.length > 0) {
                    root.repoPath = root.pendingRepoPath
                    root.pendingRepoPath = ""
                    root.repoPathLoaded = true
                    validateRepoPathProc.running = true
                } else {
                    searchRepoProc.running = true
                }
            }
        }
    }

    Process {
        id: validateRepoPathProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            root._repoSignatureFn +
            "p='" + root.repoPath + "'; ryoku_repo_match \"$p\" && echo OK || echo ''"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = ((text ?? "").trim() === "OK")
                if (ok) {
                    availabilityProc.running = true
                } else {
                    print("[ShellUpdates] repo_path from version.json is invalid, searching for repository...")
                    searchRepoProc.running = true
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                print("[ShellUpdates] Failed to validate repo_path, searching for repository...")
                searchRepoProc.running = true
            }
        }
    }

    // Search for repository — check config dir, RYOKU_PATH, then candidate dirs
    Process {
        id: searchRepoProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            root._repoSignatureFn +
            // 1. Active config checkout (dev: shell layer is itself a git repo)
            "if ryoku_repo_match \"" + root.configDir + "\"; then echo \"" + root.configDir + "\"; exit 0; fi; " +
            // 2. RYOKU_PATH env (set by lib/runtime-env.sh in ryoku-* tools)
            "if [[ -n \"${RYOKU_PATH:-}\" ]] && ryoku_repo_match \"$RYOKU_PATH\"; then echo \"$RYOKU_PATH\"; exit 0; fi; " +
            // 3. Canonical install + common dev/legacy locations
            "for dir in " +
            "  ~/.local/share/ryoku ~/.local/share/omarchy " +
            "  ~/prowl/ryoku-arch ~/ryoku-arch ~/Ryoku ~/illogical-impulse " +
            "  ~/.local/src/ryoku-arch ~/.local/src/illogical-impulse " +
            "  ~/Projects/ryoku-arch ~/Projects/illogical-impulse " +
            "  ~/Downloads/ryoku-arch ~/Downloads/illogical-impulse " +
            "  ~/src/ryoku-arch ~/src/illogical-impulse; do " +
            "  if ryoku_repo_match \"$dir\"; then echo \"$dir\"; exit 0; fi; " +
            "done; " +
            // 4. Last resort: shallow find under $HOME for either repo shape
            "timeout 2 find \"$HOME\" -maxdepth 4 -type d -name .git 2>/dev/null | while read -r g; do " +
            "  d=\"$(dirname \"$g\")\"; ryoku_repo_match \"$d\" && echo \"$d\" && break; " +
            "done; "
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const foundPath = (text ?? "").trim()
                if (foundPath.length > 0) {
                    root.repoPath = foundPath
                    if (root.installMode === "unknown") {
                        root.installMode = foundPath === root.configDir ? "repo-link" : "repo-copy"
                    }
                    if (root.updateStrategy === "unknown") {
                        root.updateStrategy = "repo-setup"
                    }
                    print("[ShellUpdates] Found repository at: " + root.repoPath)
                    // Persist found path to version.json to avoid repeated searches
                    persistRepoPathProc.running = true
                } else {
                    print("[ShellUpdates] Repository not found, using config dir: " + root.configDir)
                    print("[ShellUpdates] Update feature will not be available")
                }
                root.repoPathLoaded = true
            }
        }
        onExited: (exitCode, exitStatus) => {
            // Now check git availability
            availabilityProc.running = true
        }
    }

    // Persist found repo path to version.json
    Process {
        id: persistRepoPathProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "vfile='" + Directories.shellConfig + "/version.json'; " +
            "if [[ -s \"$vfile\" ]] && command -v jq &>/dev/null; then " +
            "  tmp=$(mktemp); " +
            "  jq --arg p '" + root.repoPath + "' --arg m '" + root.installMode + "' --arg u '" + root.updateStrategy + "' '.repo_path = $p | .repoPath = $p | .install_mode = $m | .installMode = $m | .update_strategy = $u | .updateStrategy = $u' \"$vfile\" > \"$tmp\" && mv \"$tmp\" \"$vfile\" && " +
            "  echo 'Updated'; " +
            "elif command -v python3 &>/dev/null; then " +
            "  tmp=$(mktemp); " +
            "  python3 -c 'import json,sys; path=sys.argv[1]; repo=sys.argv[2]; " +
            "\ntry: data=json.load(open(path,\"r\",encoding=\"utf-8\"))" +
            "\nexcept Exception: data={}" +
            "\ndata[\"repo_path\"]=repo" +
            "\ndata[\"repoPath\"]=repo" +
            "\ndata[\"install_mode\"]=sys.argv[3]" +
            "\ndata[\"installMode\"]=sys.argv[3]" +
            "\ndata[\"update_strategy\"]=sys.argv[4]" +
            "\ndata[\"updateStrategy\"]=sys.argv[4]" +
            "\njson.dump(data, sys.stdout, ensure_ascii=False, indent=2)' \"$vfile\" '" + root.repoPath + "' '" + root.installMode + "' '" + root.updateStrategy + "' > \"$tmp\" " +
            "    && mv \"$tmp\" \"$vfile\" && echo 'Updated' || echo 'Skipped'; " +
            "else " +
            "  echo 'Skipped'; " +
            "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = (text ?? "").trim()
                if (result === "Updated") {
                    print("[ShellUpdates] Persisted repo_path to version.json: " + root.repoPath)
                }
            }
        }
    }

    // Periodic check
    Timer {
        id: periodicCheck
        interval: root.checkIntervalMs
        repeat: true
        running: root.enabled && root.available && Config.ready
        onTriggered: root.check()
    }

    // Also check when config becomes ready (session restore)
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready && root.enabled) {
                startupDelay.restart()
            }
        }
    }

    // Lightweight git command prefix — disables LFS filter and auto-gc to prevent
    // CPU spikes from global git-lfs config on repos with zero LFS objects.
    readonly property var _gitCmd: [
        "git",
        "-c", "filter.lfs.process=",
        "-c", "filter.lfs.required=false",
        "-c", "filter.lfs.smudge=",
        "-c", "filter.lfs.clean=",
        "-c", "gc.auto=0",
        "-C", root.repoPath
    ]
    readonly property var _gitEnv: ({
        GIT_TERMINAL_PROMPT: "0",
        GIT_ASKPASS: "/bin/true"
    })

    // Step 1: Check if git is available
    Process {
        id: availabilityProc
        running: false
        command: [...root._gitCmd, "rev-parse", "--git-dir"]
        onExited: (exitCode, exitStatus) => {
            if (root.managedExternally) {
                root.available = false
                root.initialAvailabilityChecked = true
                root.initialUpdateCheckDone = true
                return
            }
            root.available = (exitCode === 0)
            root.initialAvailabilityChecked = true
            print("[ShellUpdates] Git available: " + root.available)
            if (root.available) {
                // Load system info (manifest + local log) before checking for updates
                manifestInfoProc.running = true
            }
        }
    }

    // Step 1b: Parse manifest for installed commit and date
    Process {
        id: manifestInfoProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "manifest='" + root.manifestPath + "'; " +
            "[[ -f \"$manifest\" ]] || exit 1; " +
            "head -3 \"$manifest\" | grep -E '^# (generated|commit):' | sed 's/^# //'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = (text ?? "").trim().split("\n")
                for (const line of lines) {
                    if (line.startsWith("generated: ")) {
                        root.installedDate = line.substring(11).trim()
                    } else if (line.startsWith("commit: ")) {
                        root.installedCommit = line.substring(8).trim()
                    }
                }
                print("[ShellUpdates] Manifest: commit=" + root.installedCommit + " date=" + root.installedDate)
            }
        }
        onExited: (exitCode, exitStatus) => {
            recentLocalLogProc.running = true
        }
    }

    // Step 1c: Get recent local commit history (last 15 commits)
    Process {
        id: recentLocalLogProc
        running: false
        command: [
            ...root._gitCmd, "log",
            "--pretty=format:%h|%s|%cr|%an",
            "-15"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.recentLocalLog = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            // Also read local VERSION on startup
            localVersionStartupProc.running = true
        }
    }

    // Step 1d: Read local VERSION on startup
    // Try repo path first (VERSION is there), fallback to config dir (dev setup)
    Process {
        id: localVersionStartupProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "cat '" + root.repoPath + "/VERSION' 2>/dev/null || cat '" + root.repoPath + "/version' 2>/dev/null || cat '" + root.repoPath + "/shell/VERSION' 2>/dev/null || cat '" + root.configDir + "/VERSION' 2>/dev/null || echo ''"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const ver = (text ?? "").trim()
                // Only override if we got a better version than what version.json gave us
                if (ver.length > 0 && ver !== root.localVersion) {
                    root.localVersion = ver
                }
                print("[ShellUpdates] Local version: " + root.localVersion)
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.check()
        }
    }

    // Normalize ISO-copied checkouts to the public update remote before any
    // network fetch. This prevents fresh installs from inheriting a builder's
    // private or stale origin and prompting for GitHub credentials.
    Process {
        id: normalizeRemoteProc
        running: false
        environment: root._gitEnv
        command: [
            "/usr/bin/bash", "-c",
            "repo=\"$1\"; remote=\"$2\"; " +
            "if git -c filter.lfs.process= -c filter.lfs.required=false -c filter.lfs.smudge= -c filter.lfs.clean= -c gc.auto=0 -C \"$repo\" remote get-url origin >/dev/null 2>&1; then " +
            "  git -c filter.lfs.process= -c filter.lfs.required=false -c filter.lfs.smudge= -c filter.lfs.clean= -c gc.auto=0 -C \"$repo\" remote set-url origin \"$remote\"; " +
            "else " +
            "  git -c filter.lfs.process= -c filter.lfs.required=false -c filter.lfs.smudge= -c filter.lfs.clean= -c gc.auto=0 -C \"$repo\" remote add origin \"$remote\"; " +
            "fi",
            "_",
            root.repoPath,
            root.updateRemoteUrl
        ]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.isChecking = false
                root.consecutiveFetchErrors++
                print("[ShellUpdates] Remote normalization failed (attempt " + root.consecutiveFetchErrors + ")")
                return
            }
            fetchProc.running = true
        }
    }

    // Step 2: Fetch from remote
    Process {
        id: fetchProc
        running: false
        environment: root._gitEnv
        command: [...root._gitCmd, "fetch", "origin", "--quiet", "--no-tags", "--prune", "+refs/heads/main:refs/remotes/origin/main"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.isChecking = false
                root.consecutiveFetchErrors++
                root.lastError = "Cannot fetch Ryoku updates from " + root.updateRemoteUrl
                print("[ShellUpdates] Fetch failed (attempt " + root.consecutiveFetchErrors + ")")

                // Notify after 3 consecutive failures (persistent problem)
                if (root.consecutiveFetchErrors >= 3 && !root.fetchErrorNotificationShown) {
                    root.fetchErrorNotificationShown = true
                    const title = "Ryoku Update Check Failed"
                    const body = "Cannot reach remote repository. Check your internet connection or run './setup doctor'."
                    Notifications.notify({
                        summary: title,
                        body: body,
                        urgency: NotificationUrgency.Low,
                        timeout: 8000,
                        appName: "Ryoku Shell"
                    })
                    print("[ShellUpdates] Notification sent: Persistent fetch errors")
                }
                return
            }
            // Success - reset error counters
            root.consecutiveFetchErrors = 0
            root.fetchErrorNotificationShown = false
            currentBranchProc.running = true
        }
    }

    // Step 3: Get current branch
    Process {
        id: currentBranchProc
        running: false
        command: [...root._gitCmd, "rev-parse", "--abbrev-ref", "HEAD"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentBranch = (text ?? "").trim()
                print("[ShellUpdates] Current branch: " + root.currentBranch)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.isChecking = false
                return
            }
            localCommitProc.running = true
        }
    }

    // Step 4: Get local commit
    Process {
        id: localCommitProc
        running: false
        command: [...root._gitCmd, "rev-parse", "--short", "HEAD"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.localCommit = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.isChecking = false
                return
            }
            remoteCommitProc.running = true
        }
    }

    // Step 5: Get remote commit from the release branch.
    // Fresh ISO/dev installs may still be on a temporary build branch; update
    // checks must follow the shipped Ryoku release stream, not stale branch refs.
    Process {
        id: remoteCommitProc
        running: false
        command: [...root._gitCmd, "rev-parse", "--short", "origin/" + root.releaseBranch]
        stdout: StdioCollector {
            onStreamFinished: {
                root.remoteCommit = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // Try origin/master as last resort for old forks
                remoteCommitFallback2Proc.running = true
                return
            }
            root._remoteBranch = root.releaseBranch
            countCommitsProc.running = true
        }
    }

    // Step 5c: Fallback to origin/master
    Process {
        id: remoteCommitFallback2Proc
        running: false
        command: [...root._gitCmd, "rev-parse", "--short", "origin/master"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.remoteCommit = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.isChecking = false
                return
            }
            root._remoteBranch = "master"
            countCommitsProc.running = true
        }
    }

    // Step 6: Count commits behind
    Process {
        id: countCommitsProc
        running: false
        command: [...root._gitCmd, "rev-list", "--count", "HEAD..origin/" + root._remoteBranch]
        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt((text ?? "0").trim())
                root.commitsBehind = isNaN(count) ? 0 : count
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // Fallback: compare commits directly
                root.hasUpdate = root.localCommit !== root.remoteCommit && root.remoteCommit.length > 0
                root.commitsBehind = root.hasUpdate ? 1 : 0
                root.isChecking = false
                root.initialUpdateCheckDone = true
                return
            }
            root.hasUpdate = root.commitsBehind > 0
            print("[ShellUpdates] Commits behind: " + root.commitsBehind + ", hasUpdate: " + root.hasUpdate)
            if (root.hasUpdate) {
                latestMessageProc.running = true
            } else {
                root.isChecking = false
                root.initialUpdateCheckDone = true
                print("[ShellUpdates] Up to date (" + root.localCommit + ")")
            }
        }
    }

    // Step 7: Get latest commit message from remote
    Process {
        id: latestMessageProc
        running: false
        command: [...root._gitCmd, "log", "--oneline", "-1", "origin/" + root._remoteBranch]
        stdout: StdioCollector {
            onStreamFinished: {
                root.latestMessage = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.isChecking = false
            root.initialUpdateCheckDone = true
        }
    }

    // =========================================================================
    // Detail fetching (on-demand when overlay opens)
    // =========================================================================

    // Detail Step 1: Get commit log between local and remote
    Process {
        id: commitLogProc
        running: false
        command: [
            ...root._gitCmd, "log",
            "--pretty=format:%h|%s|%cr|%an",
            "HEAD..origin/" + root._remoteBranch
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.commitLog = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            remoteVersionProc.running = true
        }
    }

    // Detail Step 2: Get remote VERSION
    Process {
        id: remoteVersionProc
        running: false
        command: [
            ...root._gitCmd, "show",
            "origin/" + root._remoteBranch + ":VERSION"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.remoteVersion = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            localVersionProc.running = true
        }
    }

    // Detail Step 3: Get local VERSION (try repo, then config dir, then version.json)
    Process {
        id: localVersionProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "cat '" + root.repoPath + "/VERSION' 2>/dev/null || cat '" + root.repoPath + "/version' 2>/dev/null || cat '" + root.repoPath + "/shell/VERSION' 2>/dev/null || cat '" + root.configDir + "/VERSION' 2>/dev/null || echo ''"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.localVersion = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            remoteChangelogProc.running = true
        }
    }

    // Detail Step 4: Get remote CHANGELOG.md (first 200 lines)
    Process {
        id: remoteChangelogProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "git -C '" + root.repoPath + "' show 'origin/" + root._remoteBranch + ":CHANGELOG.md' 2>/dev/null | head -200"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.remoteChangelog = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            localModsProc.running = true
        }
    }

    // Detail Step 5: Detect local modifications via manifest checksums
    Process {
        id: localModsProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "manifest='" + root.manifestPath + "'; " +
            "target='" + root.configDir + "'; " +
            "repo='" + root.repoPath + "'; " +
            "[[ -f \"$manifest\" ]] || exit 0; " +
            // Detect ryoku-arch layout — the manifest's paths are relative to
            // the shell runtime, but the source files live under `shell/` in
            // the ryoku-arch repo. Try with that prefix when looking up git
            // content. Skip entries without a checksum AND no resolvable git
            // path: piping an empty `git show` into sha256sum yields a stable
            // non-empty hash, which would falsely flag every such file.
            "git_prefix=''; " +
            "if [[ -d \"$repo/.git\" && -f \"$repo/shell/setup\" ]]; then git_prefix='shell/'; fi; " +
            "while IFS=: read -r path checksum; do " +
            "  [[ \"$path\" =~ ^# ]] && continue; " +
            "  [[ -z \"$path\" ]] && continue; " +
            "  [[ -f \"$target/$path\" ]] || continue; " +
            "  if [[ -n \"$checksum\" ]]; then " +
            "    current=$(sha256sum \"$target/$path\" 2>/dev/null | cut -d' ' -f1); " +
            "    [[ \"$current\" != \"$checksum\" ]] && echo \"$path\"; " +
            "  elif [[ -d \"$repo/.git\" ]]; then " +
            "    resolved=''; " +
            "    if git -C \"$repo\" cat-file -e \"HEAD:${git_prefix}${path}\" 2>/dev/null; then resolved=\"${git_prefix}${path}\"; " +
            "    elif [[ -n \"$git_prefix\" ]] && git -C \"$repo\" cat-file -e \"HEAD:${path}\" 2>/dev/null; then resolved=\"${path}\"; fi; " +
            "    [[ -z \"$resolved\" ]] && continue; " +
            "    repo_hash=$(git -C \"$repo\" show \"HEAD:${resolved}\" 2>/dev/null | sha256sum | cut -d' ' -f1); " +
            "    local_hash=$(sha256sum \"$target/$path\" 2>/dev/null | cut -d' ' -f1); " +
            "    [[ \"$repo_hash\" != \"$local_hash\" ]] && echo \"$path\"; " +
            "  fi; " +
            "done < \"$manifest\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = (text ?? "").trim()
                if (raw.length > 0) {
                    root.localModifications = raw.split("\n").filter(l => l.length > 0)
                } else {
                    root.localModifications = []
                }
                print("[ShellUpdates] Local modifications: " + root.localModifications.length + " file(s)")
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.isFetchingDetails = false
            print("[ShellUpdates] Detail fetch complete")
        }
    }

    // Note: Update runs via Quickshell.execDetached() in performUpdate()
    // so it survives the shell restart that ./setup update triggers.

    // Progress poller: reads the status file every 2s while updating to parse
    // structured progress markers written by setup's _report_progress().
    Timer {
        id: updateProgressPoller
        interval: 2000
        repeat: true
        running: false
        onTriggered: {
            if (!root.isUpdating) {
                updateProgressPoller.running = false
                return
            }
            updateProgressReader.running = true
        }
    }

    Process {
        id: updateProgressReader
        running: false
        command: ["cat", Directories.updateStatusPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const status = (text ?? "").trim()
                if (status.startsWith("progress:")) {
                    // Format: progress:STEP:TOTAL:MESSAGE
                    const parts = status.split(":")
                    if (parts.length >= 4) {
                        root.updateStep = parseInt(parts[1]) || 0
                        root.updateTotalSteps = parseInt(parts[2]) || 0
                        root.updateStepMessage = parts.slice(3).join(":")
                    }
                } else if (status === "updating") {
                    // Legacy/initial marker — no granular progress yet
                    root.updateStep = 0
                    root.updateStepMessage = ""
                } else if (status.startsWith("failed")) {
                    // Update failed — stop polling, let watchdog handle error display
                    updateProgressPoller.running = false
                }
            }
        }
    }

    // Watchdog: if the shell is still alive after 120s, the update likely failed.
    // On success, ./setup update restarts the shell — this timer never fires.
    Timer {
        id: updateWatchdog
        interval: 120000
        repeat: false
        onTriggered: {
            if (!root.isUpdating) return
            print("[ShellUpdates] Watchdog: shell still alive after update launch — reading status file")
            updateStatusReader.running = true
        }
    }

    // Read the status file to determine if the update failed
    Process {
        id: updateStatusReader
        running: false
        command: ["cat", Directories.updateStatusPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const status = (text ?? "").trim()
                print("[ShellUpdates] Update status file: " + status)
                if (status.startsWith("failed")) {
                    // Update process exited with error
                    const parts = status.split(":")
                    const code = parts.length > 1 ? parts[1] : "unknown"
                    root.clearUpdateProgressUi()
                    root.lastError = "Update failed (exit " + code + "). Check " + Directories.updateLogPath + " for details."
                    clearStatusFileProc.running = true
                    print("[ShellUpdates] Update FAILED with exit code " + code)
                } else if (status.startsWith("progress:")) {
                    if (status === root._lastWatchdogStatus) {
                        // Same progress marker seen twice — update is stuck
                        root.clearUpdateProgressUi()
                        root.lastError = "Update stuck at: " + status.split(":").slice(3).join(":") + ". Check " + Directories.updateLogPath + " for details."
                        clearStatusFileProc.running = true
                        print("[ShellUpdates] Update stuck — same progress seen twice: " + status)
                    } else {
                        // Different progress marker — still moving, extend watchdog
                        root._lastWatchdogStatus = status
                        print("[ShellUpdates] Watchdog: update still progressing, extending timeout")
                        updateWatchdog.restart()
                    }
                } else if (status === "updating") {
                    // Still running after 120s — likely stuck
                    root.clearUpdateProgressUi()
                    root.lastError = "Update appears stuck. Check " + Directories.updateLogPath + " for details."
                    clearStatusFileProc.running = true
                    print("[ShellUpdates] Update appears stuck (still 'updating' after watchdog)")
                } else if (status === "success") {
                    // Update completed successfully but shell wasn't restarted
                    root.clearUpdateProgressUi()
                    clearStatusFileProc.running = true
                    print("[ShellUpdates] Update completed successfully (no restart)")
                } else {
                    // Empty or unexpected — assume failed
                    root.clearUpdateProgressUi()
                    root.lastError = "Update outcome unknown. Check " + Directories.updateLogPath + " for details."
                    clearStatusFileProc.running = true
                    print("[ShellUpdates] Update status unclear: '" + status + "'")
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.isUpdating) {
                // Status file doesn't exist — update process may not have started
                root.clearUpdateProgressUi()
                root.lastError = "Update may not have started. Check " + Directories.updateLogPath + " for details."
                print("[ShellUpdates] Status file not found (cat exited " + exitCode + ")")
            }
        }
    }
}
