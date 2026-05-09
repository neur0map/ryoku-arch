# Hosts Editor Sidebar Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Hosts editor tab to the right sidebar that lets the user add and remove `IP DOMAIN` entries within a delimited managed block in `/etc/hosts`, with privileged writes going through `pkexec` so the existing `WafflePolkit` UI handles the auth prompt.

**Architecture:** New `RyokuHosts` singleton parses the managed block from `/etc/hosts` (FileView-watched, no polling). New `HostsTab.qml` widget renders an add-form + entry list with per-row remove buttons. New `bin/ryoku-hosts-edit` Bash helper validates inputs, builds a temp file, and runs `pkexec install -m 644 -o root -g root` to atomically replace `/etc/hosts`. No topbar widget. No new polkit rule. No migration.

**Tech Stack:** Quickshell QML 6, bash, awk, pkexec, jq. Tests are static asserts in `tests/sidebar-hosts.sh` plus the existing `shell/scripts/qml-check.fish`.

**Spec:** `docs/superpowers/specs/2026-05-08-hosts-sidebar-tab-design.md`

---

## File Structure

```
bin/ryoku-hosts-edit                                          NEW   bash helper, ~140 lines
shell/services/RyokuHosts.qml                                 NEW   singleton, ~110 lines
shell/services/qmldir                                         EDIT  one register line
shell/modules/sidebarRight/hosts/HostsTab.qml                 NEW   widget, ~170 lines
shell/modules/sidebarRight/BottomWidgetGroup.qml              EDIT  import + Component + allTabs + tabOpen Binding + enabledWidgets default
shell/modules/sidebarRight/CompactSidebarRightContent.qml     EDIT  import + Component + widgetSections + tabOpen Binding + enabledWidgets default
shell/defaults/config.json                                    EDIT  add "hosts" to .sidebar.right.enabledWidgets
tests/sidebar-hosts.sh                                        NEW   static asserts
```

Each file has one responsibility. The helper is a leaf with no dependencies on the rest of the codebase. The service depends only on the helper. The widget depends only on the service. The two parent sidebar files wire the widget into the existing tab strip via the established Tailscale precedent.

---

## Task 1: Helper script + test scaffold + first assertion (TDD pair)

The helper is a leaf: it depends on nothing else in this plan and can be written and tested first. Write the test scaffold and a single assertion (helper exists + key invariants), watch it fail, write the helper, watch it pass.

**Files:**
- Create: `tests/sidebar-hosts.sh`
- Create: `bin/ryoku-hosts-edit`

- [ ] **Step 1: Create the test scaffold with first assertion**

Create `tests/sidebar-hosts.sh` with EXACTLY this content:

```bash
#!/bin/bash

# Static asserts for the Hosts sidebar tab. Mirrors the style of
# tests/sidebar-openvpn.sh and tests/sidebar-tailscale.sh. Spec:
# docs/superpowers/specs/2026-05-08-hosts-sidebar-tab-design.md.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"
  assert_file "$path"
  [[ -x $ROOT_DIR/$path ]] || fail "$path should be executable"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  assert_file "$path"
  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_matches() {
  local path="$1"
  local re="$2"
  assert_file "$path"
  grep -qE "$re" "$ROOT_DIR/$path" || fail "$path should match regex: $re"
}

assert_json_expr() {
  local path="$1"
  local jq_expr="$2"
  local message="$3"

  assert_file "$path"
  jq -e "$jq_expr" "$ROOT_DIR/$path" >/dev/null || fail "$message"
}

# 1. Helper script: pkexec writer with add/remove subcommands and the
#    canonical state-file location.
assert_executable "bin/ryoku-hosts-edit"
assert_contains   "bin/ryoku-hosts-edit" "pkexec install -m 644"
assert_contains   "bin/ryoku-hosts-edit" '# >>> ryoku-hosts (managed) >>>'
assert_contains   "bin/ryoku-hosts-edit" '# <<< ryoku-hosts (managed) <<<'
assert_contains   "bin/ryoku-hosts-edit" '${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/hosts'
assert_matches    "bin/ryoku-hosts-edit" '^[[:space:]]*case [^)]+ in$'
assert_contains   "bin/ryoku-hosts-edit" "ok-noop"
assert_contains   "bin/ryoku-hosts-edit" "is_v4"
assert_contains   "bin/ryoku-hosts-edit" "is_v6"
assert_contains   "bin/ryoku-hosts-edit" "is_domain"

echo "ok: sidebar-hosts static asserts"
```

- [ ] **Step 2: Make the test executable, run it, expect FAIL**

```bash
cd "${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
chmod +x tests/sidebar-hosts.sh
bash tests/sidebar-hosts.sh
```

Expected: non-zero exit, stderr `FAIL: bin/ryoku-hosts-edit should exist`.

- [ ] **Step 3: Create the helper script**

Create `bin/ryoku-hosts-edit` with EXACTLY this content:

