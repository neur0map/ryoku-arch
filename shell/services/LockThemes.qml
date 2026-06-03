pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// RYOKU: lock-screen theme catalogue for qylock (github.com/Darkkal44/qylock).
// Themes live in ~/.local/share/qylock/themes/<name>/ — each has a preview.png and
// a Main.qml; the "clockwork" theme nests variants (clockwork/orbital, clockwork/tape).
// The ACTIVE theme is the plaintext file ~/.config/qylock/theme, which lock.sh reads.
// This service scans the catalogue, exposes `themes` (name + preview path) and
// `active`, lets the settings select a theme, and refreshes the collection via
// `git pull` so newly published themes show up.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/root"
    readonly property string repoDir: `${home}/.local/share/qylock`
    readonly property string themesDir: `${repoDir}/themes`

    // [{ name, preview }]. `name` is the relative theme path written to the active
    // file (e.g. "nier-automata" or "clockwork/orbital"). Rebuilt on rescan().
    property var themes: []
    property string active: ""
    property bool refreshing: false
    // Last refresh error surfaced to the UI ("" when the last refresh succeeded).
    property string refreshError: ""
    // True once ~/.local/share/qylock is a real git checkout (the full
    // catalogue); false for the offline bundle. Drives the one-time first fetch.
    property bool hasGit: false
    // Applying a theme also re-themes the SDDM greeter (root, via pkexec), so it
    // is async and can be cancelled at the polkit prompt.
    property bool applying: false
    property string applyError: ""

    // Parsed [General] options of the ACTIVE theme's theme.conf. qylock has no global
    // config; per-theme options (themeMode, background_mode/index, gameMode,
    // enableWindup, fontSize, ...) live in each theme's theme.conf. Keys vary by theme.
    property var activeOptions: ({})

    function rescan(): void {
        scanProc.running = true;
        activeProc.running = true;
        gitCheckProc.running = true;
    }

    // Apply a theme to BOTH the SDDM greeter (system) and the in-session lock via
    // the pkexec-safe `ryoku-install-qylock --set-theme` - so a polkit prompt
    // appears and the login screen actually changes. Optimistic active update;
    // rescan re-confirms (and reverts if the prompt was cancelled).
    function setTheme(name: string): void {
        if (!name || root.applying || name === root.active)
            return;
        root.applying = true;
        root.applyError = "";
        root.active = name;
        setThemeProc.command = ["sh", "-c", 'exec pkexec "$(command -v ryoku-install-qylock || echo /usr/local/bin/ryoku-install-qylock)" --set-theme "$1"', "sh", name];
        setThemeProc.running = true;
    }

    // Pull the qylock repo so newly uploaded themes appear, then rescan. Best-effort:
    // a network failure leaves the existing themes intact.
    function refresh(): void {
        if (root.refreshing)
            return;
        root.refreshing = true;
        refreshProc.running = true;
    }

    // Read the active theme's theme.conf [General] options into activeOptions.
    function readActiveOptions(): void {
        if (!root.active) {
            root.activeOptions = ({});
            return;
        }
        optReadProc.command = ["sh", "-c", 'cat "$HOME/.local/share/qylock/themes/$1/theme.conf" 2>/dev/null', "sh", root.active];
        optReadProc.running = true;
    }

    function _parseIni(text: string): var {
        const out = {};
        let section = "";
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.length === 0 || line.startsWith("#") || line.startsWith(";"))
                continue;
            if (line.startsWith("[") && line.endsWith("]")) {
                section = line;
                continue;
            }
            if (section === "[General]") {
                const eq = line.indexOf("=");
                if (eq > 0)
                    out[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
            }
        }
        return out;
    }

    // Write one theme.conf [General] option for the active theme (update in place, or
    // append under [General] if absent), then re-read. Only safe-valued keys are wired
    // from the UI (combos/toggles/spin), so no shell-escaping hazards.
    function setOption(key: string, value: string): void {
        if (!root.active || !key)
            return;
        const o = Object.assign({}, root.activeOptions);
        o[key] = String(value);
        root.activeOptions = o; // optimistic; optWriteProc re-reads to confirm
        optWriteProc.command = ["sh", "-c", 'f="$HOME/.local/share/qylock/themes/$1/theme.conf"; [ -f "$f" ] || exit 0; if grep -qE "^[[:space:]]*$2[[:space:]]*=" "$f"; then sed -i -E "s|^[[:space:]]*$2[[:space:]]*=.*|$2=$3|" "$f"; else printf "%s=%s\\n" "$2" "$3" >> "$f"; fi', "sh", root.active, key, String(value)];
        optWriteProc.running = true;
    }

    // Scan: one JSON object per selectable theme (a dir containing Main.qml at depth
    // 1 or 2). Preview is the theme's own preview.png, else its parent's (variants).
    Process {
        id: scanProc
        command: ["sh", "-c", `
            t="${root.themesDir}"
            printf '['
            first=1
            find "$t" -mindepth 1 -maxdepth 3 -name Main.qml -printf '%P\\n' 2>/dev/null | sort | while IFS= read -r rel; do
              name=$(dirname "$rel")
              d="$t/$name"
              if [ -f "$d/preview.png" ]; then p="$d/preview.png"; else p="$t/$(dirname "$name")/preview.png"; fi
              [ -f "$p" ] || p=""
              [ "$first" -eq 0 ] && printf ','
              first=0
              printf '{"name":"%s","preview":"%s"}' "$name" "$p"
            done
            printf ']'
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.themes = JSON.parse(text);
                } catch (e) {
                    console.warn("LockThemes: scan parse failed:", e);
                    root.themes = [];
                }
            }
        }
    }

    Process {
        id: activeProc
        command: ["sh", "-c", 'cat "$HOME/.config/qylock/theme" 2>/dev/null | head -n1']
        stdout: StdioCollector {
            onStreamFinished: {
                root.active = text.trim();
                root.readActiveOptions();
            }
        }
    }

    // Detect whether the catalogue is a full git checkout (vs the offline bundle)
    // so the settings can do a one-time first fetch and skip it thereafter.
    Process {
        id: gitCheckProc
        command: ["sh", "-c", `[ -d "${root.repoDir}/.git" ] && echo 1 || echo 0`]
        stdout: StdioCollector {
            onStreamFinished: root.hasGit = (text.trim() === "1")
        }
    }

    // Privileged apply (pkexec ryoku-install-qylock --set-theme). On success the
    // greeter + in-session lock are themed; on a non-zero exit (prompt cancelled
    // or failed) surface it and rescan to revert the optimistic active.
    Process {
        id: setThemeProc
        running: false
        onExited: function (exitCode) {
            root.applying = false;
            root.applyError = (exitCode === 0) ? "" : "Theme not applied - authentication was cancelled or failed.";
            root.rescan();
        }
    }

    Process {
        id: optReadProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.activeOptions = root._parseIni(text)
        }
    }

    Process {
        id: optWriteProc
        running: false
        onExited: root.readActiveOptions()
    }

    // Fetch the qylock catalogue from upstream. First fetch (no .git - e.g. the
    // offline bundle) does a FULL clone of the repo (themes + Assets + the
    // lockscreen engine) and adopts its .git, so every later refresh is an
    // incremental `git pull --ff-only` that pulls only new/updated themes and
    // assets (so future themes appear automatically). Local theme.conf edits are
    // stashed across the pull. Previews are regenerated afterwards. On failure
    // the offline bundle is left intact and the error surfaces via refreshError.
    Process {
        id: refreshProc
        command: ["sh", "-c", `
            repo="${root.repoDir}"
            mkdir -p "$repo"
            err=""
            if [ -d "$repo/.git" ]; then
              git -C "$repo" stash push >/dev/null 2>&1 || true
              git -C "$repo" pull --ff-only >/dev/null 2>&1 || err="update failed"
              git -C "$repo" stash pop >/dev/null 2>&1 || true
            else
              tmp=$(mktemp -d) || { echo "no temp dir" >&2; exit 1; }
              if git clone --depth=1 https://github.com/Darkkal44/qylock.git "$tmp/qylock" >/dev/null 2>&1; then
                rm -rf "$repo"
                mv "$tmp/qylock" "$repo"
              else
                err="download failed"
                rm -rf "$tmp"
              fi
            fi
            ryoku-refresh-qylock-previews "$repo" >/dev/null 2>&1 || true
            [ -z "$err" ] || { echo "$err" >&2; exit 3; }
        `]
        onExited: function (exitCode) {
            root.refreshing = false;
            root.refreshError = (exitCode === 0) ? "" : "Refresh failed - check your connection and try again.";
            root.rescan();
        }
    }

    Component.onCompleted: root.rescan()
}
