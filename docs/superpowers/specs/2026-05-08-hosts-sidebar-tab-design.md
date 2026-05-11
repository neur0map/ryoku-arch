# Hosts Editor Sidebar Tab

Date: 2026-05-08
Status: Approved (pending implementation plan)

## Summary

Add a new tab to the right sidebar's bottom widget group: a focused editor for `/etc/hosts` that lets the user add and remove IP+domain entries within a delimited managed block. Privileged writes go through `pkexec`, which the existing `WafflePolkit` UI catches as the password prompt. No topbar widget. No new polkit rule.

## Motivation

A frequent need on a security-positioned workstation: pin a domain to a lab IP, route around a flaky DNS resolver, or shadow a hostname for a CTF target. Doing it from a terminal is fast for the maintainer, but cumbersome for the kind of one-off "make `thm.box` resolve to `10.10.10.5`" that comes up once per engagement and is easy to leave dangling. A focused sidebar tab makes the operation a two-field form, makes the inventory of additions visible, and confines edits to a delimited block so the rest of `/etc/hosts` (system defaults, anything you wrote by hand) stays untouched.

## Non-goals

1. No topbar indicator. The user explicitly requested no bar icon.
2. No editing of system entries. `127.0.0.1 localhost`, `::1 localhost`, IPv6 link-local, container hosts, and anything outside the managed-block markers are read-only from this UI's perspective.
3. No multi-domain-per-line. `/etc/hosts` allows `IP DOMAIN1 DOMAIN2 ...`, but supporting it doubles UI complexity for marginal gain. To point one IP at two domains, add two rows.
4. No per-entry comments, aliases, hostnames vs FQDNs, MX-style metadata.
5. No DNS lookup tester ("does this resolve now?" button) inside the tab. `dig` is one Alt+Tab away.
6. No new polkit rule. Helper uses plain `pkexec`; the existing `shell/modules/polkit/Polkit.qml` + `WafflePolkit.qml` UI renders the prompt every time. (A `49-ryoku-hosts.rules` for password-less control is a separate decision if the user wants it later.)
7. No bar.modules toggle. Tab visibility is governed by `sidebar.right.enabledWidgets` like every other sidebar tab.
8. No history, undo, or import/export of the managed block. The block IS the state; editing by hand outside the UI is fine and the next poll picks up the change.

## Architecture

```
shell/
  services/
    RyokuHosts.qml                                  NEW   singleton, parses /etc/hosts managed block
    qmldir                                          EDIT  register the singleton
  modules/
    sidebarRight/
      BottomWidgetGroup.qml                         EDIT  add tab, drive RyokuHosts.tabOpen Binding
      CompactSidebarRightContent.qml                EDIT  same, for compact sidebar layout
      hosts/
        HostsTab.qml                                NEW   form + list + per-row remove button
  defaults/
    config.json                                     EDIT  add "hosts" to .sidebar.right.enabledWidgets
bin/
  ryoku-hosts-edit                                  NEW   pkexec helper, add/remove subcommands
tests/
  sidebar-hosts.sh                                  NEW   static asserts: service, tab, helper, defaults
```

### Boundaries

| Unit | Responsibility | Depends on |
|---|---|---|
| `RyokuHosts.qml` | Read `/etc/hosts`, expose parsed managed-block entries, expose `add()`/`remove()` action methods, surface error/busy state | `Quickshell.Io`, `pkexec`, `bin/ryoku-hosts-edit` |
| `HostsTab.qml` | Render add-form + entry list with remove buttons, bind to `RyokuHosts` | `RyokuHosts`, `MaterialTextField`, `DialogButton`, `MaterialSymbol`, `StyledText`, `StyledToolTip` |
| `bin/ryoku-hosts-edit` | Validate inputs, edit `/etc/hosts` atomically via `pkexec install`, write status manifest for QML | `pkexec`, `awk`, `install`, `/etc/hosts` |
| `BottomWidgetGroup.qml` + `CompactSidebarRightContent.qml` | Register tab, drive `tabOpen` so the service polls only when the tab is selected | `RyokuHosts`, `HostsTab.qml` |

Each unit has one purpose and a stable interface. The service can be tested without reading the tab; the tab can be understood without reading the helper; the helper is a self-contained Bash script.