```bash
#!/bin/bash
# Add or remove an IP DOMAIN entry inside the ryoku-hosts managed block
# of /etc/hosts. Privileged write runs through `pkexec install` so the
# existing WafflePolkit UI handles the auth prompt.
#
# Usage:
#   ryoku-hosts-edit add IP DOMAIN
#   ryoku-hosts-edit remove IP DOMAIN
#
# Status manifest (per-user state):
#   ${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/hosts/last-op.json
#   {"op":"add|remove","ip":"...","domain":"...","status":"ok|ok-noop|error|cancelled","error":"...","at":"..."}

set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/hosts"
mkdir -p "$STATE_DIR"
LAST_OP="$STATE_DIR/last-op.json"

HOSTS_FILE="/etc/hosts"
BEGIN_MARKER='# >>> ryoku-hosts (managed) >>>'
END_MARKER='# <<< ryoku-hosts (managed) <<<'
ADVISORY='# Edit via Ryoku sidebar: do not modify these lines manually.'

write_result() {
  local op="$1" ip="$2" domain="$3" status="$4" error="${5:-}"
  local ts
  ts="$(date -Iseconds)"
  local s_op="${op//\\/\\\\}";       s_op="${s_op//\"/\\\"}"
  local s_ip="${ip//\\/\\\\}";       s_ip="${s_ip//\"/\\\"}"
  local s_domain="${domain//\\/\\\\}"; s_domain="${s_domain//\"/\\\"}"
  local s_status="${status//\\/\\\\}"; s_status="${s_status//\"/\\\"}"
  local s_error="${error//\\/\\\\}"; s_error="${s_error//\"/\\\"}"
  printf '{"op":"%s","ip":"%s","domain":"%s","status":"%s","error":"%s","at":"%s"}\n' \
    "$s_op" "$s_ip" "$s_domain" "$s_status" "$s_error" "$ts" >"$LAST_OP"
}

is_v4() { [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; }
is_v6() { [[ $1 =~ ^[0-9a-fA-F:]+$ ]] && [[ $1 == *:*:* ]]; }
is_ip()     { is_v4 "$1" || is_v6 "$1"; }
is_domain() { [[ ${#1} -ge 1 && ${#1} -le 253 ]] && [[ $1 =~ ^[a-zA-Z0-9._-]+$ ]]; }

if ! command -v pkexec >/dev/null 2>&1; then
  write_result "${1:-?}" "" "" error "pkexec is not installed"
  exit 1
fi

op="${1:-}"
ip="${2:-}"
domain="${3:-}"

case "$op" in
  add|remove) ;;
  *)
    write_result "$op" "$ip" "$domain" error "usage: ryoku-hosts-edit add|remove IP DOMAIN"
    exit 2
    ;;
esac

if ! is_ip "$ip"; then
  write_result "$op" "$ip" "$domain" error "invalid IP: $ip"
  exit 2
fi
if ! is_domain "$domain"; then
  write_result "$op" "$ip" "$domain" error "invalid domain: $domain"
  exit 2
fi

if [[ ! -r $HOSTS_FILE ]]; then
  write_result "$op" "$ip" "$domain" error "cannot read $HOSTS_FILE"
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Render the new /etc/hosts to $tmp by editing the managed block in-place.
# awk does the entire transformation in one pass: lines outside the block
# pass through unchanged; lines inside the block are dropped (we rebuild
# them); markers themselves are dropped (we re-emit at the end if needed).
# Returns to stdout the file with the managed block STRIPPED.
strip_block() {
  awk -v B="$BEGIN_MARKER" -v E="$END_MARKER" '
    BEGIN { in_block = 0 }
    $0 == B { in_block = 1; next }
    $0 == E { in_block = 0; next }
    !in_block { print }
  ' "$HOSTS_FILE"
}

# Extract the entries currently inside the managed block as IP\tDOMAIN
# pairs, one per line. Skips advisory comments and blank lines.
current_entries() {
  awk -v B="$BEGIN_MARKER" -v E="$END_MARKER" '
    BEGIN { in_block = 0 }
    $0 == B { in_block = 1; next }
    $0 == E { in_block = 0; next }
    in_block && $0 !~ /^[[:space:]]*#/ && NF >= 2 { print $1 "\t" $2 }
  ' "$HOSTS_FILE"
}

# Build the new entry list as a tab-separated stream on stdout.
new_entries() {
  local cur new_pair
  cur="$(current_entries)"
  new_pair="$ip"$'\t'"$domain"
  case "$op" in
    add)
      # If the exact pair already exists, it's a no-op success.
      if printf '%s\n' "$cur" | grep -qxF "$new_pair"; then
        return 1   # signal "no change"
      fi
      printf '%s\n' "$cur"
      printf '%s\n' "$new_pair"
      ;;
    remove)
      # If the pair doesn't exist, it's a no-op success.
      if ! printf '%s\n' "$cur" | grep -qxF "$new_pair"; then
        return 1   # signal "no change"
      fi
      printf '%s\n' "$cur" | grep -vxF "$new_pair" || true
      ;;
  esac
}

entries_after="$(new_entries)" || {
  # No-op success: emit ok-noop without invoking pkexec.
  write_result "$op" "$ip" "$domain" ok-noop ""
  exit 0
}

# Compose the final file content: stripped file (without any old markers)
# followed by the rebuilt managed block (only if there are entries left).
{
  # Strip the existing managed block AND any trailing blank lines.
  # awk pipeline: pass through non-block lines via strip_block, then a
  # second awk drops trailing blanks by buffering until a non-blank line
  # appears, emitting buffered blanks only when followed by content.
  strip_block | awk '
    /^[[:space:]]*$/ { buf = buf $0 "\n"; next }
    { printf "%s%s\n", buf, $0; buf = "" }
  '
  if [[ -n $entries_after ]]; then
    printf '\n%s\n' "$BEGIN_MARKER"
    printf '%s\n' "$ADVISORY"
    printf '%s\n' "$entries_after" | awk -F'\t' 'NF == 2 { printf "%s\t%s\n", $1, $2 }'
    printf '%s\n' "$END_MARKER"
  fi
} >"$tmp"

# Reject empty output as a safety check: if the stripped file plus the
# rebuilt block came out empty, something is wrong, abort the install.
if [[ ! -s $tmp ]]; then
  write_result "$op" "$ip" "$domain" error "computed /etc/hosts is empty, refusing to install"
  exit 1
fi

# Atomic privileged install. Mode 644, owner root:root, exactly matching
# the conventional /etc/hosts perms.
if ! pkexec install -m 644 -o root -g root "$tmp" "$HOSTS_FILE"; then
  rc=$?
  case $rc in
    126) write_result "$op" "$ip" "$domain" cancelled "authentication cancelled" ;;
    *)   write_result "$op" "$ip" "$domain" error "pkexec install failed (rc=$rc)" ;;
  esac
  exit "$rc"
fi

write_result "$op" "$ip" "$domain" ok ""
exit 0
```

