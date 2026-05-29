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

    // Parsed [General] options of the ACTIVE theme's theme.conf. qylock has no global
    // config; per-theme options (themeMode, background_mode/index, gameMode,
    // enableWindup, fontSize, ...) live in each theme's theme.conf. Keys vary by theme.
    property var activeOptions: ({})

    function rescan(): void {
        scanProc.running = true;
        activeProc.running = true;
    }

    function setTheme(name: string): void {
        if (!name || name === root.active)
            return;
        root.active = name; // optimistic; activeProc re-confirms after write
        writeProc.command = ["sh", "-c", 'mkdir -p "$HOME/.config/qylock" && printf "%s" "$1" > "$HOME/.config/qylock/theme"', "sh", name];
        writeProc.running = true;
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

    Process {
        id: writeProc
        running: false
        onExited: activeProc.running = true
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

    // Stash local edits (theme.conf customisations are tracked) so pull --ff-only can
    // fast-forward, fetch newly published themes, then restore the edits. Untracked
    // files (preview.png images) are intentionally NOT stashed (no -u) so they survive.
    Process {
        id: refreshProc
        command: ["sh", "-c", `cd "${root.repoDir}" 2>/dev/null || exit 0; git stash push >/dev/null 2>&1; git pull --ff-only >/dev/null 2>&1 || true; git stash pop >/dev/null 2>&1 || true`]
        onExited: {
            root.refreshing = false;
            root.rescan();
        }
    }

    Component.onCompleted: root.rescan()
}