### Path conventions (per docs/ui-patterns.md tree map)

| Tree | Path | This feature writes there | Why |
|---|---|---|---|
| Dev | `~/prowl/ryoku-arch/shell/...` | Yes (during development) | Git source of truth; everything in this design ships from here |
| Installed repo | `~/.local/share/ryoku/shell/...` | Only `ryoku-update` | Pulled by `git pull`, not touched by hand |
| SHELL_PATH | `~/.local/share/ryoku-shell/...` | Only the install/update flow | Auto-synced from installed repo per the Tailscale-session install fix |
| Runtime | `~/.config/quickshell/ryoku-shell/...` | Only the install/update flow (or rsync preview) | What Quickshell loads now |
| User state | `${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/hosts/` | Helper writes `last-op.json` here (mirrors OVPN convention at `bin/ryoku-openvpn-import:8`) | Per-user, per-feature state directory |
| System state | `/etc/hosts` | Helper writes this via `pkexec install` | The actual file under management |

## Managed-block format

The block lives at the bottom of `/etc/hosts` and is anchored by exact-match marker lines:

```
# >>> ryoku-hosts (managed) >>>
# Edit via Ryoku sidebar: do not modify these lines manually.
192.168.1.10    server.local
10.0.0.5        thm.box
fd7a:115c::1    tail.example
# <<< ryoku-hosts (managed) <<<
```

Rules:

1. **Markers are byte-for-byte exact**. Helper anchors via `awk` on `^# >>> ryoku-hosts \(managed\) >>>$` and `^# <<< ryoku-hosts \(managed\) <<<$`. A user who edits the markers by hand breaks the contract; this is acceptable for a single-user workstation feature.
2. **Block is appended on first add** if absent. Removed entirely (markers + advisory comment) when the last entry is removed. No empty block left dangling.
3. **One IP + one domain per line**. Entries are written tab-separated for legibility (`printf '%s\t%s\n' "$ip" "$domain"`).
4. **IPv4 and IPv6 both accepted**. The validator accepts dotted-quad (`\d{1,3}(\.\d{1,3}){3}`) or any colon-separated hex sequence (`[0-9a-fA-F:]+` containing at least two colons). No zone-identifier suffix support (e.g. `fe80::1%eth0`); rejected as user error.
5. **Domain validation**: `^[a-zA-Z0-9]([a-zA-Z0-9._-]{0,251}[a-zA-Z0-9])?$`. Length cap 253. Underscore allowed because some lab/CTF setups use it.
6. **De-duplication**: adding an exact `IP DOMAIN` pair already in the managed block is a no-op success (helper exits 0 with `status: "ok-noop"`).
7. **Removal of nonexistent entries**: helper exits 0 with `status: "ok-noop"`, no error surfaced.

## Service surface (`RyokuHosts`)

Mirrors `RyokuOpenVpn.qml` shape: `pragma Singleton`, gated polling, post-action poll, FileView for state-file watching. Public surface:

```qml
property var entries          // [{ip: "192.168.1.10", domain: "server.local"}, ...]
property bool busy            // true while a pkexec helper is in flight
property string lastError     // "" when fine, populated with helper's error string on failure
property bool tabOpen: false  // driven by parent sidebar layout

function add(ip: string, domain: string): void
function remove(ip: string, domain: string): void
```

### Polling and watching

Two FileView instances and one Process:

1. **`FileView /etc/hosts`** with `watchChanges: true`: re-parses on any external edit (helper, hand-edit in vim, package-manager touch, etc.).
2. **`FileView ${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/hosts/last-op.json`** with `watchChanges: true`: signals helper completion plus error info.
3. **One-shot `Process` to read `/etc/hosts`** (used at startup and when FileView fires): runs `awk '/^# >>> ryoku-hosts \(managed\) >>>/,/^# <<< ryoku-hosts \(managed\) <<</'` to extract the block, parses lines into `entries`. No pkexec needed: `/etc/hosts` is world-readable.

No periodic timer. Reads are event-driven via the FileViews. This is simpler than `RyokuOpenVpn`'s 30s status poll because `/etc/hosts` changes are rare and detectable instantly via filesystem watch, whereas systemd-unit state changes are not directly watchable as a file.