- [ ] **Step 4: Make the helper executable, run the test + bash syntax check**

```bash
chmod +x bin/ryoku-hosts-edit
bash -n bin/ryoku-hosts-edit && echo "syntax OK"
bash tests/sidebar-hosts.sh
```

Expected: bash syntax OK, then `ok: sidebar-hosts static asserts` (test passes).

- [ ] **Step 5: Commit**

Stage ONLY the two files:

```bash
cd "${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
git add tests/sidebar-hosts.sh bin/ryoku-hosts-edit
git status --short
```

Verify exactly two files staged. Then:

```bash
git commit -m "feat(hosts): add ryoku-hosts-edit helper for managed-block /etc/hosts edits"
```

---

## Task 2: `RyokuHosts` singleton + qmldir + assertion

The service is the next leaf-up: it depends only on the helper (Task 1). It parses `/etc/hosts`, exposes `entries` and the `add()`/`remove()` action methods, and watches both `/etc/hosts` and the helper's status manifest.

**Files:**
- Modify: `tests/sidebar-hosts.sh` (add second assertion)
- Create: `shell/services/RyokuHosts.qml`
- Modify: `shell/services/qmldir`

- [ ] **Step 1: Add the failing assertion**

Insert ABOVE the FINAL `echo "ok: sidebar-hosts static asserts"` line in `tests/sidebar-hosts.sh`. Add a blank line separator from block #1, then this new block:

```bash
# 2. Service singleton + qmldir registration. Service exposes add/remove
#    action methods, parses the managed block, and watches both
#    /etc/hosts and the helper's last-op.json status manifest.
assert_file       "shell/services/RyokuHosts.qml"
assert_contains   "shell/services/qmldir" "singleton RyokuHosts 1.0 RyokuHosts.qml"
assert_contains   "shell/services/RyokuHosts.qml" "function add"
assert_contains   "shell/services/RyokuHosts.qml" "function remove"
assert_contains   "shell/services/RyokuHosts.qml" 'Quickshell.execDetached(["ryoku-hosts-edit"'
assert_matches    "shell/services/RyokuHosts.qml" "ryoku-hosts.*managed"
assert_contains   "shell/services/RyokuHosts.qml" "/etc/hosts"
assert_matches    "shell/services/RyokuHosts.qml" 'property bool tabOpen'
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
cd "${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
bash tests/sidebar-hosts.sh
```

Expected stderr first line: `FAIL: shell/services/RyokuHosts.qml should exist`.

- [ ] **Step 3: Create the singleton**

Create `shell/services/RyokuHosts.qml` with EXACTLY this content:

