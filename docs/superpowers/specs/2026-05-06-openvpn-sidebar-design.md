# OpenVPN Sidebar Tab, Design

## Context

Ryoku is positioned as a security workstation. The day-to-day workflow for
TryHackMe / Hack The Box / corp-engagement labs is: download a `.ovpn`,
run `sudo openvpn --config X.ovpn` in a terminal, leave that terminal alive
for the session, and switch configs by killing and re-launching. Friction
points: terminal stays open, sudo every time, no at-a-glance status, no
"connect THM, then connect HTB" muscle memory.

The right-sidebar `BottomWidgetGroup` (`shell/modules/sidebarRight/BottomWidgetGroup.qml`)
already hosts a tab strip, Calendar, Events, Todo, Notepad, Calc, System,
Timer, with a clean extension point: each tab is one `{type, name, icon, widget}`
entry in `allTabs[]` plus a Component definition. This spec adds an OpenVPN
tab there, backed by a new singleton service (`RyokuOpenVpn`) and the
standard Arch `openvpn-client@.service` template, gated by a polkit rule
so the user never sees a password prompt for connect/disconnect.

Tailscale lives in SecPulse already (recent rework, 2026-05-06). OpenVPN is
intentionally separate: Tailscale is the always-on identity network;
OpenVPN configs are short-lived engagement tunnels. Two indicators on the
bar, one each, keeps the mental model clean.

## Goals

- New `openvpn` tab in `BottomWidgetGroup` (sidebar bottom tab strip).
- One-click connect / disconnect for any imported profile, no password prompt
  in the steady state.
- File-picker import flow: pick a `.ovpn` → it lands in
  `/etc/openvpn/client/`, appears in the profile list, ready to use. One
  graphical pkexec prompt per import.
- Bar indicator: a second SecPulse glyph next to the Tailscale lock,
  showing OpenVPN active state with profile name + tunnel IP in the
  tooltip.
- Live log tail in the tab when a profile is active, for diagnosing
  push-reject / DNS / TLS issues without dropping to a terminal.
- Default-installed: `openvpn` ships in `ryoku-base.packages`; the polkit
  rule installs via `install/config/openvpn.sh`.

## Non-Goals (v1)

- Credential-prompted configs (`auth-user-pass`). Most CTF `.ovpn`s are
  cert-only; corp/lab cases that require user/pw will fall back to entering
  them once via openvpn's own prompt in journal logs. We can add inline
  cred handling in v2.
- NetworkManager integration. NM mangles THM/HTB push-reset and custom
  routes; we deliberately stay outside it.
- Multi-tunnel concurrent connections. UI assumes at most one
  `openvpn-client@*` unit is active at a time (matches user workflow).
- Full config editor in the tab. Edits drop the user into `$EDITOR` via
  `pkexec` on the underlying `.conf`. v2 might inline an editor.
- Importing `.ovpn` files that reference external cert/key files (we
  support inline `<cert>…</cert>` blocks only in v1; the importer warns
  and refuses externals).

## UX

The tab is the front door. Everything else is plumbing.

### Tab layout

```
╭─────────────────────────────────────────╮
│ [📅][✓][📝][🧮][📊][⏱][🔑VPN]  ← tab bar │
├─────────────────────────────────────────┤
│  ╭ Connected ──────────────────────╮    │
│  │ 🔒 htb · since 14:23            │    │
│  │ 10.10.14.42 · tun0              │    │
│  │ [ Disconnect ]                  │    │
│  ╰─────────────────────────────────╯    │
│                                          │
│  Profiles                        [ + ]  │
│  ╭─────────────────────────────────╮    │
│  │  thm            Connect ▶       │    │
│  │  htb            ● Active   ⋮   │    │
│  │  htb-academy    Connect ▶       │    │
│  │  work-corp      Connect ▶  ⋮   │    │
│  ╰─────────────────────────────────╯    │
│                                          │
│  ▾ Recent log (last 5 lines)            │
│  ╭─────────────────────────────────╮    │
│  │ Initialization Sequence Compl.. │    │
│  │ TUN/TAP device tun0 opened     │    │
│  ╰─────────────────────────────────╯    │
╰─────────────────────────────────────────╯
```

### State variants

- **Disconnected, profiles exist**: status card hidden. Profiles list shows
  every `.conf` in `/etc/openvpn/client/`, each with a `Connect ▶` button.
  Log section collapsed.