### Action methods

```qml
function add(ip: string, domain: string): void {
    if (root.busy) return
    root.busy = true
    root.lastError = ""
    busyTimeout.restart()
    Quickshell.execDetached(["ryoku-hosts-edit", "add", ip, domain])
}

function remove(ip: string, domain: string): void {
    if (root.busy) return
    root.busy = true
    root.lastError = ""
    busyTimeout.restart()
    Quickshell.execDetached(["ryoku-hosts-edit", "remove", ip, domain])
}
```

`busyTimeout` is a 30s `Timer` that clears `busy` if the helper hangs (e.g., user takes a long time at the polkit prompt and never finishes). When `last-op.json` is updated by the helper, the FileView reads it: if `status` is `ok` or `ok-noop`, clear busy and lastError; if `error` or `cancelled`, clear busy and surface `error` field as `lastError`.

The helper is invoked by bare name (`"ryoku-hosts-edit"`), not absolute path. This matches `RyokuOpenVpn.qml:172` (`Quickshell.execDetached(["ryoku-openvpn-import"])`). The Quickshell process inherits the user's PATH which includes `~/.local/share/ryoku/bin/` (verified earlier in this session by inspecting `/proc/<qs-pid>/environ`).

### Tab-open gate

The polling flag follows the established pattern. Two parent files drive it (matching how `RyokuOpenVpn.tabOpen` and `RyokuTailscale.tabOpen` are driven):

- `shell/modules/sidebarRight/BottomWidgetGroup.qml` adds a `Binding { target: RyokuHosts; property: "tabOpen"; value: root.currentTabType === "hosts" && !root.collapsed }` next to the existing OVPN/Tailscale Bindings.
- `shell/modules/sidebarRight/CompactSidebarRightContent.qml` adds the corresponding compact-layout Binding.

Tab-open gate isn't strictly required for `/etc/hosts` (FileView is event-driven, no polling cost), but the property is exposed for symmetry with sibling services and for future use (e.g., a refresh-on-tab-switch nudge if the FileView ever drops a notification). The Binding keeps the public-property contract uniform across the three services.

## Helper script (`bin/ryoku-hosts-edit`)

Bash, executable, in `bin/` next to `ryoku-openvpn-import`. Mirrors the OVPN helper's structure: the script runs as the user, validates, prepares a temp file, then `pkexec`s the privileged write.

### Subcommands

```
ryoku-hosts-edit add IP DOMAIN
ryoku-hosts-edit remove IP DOMAIN
```

Each subcommand:

1. Sets up state dir `${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/hosts` and the manifest file `last-op.json`. Same convention as `bin/ryoku-openvpn-import:8`.
2. Validates IP and DOMAIN against the regexes documented in the managed-block format section.
3. Reads `/etc/hosts` into a temp file. For `add`: appends a new line inside the managed block, creating the block if absent, deduping if the exact pair exists. For `remove`: deletes the matching line, dropping the markers if the block becomes empty.
4. Calls `pkexec install -m 644 -o root -g root "$tmpfile" /etc/hosts`. The `install` command does the atomic replace and preserves correct permissions.
5. Writes `last-op.json` with `{op, ip, domain, status, error, at}`. Status is one of `ok`, `ok-noop`, `error`, `cancelled` (pkexec exit 126).

Error cases the helper surfaces explicitly:

| Trigger | `status` | `error` |
|---|---|---|
| IP regex mismatch | `error` | `"invalid IP: <value>"` |
| Domain regex mismatch or length cap | `error` | `"invalid domain: <value>"` |
| pkexec cancelled by user | `cancelled` | `"authentication cancelled"` |
| pkexec failed (other) | `error` | `"pkexec install failed (rc=$rc)"` |
| /etc/hosts unreadable | `error` | `"cannot read /etc/hosts"` |
| /etc/hosts vanished mid-edit (vanishingly unlikely) | `error` | `"/etc/hosts disappeared"` |

The script never bypasses the validator and never writes to `/etc/hosts` without going through `pkexec install`. No shortcut for the maintainer's account.

### Why `install` and not `cp`/`mv`/`tee`