```qml
pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

/**
 * Ryoku Hosts service: parses the ryoku-hosts managed block from
 * /etc/hosts and exposes add/remove action methods that go through
 * `pkexec` (the existing WafflePolkit UI catches the auth prompt).
 * No polling: a FileView watches /etc/hosts directly, and a second
 * FileView watches the helper's status manifest for completion + errors.
 */
Singleton {
    id: root

    // ── public state ──────────────────────────────────────────────
    property var entries: []          // [{ip, domain}, ...]
    property bool busy: false         // true while a pkexec helper is in flight
    property string lastError: ""     // populated on helper failure
    property bool tabOpen: false      // driven by parent sidebar layout (symmetry; not load-bearing)

    // ── parse /etc/hosts managed block ────────────────────────────
    Process {
        id: parseProc
        command: ["awk",
            "/^# >>> ryoku-hosts \\(managed\\) >>>/,/^# <<< ryoku-hosts \\(managed\\) <<</",
            "/etc/hosts"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const lines = (this.text || "").split("\n")
                for (const line of lines) {
                    const trimmed = line.trim()
                    if (trimmed.length === 0) continue
                    if (trimmed.startsWith("#")) continue   // skip markers + advisory
                    const parts = trimmed.split(/[ \t]+/)
                    if (parts.length < 2) continue
                    out.push({ ip: parts[0], domain: parts[1] })
                }
                root.entries = out
            }
        }
    }
    Component.onCompleted: parseProc.running = true

    // ── watch /etc/hosts: any external write triggers a re-parse ──
    FileView {
        path: "/etc/hosts"
        watchChanges: true
        onFileChanged: { reload(); parseProc.running = true }
        onLoadFailed: (err) => { /* /etc/hosts always exists; ignore */ }
    }

    // ── watch helper's status manifest for op completion ──────────
    FileView {
        id: opManifest
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
              + "/ryoku/hosts/last-op.json"
        watchChanges: true
        onFileChanged: { reload(); root._parseOpManifest(text()) }
        onLoaded: root._parseOpManifest(text())
        onLoadFailed: (err) => { /* expected before first op */ }
    }

    function _parseOpManifest(jsonText: string): void {
        try {
            const d = JSON.parse(jsonText)
            const status = d.status || ""
            if (status === "ok" || status === "ok-noop") {
                root.busy = false
                root.lastError = ""
                busyTimeout.stop()
                parseProc.running = true
            } else if (status === "cancelled") {
                root.busy = false
                root.lastError = ""    // user cancel: silent
                busyTimeout.stop()
            } else if (status === "error") {
                root.busy = false
                root.lastError = d.error || "unknown error"
                busyTimeout.stop()
            }
        } catch (e) {
            root.busy = false
            root.lastError = "could not parse helper status"
            busyTimeout.stop()
        }
    }

    // ── safety: clear busy if helper hangs (user wanders off) ─────
    Timer {
        id: busyTimeout
        interval: 30000
        repeat: false
        onTriggered: {
            root.busy = false
            root.lastError = ""
        }
    }

    // ── public API ────────────────────────────────────────────────
    function add(ip: string, domain: string): void {
        if (root.busy) return
        if (!ip || !domain) return
        root.busy = true
        root.lastError = ""
        busyTimeout.restart()
        Quickshell.execDetached(["ryoku-hosts-edit", "add", ip, domain])
    }

    function remove(ip: string, domain: string): void {
        if (root.busy) return
        if (!ip || !domain) return
        root.busy = true
        root.lastError = ""
        busyTimeout.restart()
        Quickshell.execDetached(["ryoku-hosts-edit", "remove", ip, domain])
    }

    function clearError(): void {
        root.lastError = ""
    }
}
```

- [ ] **Step 4: Register the singleton in `shell/services/qmldir`**

Open `shell/services/qmldir`. Find the existing line `singleton RyokuTailscale 1.0 RyokuTailscale.qml` (currently line 59). Insert the new line immediately after it:

```
singleton RyokuHosts 1.0 RyokuHosts.qml
```

Preserve every other line of `qmldir` byte-for-byte.

- [ ] **Step 5: Run the test + qml-check**

```bash
bash tests/sidebar-hosts.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: sidebar-hosts static asserts`. qml-check exits 0; the new singleton parses.

If qml-check reports an unresolved import or property, double-check imports match `shell/services/RyokuTailscale.qml`'s exactly. STOP and report rather than guessing.

- [ ] **Step 6: Commit**

Stage ONLY the three files:

```bash
git add tests/sidebar-hosts.sh shell/services/RyokuHosts.qml shell/services/qmldir
git commit -m "feat(services): add RyokuHosts singleton bound to /etc/hosts managed block"
```

---

## Task 3: Create `HostsTab.qml` widget

Author the sidebar tab widget. Form on top, error banner, header, list of entries with per-row remove buttons.

**Files:**
- Modify: `tests/sidebar-hosts.sh` (add third assertion)
- Create: `shell/modules/sidebarRight/hosts/HostsTab.qml`

- [ ] **Step 1: Add the failing assertion**

Insert ABOVE the FINAL `echo "ok: sidebar-hosts static asserts"` line, with a blank line separator from block #2:

```bash
# 3. Sidebar tab widget exists, binds to RyokuHosts state, calls add()
#    and remove(), and uses the canonical "dns" + "close" Material symbols.
assert_file       "shell/modules/sidebarRight/hosts/HostsTab.qml"
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "RyokuHosts.entries"
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "RyokuHosts.add("
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "RyokuHosts.remove("
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" '"dns"'
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" '"close"'
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "RyokuHosts.clearError()"
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "!RyokuHosts.busy"
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "_isValidIp"
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "_isValidDomain"
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/sidebar-hosts.sh
```

Expected stderr first line: `FAIL: shell/modules/sidebarRight/hosts/HostsTab.qml should exist`.

- [ ] **Step 3: Create the widget**

Create `shell/modules/sidebarRight/hosts/HostsTab.qml` with EXACTLY this content:

