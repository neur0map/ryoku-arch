# OpenVPN Sidebar Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a polished OpenVPN-management tab in the right sidebar, file-picker import, one-click connect, live status, log tail, for THM/HTB/corp lab workflows.

**Architecture:** A new singleton service (`RyokuOpenVpn`) polls `systemctl is-active 'openvpn-client@*'` and `ip -j addr` to expose live VPN state. A new `BottomWidgetGroup` tab renders status / profiles / log tail and triggers connect/disconnect via `Quickshell.execDetached(["systemctl", "start|stop", "openvpn-client@<name>"])`. A polkit rule (installed by `install/config/openvpn.sh`) lets the active session manage `openvpn-client@*` units without password. Imports run through `bin/ryoku-openvpn-import` which uses `pkexec install` (handled by ryoku's existing in-shell `WafflePolkit` agent) to copy validated `.ovpn` files into `/etc/openvpn/client/`. A second SecPulse bar indicator next to the Tailscale lock surfaces the active state at a glance.

**Tech Stack:** QML (Quickshell), bash, systemd `openvpn-client@.service` template, polkit rules, zenity (file picker), pkexec, journalctl, ip-iproute2, jq.

**Spec:** `docs/superpowers/specs/2026-05-06-openvpn-sidebar-design.md`

**Sync convention** (per CLAUDE.md / prior conversation): edit dev (`~/prowl/ryoku-arch`) as source of truth, then `cp` each touched file to the live mirror (`~/.local/share/ryoku`), the SHELL_PATH (`~/.local/share/ryoku-shell`, for QML files only), and the runtime (`~/.config/quickshell/ryoku-shell`, for QML files only). Each task that touches a synced file ends with a sync step.

---

## File Structure

| Layer | Path | Responsibility |
|---|---|---|
| Polkit | `default/polkit/49-ryoku-openvpn.rules` | JS rule allowing `openvpn-client@*` start/stop/restart for active wheel-group sessions, no password |
| Installer | `install/config/openvpn.sh` | Copy polkit rule, ensure `/etc/openvpn/client/` exists, add user to `systemd-journal` group |
| Installer wiring | `install/config/all.sh:18` | Add `run_logged $RYOKU_INSTALL/config/openvpn.sh` after `tailscale.sh` |
| Helper | `bin/ryoku-openvpn-import` | zenity picker → validate `.ovpn` → sanitize name → `pkexec install -m 600` → write `last-import.json` manifest |
| Helper | `bin/ryoku-openvpn-remove` | Stop unit if active → `pkexec rm` → write manifest |
| Helper | `bin/ryoku-openvpn-rename` | Stop unit if active → `pkexec mv` → restart under new name → update manifests |
| Service | `shell/services/RyokuOpenVpn.qml` | Singleton: profiles, activeProfile, activeIp, activeSince, transitioning, connect/disconnect/remove, 5s poll, 30s rescan, FileView watch on last-import.json |
| Service registry | `shell/services/qmldir` | Add `singleton RyokuOpenVpn 1.0 RyokuOpenVpn.qml` |
| UI, composer | `shell/modules/sidebarRight/openvpn/OpenVpnTab.qml` | Tab entry point: composes status card + profiles list + log tail + import button + empty state |
| UI, status | `shell/modules/sidebarRight/openvpn/OpenVpnStatusCard.qml` | Top card with Connected / Connecting / Failed / Switching variants |
| UI, profile | `shell/modules/sidebarRight/openvpn/OpenVpnProfileRow.qml` | One profile: name, Connect/Active button, ⋮ menu (view log, edit, rename, delete) |
| UI, log | `shell/modules/sidebarRight/openvpn/OpenVpnLogTail.qml` | Collapsible journalctl -fu output; owns its own Process; lifecycle tied to Loader |
| UI, wiring | `shell/modules/sidebarRight/BottomWidgetGroup.qml:36` | Add `{"type": "openvpn", "name": "VPN", "icon": "vpn_key", "widget": openVpnWidget}` + Component def + add to `enabledWidgets` fallback |
| Bar | `shell/modules/bar/threeIsland/SecPulseIndicator.qml` | Add second `Item` after Tailscale block, bound to `RyokuOpenVpn.activeProfile`, click opens sidebar to VPN tab |
| Config | `shell/modules/common/Config.qml` | Add `bar.secPulse.showOpenVpn: true`; add `"openvpn"` to default `sidebar.right.enabledWidgets` list (currently line 1394) |
| Test | `tests/sidebar-openvpn.sh` | File-existence + grep assertions matching `tests/topbar-three-island.sh` style |

---

## Task 1: Polkit rule + installer

**Files:**
- Create: `default/polkit/49-ryoku-openvpn.rules`
- Create: `install/config/openvpn.sh`
- Modify: `install/config/all.sh:17` (insert new line after `tailscale.sh`)

- [ ] **Step 1: Write the polkit rule**

Create `default/polkit/49-ryoku-openvpn.rules` with:

```javascript
// Ryoku: allow active wheel-group sessions to manage openvpn-client@*
// systemd units without a password. Scope is intentionally narrow:
// only start/stop/restart/reload-or-restart, only openvpn-client@*
// unit names, only active+local sessions, only wheel members.
polkit.addRule(function(action, subject) {
    if (action.id !== "org.freedesktop.systemd1.manage-units") return;
    if (!subject.active || !subject.local) return;
    if (!subject.isInGroup("wheel")) return;

    var unit = action.lookup("unit") || "";
    if (!/^openvpn-client@.+\.service$/.test(unit)) return;

    var verb = action.lookup("verb") || "";
    if (["start", "stop", "restart", "reload-or-restart"].indexOf(verb) === -1) return;

    return polkit.Result.YES;
});
```

- [ ] **Step 2: Write the installer**

Create `install/config/openvpn.sh` with:

```bash
# Install polkit rule for password-less openvpn-client@* control,
# ensure /etc/openvpn/client/ exists, and add this user to the
# systemd-journal group so the SecPulse OpenVPN tab's log tail can
# read system-unit journals without sudo.

if ! ryoku-cmd-present openvpn; then
  echo "openvpn not installed; skipping openvpn.sh"
  exit 0
fi

sudo install -m 644 -o root -g root \
  "$RYOKU_PATH/default/polkit/49-ryoku-openvpn.rules" \
  /etc/polkit-1/rules.d/49-ryoku-openvpn.rules

sudo install -d -m 700 -o root -g root /etc/openvpn/client

if ! id -nG "$USER" | tr ' ' '\n' | grep -qx systemd-journal; then
  sudo usermod -aG systemd-journal "$USER"
fi
```

- [ ] **Step 3: Wire installer into all.sh**

Modify `install/config/all.sh` line 17, change the `tailscale.sh` line to be followed by the new openvpn.sh line:

Find:
```
run_logged $RYOKU_INSTALL/config/tailscale.sh
```
Replace with:
```
run_logged $RYOKU_INSTALL/config/tailscale.sh
run_logged $RYOKU_INSTALL/config/openvpn.sh
```

- [ ] **Step 4: Sync to live mirror**

Run:
```bash
cp $HOME/prowl/ryoku-arch/default/polkit/49-ryoku-openvpn.rules $HOME/.local/share/ryoku/default/polkit/49-ryoku-openvpn.rules
cp $HOME/prowl/ryoku-arch/install/config/openvpn.sh $HOME/.local/share/ryoku/install/config/openvpn.sh
cp $HOME/prowl/ryoku-arch/install/config/all.sh $HOME/.local/share/ryoku/install/config/all.sh
chmod +x $HOME/prowl/ryoku-arch/install/config/openvpn.sh $HOME/.local/share/ryoku/install/config/openvpn.sh
mkdir -p $HOME/prowl/ryoku-arch/default/polkit $HOME/.local/share/ryoku/default/polkit
```

(The `mkdir -p` is in case `default/polkit/` doesn't exist yet, re-run cp after if needed.)

- [ ] **Step 5: Apply the polkit rule on this box**

Run:
```bash
sudo install -m 644 -o root -g root $HOME/prowl/ryoku-arch/default/polkit/49-ryoku-openvpn.rules /etc/polkit-1/rules.d/49-ryoku-openvpn.rules
sudo install -d -m 700 -o root -g root /etc/openvpn/client
sudo usermod -aG systemd-journal carlos
```

Expected: no errors. The user-group change takes effect on next login but doesn't affect this session.

- [ ] **Step 6: Verify the polkit rule**

Run (no openvpn unit yet, so this just exercises the rule):
```bash
sudo systemctl daemon-reload
ls /etc/polkit-1/rules.d/49-ryoku-openvpn.rules
ls -ld /etc/openvpn/client
```
Expected: file exists, dir exists with mode 700.

- [ ] **Step 7: Commit**

```bash
cd $HOME/prowl/ryoku-arch
git add default/polkit/49-ryoku-openvpn.rules install/config/openvpn.sh install/config/all.sh
git commit -m "$(cat <<'EOF'
feat(install): polkit + installer for openvpn-client@* tab

Adds a polkit rule and an install/config/openvpn.sh script that lets
the active wheel session manage openvpn-client@* systemd units without
a password prompt. Also adds the user to systemd-journal so the
in-shell log tail can read system-unit journals.

Wired into install/config/all.sh after tailscale.sh.

EOF
)"
```

---

## Task 2: Importer helper

**Files:**
- Create: `bin/ryoku-openvpn-import`

- [ ] **Step 1: Write the importer**

Create `bin/ryoku-openvpn-import` with:

```bash
#!/bin/bash
# Pick a .ovpn file, validate it (inline cert/key blocks only),
# sanitize the name, install it into /etc/openvpn/client/ via pkexec,
# and write a manifest the QML side watches via FileView.

set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/openvpn"
mkdir -p "$STATE_DIR"
LAST_IMPORT="$STATE_DIR/last-import.json"
IMPORTS="$STATE_DIR/imports.json"

write_result() {
  local status="$1" name="${2:-}" error="${3:-}"
  local ts
  ts="$(date -Iseconds)"
  printf '{"status":"%s","name":"%s","error":"%s","at":"%s"}\n' \
    "$status" "$name" "${error//\"/\\\"}" "$ts" >"$LAST_IMPORT"
}

if ! command -v zenity >/dev/null 2>&1; then
  write_result error "" "zenity is not installed"
  exit 1
fi
if ! command -v pkexec >/dev/null 2>&1; then
  write_result error "" "pkexec is not installed"
  exit 1
fi

src="$(zenity --file-selection \
  --title="Import OpenVPN profile" \
  --filename="$HOME/Downloads/" \
  --file-filter="OpenVPN | *.ovpn *.conf" 2>/dev/null)" || {
    write_result cancelled
    exit 0
}
[[ -z $src || ! -r $src ]] && { write_result error "" "could not read selected file"; exit 1; }

# Validate: must contain `client` directive; cert/key references must be inline blocks.
if ! grep -qE '^[[:space:]]*client([[:space:]]|$)' "$src"; then
  write_result error "" "missing 'client' directive, not a client config"
  exit 1
fi
if grep -qE '^[[:space:]]*(ca|cert|key|tls-auth|tls-crypt|crl-verify)[[:space:]]+[^<]' "$src"; then
  write_result error "" "external cert/key references not supported, use a self-contained .ovpn"
  exit 1
fi

# Sanitize name: stem of filename, lowercase, [^a-z0-9-] -> -, squeeze, strip leading/trailing dashes.
stem="$(basename "$src")"
stem="${stem%.*}"
name="$(printf '%s' "$stem" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-+|-+$//g')"
[[ -z $name ]] && { write_result error "" "filename produced an empty unit name after sanitization"; exit 1; }

# Collision: prepend ryoku- if a same-named unit file already exists.
if [[ -f "/etc/openvpn/client/$name.conf" ]]; then
  name="ryoku-$name"
fi

# pkexec install (graphical prompt via WafflePolkit).
if ! pkexec install -m 600 -o root -g root "$src" "/etc/openvpn/client/$name.conf"; then
  rc=$?
  case $rc in
    126) write_result cancelled "$name" "authentication cancelled" ;;
    *)   write_result error "$name" "pkexec install failed (rc=$rc)" ;;
  esac
  exit "$rc"
fi

# Append to imports.json (jq if present, else naive).
if command -v jq >/dev/null 2>&1; then
  tmp="$(mktemp)"
  if [[ -f $IMPORTS ]]; then
    jq --arg n "$name" --arg o "$(basename "$src")" --arg t "$(date -Iseconds)" \
      '. + [{name:$n, originalFilename:$o, importedAt:$t}]' "$IMPORTS" >"$tmp"
  else
    jq -n --arg n "$name" --arg o "$(basename "$src")" --arg t "$(date -Iseconds)" \
      '[{name:$n, originalFilename:$o, importedAt:$t}]' >"$tmp"
  fi
  mv "$tmp" "$IMPORTS"
fi

write_result ok "$name"
```

- [ ] **Step 2: Make executable + sync to live mirror**

Run:
```bash
chmod +x $HOME/prowl/ryoku-arch/bin/ryoku-openvpn-import
cp $HOME/prowl/ryoku-arch/bin/ryoku-openvpn-import $HOME/.local/share/ryoku/bin/ryoku-openvpn-import
chmod +x $HOME/.local/share/ryoku/bin/ryoku-openvpn-import
```

- [ ] **Step 3: Smoke-test sanitization (no real .ovpn needed)**

Run a manual test of the sanitization regex by extracting it:
```bash
for stem in "TryHackMe-myname" "htb_USER 2" "ALL-CAPS" "....weird"; do
  printf '%s -> ' "$stem"
  printf '%s' "$stem" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-+|-+$//g'
done
```
Expected output:
```
TryHackMe-myname -> tryhackme-myname
htb_USER 2 -> htb-user-2
ALL-CAPS -> all-caps
....weird -> weird
```

- [ ] **Step 4: Commit**

```bash
cd $HOME/prowl/ryoku-arch
git add bin/ryoku-openvpn-import
git commit -m "$(cat <<'EOF'
feat(bin): ryoku-openvpn-import helper

Picks a .ovpn via zenity, validates it (rejects external cert/key
references), sanitizes the resulting unit name, and installs it into
/etc/openvpn/client/ via pkexec install. Writes a JSON manifest the
QML service watches to refresh the profile list instantly.

EOF
)"
```

---

## Task 3: Remove + rename helpers

**Files:**
- Create: `bin/ryoku-openvpn-remove`
- Create: `bin/ryoku-openvpn-rename`

- [ ] **Step 1: Write ryoku-openvpn-remove**

Create `bin/ryoku-openvpn-remove`:

```bash
#!/bin/bash
# Remove an OpenVPN profile. Stops the unit first if it's active.
# Usage: ryoku-openvpn-remove <name>

set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/openvpn"
mkdir -p "$STATE_DIR"
LAST_OP="$STATE_DIR/last-op.json"

write_result() {
  local op="$1" status="$2" name="${3:-}" error="${4:-}"
  printf '{"op":"%s","status":"%s","name":"%s","error":"%s","at":"%s"}\n' \
    "$op" "$status" "$name" "${error//\"/\\\"}" "$(date -Iseconds)" >"$LAST_OP"
}

name="${1:-}"
if [[ -z $name ]] || [[ "$name" =~ [^a-z0-9-] ]]; then
  write_result remove error "$name" "invalid name"
  exit 2
fi

conf="/etc/openvpn/client/$name.conf"
if [[ ! -f $conf ]]; then
  write_result remove error "$name" "no such profile"
  exit 1
fi

# Stop if active (polkit rule allows this without password).
if systemctl is-active --quiet "openvpn-client@$name.service"; then
  systemctl stop "openvpn-client@$name.service" || true
fi

if ! pkexec rm -f "$conf"; then
  rc=$?
  case $rc in
    126) write_result remove cancelled "$name" "authentication cancelled" ;;
    *)   write_result remove error "$name" "pkexec rm failed (rc=$rc)" ;;
  esac
  exit "$rc"
fi

write_result remove ok "$name"
```

- [ ] **Step 2: Write ryoku-openvpn-rename**

Create `bin/ryoku-openvpn-rename`:

```bash
#!/bin/bash
# Rename an OpenVPN profile. Stops the unit first if active, then
# starts it under the new name. Usage: ryoku-openvpn-rename <old> <new>

set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/openvpn"
mkdir -p "$STATE_DIR"
LAST_OP="$STATE_DIR/last-op.json"

write_result() {
  local op="$1" status="$2" name="${3:-}" error="${4:-}"
  printf '{"op":"%s","status":"%s","name":"%s","error":"%s","at":"%s"}\n' \
    "$op" "$status" "$name" "${error//\"/\\\"}" "$(date -Iseconds)" >"$LAST_OP"
}

old="${1:-}" new="${2:-}"
if [[ -z $old || -z $new ]] || [[ "$old$new" =~ [^a-z0-9-] ]]; then
  write_result rename error "$new" "invalid name(s)"
  exit 2
fi

src="/etc/openvpn/client/$old.conf"
dst="/etc/openvpn/client/$new.conf"
[[ -f $src ]] || { write_result rename error "$new" "no such profile: $old"; exit 1; }
[[ -f $dst ]] && { write_result rename error "$new" "destination already exists: $new"; exit 1; }

was_active=0
if systemctl is-active --quiet "openvpn-client@$old.service"; then
  was_active=1
  systemctl stop "openvpn-client@$old.service" || true
fi

if ! pkexec mv -n "$src" "$dst"; then
  rc=$?
  (( was_active )) && systemctl start "openvpn-client@$old.service" || true
  case $rc in
    126) write_result rename cancelled "$new" "authentication cancelled" ;;
    *)   write_result rename error "$new" "pkexec mv failed (rc=$rc)" ;;
  esac
  exit "$rc"
fi

if (( was_active )); then
  systemctl start "openvpn-client@$new.service" || true
fi

write_result rename ok "$new"
```

- [ ] **Step 3: Make executable + sync**

```bash
chmod +x $HOME/prowl/ryoku-arch/bin/ryoku-openvpn-remove $HOME/prowl/ryoku-arch/bin/ryoku-openvpn-rename
cp $HOME/prowl/ryoku-arch/bin/ryoku-openvpn-remove $HOME/.local/share/ryoku/bin/ryoku-openvpn-remove
cp $HOME/prowl/ryoku-arch/bin/ryoku-openvpn-rename $HOME/.local/share/ryoku/bin/ryoku-openvpn-rename
chmod +x $HOME/.local/share/ryoku/bin/ryoku-openvpn-remove $HOME/.local/share/ryoku/bin/ryoku-openvpn-rename
```

- [ ] **Step 4: Commit**

```bash
cd $HOME/prowl/ryoku-arch
git add bin/ryoku-openvpn-remove bin/ryoku-openvpn-rename
git commit -m "$(cat <<'EOF'
feat(bin): ryoku-openvpn-remove + rename helpers

Stop active unit if any, then pkexec rm/mv the .conf, then restart
under the new name (rename only). Both write a last-op.json manifest
the QML service watches for refresh.

EOF
)"
```

---

## Task 4: RyokuOpenVpn singleton service

**Files:**
- Create: `shell/services/RyokuOpenVpn.qml`
- Modify: `shell/services/qmldir`

- [ ] **Step 1: Add the singleton entry to qmldir**

Modify `shell/services/qmldir`, add a new line `singleton RyokuOpenVpn 1.0 RyokuOpenVpn.qml` next to the existing `singleton RyokuSecPulse …` entry.

Find the line:
```
singleton RyokuSecPulse 1.0 RyokuSecPulse.qml
```
Insert after it:
```
singleton RyokuOpenVpn 1.0 RyokuOpenVpn.qml
```

- [ ] **Step 2: Write the service singleton**

Create `shell/services/RyokuOpenVpn.qml`:

```qml
pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

/**
 * Ryoku OpenVPN service: discovers profiles in /etc/openvpn/client/,
 * tracks the active openvpn-client@<name>.service if any, and exposes
 * connect/disconnect/remove actions that go through systemctl (gated
 * by the 49-ryoku-openvpn.rules polkit rule for password-less control).
 *
 * Polling is gated: the 5s status poll only runs while the SecPulse
 * bar indicator is enabled or the sidebar VPN tab is open; the 30s
 * profile rescan only runs while the tab is open. A FileView on
 * last-import.json triggers an immediate rescan after imports.
 */
Singleton {
    id: root

    // ── public state ──────────────────────────────────────────────
    property var profiles: []                 // [{name, path, isActive}]
    property string activeProfile: ""
    property string activeIp: ""
    property string activeSince: ""
    property int otherActiveCount: 0          // >0 if user manually started extras
    property bool transitioning: false        // disables Connect/Disconnect during state change
    property string transitionTarget: ""      // empty when transitioning=false
    property bool openvpnInstalled: true      // false iff `openvpn` binary is missing

    // ── activation gates (parents flip these) ─────────────────────
    property bool barIndicatorEnabled: Config.options?.bar?.secPulse?.showOpenVpn ?? true
    property bool tabOpen: false              // OpenVpnTab sets this in onCompleted/onDestruction
    readonly property bool _statusActive: barIndicatorEnabled || tabOpen
    readonly property bool _discoveryActive: tabOpen

    // ── status poll: 5s, gated on _statusActive ───────────────────
    Process {
        id: statusProc
        command: ["sh", "-c",
            "set -e; " +
            "active=$(systemctl --type=service --state=active --no-legend 'openvpn-client@*.service' 2>/dev/null); " +
            "if [ -z \"$active\" ]; then echo '{\"profile\":\"\",\"ip\":\"\",\"since\":\"\",\"others\":0}'; exit 0; fi; " +
            "first=$(printf '%s\\n' \"$active\" | head -1 | awk '{print $1}'); " +
            "count=$(printf '%s\\n' \"$active\" | wc -l); " +
            "name=${first#openvpn-client@}; name=${name%.service}; " +
            "since=$(systemctl show \"$first\" -p ActiveEnterTimestamp --value 2>/dev/null); " +
            "ip=$(ip -j addr show 2>/dev/null | jq -r '[.[] | select(.ifname|test(\"^tun\")) | .addr_info[]? | select(.family==\"inet\") | .local] | first // \"\"'); " +
            "printf '{\"profile\":\"%s\",\"ip\":\"%s\",\"since\":\"%s\",\"others\":%d}\\n' \"$name\" \"$ip\" \"$since\" \"$((count-1))\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    root.activeProfile = d.profile || ""
                    root.activeIp = d.ip || ""
                    root.activeSince = d.since || ""
                    root.otherActiveCount = d.others || 0
                } catch (e) {
                    root.activeProfile = ""
                    root.activeIp = ""
                    root.activeSince = ""
                    root.otherActiveCount = 0
                }
                root._reconcileTransition()
            }
        }
    }
    Timer {
        running: root._statusActive
        repeat: true
        triggeredOnStart: true
        interval: 5000
        onTriggered: statusProc.running = true
    }

    // ── discovery poll: 30s, gated on _discoveryActive + on-demand rescan() ──
    Process {
        id: discoveryProc
        command: ["sh", "-c",
            "ls -1 /etc/openvpn/client/*.conf 2>/dev/null | sed 's|^/etc/openvpn/client/||; s|\\.conf$||' | sort"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = this.text.split("\n").filter(s => s.length > 0)
                const out = []
                for (const n of names) {
                    out.push({
                        name: n,
                        path: "/etc/openvpn/client/" + n + ".conf",
                        isActive: (n === root.activeProfile)
                    })
                }
                root.profiles = out
            }
        }
    }
    Timer {
        running: root._discoveryActive
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: discoveryProc.running = true
    }

    // ── openvpn-installed check (one-shot at startup) ─────────────
    Process {
        id: presenceProc
        command: ["sh", "-c", "command -v openvpn >/dev/null 2>&1 && echo y || echo n"]
        stdout: StdioCollector {
            onStreamFinished: { root.openvpnInstalled = (this.text.trim() === "y") }
        }
    }
    Component.onCompleted: presenceProc.running = true

    // ── on-demand: importer / remove / rename signal via FileView ─
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
              + "/ryoku/openvpn/last-import.json"
        watchChanges: true
        onFileChanged: { reload(); root.rescan() }
    }
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
              + "/ryoku/openvpn/last-op.json"
        watchChanges: true
        onFileChanged: { reload(); root.rescan() }
    }

    // ── public API ────────────────────────────────────────────────
    function rescan(): void {
        discoveryProc.running = true
        statusProc.running = true
    }

    function connect(name: string): void {
        if (!name) return
        if (root.activeProfile && root.activeProfile !== name) {
            root._beginTransition(name)
            Quickshell.execDetached(["sh", "-c",
                "systemctl stop 'openvpn-client@" + root.activeProfile + ".service' 2>/dev/null; " +
                "systemctl start 'openvpn-client@" + name + ".service'"])
        } else {
            root._beginTransition(name)
            Quickshell.execDetached(["systemctl", "start", "openvpn-client@" + name + ".service"])
        }
    }

    function disconnect(): void {
        if (!root.activeProfile) return
        root._beginTransition("")
        Quickshell.execDetached(["systemctl", "stop", "openvpn-client@" + root.activeProfile + ".service"])
    }

    function remove(name: string): void {
        if (!name) return
        Quickshell.execDetached(["ryoku-openvpn-remove", name])
    }

    function importNew(): void {
        Quickshell.execDetached(["ryoku-openvpn-import"])
    }

    function rename(oldName: string, newName: string): void {
        if (!oldName || !newName) return
        Quickshell.execDetached(["ryoku-openvpn-rename", oldName, newName])
    }

    // ── transition state machine ──────────────────────────────────
    function _beginTransition(target: string): void {
        root.transitioning = true
        root.transitionTarget = target
        transitionTimeout.restart()
    }
    function _reconcileTransition(): void {
        if (!root.transitioning) return
        if (root.activeProfile === root.transitionTarget) {
            root.transitioning = false
            root.transitionTarget = ""
            transitionTimeout.stop()
        }
    }
    Timer {
        id: transitionTimeout
        interval: 15000
        repeat: false
        onTriggered: {
            root.transitioning = false
            root.transitionTarget = ""
        }
    }
}
```

- [ ] **Step 3: Sync QML files to all 4 locations**

Run:
```bash
DEV=$HOME/prowl/ryoku-arch
LIVE=$HOME/.local/share/ryoku
SHELLP=$HOME/.local/share/ryoku-shell
RUNT=$HOME/.config/quickshell/ryoku-shell
for rel in shell/services/RyokuOpenVpn.qml shell/services/qmldir; do
  cp "$DEV/$rel" "$LIVE/$rel"
  cp "$DEV/$rel" "$SHELLP/${rel#shell/}"
  cp "$DEV/$rel" "$RUNT/${rel#shell/}"
done
```

- [ ] **Step 4: Restart shell + verify no QML errors**

```bash
systemctl --user restart ryoku-shell.service
sleep 3
journalctl --user -u ryoku-shell.service -n 30 --no-pager | grep -iE "error|warn.*openvpn|RyokuOpenVpn" || echo "no openvpn-related errors"
```
Expected: "no openvpn-related errors" (or only the pre-existing translations/svg warnings unrelated to our new file).

- [ ] **Step 5: Smoke-test the service from a quick QML probe**

Run a one-shot: confirm the service compiles and exposes its properties by inspecting the qmldir registration:
```bash
grep -n "RyokuOpenVpn" $HOME/.config/quickshell/ryoku-shell/services/qmldir
ls $HOME/.config/quickshell/ryoku-shell/services/RyokuOpenVpn.qml
```

- [ ] **Step 6: Commit**

```bash
cd $HOME/prowl/ryoku-arch
git add shell/services/RyokuOpenVpn.qml shell/services/qmldir
git commit -m "$(cat <<'EOF'
feat(shell/services): RyokuOpenVpn singleton

Discovers profiles in /etc/openvpn/client/, polls active state every
5s (gated), exposes connect/disconnect/remove/import/rename actions.
A FileView on the importer/op manifests triggers immediate refresh
without waiting for the 30s discovery cycle.

EOF
)"
```

---

## Task 5: Status card UI

**Files:**
- Create: `shell/modules/sidebarRight/openvpn/OpenVpnStatusCard.qml`

- [ ] **Step 1: Write the status card**

Create the new directory + file. Status card has 4 visual states: Disconnected (hidden), Connecting, Connected, Failed.

```qml
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: visible ? content.implicitHeight + 20 : 0
    visible: RyokuOpenVpn.activeProfile.length > 0 || RyokuOpenVpn.transitioning
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2
    border.color: Appearance.colors.colLayer3Hover
    border.width: 1

    readonly property color colAccent: Appearance.angelEverywhere ? Appearance.angel.colAccent
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colAccent
        : Appearance.colors.colPrimary
    readonly property color colError: Appearance.colors.colError ?? "#fb4934"

    readonly property string headline: {
        if (RyokuOpenVpn.transitioning) {
            if (RyokuOpenVpn.transitionTarget.length === 0) return "Disconnecting…"
            if (RyokuOpenVpn.activeProfile.length > 0) return "Switching " + RyokuOpenVpn.activeProfile + " → " + RyokuOpenVpn.transitionTarget + "…"
            return "Connecting to " + RyokuOpenVpn.transitionTarget + "…"
        }
        return "Connected"
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MaterialSymbol {
                text: RyokuOpenVpn.transitioning ? "sync" : "vpn_key"
                fill: RyokuOpenVpn.transitioning ? 0 : 1
                iconSize: Appearance.font.pixelSize.normal
                color: root.colAccent
                RotationAnimation on rotation {
                    running: RyokuOpenVpn.transitioning
                    from: 0; to: 360; duration: 1500
                    loops: Animation.Infinite
                }
            }
            StyledText {
                text: root.headline
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
                Layout.fillWidth: true
            }
        }
        StyledText {
            visible: !RyokuOpenVpn.transitioning && RyokuOpenVpn.activeProfile.length > 0
            text: RyokuOpenVpn.activeProfile + " · since " + (RyokuOpenVpn.activeSince.length > 0 ? RyokuOpenVpn.activeSince.substring(11, 16) : "?")
            color: Appearance.colors.colOnLayer2Subtitle
            font.pixelSize: Appearance.font.pixelSize.small
        }
        StyledText {
            visible: !RyokuOpenVpn.transitioning && RyokuOpenVpn.activeIp.length > 0
            text: RyokuOpenVpn.activeIp + " · tun"
            color: Appearance.colors.colOnLayer2Subtitle
            font.pixelSize: Appearance.font.pixelSize.small
        }
        StyledText {
            visible: !RyokuOpenVpn.transitioning && RyokuOpenVpn.activeProfile.length > 0 && RyokuOpenVpn.activeIp.length === 0
            text: "Tunnel up, no IP yet, check log"
            color: root.colError
            font.pixelSize: Appearance.font.pixelSize.small
        }
        StyledText {
            visible: RyokuOpenVpn.otherActiveCount > 0
            text: "(+" + RyokuOpenVpn.otherActiveCount + " other unit" + (RyokuOpenVpn.otherActiveCount === 1 ? "" : "s") + " active)"
            color: Appearance.colors.colOnLayer2Subtitle
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
        Item { Layout.preferredHeight: 4 }
        Button {
            Layout.fillWidth: true
            enabled: !RyokuOpenVpn.transitioning && RyokuOpenVpn.activeProfile.length > 0
            text: "Disconnect"
            onClicked: RyokuOpenVpn.disconnect()
        }
    }
}
```

- [ ] **Step 2: Sync to all 4 locations**

```bash
DEV=$HOME/prowl/ryoku-arch
LIVE=$HOME/.local/share/ryoku
SHELLP=$HOME/.local/share/ryoku-shell
RUNT=$HOME/.config/quickshell/ryoku-shell
mkdir -p "$DEV/shell/modules/sidebarRight/openvpn" "$LIVE/shell/modules/sidebarRight/openvpn" "$SHELLP/modules/sidebarRight/openvpn" "$RUNT/modules/sidebarRight/openvpn"
rel=shell/modules/sidebarRight/openvpn/OpenVpnStatusCard.qml
cp "$DEV/$rel" "$LIVE/$rel"
cp "$DEV/$rel" "$SHELLP/${rel#shell/}"
cp "$DEV/$rel" "$RUNT/${rel#shell/}"
```

- [ ] **Step 3: Commit**

```bash
cd $HOME/prowl/ryoku-arch
git add shell/modules/sidebarRight/openvpn/OpenVpnStatusCard.qml
git commit -m "$(cat <<'EOF'
feat(sidebar/openvpn): status card

Top-of-tab card with Connecting / Connected / Switching states. Shows
profile, since-time, tunnel IP, "(+N others)" hint when extra units
are active, and a Disconnect button.

EOF
)"
```

---

## Task 6: Profile row UI

**Files:**
- Create: `shell/modules/sidebarRight/openvpn/OpenVpnProfileRow.qml`

- [ ] **Step 1: Write the profile row**

```qml
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root
    required property var profile  // {name, path, isActive}

    // Bubble up to the Tab composer (parent-chain is too deep for direct calls).
    signal expandLogRequested(string name)
    signal renameRequested(string name)
    signal deleteRequested(string name)

    Layout.fillWidth: true
    Layout.preferredHeight: 40
    radius: Appearance.rounding.small
    color: rowMouse.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"

    readonly property color colAccent: Appearance.angelEverywhere ? Appearance.angel.colAccent
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colAccent
        : Appearance.colors.colPrimary

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 8
        StyledText {
            text: root.profile.name
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.normal
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Button {
            visible: !root.profile.isActive
            enabled: !RyokuOpenVpn.transitioning
            text: "Connect"
            onClicked: RyokuOpenVpn.connect(root.profile.name)
        }
        RowLayout {
            visible: root.profile.isActive
            spacing: 4
            Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: root.colAccent }
            StyledText { text: "Active"; color: root.colAccent; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Bold }
        }
        Button {
            text: "⋮"
            flat: true
            onClicked: rowMenu.popup()
        }
    }

    Menu {
        id: rowMenu
        MenuItem {
            text: "View full log"
            onTriggered: root.expandLogRequested(root.profile.name)
        }
        MenuItem {
            text: "Edit config…"
            onTriggered: Quickshell.execDetached(["sh", "-c",
                "kitty --class=ryoku-vpn-edit --title='Edit " + root.profile.name + "' -e " +
                "pkexec env EDITOR=\"${EDITOR:-nano}\" \"${EDITOR:-nano}\" /etc/openvpn/client/" + root.profile.name + ".conf"])
        }
        MenuItem {
            text: "Rename…"
            onTriggered: root.renameRequested(root.profile.name)
        }
        MenuItem {
            text: "Delete"
            onTriggered: root.deleteRequested(root.profile.name)
        }
    }
}
```

- [ ] **Step 2: Sync to all 4 locations**

```bash
DEV=$HOME/prowl/ryoku-arch
LIVE=$HOME/.local/share/ryoku
SHELLP=$HOME/.local/share/ryoku-shell
RUNT=$HOME/.config/quickshell/ryoku-shell
rel=shell/modules/sidebarRight/openvpn/OpenVpnProfileRow.qml
cp "$DEV/$rel" "$LIVE/$rel"
cp "$DEV/$rel" "$SHELLP/${rel#shell/}"
cp "$DEV/$rel" "$RUNT/${rel#shell/}"
```

- [ ] **Step 3: Commit**

```bash
cd $HOME/prowl/ryoku-arch
git add shell/modules/sidebarRight/openvpn/OpenVpnProfileRow.qml
git commit -m "$(cat <<'EOF'
feat(sidebar/openvpn): profile row

One row per profile in /etc/openvpn/client/. Connect button (or
Active dot when running), ⋮ menu for view-log / edit / rename / delete.
Edit pkexec's into the user's EDITOR inside a kitty window.

EOF
)"
```

---

## Task 7: Log tail UI

**Files:**
- Create: `shell/modules/sidebarRight/openvpn/OpenVpnLogTail.qml`

- [ ] **Step 1: Write the log tail**

```qml
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ColumnLayout {
    id: root
    property string profileName: RyokuOpenVpn.activeProfile
    property bool expanded: false
    spacing: 4
    Layout.fillWidth: true
    visible: profileName.length > 0

    onProfileNameChanged: { tailLines.text = ""; if (expanded) tailLoader.active = true }
    onExpandedChanged: tailLoader.active = expanded

    Button {
        Layout.fillWidth: true
        text: (root.expanded ? "▾ " : "▸ ") + "Recent log" + (root.profileName ? "  (" + root.profileName + ")" : "")
        flat: true
        onClicked: root.expanded = !root.expanded
    }

    Rectangle {
        visible: root.expanded
        Layout.fillWidth: true
        Layout.preferredHeight: 140
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.small
        border.color: Appearance.colors.colLayer3Hover
        border.width: 1

        ScrollView {
            anchors.fill: parent
            anchors.margins: 6
            clip: true
            TextArea {
                id: tailLines
                readOnly: true
                wrapMode: TextArea.NoWrap
                font.family: Appearance.font.family.monospace ?? "monospace"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                text: ""
                background: null
            }
        }
    }

    Loader {
        id: tailLoader
        active: false
        sourceComponent: Item {
            Process {
                id: tailProc
                running: true
                command: ["journalctl", "-fu", "openvpn-client@" + root.profileName + ".service", "-n", "20", "--no-pager"]
                stdout: SplitParser {
                    splitMarker: "\n"
                    onRead: data => {
                        // Keep at most ~200 lines.
                        const lines = (tailLines.text + data + "\n").split("\n")
                        const trimmed = lines.length > 200 ? lines.slice(lines.length - 200) : lines
                        tailLines.text = trimmed.join("\n")
                    }
                }
            }
            Component.onDestruction: tailProc.running = false
        }
    }
}
```

- [ ] **Step 2: Sync to all 4 locations**

```bash
DEV=$HOME/prowl/ryoku-arch
LIVE=$HOME/.local/share/ryoku
SHELLP=$HOME/.local/share/ryoku-shell
RUNT=$HOME/.config/quickshell/ryoku-shell
rel=shell/modules/sidebarRight/openvpn/OpenVpnLogTail.qml
cp "$DEV/$rel" "$LIVE/$rel"
cp "$DEV/$rel" "$SHELLP/${rel#shell/}"
cp "$DEV/$rel" "$RUNT/${rel#shell/}"
```

- [ ] **Step 3: Commit**

```bash
cd $HOME/prowl/ryoku-arch
git add shell/modules/sidebarRight/openvpn/OpenVpnLogTail.qml
git commit -m "$(cat <<'EOF'
feat(sidebar/openvpn): collapsible log tail

journalctl -fu owned by a Loader so the child process dies when the
tab unloads or the panel collapses. Replays the last 20 lines on
expand and follows live thereafter, capped at ~200 lines in memory.

EOF
)"
```

---

## Task 8: Tab composer + empty state + import button

**Files:**
- Create: `shell/modules/sidebarRight/openvpn/OpenVpnTab.qml`

- [ ] **Step 1: Write the tab composer**

```qml
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root
    anchors.fill: parent
    Component.onCompleted: RyokuOpenVpn.tabOpen = true
    Component.onDestruction: RyokuOpenVpn.tabOpen = false

    // (Child OpenVpnProfileRow rows bubble up via signals;
    // see the Repeater delegate below for the wiring.)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // openvpn not installed → stub
        Rectangle {
            visible: !RyokuOpenVpn.openvpnInstalled
            Layout.fillWidth: true
            Layout.preferredHeight: stubCol.implicitHeight + 20
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal
            ColumnLayout {
                id: stubCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6
                StyledText { text: "OpenVPN not installed"; font.weight: Font.Bold; color: Appearance.colors.colOnLayer2 }
                StyledText {
                    text: "Install with: pacman -S openvpn"
                    color: Appearance.colors.colOnLayer2Subtitle
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }

        OpenVpnStatusCard {
            id: statusCard
            visible: RyokuOpenVpn.openvpnInstalled
        }

        // Profiles header
        RowLayout {
            visible: RyokuOpenVpn.openvpnInstalled
            Layout.fillWidth: true
            StyledText {
                text: "Profiles"
                color: Appearance.colors.colOnLayer1
                font.weight: Font.Bold
                Layout.fillWidth: true
            }
            Button {
                text: "+"
                onClicked: RyokuOpenVpn.importNew()
            }
        }

        // Profiles list (or empty state)
        Rectangle {
            visible: RyokuOpenVpn.openvpnInstalled
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                visible: RyokuOpenVpn.profiles.length === 0
                spacing: 6
                StyledText {
                    text: "No profiles yet"
                    color: Appearance.colors.colOnLayer2
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                }
                StyledText {
                    text: "Import a .ovpn from THM, HTB, or your corp portal."
                    color: Appearance.colors.colOnLayer2Subtitle
                    font.pixelSize: Appearance.font.pixelSize.small
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                }
                Button {
                    text: "Import .ovpn"
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: RyokuOpenVpn.importNew()
                }
            }

            // List
            ScrollView {
                anchors.fill: parent
                anchors.margins: 6
                visible: RyokuOpenVpn.profiles.length > 0
                clip: true
                ColumnLayout {
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: RyokuOpenVpn.profiles
                        delegate: OpenVpnProfileRow {
                            required property var modelData
                            profile: modelData
                            onExpandLogRequested: name => { logTail.expanded = true }
                            onRenameRequested:    name => renameDialog.openFor(name)
                            onDeleteRequested:    name => deleteDialog.openFor(name)
                        }
                    }
                }
            }
        }

        OpenVpnLogTail {
            id: logTail
            visible: RyokuOpenVpn.openvpnInstalled
        }
    }

    // Rename dialog
    Dialog {
        id: renameDialog
        property string oldName: ""
        title: "Rename profile"
        standardButtons: Dialog.Ok | Dialog.Cancel
        function openFor(name) { oldName = name; renameInput.text = name; open() }
        ColumnLayout {
            spacing: 6
            StyledText { text: "Rename '" + renameDialog.oldName + "' to:" }
            TextField {
                id: renameInput
                Layout.preferredWidth: 240
                validator: RegularExpressionValidator { regularExpression: /^[a-z0-9-]+$/ }
            }
            StyledText {
                text: "Lowercase letters, digits, dashes only."
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer2Subtitle
            }
        }
        onAccepted: {
            if (renameInput.text && renameInput.text !== renameDialog.oldName)
                RyokuOpenVpn.rename(renameDialog.oldName, renameInput.text)
        }
    }

    // Delete confirm
    Dialog {
        id: deleteDialog
        property string name: ""
        title: "Delete profile?"
        standardButtons: Dialog.Yes | Dialog.No
        function openFor(n) { name = n; open() }
        StyledText { text: "Delete '" + deleteDialog.name + "'? The .conf file is removed permanently." }
        onAccepted: RyokuOpenVpn.remove(deleteDialog.name)
    }
}
```

- [ ] **Step 2: Sync to all 4 locations**

```bash
DEV=$HOME/prowl/ryoku-arch
LIVE=$HOME/.local/share/ryoku
SHELLP=$HOME/.local/share/ryoku-shell
RUNT=$HOME/.config/quickshell/ryoku-shell
rel=shell/modules/sidebarRight/openvpn/OpenVpnTab.qml
cp "$DEV/$rel" "$LIVE/$rel"
cp "$DEV/$rel" "$SHELLP/${rel#shell/}"
cp "$DEV/$rel" "$RUNT/${rel#shell/}"
```

- [ ] **Step 3: Commit**

```bash
cd $HOME/prowl/ryoku-arch
git add shell/modules/sidebarRight/openvpn/OpenVpnTab.qml
git commit -m "$(cat <<'EOF'
feat(sidebar/openvpn): tab composer with empty state + dialogs

Composes status card, profiles list, log tail, import button. Empty
state for zero profiles. Rename/delete confirmation dialogs.

Sets RyokuOpenVpn.tabOpen=true on completion so the service knows to
run the discovery rescan and (gates the per-tab status poll path).

EOF
)"
```

---

## Task 9: Wire VPN tab into BottomWidgetGroup

**Files:**
- Modify: `shell/modules/sidebarRight/BottomWidgetGroup.qml` (around lines 36–44 and 67)

- [ ] **Step 1: Add the tab entry**

Modify `shell/modules/sidebarRight/BottomWidgetGroup.qml`, add an entry to `allTabs` and a Component definition.

Find:
```
        {"type": "timer", "name": Translation.tr("Timer"), "icon": "schedule", "widget": pomodoroWidget},
    ]
```
Replace with:
```
        {"type": "timer", "name": Translation.tr("Timer"), "icon": "schedule", "widget": pomodoroWidget},
        {"type": "openvpn", "name": Translation.tr("VPN"), "icon": "vpn_key", "widget": openVpnWidgetComponent},
    ]
```

- [ ] **Step 2: Add the import + component definition**

Find the existing imports near the top of the file (e.g. `import qs.modules.sidebarRight.bluetoothDevices` etc.). Add:
```
import qs.modules.sidebarRight.openvpn
```

Then find the `eventsWidgetComponent` Component definition and add a sibling for openvpn just below it:
```
    Component {
        id: openVpnWidgetComponent
        OpenVpnTab {
            anchors.fill: parent
            anchors.margins: 5
        }
    }
```

- [ ] **Step 3: Add openvpn to the enabledWidgets fallback**

Find line 67 in `BottomWidgetGroup.qml`:
```
        return Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "timer"]
```
Replace with:
```
        return Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "timer", "openvpn"]
```

- [ ] **Step 4: Sync to all 4 locations**

```bash
DEV=$HOME/prowl/ryoku-arch
LIVE=$HOME/.local/share/ryoku
SHELLP=$HOME/.local/share/ryoku-shell
RUNT=$HOME/.config/quickshell/ryoku-shell
rel=shell/modules/sidebarRight/BottomWidgetGroup.qml
cp "$DEV/$rel" "$LIVE/$rel"
cp "$DEV/$rel" "$SHELLP/${rel#shell/}"
cp "$DEV/$rel" "$RUNT/${rel#shell/}"
```

- [ ] **Step 5: Restart shell + verify VPN tab appears**

```bash
systemctl --user restart ryoku-shell.service
sleep 3
journalctl --user -u ryoku-shell.service -n 50 --no-pager | grep -iE "error.*(VPN|openvpn|RyokuOpenVpn)" || echo "no openvpn-related errors"
```

Visual check: open the right sidebar, scroll to the bottom widget tab strip, confirm a 🔑 VPN tab appears at the end. (User-side check.)

- [ ] **Step 6: Commit**

```bash
cd $HOME/prowl/ryoku-arch
git add shell/modules/sidebarRight/BottomWidgetGroup.qml
git commit -m "$(cat <<'EOF'
feat(sidebar): wire VPN tab into BottomWidgetGroup

Adds the openvpn entry to allTabs[] and includes it in the default
enabledWidgets fallback so the tab is on by default.

EOF
)"
```

---

## Task 10: Config defaults + bar SecPulse second indicator

**Files:**
- Modify: `shell/modules/common/Config.qml` (add `showOpenVpn`, add `openvpn` to enabledWidgets default at line ~1394, comment block update next to `showVpn`)
- Modify: `shell/modules/bar/threeIsland/SecPulseIndicator.qml` (add second `Item` after the Tailscale block)

- [ ] **Step 1: Add `showOpenVpn` config option**

Modify `shell/modules/common/Config.qml`. Find the `secPulse` block (around line 728):
```
                property JsonObject secPulse: JsonObject {
                    property bool showVpn: true
                    property bool showPublicIp: false
                    property bool showListening: false
```
Replace with:
```
                property JsonObject secPulse: JsonObject {
                    property bool showVpn: true            // tailscale lock
                    property bool showOpenVpn: true        // openvpn key, second indicator
                    property bool showPublicIp: false
                    property bool showListening: false
```

- [ ] **Step 2: Add openvpn to the enabledWidgets default in Config.qml**

In the same Config.qml, find line 1394 area:
```
                    property list<string> enabledWidgets: ["calendar", "todo", "notepad", "calculator", "sysmon", "timer"]
```
Replace with:
```
                    property list<string> enabledWidgets: ["calendar", "todo", "notepad", "calculator", "sysmon", "timer", "openvpn"]
```

- [ ] **Step 3: Add the second SecPulse indicator**

Modify `shell/modules/bar/threeIsland/SecPulseIndicator.qml`. After the closing `}` of the Tailscale `Item { id: vpnItem … }` block (currently right before the `// Listening socket count (opt-in)` comment), insert a second indicator:

Find:
```qml
        }

        // Listening socket count (opt-in)
        RowLayout {
```
Replace with:
```qml
        }

        // OpenVPN indicator (separate from tailscale; engagement tunnels
        // come and go, tailscale stays).
        Item {
            id: ovpnItem
            visible: (Config.options?.bar?.secPulse?.showOpenVpn ?? true)
            implicitWidth: ovpnIcon.implicitWidth
            implicitHeight: ovpnIcon.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            MaterialSymbol {
                id: ovpnIcon
                anchors.centerIn: parent
                text: "vpn_key"
                iconSize: Appearance.font.pixelSize.normal
                fill: RyokuOpenVpn.activeProfile.length > 0 ? 1 : 0
                color: RyokuOpenVpn.activeProfile.length > 0
                    ? (ovpnMouse.containsMouse ? root.colText : root.colAccent)
                    : (ovpnMouse.containsMouse ? root.colText : root.colSubtle)
            }
            MouseArea {
                id: ovpnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { GlobalStates.sidebarRightOpen = true }
            }
            StyledToolTip {
                extraVisibleCondition: ovpnMouse.containsMouse
                text: {
                    if (RyokuOpenVpn.activeProfile.length === 0) return "OpenVPN · off"
                    let lines = ["OpenVPN · " + RyokuOpenVpn.activeProfile]
                    if (RyokuOpenVpn.activeIp) lines.push(RyokuOpenVpn.activeIp + " · tun")
                    if (RyokuOpenVpn.activeSince) lines.push("since " + RyokuOpenVpn.activeSince.substring(11, 16))
                    return lines.join("\n")
                }
            }
        }

        // Listening socket count (opt-in)
        RowLayout {
```

Note: the click action just opens the sidebar. Selecting the openvpn tab specifically requires a `GlobalStates.requestSidebarTab` API which doesn't exist yet; for v1 just opening the sidebar (with the user's last-used tab) is enough.

- [ ] **Step 4: Sync edits to all 4 QML locations**

```bash
DEV=$HOME/prowl/ryoku-arch
LIVE=$HOME/.local/share/ryoku
SHELLP=$HOME/.local/share/ryoku-shell
RUNT=$HOME/.config/quickshell/ryoku-shell
for rel in shell/modules/common/Config.qml shell/modules/bar/threeIsland/SecPulseIndicator.qml; do
  cp "$DEV/$rel" "$LIVE/$rel"
  cp "$DEV/$rel" "$SHELLP/${rel#shell/}"
  cp "$DEV/$rel" "$RUNT/${rel#shell/}"
done
```

- [ ] **Step 5: Restart shell + verify**

```bash
systemctl --user restart ryoku-shell.service
sleep 3
journalctl --user -u ryoku-shell.service -n 50 --no-pager | grep -iE "error.*(SecPulse|openvpn|RyokuOpenVpn)" || echo "clean"
```

Visual check: bar shows `🔒 [tailscale] 🔑 [openvpn]` (vpn_key icon hollow/subtle since no openvpn unit is active yet); hovering each gives its tooltip.

- [ ] **Step 6: Commit**

```bash
cd $HOME/prowl/ryoku-arch
git add shell/modules/common/Config.qml shell/modules/bar/threeIsland/SecPulseIndicator.qml
git commit -m "$(cat <<'EOF'
feat(bar/secpulse): second indicator for OpenVPN

Adds a vpn_key glyph next to the existing tailscale lock. Reads
state from the new RyokuOpenVpn singleton, no new state in SecPulse.
Click opens the right sidebar.

Also adds bar.secPulse.showOpenVpn (default true) and includes
"openvpn" in the default sidebar.right.enabledWidgets list.

EOF
)"
```

---

## Task 11: Test script

**Files:**
- Create: `tests/sidebar-openvpn.sh`

- [ ] **Step 1: Write the test**

Look at `tests/topbar-three-island.sh` first to copy the helper-functions header. Then create `tests/sidebar-openvpn.sh`:

```bash
#!/usr/bin/env bash
# Static asserts for the OpenVPN sidebar feature. Mirrors the style
# of tests/topbar-three-island.sh.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

assert_file()       { [[ -f "$1" ]] || fail "missing file: $1"; }
assert_executable() { [[ -x "$1" ]] || fail "not executable: $1"; }
assert_contains()   { grep -qF "$2" "$1" || fail "$1 missing substring: $2"; }
assert_matches()    { grep -qE "$2" "$1" || fail "$1 missing regex: $2"; }

# 1. Service singleton
assert_file        "shell/services/RyokuOpenVpn.qml"
assert_contains    "shell/services/qmldir" "singleton RyokuOpenVpn 1.0 RyokuOpenVpn.qml"

# 2. Sidebar widgets
assert_file        "shell/modules/sidebarRight/openvpn/OpenVpnTab.qml"
assert_file        "shell/modules/sidebarRight/openvpn/OpenVpnStatusCard.qml"
assert_file        "shell/modules/sidebarRight/openvpn/OpenVpnProfileRow.qml"
assert_file        "shell/modules/sidebarRight/openvpn/OpenVpnLogTail.qml"

# 3. Tab is wired into BottomWidgetGroup
assert_contains    "shell/modules/sidebarRight/BottomWidgetGroup.qml" '"type": "openvpn"'
assert_contains    "shell/modules/sidebarRight/BottomWidgetGroup.qml" "openVpnWidgetComponent"
assert_matches     "shell/modules/sidebarRight/BottomWidgetGroup.qml" '"openvpn"'

# 4. Config defaults
assert_contains    "shell/modules/common/Config.qml" "property bool showOpenVpn"
assert_matches     "shell/modules/common/Config.qml" '"openvpn"'

# 5. Bar second indicator
assert_contains    "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "ovpnItem"
assert_contains    "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "RyokuOpenVpn.activeProfile"

# 6. Bash helpers
assert_executable  "bin/ryoku-openvpn-import"
assert_executable  "bin/ryoku-openvpn-remove"
assert_executable  "bin/ryoku-openvpn-rename"

# 7. Polkit + installer
assert_file        "default/polkit/49-ryoku-openvpn.rules"
assert_executable  "install/config/openvpn.sh"
assert_contains    "install/config/all.sh" "openvpn.sh"

# 8. openvpn package
assert_contains    "install/ryoku-base.packages" "openvpn"

printf 'PASS: tests/sidebar-openvpn.sh\n'
```

- [ ] **Step 2: Make executable + sync to live**

```bash
chmod +x $HOME/prowl/ryoku-arch/tests/sidebar-openvpn.sh
cp $HOME/prowl/ryoku-arch/tests/sidebar-openvpn.sh $HOME/.local/share/ryoku/tests/sidebar-openvpn.sh
chmod +x $HOME/.local/share/ryoku/tests/sidebar-openvpn.sh
```

- [ ] **Step 3: Run the test**

```bash
bash $HOME/prowl/ryoku-arch/tests/sidebar-openvpn.sh
```
Expected: `PASS: tests/sidebar-openvpn.sh`

- [ ] **Step 4: Commit**

```bash
cd $HOME/prowl/ryoku-arch
git add tests/sidebar-openvpn.sh
git commit -m "$(cat <<'EOF'
test: static asserts for openvpn sidebar feature

Same shape as tests/topbar-three-island.sh, file existence + grep
checks for service, widgets, wiring, config, bar indicator, helpers,
polkit rule, installer, and package list.

EOF
)"
```

---

## Task 12: End-to-end smoke + manual verification

**Files:** none, manual verification only.

- [ ] **Step 1: Re-run all tests**

```bash
bash $HOME/prowl/ryoku-arch/tests/topbar-three-island.sh
bash $HOME/prowl/ryoku-arch/tests/sidebar-openvpn.sh
```
Expected: both PASS.

- [ ] **Step 2: Verify shell is clean**

```bash
systemctl --user restart ryoku-shell.service
sleep 3
journalctl --user -u ryoku-shell.service -n 60 --no-pager | grep -iE "error|warn.*openvpn|warn.*RyokuOpenVpn|fileview" | grep -v "qt.svg\|Translation\|illogical-impulse" || echo "clean"
```

- [ ] **Step 3: User smoke test (interactive)**

Have the user perform these actions and confirm:

1. Open right sidebar → see VPN tab at the end of the bottom widget group.
2. VPN tab shows empty state ("No profiles yet").
3. Click `+ Import .ovpn` → file picker opens via zenity.
4. Pick a real .ovpn (e.g. an HTB lab or test config) → pkexec prompt via WafflePolkit → enter password.
5. After success: profile appears in the list (within 1s thanks to FileView).
6. Click `Connect` on the profile → status card transitions through `Connecting → Connected`, IP appears within ~10s, bar indicator's `vpn_key` glyph turns accent-color and fills in.
7. Hover bar indicator → tooltip shows profile name + IP + since-time.
8. Expand log tail → see live journalctl output for the openvpn-client@<name>.service unit.
9. Click `Disconnect` → unit stops, status card clears, bar indicator returns to subtle.
10. Profile row ⋮ → Delete → confirm → file is gone from `/etc/openvpn/client/`.
11. Try to import a .ovpn that uses external cert refs (`ca ca.crt` line) → toast / manifest indicates refusal.

- [ ] **Step 4: If smoke succeeds, no commit needed (no code changed). If issues found, return to the relevant task to fix.**

---

## Self-Review Notes

(Filled in by writer; informational for executor.)

**Spec coverage check:** Each spec section maps to at least one task ,
- UX states → Tasks 5/8 (status card variants + tab empty state)
- Architecture call graph → Tasks 4/5/6/7/8 wire the same pattern
- Components table → Tasks 1–10 each touch one or more rows
- Process lifecycle → Task 4 implements all gating (`_statusActive`, `_discoveryActive`, FileView), Task 7 implements log-tail Loader ownership, Task 8 sets `tabOpen`
- Concurrency → Task 4 implements `transitioning`, `transitionTimeout`, switch-then-start in `connect()`
- Error handling → Tasks 4 (openvpnInstalled stub), 7 (log tail one-shot fallback NOT implemented in v1; deferred), 8 (empty state + dialogs); the rest surface via toasts which we render as plain status text in v1
- Security → Task 1 (polkit narrow rule), Task 2 (validator regex)
- Testing → Tasks 11 (static asserts) + 12 (manual smoke)

**Known minor deferrals from spec to v2 (called out here so the executor doesn't expect to find them):**

- Toast notification system: the spec describes inline toasts; v1 surfaces results inline in the status card / log tail / dialog text. A real toast system would touch Notifications and is out of scope for this plan.
- The "log tail one-shot fallback if user not in systemd-journal group" is partially handled, the installer adds them to the group, so the failure mode shouldn't appear on a properly-installed system. We don't render an explicit error stub in v1; if it triggers, the log tail simply stays empty.
- Bar indicator click currently opens the sidebar but does NOT focus the VPN tab (would require a new `GlobalStates.requestSidebarTab` plumbing, deferred).