`install -m 644 -o root -g root` does three things atomically: copy bytes, set mode, set owner/group. Single command, single pkexec invocation, predictable post-state. Mirrors `bin/ryoku-openvpn-import:66` which uses the same pattern for placing `.conf` files.

## UI shape (`HostsTab.qml`)

Follows the OVPN sidebar tab structure. Top to bottom:

```
ColumnLayout (anchors.fill, margins 14, spacing 12)

  Add-entry form (RowLayout)
    MaterialTextField  placeholder "IP"      validator: regex (v4 or v6)
    MaterialTextField  placeholder "Domain"  validator: regex
    DialogButton       "Add"
                       enabled: ipValid && domainValid && !RyokuHosts.busy

  Inline error banner (Rectangle)
    visible: RyokuHosts.lastError.length > 0
    MaterialSymbol "error_outline"  StyledText "Error: <lastError>"  Button "x"
    (mirrors OpenVpnTab.qml's import-error banner shape)

  Header row (RowLayout)
    MaterialSymbol "dns"
    StyledText "Managed entries"  font-bold
    StyledText "(N entries)"  small  colSubtext

  Entries list (Rectangle wrapping ScrollView+ColumnLayout+Repeater, fillHeight)
    Empty state when entries.length === 0:
      MaterialSymbol "dns" iconSize 56 colSubtext
      StyledText "No managed entries yet"  bold
      StyledText "Add an IP and domain above to pin a hostname locally."
                 colSubtext  small  wrapped
    Otherwise:
      ScrollView clipped, ColumnLayout
        Repeater  model: RyokuHosts.entries
          delegate: HostsEntryRow  (RowLayout)
            StyledText  modelData.ip       monospace, fillWidth, ellipsize
            StyledText  modelData.domain   colOnLayer1, fillWidth
            (inline icon button, mirrors `OpenVpnStatusCard.qml:148-187`'s `logsBtn`)
              Rectangle  width 36, height 36, radius small
                color: hovered ? colLayer2Hover : "transparent"
                border 1px colLayer3Hover transparentized
                MaterialSymbol  "close"  iconSize normal
                MouseArea  cursorShape PointingHandCursor
                  onClicked: RyokuHosts.remove(modelData.ip, modelData.domain)
                  enabled: !RyokuHosts.busy
                StyledToolTip  text: "Remove"
```