```qml
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * Hosts editor sidebar tab. Adds and removes entries inside the
 * ryoku-hosts managed block of /etc/hosts via the existing pkexec +
 * WafflePolkit prompt UI. Mirrors OpenVpnTab.qml's overall shape.
 */
Item {
    id: root
    anchors.fill: parent

    readonly property color colAccent:
        Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colPrimary
        : Appearance.colors.colPrimary

    // Loose v4-or-v6 validation, same as the helper's regex.
    function _isValidIp(s) {
        if (!s) return false
        if (/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/.test(s)) return true
        if (/^[0-9a-fA-F:]+$/.test(s) && s.indexOf(":") !== s.lastIndexOf(":")) return true
        return false
    }
    function _isValidDomain(s) {
        if (!s || s.length > 253) return false
        return /^[a-zA-Z0-9._-]+$/.test(s)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Add-entry form.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialTextField {
                id: ipField
                Layout.preferredWidth: 160
                placeholderText: "IP"
                onAccepted: addBtn.clicked()
            }
            MaterialTextField {
                id: domainField
                Layout.fillWidth: true
                placeholderText: "Domain"
                onAccepted: addBtn.clicked()
            }
            DialogButton {
                id: addBtn
                buttonText: "Add"
                enabled: !RyokuHosts.busy
                        && root._isValidIp(ipField.text)
                        && root._isValidDomain(domainField.text)
                onClicked: {
                    RyokuHosts.add(ipField.text, domainField.text)
                    ipField.text = ""
                    domainField.text = ""
                    ipField.forceActiveFocus()
                }
            }
        }

        // Inline error banner.
        Rectangle {
            visible: RyokuHosts.lastError.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: errRow.implicitHeight + 16
            radius: Appearance.rounding.small
            color: ColorUtils.transparentize(Appearance.m3colors.m3error ?? "#fb4934", 0.85)
            border.width: 1
            border.color: ColorUtils.transparentize(Appearance.m3colors.m3error ?? "#fb4934", 0.5)

            RowLayout {
                id: errRow
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8
                MaterialSymbol {
                    text: "error_outline"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3error ?? "#fb4934"
                    Layout.alignment: Qt.AlignTop
                }
                StyledText {
                    text: "Error: " + RyokuHosts.lastError
                    color: Appearance.m3colors.m3error ?? "#fb4934"
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                Button {
                    text: "x"
                    flat: true
                    onClicked: RyokuHosts.clearError()
                    Layout.alignment: Qt.AlignTop
                }
            }
        }

        // Header row.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: "dns"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
            StyledText {
                text: "Managed entries"
                color: Appearance.colors.colOnLayer1
                font.weight: Font.Bold
                font.pixelSize: Appearance.font.pixelSize.normal
            }
            StyledText {
                visible: RyokuHosts.entries.length > 0
                text: RyokuHosts.entries.length === 1
                      ? "1 entry"
                      : RyokuHosts.entries.length + " entries"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            Item { Layout.fillWidth: true }
        }

        // List area: empty-state hero or scrollable list.
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: RyokuHosts.entries.length === 0 ? "transparent" : Appearance.colors.colLayer2
            radius: Appearance.rounding.normal
            border.width: RyokuHosts.entries.length === 0 ? 1 : 0
            border.color: RyokuHosts.entries.length === 0
                          ? ColorUtils.transparentize(Appearance.colors.colLayer3Hover, 0.5)
                          : "transparent"

            // Empty-state hero.
            ColumnLayout {
                visible: RyokuHosts.entries.length === 0
                anchors.centerIn: parent
                width: Math.min(parent.width - 32, 320)
                spacing: 14

                MaterialSymbol {
                    text: "dns"
                    iconSize: 56
                    color: Appearance.colors.colSubtext
                    Layout.alignment: Qt.AlignHCenter
                }
                StyledText {
                    text: "No managed entries yet"
                    color: Appearance.colors.colOnLayer1
                    font.weight: Font.Bold
                    font.pixelSize: Appearance.font.pixelSize.larger ?? 16
                    Layout.alignment: Qt.AlignHCenter
                }
                StyledText {
                    text: "Add an IP and domain above to pin a hostname locally."
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            // Entry list.
            ScrollView {
                visible: RyokuHosts.entries.length > 0
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                ColumnLayout {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: RyokuHosts.entries
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8

                            StyledText {
                                text: modelData.ip
                                color: Appearance.colors.colOnLayer2
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.family: Appearance.font.family.monospace ?? "monospace"
                                Layout.preferredWidth: 160
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: modelData.domain
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                id: removeBtn
                                implicitWidth: 36
                                implicitHeight: 36
                                radius: Appearance.rounding.small
                                color: removeMouse.containsPress ? ColorUtils.transparentize(root.colAccent, 0.7)
                                       : removeMouse.containsMouse ? Appearance.colors.colLayer2Hover
                                       : "transparent"
                                border.width: 1
                                border.color: ColorUtils.transparentize(Appearance.colors.colLayer3Hover, 0.5)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: removeMouse.containsMouse ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                                }
                                MouseArea {
                                    id: removeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !RyokuHosts.busy
                                    onClicked: RyokuHosts.remove(modelData.ip, modelData.domain)
                                }
                                StyledToolTip {
                                    extraVisibleCondition: removeMouse.containsMouse
                                    text: "Remove"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run the test + qml-check**

```bash
bash tests/sidebar-hosts.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: sidebar-hosts static asserts`. qml-check exits 0.

If qml-check reports unresolved imports or properties, STOP and report. Do NOT add new properties or restructure.

- [ ] **Step 5: Commit**

```bash
git add tests/sidebar-hosts.sh shell/modules/sidebarRight/hosts/HostsTab.qml
git commit -m "feat(sidebar): add HostsTab widget with form, list, and per-row remove button"
```

---

## Task 4: Wire `HostsTab` into `BottomWidgetGroup.qml`

The regular sidebar layout is the primary tab strip. Add the import, the `Component` wrapper, the `allTabs` entry, the `tabOpen` Binding, and the `enabledWidgets` fallback default entry.

**Files:**
- Modify: `tests/sidebar-hosts.sh` (add fourth assertion)
- Modify: `shell/modules/sidebarRight/BottomWidgetGroup.qml`

- [ ] **Step 1: Add the failing assertion**

Insert ABOVE the FINAL `echo "ok: sidebar-hosts static asserts"` line, with a blank line separator from block #3:

```bash
# 4. BottomWidgetGroup imports the hosts module, wraps HostsTab in a
#    Component, declares the tab in allTabs, drives RyokuHosts.tabOpen,
#    and includes "hosts" in the enabledWidgets fallback default.
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "import qs.modules.sidebarRight.hosts"
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "id: hostsWidgetComponent"
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" '"type": "hosts"'
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "target: RyokuHosts"
assert_matches    "shell/modules/sidebarRight/BottomWidgetGroup.qml" '"openvpn",[[:space:]]*"hosts"'
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/sidebar-hosts.sh
```

Expected stderr first line: `FAIL: shell/modules/sidebarRight/BottomWidgetGroup.qml should contain: import qs.modules.sidebarRight.hosts`.

- [ ] **Step 3: Add the import**

Edit `shell/modules/sidebarRight/BottomWidgetGroup.qml`. Locate the block of imports near the top of the file (lines 1-12 area). Find the existing line:

```qml
import qs.modules.sidebarRight.openvpn
```

Add immediately after it:

```qml
import qs.modules.sidebarRight.hosts
```

- [ ] **Step 4: Add the `Component` wrapper for HostsTab**

In the same file, locate the existing OpenVPN component wrapper (around lines 67-73):

```qml
    // OpenVPN component
    Component {
        id: openVpnWidgetComponent
        OpenVpnTab {
            anchors.fill: parent
            anchors.margins: 5
        }
    }