- **Disconnected, no profiles**: status card hidden. Profiles list shows an
  empty-state card: "No profiles yet. Import a .ovpn from THM, HTB, or your
  corp portal." with a prominent `[ + Import .ovpn ]` button.
- **Connecting**: status card shows the profile name with a `Connecting…`
  spinner where the IP would be. Disconnect button shown. Log section
  auto-expanded.
- **Connected**: status card shows profile, since-time, tunnel IP, device
  (`tun0`), Disconnect button. Active profile in the list shows
  `● Active` instead of Connect button. Log section collapsed by default,
  one click expands.
- **Failed**: status card shows the profile in error state ("Failed: see
  log"), Disconnect button replaced by `Retry`. Log auto-expanded.

### Connect interaction

- Click `Connect ▶` on a profile → `RyokuOpenVpn.connect(name)` →
  `Quickshell.execDetached(["systemctl", "start", "openvpn-client@" + name])`.
- Polkit rule allows it without password (active session, member of the
  `wheel` group; rule is permissive on these grounds since the .conf files
  are already root-owned and the user installed them).
- Status card transitions to `Connecting…` immediately (button disabled).
- Within 5s the next poll detects the unit is active and the tun device
  has an IP → `Connected` state.

### Import interaction

- Click `[ + ]` on the Profiles header → spawns `ryoku-openvpn-import` via
  `Quickshell.execDetached`.
- Helper opens a `zenity --file-selection --file-filter='OpenVPN | *.ovpn *.conf'`
  rooted at `~/Downloads`.
- On selection: helper sanitizes the filename (`tryhackme-myname.ovpn` →
  `tryhackme-myname.conf`; lowercase; `[^a-z0-9-]` → `-`; squeeze repeats;
  prepend `ryoku-` if it would collide with an existing system unit name).
- Helper validates: file is plaintext, contains `client` directive, all
  cert/key blocks are inline (`<ca>…</ca>` etc., no `ca filename` lines
  pointing at external files). On fail: helper exits non-zero with an
  error to stderr; QML shows a toast.
- Helper runs `pkexec install -m 600 -o root -g root <src> /etc/openvpn/client/<name>.conf`.
  One graphical prompt per import.
- After success, helper writes a tiny manifest entry to
  `~/.local/state/ryoku/openvpn/imports.json` (just `{name, originalFilename, importedAt}`)
  so the UI can show "imported from <originalFilename>" on hover.
- The service notices `/etc/openvpn/client/` mtime changed and rescans.
  New profile appears at the top of the list with a soft highlight for 3s.

### Profile row menu (`⋮`)

- **View full log** → expands the log tail to fullscreen-of-the-tab,
  scrollable, with an "Open in terminal" escape hatch
  (`kitty -e journalctl -fu openvpn-client@<name>`).
- **Edit config** → `pkexec env EDITOR="${EDITOR:-nano}" "${EDITOR:-nano}" /etc/openvpn/client/<name>.conf` (spawned in a kitty window since pkexec'd editors can't share the QML process's TTY).
- **Rename** → inline text input, helper does `pkexec mv` of the .conf and
  updates `imports.json`. If unit was active under the old name, restart
  under new name.
- **Delete** → confirm modal, helper does `pkexec rm /etc/openvpn/client/<name>.conf`.
  If unit was active, stop it first.

### Toasts (existing `Notifications` infra, brief inline messages)

- Import success: "Imported as `htb`. Click to connect." (clickable: jumps
  to that row and triggers connect).
- Import refused (validation): "Refused: external cert/key references not
  supported. Use a self-contained .ovpn."
- pkexec cancelled: "Import cancelled."
- Connect failed: "openvpn-client@htb failed to start. See log."

### Bar indicator

- Add a second `Item` to `SecPulseIndicator.qml`'s `RowLayout`, after the
  Tailscale block.
- Icon `vpn_key` (filled when active, hollow when not). Color: accent on
  active, subtle on inactive.
- Visibility gated by `bar.secPulse.showOpenVpn` (default `true`).
- Click action: opens the right sidebar with the OpenVPN tab focused
  (`GlobalStates.sidebarRightOpen = true; <select-tab "openvpn">`).
- Tooltip (hover, fixed-hover bug already solved by extraVisibleCondition):

  ```
  OpenVPN · htb
  10.10.14.42 · tun0
  since 14:23
  ```
  When inactive: `"OpenVPN · off"`.

## Architecture

```
┌─ Sidebar tab "VPN" ──────────────────────────────┐
│ OpenVpnTab.qml  (sidebarRight/openvpn/)          │
│   ├─ Status card  (binds RyokuOpenVpn.active*)   │
│   ├─ Profiles list (binds .profiles)             │
│   ├─ Import button → execDetached                │
│   │     ryoku-openvpn-import                     │
│   └─ Log tail   (Process: journalctl -u ...)     │
└──┬───────────────────────────────────────────────┘
   │ reads/writes
   ▼
┌─ Service (singleton) ────────────────────────────┐
│ RyokuOpenVpn.qml  (services/)                    │
│   property activeProfile, activeIp, activeSince  │
│   property profiles: [{name, path, isActive}]    │
│   func connect(name)/disconnect()/remove(name)   │
│   Timer 5s: poll `systemctl is-active            │
│             openvpn-client@*` + ip -j addr       │
└──┬───────────────────────────────────────────────┘
   │ actions issue
   ▼
┌─ System layer ───────────────────────────────────┐
│ systemctl start|stop openvpn-client@<name>       │
│   ↳ polkit rule allows active session, no pw     │
│ /etc/openvpn/client/*.conf  (root-owned 600)     │
│ ryoku-openvpn-import  (pkexec install + chmod)   │
│ openvpn  (pacman, ryoku-base.packages)           │
└──────────────────────────────────────────────────┘
```

## Components

| File | Purpose |
|---|---|
| `shell/services/RyokuOpenVpn.qml` | Singleton: `profiles`, `activeProfile`, `activeIp`, `activeSince`, `connect()/disconnect()/remove()`. 5s status poll, mtime-watch on `/etc/openvpn/client/` for re-list. |
| `shell/services/qmldir` | Register the new singleton. |
| `shell/modules/sidebarRight/openvpn/OpenVpnTab.qml` | Tab widget. Renders the four state variants from the UX section. |
| `shell/modules/sidebarRight/openvpn/OpenVpnProfileRow.qml` | One profile card: name, connect button or active badge, ⋮ menu. |
| `shell/modules/sidebarRight/openvpn/OpenVpnStatusCard.qml` | Top status card (connected / connecting / failed states). |
| `shell/modules/sidebarRight/openvpn/OpenVpnLogTail.qml` | Collapsible log tail. Owns its own `Process` for `journalctl -fu`. |
| `shell/modules/sidebarRight/BottomWidgetGroup.qml` | Add `{"type":"openvpn", "name":"VPN", "icon":"vpn_key", "widget": openVpnWidget}` to `allTabs`. Add Component definition. |
| `bin/ryoku-openvpn-import` | Bash. Validates input (inline-only), sanitizes name, `pkexec install -m 600`, updates `~/.local/state/ryoku/openvpn/imports.json`. |
| `bin/ryoku-openvpn-remove` | Bash. `pkexec rm /etc/openvpn/client/<name>.conf`. |
| `bin/ryoku-openvpn-rename` | Bash. `pkexec mv` + restart unit if active. |
| `default/polkit/49-ryoku-openvpn.rules` | Polkit JS rule allowing `org.freedesktop.systemd1.manage-units` for `openvpn-client@*` unit names, `wheel` group, active session. |
| `install/config/openvpn.sh` | Copies polkit rule to `/etc/polkit-1/rules.d/`, ensures `/etc/openvpn/client/` exists, adds `$USER` to `systemd-journal` group (so the in-tab log tail can read system-unit journals without sudo). Idempotent. |
| `install/config/all.sh` | Wire `openvpn.sh` after `tailscale.sh`. |
| `install/ryoku-base.packages` | Verify `openvpn` is present (already there at line 228 region; assert in test). |
| `shell/modules/bar/threeIsland/SecPulseIndicator.qml` | Add second indicator `Item` after the tailscale block, bound to `RyokuOpenVpn.activeProfile.length > 0`. Click opens sidebar to the openvpn tab. (No new state in `RyokuSecPulse`, `RyokuOpenVpn` is the single source of truth; the indicator reads from it directly.) |
| `shell/modules/common/Config.qml` | Add `bar.secPulse.showOpenVpn: true`. Add `"openvpn"` to default `sidebar.right.enabledWidgets`. |
| `tests/sidebar-openvpn.sh` | File-existence + grep assertions: service file, polkit rule, import bin, base.packages contains openvpn, BottomWidgetGroup contains the new tab. |

## Process lifecycle

Spelling out when each background thing starts, stops, and what owns it ,
because nothing here is "always on by default", and getting this wrong
either burns CPU or misses state changes.

### `RyokuOpenVpn` 5s status poll

- **Starts** when ANY of: (a) sidebar is open AND VPN tab is selected;
  (b) bar SecPulse OpenVPN indicator is enabled (`bar.secPulse.showOpenVpn`,
  default `true`).
- **Stops** when neither condition holds. Uses a `_active` derived property
  bound to those conditions and gates the `Timer.running`.
- Default ryoku install: indicator is on → poll runs continuously while
  shell is up. CPU cost: a single `systemctl is-active …` plus `ip -j addr`
  every 5s, both sub-millisecond.
- **First poll** fires immediately on enable (`triggeredOnStart: true`)
  so the UI is correct on first open without waiting 5s.

### `RyokuOpenVpn` 30s discovery rescan

- **Starts** when sidebar is open AND VPN tab is selected (no point
  rescanning for a tab no one's looking at).
- **Stops** when tab loses focus or sidebar closes.
- Rescans on `last-import.json` change (FileView) regardless of the above ,
  so the post-import "profile appears" feels instant even from outside the
  tab (the bar indicator can show the new active profile if the user
  imports + connects via two clicks).

### Log-tail `Process` (`journalctl -fu openvpn-client@<name>`)

- **Owned by** the `OpenVpnLogTail.qml` Loader inside the tab.
- **Starts** when the log tail is expanded by the user (or auto-expanded
  in the Connecting/Failed states).
- **Stops** automatically when the Loader becomes inactive: tab loses focus,
  sidebar closes, profile changes, log tail collapsed. Quickshell sends
  SIGTERM to the child journalctl.
- **Restarts** when the active profile changes (so a switch from htb → thm
  shows thm's logs, not stale htb).
- One-shot fallback if `journalctl -fu` fails (e.g. user isn't in
  `systemd-journal` group): show a one-line stub "Logs unavailable, add
  yourself to the systemd-journal group: `sudo usermod -aG systemd-journal $USER`,
  then log out and back in." (The installer does this, so this is only seen
  by users who skipped or rolled back `install/config/openvpn.sh`.)

### Importer process (`ryoku-openvpn-import`)

- **Spawned by** `Quickshell.execDetached`, fire-and-forget. We do not
  see exit code or stderr from QML.
- **Lives** for the duration of the file picker + pkexec prompt + copy
  (typically <10s of user time).
- **Communicates back** by writing `~/.local/state/ryoku/openvpn/last-import.json`
  with `{status: "ok"|"error"|"cancelled", name?: string, error?: string}`.
- **Watchdog**: when the import is initiated, the tab arms a 60s `Timer`.
  If `last-import.json` hasn't changed by then, the tab assumes the
  importer crashed or the user left the file picker open and surfaces a
  "Import dialog closed" toast and rearms the import button. (The user
  re-clicking `+` always works, there's no "import in progress" lock.)
- Importer always writes the manifest, even on its own error paths
  (validation failure, pkexec cancel, copy failure), so the watchdog
  is a true safety net, not the primary signaling channel.

### Polkit auth agent

- pkexec needs an auth agent to render the password prompt. Ryoku already
  ships one: `shell/modules/waffle/polkit/WafflePolkit.qml`. It runs as
  part of `ryoku-shell.service` and registers itself as the session's
  polkit agent. No additional agent needs to be installed for the importer
  flow.
- If `ryoku-shell` is not running (early boot before the user has logged
  in graphically, or shell crashed), pkexec falls back to text prompts on
  the controlling terminal, there is none for the importer (it was spawned
  via execDetached) so it'll exit non-zero and the watchdog catches it.

### Concurrency / race protection

- **Connect button per profile**: disabled while any state transition is in
  progress (`RyokuOpenVpn.transitioning: bool`, set on `connect()`/
  `disconnect()`, cleared on the first poll where state matches the
  intended target, or on a 15s timeout).
- **Disconnect button**: same disabled-during-transition behavior.
- **Switching profiles** (B+D MVP): if the user clicks Connect on profile
  Y while X is active, the service issues `systemctl stop openvpn-client@X`
  and waits for the next poll showing X as inactive, then issues
  `systemctl start openvpn-client@Y`. UI shows "Switching X → Y…" in the
  status card. If openvpn's TLS exit handshake takes >15s, surface
  "Switch taking longer than expected, see log" and let user retry.
- **Manual `systemctl start openvpn-client@…` from a terminal** while UI is
  open: the next 5s poll picks it up; the new profile appears as Active
  with no further user interaction. UI is purely a view + actions, never
  a source of truth about what's running.
- **Multiple openvpn-client units active simultaneously** (only possible
  if the user manually started a second from terminal): UI picks the most
  recent by `ActiveEnterTimestamp`, logs a warning to journal, and the
  status card carries a small "(+1 other unit active)" hint. Disconnect
  button stops the displayed one.

## Data flow

### Discovery (`profiles` property)

- 30s `Timer` rescans `/etc/openvpn/client/`.
- Plus an explicit `rescan()` call after the importer succeeds (importer
  writes `~/.local/state/ryoku/openvpn/last-import.json`; service watches
  that file via `FileView` and triggers `rescan()` on change). This makes
  the import → "profile appears" round-trip feel instant instead of waiting
  up to 30s.
- Lists `*.conf` files; for each, profile name = stem.
- Cross-references `~/.local/state/ryoku/openvpn/imports.json` to attach
  `originalFilename` / `importedAt` if the user imported via the helper
  (manual `sudo cp` users still see the profile, just without the metadata).
- Importer is responsible for `mkdir -p ~/.local/state/ryoku/openvpn/`
  before writing manifests.

### Active detection (`activeProfile`, `activeIp`, `activeSince`)

- 5s `Timer`. Run a single `sh -c` pipeline:
  ```
  systemctl --type=service --state=active --no-legend 'openvpn-client@*' 2>/dev/null
  ```
  Take first match → derive `<name>` from `openvpn-client@<name>.service`.
- If matched:
  - `systemctl show "openvpn-client@$name" -p ActiveEnterTimestamp --value`
    → `activeSince`.
  - `ip -j addr show 2>/dev/null` → JSON; pick first interface whose
    `ifname` matches `tun*` and is `UP` → `activeIp`.
- If no match: clear all three.

### Connect / disconnect

- `connect(name)`:
  - If a different profile is active, `disconnect()` first (await one poll
    cycle, then start the new one). UI shows "Switching from htb to thm…"
    in the status card during the gap.
  - `Quickshell.execDetached(["systemctl", "start", "openvpn-client@" + name])`.
- `disconnect()`:
  - `Quickshell.execDetached(["systemctl", "stop", "openvpn-client@" + activeProfile])`.

### Import

- QML calls `Quickshell.execDetached(["ryoku-openvpn-import"])` with no
  arguments (helper handles its own file picker).
- Helper writes success/failure to a state file
  (`~/.local/state/ryoku/openvpn/last-import.json`); QML watches that file
  for changes and surfaces a toast.

## Error handling

| Condition | Detection | UX response |
|---|---|---|
| `openvpn` not installed | `command -v openvpn` fails on tab open | Tab shows "openvpn not installed" stub; `[Install]` button runs `pkexec pacman -S --noconfirm openvpn` |
| Polkit rule missing | First connect attempt prompts for password (we never see this from QML, but if pkexec is invoked instead, that fails) | If `systemctl start` exits non-zero AND `pkexec` was prompted, surface "Polkit rule missing, run `sudo /home/$USER/.local/share/ryoku/install/config/openvpn.sh`" |
| Import: external cert refs | Validator regex sees `^[[:space:]]*(ca|cert|key|tls-auth)[[:space:]]+[^<]` | Refused with toast |
| Import: pkexec cancelled | Helper exit code 126 | Silent (cancellation is user intent) |
| Connect: unit fails | 5s poll sees unit went `failed` instead of `active` | Status card → Failed state; log auto-expanded; Retry button |
| Tunnel up but no IP | Unit active for >5s but `tun*` has no IP | "Tunnel up, no IP yet, check log" |
| Active unit but it crashed mid-session | Poll loses the active match | Status card clears (same as user-initiated disconnect). v1 doesn't distinguish causes; users can check log. |
| Multiple openvpn-client units somehow active | Poll finds >1 | Pick the most recent by `ActiveEnterTimestamp`; UI shows the one we picked plus a small "(+N others active)" hint; Disconnect stops only the displayed one |
| User not in `systemd-journal` group | journalctl child exits with permission error on log tail open | Log tail shows the one-line group-membership-fix stub (see Process lifecycle § Log-tail); does not block other functionality |
| Pushed DNS doesn't take effect | OpenVPN pushes DNS via `--up` script but `openvpn-client@.service` doesn't apply it on Arch by default | v1 doesn't try to fix this, `tailscale` already handles MagicDNS for the always-on case, and engagement tunnels usually don't need DNS for IP-based scanning. Documented as a known limitation; v2 may ship `update-systemd-resolved` integration. |
| ryoku-shell crashed → no polkit agent | Importer's pkexec hangs → watchdog fires at 60s | Toast: "ryoku-shell polkit agent unavailable, restart with `systemctl --user restart ryoku-shell`" |

## Security considerations

- Polkit rule is narrow: matches only `openvpn-client@*` units, only
  `start`/`stop`/`restart`/`reload-or-restart` actions, only `active`
  sessions, only `wheel` group members. Cannot be used to manage other
  systemd units.
- `.conf` files are root:root 600. Only root can read; openvpn-client@.service
  runs as root so it has access. The user can install/edit only via
  `pkexec` (graphical prompt), never via direct file write.
- Importer rejects `.ovpn` files referencing external certs/keys to prevent
  smuggling references to attacker-controlled paths into root-owned configs.
  Inline-only is enforced by a single regex check.
- `imports.json` and `last-import.json` are user-owned, no privileged data.
- No secret material is ever written to user-readable space by this code.

## Testing

- `tests/sidebar-openvpn.sh` (matches the style of `tests/topbar-three-island.sh`):
  - `assert_file shell/services/RyokuOpenVpn.qml`
  - `assert_contains shell/services/qmldir "singleton RyokuOpenVpn 1.0 RyokuOpenVpn.qml"`
  - `assert_file shell/modules/sidebarRight/openvpn/OpenVpnTab.qml`
  - `assert_executable bin/ryoku-openvpn-import`
  - `assert_executable bin/ryoku-openvpn-remove`
  - `assert_executable bin/ryoku-openvpn-rename`
  - `assert_file default/polkit/49-ryoku-openvpn.rules`
  - `assert_executable install/config/openvpn.sh`
  - `assert_contains install/config/all.sh "openvpn.sh"`
  - `assert_contains install/ryoku-base.packages "openvpn"`
  - `assert_contains shell/modules/sidebarRight/BottomWidgetGroup.qml '"type": "openvpn"'`
- Manual smoke (real session):
  1. Tab appears in BottomWidgetGroup.
  2. Empty state shown when `/etc/openvpn/client/` is empty.
  3. Import a real THM/HTB .ovpn → profile appears, single pkexec prompt.
  4. Connect → status card transitions, tun0 has an IP within 10s, bar
     SecPulse second indicator goes accent-color.
  5. `journalctl -fu openvpn-client@<name>` matches the in-tab log tail.
  6. Disconnect → unit stops, status card clears, bar indicator goes subtle.
  7. Remove a profile → confirms, file is gone from `/etc/openvpn/client/`.
  8. Edit profile → opens in $EDITOR via pkexec.
  9. Validation refusal: try to import a non-inline .ovpn → toast, no copy.
  10. Click bar indicator → sidebar opens with VPN tab focused.

## Open questions resolved

- **Sanitization**: lowercase + `[^a-z0-9-]` → `-` + squeeze repeats; prepend
  `ryoku-` if the resulting name collides with an existing systemd unit name
  in `/etc/openvpn/client/`. Confirmed.
- **Polkit rule location**: `/etc/polkit-1/rules.d/49-ryoku-openvpn.rules`.
  Confirmed.
- **Bar indicator placement**: second indicator next to the Tailscale lock,
  not folded into one icon. Confirmed by the "two distinct identity stories"
  framing.
- **Default `enabledWidgets`**: `openvpn` ON by default. Users who don't use
  OpenVPN can hide it from settings → BarConfig → enabled widgets.

## Out of scope (v2 candidates)

- Inline credential capture for `auth-user-pass` configs.
- Connect-on-boot toggle per profile (`systemctl enable openvpn-client@<name>`).
- Kill-switch (nftables drop-rule on the default route while VPN is up).
- Multi-tunnel concurrent connections.
- DNS-leak test panel.
- Inline `.conf` editor.
- External cert/key references support.
- NetworkManager bridge for users who do want NM-managed tunnels.
- Pushed-DNS integration via `update-systemd-resolved` (so `--push dhcp-option DNS …` from the .ovpn actually applies on Arch).