Validation is live: the Add button stays disabled until both fields match their regex, and the field underlines turn `m3error` color on regex mismatch (uses `MaterialTextField`'s built-in invalid-state visual). Pressing Enter in the domain field is equivalent to clicking Add.

When `RyokuHosts.busy` is true, the Add button shows a small `progress_activity` spinner and is disabled; the per-row remove buttons disable too. This prevents the user from queuing a second pkexec call before the first auth dialog resolves.

The tab's icon in the bottom-tab strip is `dns`; its `name` field in `BottomWidgetGroup.qml`'s `allTabs` array is `Translation.tr("Hosts")`.

## Error handling

| Failure mode | Visible behavior |
|---|---|
| Invalid IP / invalid domain in helper | `lastError` populated with the error string from `last-op.json`; banner appears at top of tab; form fields stay populated so user can correct |
| User cancels polkit prompt | `lastError = ""` (silent cancel: spec'd as `cancelled` in the manifest, treated as user intent, no error surfaced) |
| pkexec returns non-zero for any other reason | `lastError` populated with `"pkexec install failed (rc=N)"`; banner appears |
| /etc/hosts vanishes between read and `pkexec install` | `lastError = "/etc/hosts disappeared"`; helper exits non-zero |
| Helper hangs (user wanders off mid-prompt) | After 30s, `busyTimeout` clears `busy` so the UI is interactive again. The pkexec prompt is still visible to the user; if they eventually authenticate, the FileView still picks up the state-file write and reflects the new entry |
| FileView misses a notification | A 5-second post-action poll re-reads `/etc/hosts`. If still no change, the user can click Add again to retry |

The `busy` flag is local to the service instance, so a shell restart clears it. No persistent stuck-busy state.

## Tests

`tests/sidebar-hosts.sh` (new) asserts:

1. `shell/services/RyokuHosts.qml` exists.
2. `shell/services/qmldir` registers `singleton RyokuHosts 1.0 RyokuHosts.qml`.
3. The service exposes `function add` and `function remove`.
4. The service contains the awk anchor pattern for the managed block.
5. `shell/modules/sidebarRight/hosts/HostsTab.qml` exists.
6. `BottomWidgetGroup.qml` declares the tab in `allTabs` (`"type": "hosts"` and the `dns` icon string).
7. `BottomWidgetGroup.qml` and `CompactSidebarRightContent.qml` each contain a `Binding { target: RyokuHosts; property: "tabOpen"; ... }`.
8. `shell/defaults/config.json` `.sidebar.right.enabledWidgets` contains `"hosts"`.
9. `bin/ryoku-hosts-edit` exists, is executable, contains `pkexec install` and the marker strings.
10. The helper writes `last-op.json` (grep for the path) under `XDG_STATE_HOME` / `$HOME/.local/state`.

Run: `bash tests/sidebar-hosts.sh && bash tests/sidebar-tailscale.sh && bash tests/sidebar-openvpn.sh && bash tests/bar-secpulse.sh && bash tests/topbar-removal-regression.sh && fish shell/scripts/qml-check.fish`.

## Risks and rollback

1. **Block markers are simple regex anchors.** A user who manually edits the markers (e.g. adds a trailing space) breaks the contract. Mitigation: the helper rebuilds the block from the parsed entries it found, so a malformed marker means the helper sees an empty block and creates a fresh one below the malformed remnant. Worst case is a duplicate set of markers, which the user can hand-fix in 30 seconds. The alternative (sigil files, JSON metadata next to /etc/hosts, NSS hooks) is heavier than the failure mode warrants.
2. **No multi-domain support.** Users who want `IP D1 D2` will add two rows with the same IP. `/etc/hosts` accepts this and resolves correctly. The cosmetic price is two managed-block lines instead of one.
3. **pkexec polkit prompt can be cancelled or fail.** Surfaced as `lastError` in the banner. No data corruption: the helper writes to a temp file first, only `pkexec install`s if the temp file is well-formed.
4. **No authentication caching.** Every add/remove triggers a fresh polkit prompt. Acceptable for v1; if the user wants password-less control later, ship `default/polkit/49-ryoku-hosts.rules` allowing the `org.freedesktop.policykit.exec` action for `ryoku-hosts-edit` (or a more specific action). Out of scope for this design.
5. **No locking against concurrent helper invocations from two shells.** Single-user single-shell workstation; functionally impossible to hit. Adding `flock` is overkill.

Rollback: revert all listed files plus delete the new ones. The helper's residue (managed block in `/etc/hosts`, state files in `~/.local/state/ryoku/hosts/`) can be cleaned by hand or left in place; neither breaks anything.

## Open questions resolved during brainstorming

| Question | Decision |
|---|---|
| Write strategy for /etc/hosts? | Managed-section block between `# >>> ryoku-hosts (managed) >>>` and `# <<< ryoku-hosts (managed) <<<`. System entries outside the block are never touched. |
| Topbar widget? | None. Explicit user request. |
| Polkit rule for password-less control? | None. Use plain `pkexec` so the existing `WafflePolkit` UI handles the prompt. Password-less is a separate decision later. |
| IPv6 support? | Yes. Validator accepts both v4 dotted-quad and v6 colon-hex. No zone-identifier syntax. |
| Multi-domain per line? | No. One IP + one domain per row. Use multiple rows for multi-domain. |
| Module toggle? | None. Tab visibility is governed by `sidebar.right.enabledWidgets` like every other sidebar tab. |
| Helper invoked by absolute path or bare name? | Bare name. Mirrors `RyokuOpenVpn`'s `Quickshell.execDetached(["ryoku-openvpn-import"])`. Quickshell's inherited PATH already includes `~/.local/share/ryoku/bin/`. |
| State-file location? | `${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/hosts/last-op.json`. Mirrors OVPN convention. |
| Periodic poll? | None. FileView on `/etc/hosts` and on `last-op.json` is event-driven; cheaper and more responsive than a timer. |
| Migration? | None. Purely additive. Existing user configs without `"hosts"` in `enabledWidgets` get the runtime fallback to the documented default list. |