```

Add immediately after the closing `}` of that block:

```qml

    // Hosts component
    Component {
        id: hostsWidgetComponent
        HostsTab {
            anchors.fill: parent
            anchors.margins: 5
        }
    }
```

- [ ] **Step 5: Add the entry to `allTabs`**

Locate the `allTabs` array (around lines 37-44). Find the last entry:

```qml
        {"type": "openvpn", "name": Translation.tr("VPN"), "icon": "vpn_key", "widget": openVpnWidgetComponent},
```

Add a new line immediately after it (inside the array's closing `]`):

```qml
        {"type": "hosts", "name": Translation.tr("Hosts"), "icon": "dns", "widget": hostsWidgetComponent},
```

- [ ] **Step 6: Update the `enabledWidgets` fallback default**

Locate the line:

```qml
        return Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "timer", "openvpn"]
```

Replace it with:

```qml
        return Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "timer", "openvpn", "hosts"]
```

- [ ] **Step 7: Add the `tabOpen` Binding for `RyokuHosts`**

Locate the existing Binding for `RyokuTailscale.tabOpen` (around lines 127-131). It looks like:

```qml
    Binding {
        target: RyokuTailscale
        property: "tabOpen"
        value: root.currentTabType === "openvpn" && !root.collapsed
    }
```

Add an identical-looking sibling Binding immediately after it, with `target: RyokuHosts` and the value condition matching the new tab type:

```qml
    Binding {
        target: RyokuHosts
        property: "tabOpen"
        value: root.currentTabType === "hosts" && !root.collapsed
    }
```

- [ ] **Step 8: Run the test + qml-check + verify diff is purely additive**

```bash
git diff -- shell/modules/sidebarRight/BottomWidgetGroup.qml
```

Expected: only `+` lines for the five edits (import, Component, allTabs entry, fallback array, Binding) plus one tiny `+/-` pair on the fallback array line (the only line edited rather than inserted). Verify no other changes.

```bash
bash tests/sidebar-hosts.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: sidebar-hosts static asserts`. qml-check exits 0.

If `git diff` shows pre-existing user modifications elsewhere in the file, STOP and report `BLOCKED`.

- [ ] **Step 9: Commit**

```bash
git add tests/sidebar-hosts.sh shell/modules/sidebarRight/BottomWidgetGroup.qml
git commit -m "feat(sidebar): wire HostsTab into BottomWidgetGroup tab strip"
```

---

## Task 5: Wire `HostsTab` into `CompactSidebarRightContent.qml`

The compact sidebar layout has its own tab structure (`widgetSections` array, `Component` wrappers). Mirror the BottomWidgetGroup wiring but in the compact-layout shape.

**Files:**
- Modify: `tests/sidebar-hosts.sh` (add fifth assertion)
- Modify: `shell/modules/sidebarRight/CompactSidebarRightContent.qml`

- [ ] **Step 1: Add the failing assertion**

Insert ABOVE the FINAL `echo "ok: sidebar-hosts static asserts"` line, with a blank line separator from block #4:

```bash
# 5. CompactSidebarRightContent imports the hosts module, wraps HostsTab
#    in a Component, declares the section in widgetSections, drives
#    RyokuHosts.tabOpen, and includes "hosts" in the enabledWidgets
#    fallback default.
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "import qs.modules.sidebarRight.hosts"
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "id: hostsComponent"
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" 'id: "hosts"'
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "target: RyokuHosts"
assert_matches    "shell/modules/sidebarRight/CompactSidebarRightContent.qml" '"openvpn",[[:space:]]*"hosts"'
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/sidebar-hosts.sh
```

Expected stderr first line: `FAIL: shell/modules/sidebarRight/CompactSidebarRightContent.qml should contain: import qs.modules.sidebarRight.hosts`.

- [ ] **Step 3: Add the import**

Edit `shell/modules/sidebarRight/CompactSidebarRightContent.qml`. Locate the imports block (around lines 14-46). Find:

```qml
import qs.modules.sidebarRight.openvpn
```

Add immediately after it:

```qml
import qs.modules.sidebarRight.hosts
```

- [ ] **Step 4: Add the `Component` wrapper for HostsTab**

In the same file, locate the existing `openvpnComponent` block (starts around line 529 with `id: openvpnComponent`, ends with the matching `}` after `OpenVpnTab { ... }`). Read about 35 lines starting at line 529 to see the full pattern:

```bash
sed -n '529,565p' shell/modules/sidebarRight/CompactSidebarRightContent.qml
```

Note the structure: `Component { id: openvpnComponent; Item { ... StyledRectangularShadow ... Rectangle { id: openvpnSurface ... OpenVpnTab { ... } ... } } }`.

Mirror this verbatim with hosts substitutions. Add a new `Component` block immediately after the closing `}` of `openvpnComponent`:

```qml
    Component {
        id: hostsComponent
        Item {
            anchors.fill: parent

            StyledRectangularShadow {
                target: hostsSurface
                visible: !bg.ryokuEverywhere && !bg.auroraEverywhere && !bg.angelEverywhere
                blur: 0.35 * Appearance.sizes.elevationMargin
            }

            Rectangle {
                id: hostsSurface
                anchors.fill: parent
                anchors.margins: 8
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                    : Appearance.ryokuEverywhere ? Appearance.ryoku.roundingNormal
                    : Appearance.rounding.normal
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer1
                    : Appearance.auroraEverywhere ? "transparent"
                    : Appearance.colors.colLayer1
                border.width: Appearance.angelEverywhere ? 0 : (Appearance.ryokuEverywhere ? 1 : 0)
                border.color: Appearance.angelEverywhere ? "transparent"
                    : Appearance.ryokuEverywhere ? Appearance.ryoku.colBorder : "transparent"
                clip: true

                AngelPartialBorder { targetRadius: hostsSurface.radius; coverage: 0.5 }

                HostsTab {
                    anchors.fill: parent
                    anchors.margins: 5
                }
            }
        }
    }
```

If the actual `openvpnComponent` block in the file differs from the structure above (e.g. has additional decorations the spec wasn't aware of), copy that exact structure with `openvpn`/`OpenVpnTab` replaced by `hosts`/`HostsTab` and `openvpnSurface` replaced by `hostsSurface`. Stop and report if the substitution would lose any visible behavior.

- [ ] **Step 5: Add entry to `widgetSections`**

Locate the `widgetSections` array (around line 694). Find:

```qml
            {id: "openvpn",    icon: "vpn_key",       label: Translation.tr("VPN"),        component: openvpnComponent},
```

Add a new line immediately after it (inside the array):

```qml
            {id: "hosts",      icon: "dns",           label: Translation.tr("Hosts"),      component: hostsComponent},
```

Match the column-aligned spacing of the existing entries.

- [ ] **Step 6: Update the `enabledWidgets` fallback default**

Locate the line (around line 685):

```qml
        const enabled = Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "timer", "openvpn"]
```

Replace with:

```qml
        const enabled = Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "timer", "openvpn", "hosts"]
```

- [ ] **Step 7: Add the `tabOpen` Binding for `RyokuHosts`**

Locate the existing Binding for `RyokuTailscale.tabOpen` (around lines 710-714). It looks like:

```qml
    Binding {
        target: RyokuTailscale
        property: "tabOpen"
        value: root.sections[root.activeSection]?.id === "openvpn"
    }
```

Add an identical-looking sibling Binding immediately after it, with `target: RyokuHosts` and the value condition keying on the new section id:

```qml
    Binding {
        target: RyokuHosts
        property: "tabOpen"
        value: root.sections[root.activeSection]?.id === "hosts"
    }
```

- [ ] **Step 8: Run the test + qml-check**

```bash
git diff -- shell/modules/sidebarRight/CompactSidebarRightContent.qml
```

Expected: `+` lines for the five edits (import, Component, widgetSections entry, fallback array, Binding). One tiny `+/-` pair on the fallback array line. No other changes.

```bash
bash tests/sidebar-hosts.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: sidebar-hosts static asserts`. qml-check exits 0.

- [ ] **Step 9: Commit**

```bash
git add tests/sidebar-hosts.sh shell/modules/sidebarRight/CompactSidebarRightContent.qml
git commit -m "feat(sidebar): wire HostsTab into CompactSidebarRightContent layout"
```

---

## Task 6: Add `"hosts"` to the shell-defaults `enabledWidgets`

The hardcoded fallbacks in the QML files (Tasks 4 and 5) cover existing user configs that pre-date this feature. The shell defaults file gives fresh installs the same list.

**Files:**
- Modify: `tests/sidebar-hosts.sh` (add sixth assertion)
- Modify: `shell/defaults/config.json`

- [ ] **Step 1: Add the failing assertion**

Insert ABOVE the FINAL `echo "ok: sidebar-hosts static asserts"` line, with a blank line separator from block #5:

```bash
# 6. Shell defaults include "hosts" in sidebar.right.enabledWidgets so
#    the tab appears for fresh installs.
assert_json_expr  "shell/defaults/config.json" '.sidebar.right.enabledWidgets | index("hosts") != null' \
  "shell defaults should include 'hosts' in sidebar.right.enabledWidgets"
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/sidebar-hosts.sh
```

Expected stderr first line: `FAIL: shell defaults should include 'hosts' in sidebar.right.enabledWidgets`.

- [ ] **Step 3: Add `"hosts"` to the array**

Edit `shell/defaults/config.json`. Locate the `.sidebar.right.enabledWidgets` array. Currently it contains:

```json
[
  "dashboard",
  "calendar",
  "events",
  "todo",
  "notepad",
  "calculator",
  "sysmon",
  "timer",
  "openvpn"
]
```

Add `"hosts"` as a new entry after `"openvpn"`, preserving the rest of the file byte-for-byte:

```json
[
  "dashboard",
  "calendar",
  "events",
  "todo",
  "notepad",
  "calculator",
  "sysmon",
  "timer",
  "openvpn",
  "hosts"
]
```

- [ ] **Step 4: Validate JSON, run all tests**

```bash
jq . shell/defaults/config.json >/dev/null && echo "JSON valid"
bash tests/sidebar-hosts.sh
bash tests/sidebar-tailscale.sh
bash tests/sidebar-openvpn.sh
bash tests/bar-secpulse.sh
bash tests/topbar-removal-regression.sh
fish shell/scripts/qml-check.fish
echo "all green"
```

Expected: `JSON valid`, every test prints its `ok:` / `PASS:` line, and `all green` at the end.

- [ ] **Step 5: Commit**

```bash
git add tests/sidebar-hosts.sh shell/defaults/config.json
git commit -m "feat(defaults): add hosts to sidebar.right.enabledWidgets so fresh installs see the tab"
```

---

## Task 7: Deploy to live runtime, restart shell, visual smoke test

Per `docs/ui-patterns.md`, dev to runtime sync via rsync is the safe preview path.

**Files:** none (no commits)

- [ ] **Step 1: Sync dev shell to the runtime tree**

```bash
DEV="${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
RUNT="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell"
rsync -a --delete "$DEV/shell/" "$RUNT/"
```

Expected: command exits 0, no stderr.

- [ ] **Step 2: Make sure the helper is on PATH**

The Quickshell process inherits PATH from the user session, which includes `~/.local/share/ryoku/bin/`. Until the next `ryoku-update` runs and rsyncs the new helper into `~/.local/share/ryoku/bin/`, copy it manually for this preview:

```bash
install -m 755 "$DEV/bin/ryoku-hosts-edit" "$HOME/.local/share/ryoku/bin/ryoku-hosts-edit"
```

(The next `ryoku-update` will do this automatically via `install/preflight/ensure-shell-deployment.sh`.)

- [ ] **Step 3: Restart the user shell**

```bash
systemctl --user restart ryoku-shell.service
sleep 2
systemctl --user is-active ryoku-shell.service
```

Expected: `is-active` prints `active`.

- [ ] **Step 4: Visual smoke test (manual)**

1. Open the right sidebar. The bottom tab strip should now have a "Hosts" tab with a `dns` icon, after the VPN tab.
2. Click the Hosts tab. The top of the tab is a form with two text fields ("IP" and "Domain") and an "Add" button (disabled while either field is empty or invalid).
3. Below the form is a header "Managed entries" + count + an empty-state hero with `dns` icon and "No managed entries yet" text.
4. Type `192.168.1.10` in IP and `test.local` in Domain. The Add button enables.
5. Click Add. The polkit prompt UI appears (the existing `WafflePolkit` window).
6. Authenticate. The form fields clear, the empty-state hero disappears, and a single row appears: `192.168.1.10` and `test.local` with a small `close` button on the right.
7. Verify the entry was written: `getent hosts test.local` should print `192.168.1.10  test.local`. Or run `grep -A2 'ryoku-hosts' /etc/hosts` to see the managed block.
8. Click the `close` button on the row. Polkit prompts again. Authenticate. The row disappears, the empty-state hero returns, and the managed block is removed from `/etc/hosts` (since the last entry was just removed).
9. Test cancel: type a new IP/domain, click Add, then cancel the polkit prompt. The Add button re-enables, no error banner appears (cancellation is silent), `/etc/hosts` is unchanged.
10. Test invalid input: type `not-an-ip` in IP. The Add button stays disabled.
11. Test the compact sidebar layout (if you use it): switch to compact via the layout toggle and confirm the Hosts tab is also present there.

If any check fails, identify which task introduced the regression and `git revert` that specific commit.

---

## Task 8: Push to origin/main (after user confirms visual)

**Files:** none (push only)

- [ ] **Step 1: Wait for explicit user confirmation**

Do not push without the user saying the visual smoke test passed.

- [ ] **Step 2: Push**

```bash
cd "${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
git push origin main
```

Expected: push succeeds; six commits land on `main` (Task 1 helper, Task 2 service+qmldir, Task 3 widget, Task 4 BottomWidgetGroup wiring, Task 5 CompactSidebarRightContent wiring, Task 6 defaults). Other users running `ryoku-update` will pick up the Hosts tab on their next update; the now-fixed install pipeline (`install/config/shell.sh` from earlier this session) propagates the new files correctly through the four-tree path. No migration is needed because the `enabledWidgets` runtime fallback covers existing user configs that don't yet contain `"hosts"`.

---

## Test runbook (full)

When the plan is complete, the canonical verification command is:

```bash
cd "${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
bash tests/sidebar-hosts.sh \
  && bash tests/sidebar-tailscale.sh \
  && bash tests/sidebar-openvpn.sh \
  && bash tests/bar-secpulse.sh \
  && bash tests/topbar-removal-regression.sh \
  && fish shell/scripts/qml-check.fish \
  && echo "all green"
```

Every test should print at least one `ok:` / `PASS:` line and the chain ends with `all green`.
