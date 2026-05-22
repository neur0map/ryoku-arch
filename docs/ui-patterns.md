# UI Patterns and Footguns

Rules for working on the Ryoku shell desktop in `shell/`. Written from real bugs that ate hours. The goal is to keep contributors from chasing symptoms or reinventing existing primitives.

## The cardinal rule

**Verify your mental model of a property before fixing anything that uses it.**

If you change a property and the visual result is unchanged, the property does not do what you think it does. Read its definition. Do not change it harder.

Real example: `StyledPopup.popupBackgroundMargin` does NOT add internal padding. It only offsets the popup inside its containing window. Five commits were spent "fixing" padding by changing it. Net visual effect: zero.

## Padding and rounded corners

If content visually touches the rounded corner of a surface, the cause is almost always **padding smaller than the corner radius**. The arc of the corner cuts into the safe zone.

Material 3 padding tokens for popup-class surfaces:

| Surface type | Padding | When to use |
|---|---|---|
| Plain tooltip | 8 horizontal / 4 vertical | Single-line label only |
| Rich tooltip / surface popup | 16 / 12 | Icon + text rows, multi-line |
| Card | 16 all sides | Settings rows, list items |
| Dialog | 24 all sides | Modal with title + actions |
| Menu container | 8 around the list, 12 per item | ContextMenu and similar |

Rule of thumb: **padding >= corner_radius** so the arc never eats into the content.

Where the padding lives:
- `StyledPopup` exposes `horizontalPadding` and `verticalPadding`. Set them on the popup root.
- `Control` subclasses already have `padding`, `leftPadding`, etc. Use those.
- Never hardcode `margin: N` inside the surface and call it padding. Add a property.

## Layout footguns

### Qt Quick Layouts ignore manual `implicitWidth`

`ColumnLayout` and `RowLayout` compute their own implicit size from children's preferred widths. Setting `implicitWidth: 220` on a Layout silently does nothing.

If you need a Layout to report a custom width to its parent, wrap it:

```qml
Item {
    anchors.centerIn: parent
    implicitWidth: 240
    implicitHeight: columnLayout.implicitHeight
    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        // children
    }
}
```

The plain `Item` honors `implicitWidth`. `Layout.minimumWidth` on a child row also does not propagate up to the parent's implicit size; it is a constraint, not a hint.

### `children: [item]` does not anchor

When `StyledPopup` reparents your `contentItem` via `children: [contentItem]`, the item lands at position `(0, 0)`. If the surface is bigger than the content (because of padding), all the empty space pools at the bottom-right.

Fix: anchor the contentItem (`anchors.centerIn: parent` or `anchors.fill: parent` with margins) so the popup's natural padding distributes evenly.

### Mixing anchors with Row/Column positioners

`Row` and `Column` (not `RowLayout`/`ColumnLayout`) position children sequentially. A child with `anchors.verticalCenter: parent.verticalCenter` is fine for vertical centering inside a `Row`. A child that uses `anchors.fill` or `anchors.left` inside a `Row` will fight the positioner. Use `RowLayout` when you need anchor-style sizing.

## Use existing primitives, do not reinvent

Before adding a new component, search `shell/modules/common/widgets/` for what already exists.

| Need | Use |
|---|---|
| Button with hover / press animation | `DialogButton` (extends `RippleButton`) |
| Bare button with ripple | `RippleButton` |
| Hover tooltip | `StyledToolTip` (set `extraVisibleCondition: mouseArea.containsMouse`) |
| Right-click or three-dot menu | `ContextMenu` with `model: [{iconName, text, action}, {type:"separator"}, ...]` |
| Hover-activated rich popup | `StyledPopup` with `horizontalPadding` / `verticalPadding` |
| Material icon | `MaterialSymbol { text: "icon_name"; iconSize: ...; fill: 0..1 }` |
| Themed text | `StyledText` (do not use raw `Text`) |
| Text input field | `MaterialTextField` |
| Switch toggle | `ConfigSwitch` |
| Numbered slider | `StyledSlider` |
| Card with hover background | look at `WaffleConfig.qml` for the canonical card pattern |

If you find yourself writing ripple animation, hover-color logic, or Material-symbol rendering by hand, stop. There is a primitive.

## Color tokens that exist

Use the tokens, not literal colors. Common ones:

| Token | Use for |
|---|---|
| `Appearance.colors.colOnLayer1` | Primary text on the panel surface |
| `Appearance.colors.colSubtext` | Subtitle / dimmed text (THE canonical secondary, used codebase-wide) |
| `Appearance.colors.colOnLayer2` | Text on a card surface |
| `Appearance.colors.colLayer1` / `colLayer2` / `colLayer3` | Background surfaces, ascending elevation |
| `Appearance.colors.colLayer2Hover` / `colLayer2Active` | Card hover and press states |
| `Appearance.m3colors.m3primary` | Brand accent |
| `Appearance.m3colors.m3error` | Error red |
| Per-skin variants | `Appearance.angel.X`, `Appearance.ryoku.X`, `Appearance.aurora.X`, ternary-cascaded via `Appearance.angelEverywhere ? ... : ...` |

If you reach for a name like `colOnLayer2Subtitle`, search first. It probably does not exist. The codebase uses `colSubtext` everywhere.

## Peer pattern map

When you add a new sidebar tab, bar widget, or sidebar dialog, do not start from scratch. Open the closest peer first:

| Adding a... | Open this for the pattern |
|---|---|
| Sidebar bottom-tab widget | `shell/modules/sidebarRight/todo/TodoWidget.qml` |
| Sidebar tab in compact layout | `shell/modules/sidebarRight/CompactSidebarRightContent.qml` (look at `widgetSections` array) |
| Right-sidebar dialog (modal-ish) | `shell/modules/sidebarRight/wifiNetworks/WifiDialog.qml` |
| Hover popup | `shell/modules/bar/BatteryPopup.qml` (uses `StyledPopup`) |
| Singleton service that polls | `shell/services/RyokuOpenVpn.qml` |
| Settings page section | `shell/modules/settings/InterfaceConfig.qml` |
| Quick-toggle switch in sidebar | `shell/modules/sidebarRight/quickToggles/AndroidQuickPanel.qml` |

The peer is the source of truth for spacing, color tokens, animation timing, and component composition.

## One-person shell workflow

Ryoku development has two jobs that must stay separate:

1. **Development preview:** see local shell edits on the laptop quickly.
2. **Installed update:** let Git pull committed changes into the installed tree.

Do not copy dev files into `~/.local/share/ryoku` while previewing. That path is an installed Git checkout owned by `ryoku-update`. Manually copying future files there can make a later pull abort with "untracked working tree files would be overwritten by merge".

| Tree | Path | Role | Write rule |
|---|---|---|---|
| Dev | `~/prowl/ryoku-arch/shell/...` | Git source of truth | Edit, test, commit, push here |
| Installed repo | `~/.local/share/ryoku/shell/...` | User update checkout | Only `ryoku-update` or installer writes here |
| SHELL_PATH | `~/.local/share/ryoku-shell/...` | Deployed shell tree from install/update | Generated from the installed repo |
| Runtime | `~/.config/quickshell/ryoku-shell/...` | What Quickshell loads now | Local preview may overwrite this |

For local UI work, copy from dev to runtime only, then restart the shell:

```bash
DEV="${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
RUNT="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell"
rsync -a --delete "$DEV/shell/" "$RUNT/"
systemctl --user restart ryoku-shell.service
```

When the preview looks correct:

1. Run the relevant tests and `fish shell/scripts/qml-check.fish`.
2. Commit and push from the dev repo.
3. Let `ryoku-update` pull the committed change into `~/.local/share/ryoku`.

The installed repo should normally be clean:

```bash
git -C "$HOME/.local/share/ryoku" status -sb
```

If it shows untracked or modified files after manual preview work, stash them before updating instead of deleting them:

```bash
git -C "$HOME/.local/share/ryoku" stash push -u -m "pre-update-local-files"
```

## Config ownership on updates

Do not treat every file under `~/.config` as the same kind of state. Ryoku has product defaults, users have personal choices, and some files are a mix of both. Update code must respect that boundary.

| Ownership | Examples | Update rule |
|---|---|---|
| Ryoku-owned | Shell QML files, services, systemd units, command launchers, polkit rules, required feature keybinds like `Mod+S` for the toolkit | Update automatically from the repo or repair with a migration |
| User-owned | Theme choice, wallpaper, sidebar widget order, toolkit button toggles, app preferences, `.bashrc` | Never overwrite during update |
| Hybrid | `~/.config/ryoku-shell/config.json`, Hyprland config/user bind fragments, enabled sidebar widgets | Add missing Ryoku keys or entries, but preserve existing user values |
| Generated | Caches, lock files, temporary update status, generated runtime artifacts | Safe to rebuild |

The update failure mode to avoid:

1. Back up a config.
2. Reinstall or regenerate the shell.
3. Forget to merge the backup back.
4. Re-apply defaults as if user choices were missing.

That turns Ryoku defaults into a destructive reset. The correct order is:

1. Back up the active config.
2. Run the installer or payload sync.
3. Merge the active config back over freshly generated defaults.
4. Apply Ryoku-owned defaults only for missing keys or required additive entries.
5. Restart the affected service.

When patching JSON, do not use jq `//` for booleans in user config. In jq, `false // true` becomes `true`, which silently flips intentional user-disabled settings back on. Use an explicit null check instead:

```jq
def put_default($path; $value):
  if getpath($path) == null then setpath($path; $value) else . end;
```

For arrays that mix product entries with user order, append only the required missing item:

```jq
def append_once($value):
  if index($value) then . else . + [$value] end;

.sidebar.right.enabledWidgets =
  ((.sidebar.right.enabledWidgets // []) | append_once("openvpn"))
```

If a Ryoku feature needs a live config change, ship a migration. Do not solve it by replacing the whole file. The migration should be idempotent, narrowly scoped, and preserve explicit user values.


## Settings architecture: config first, visuals global

Settings are not allowed to be their own product. They are a control surface for the real desktop.

Required data flow:

```text
Settings control -> Config.setNestedValue(path, value) -> shared service/tokens recompute -> every shell surface re-renders
```

Forbidden data flow:

```text
Settings control -> local property on settings window -> settings looks changed but the shell does not
```

Use this rule before adding any setting:

1. Define the key in `shell/modules/common/Config.qml`.
2. Add the default in `shell/defaults/config.json`.
3. Put interpretation logic in the owning singleton/service, not the settings page.
4. Make shell consumers read the singleton/service token.
5. Make settings write the config key and render from the same token the shell uses.
6. Verify at least two non-settings surfaces changed after toggling the setting.

For visual settings, the owner is usually `Appearance.qml` for Material ii surfaces and `Looks.qml` for Waffle surfaces. A setting such as transparency, radius, border, color, blur, surface density, or panel family must not be implemented only inside `modules/settings/*`.

### Visual token ownership

Ryoku has several layers that look similar but have different jobs:

- `Config.qml`: schema, persistence, defaults, and writes via `Config.setNestedValue()`.
- `Appearance.qml`: Material ii visual truth. Colors, transparency, radii, style modes, and derived tokens live here.
- `modules/waffle/looks/Looks.qml`: Waffle visual truth.
- Settings pages: controls and explanations only. They mutate config and preview the real tokens.
- Shell modules: bar, sidebars, overview, dock, launcher, popups, and settings must consume tokens from the shared owner.

If a page needs a preview, bind the preview to `Appearance` or `Looks`. Do not duplicate the formula in the page. If the formula feels too settings-specific, that is a sign the real style service is missing a token.

### System-wide setting acceptance checklist

A settings change is not done until all of these are true:

- The config key exists in both `Config.qml` and `defaults/config.json`.
- The changed value survives a shell restart.
- The relevant singleton or command observes the value.
- At least one non-settings surface changes when the value changes.
- The settings UI itself is not the only consumer.
- IPC or a `ryoku-*` command exists if the setting controls system state outside QML.
- A test or script covers the config path, default, and command if practical.

### IPC and command boundary

Use QML IPC for shell UI state and shell-owned overlays. Use `ryoku-*` commands for system state. The shell should not grow into a second operating system control plane.

Good shell IPC targets:

- open, close, or toggle shell overlays
- trigger shell animations or OSDs
- update shell config through `Config.setNestedValue()`
- ask shell services for live UI state

Good `ryoku-*` command targets:

- packages, updates, snapshots, rollback, and migrations
- Hyprland config, keybinds, compositor reloads, and display config
- theme, wallpaper, fonts, cursor, icon refresh, and per-app theming
- hardware toggles, power profiles, suspend, hibernation, battery limits
- network, bluetooth, firewall, hosts, VPN, Tailscale, and DNS
- app install/remove, webapps, profiles, services, and system repair

Settings pages should prefer a thin adapter:

```text
QML control -> shell IPC or service -> ryoku-* command -> state file/config -> shell service reloads/observes result
```

Do not call `sudo`, `pacman`, `systemctl`, `nmcli`, or large shell pipelines directly from a random settings component. Put that behavior in a named `ryoku-*` command, expose a narrow IPC wrapper if needed, and display command status in the UI.

### Working tree and preview discipline

For Hyprland rebirth feature work, edit only the dev checkout on `rebirth`. Preview by syncing `shell/` into the Quickshell runtime. Do not hand-edit the installed repo or user config to make a design work.

```bash
DEV="${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
RUNT="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell"
rsync -a --delete "$DEV/shell/" "$RUNT/"
systemctl --user restart ryoku-shell.service
```

If a preview needs changed defaults or commands outside `shell/`, commit those to `rebirth` and deploy through the normal installer/update path. Otherwise you will create the exact drift where settings, keybinds, service files, and runtime shell disagree.


## When to stop and rethink

If three attempts to fix the same visual bug have not worked, the bug is not in the property you are tweaking. Patterns of "still bad", "still bad", "still bad" mean one of:

1. The property does not control what you think it controls. Re-read its definition.
2. The component you are editing is the wrong layer. Trace up to the parent surface or down to the contained child.
3. The codebase already has a primitive for what you are building from scratch. Search the widgets folder.
4. You are missing a Material 3 spec value. Look it up.

Stop, write down the actual data flow on paper, then make the next change.

## Commit-hook constraints

Repo-level hooks reject:

- `Co-Authored-By:` (or any authorship) trailer in commit messages.
- Personal home paths in any committed content. Use `$HOME`, `~`, `$RYOKU_PATH`, or runtime discovery via `$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)`.
- Em-dashes (Unicode U+2014) in any committed `.md`. Use `:` or `,` or `.` instead.

Hooks tell you exactly what they rejected; fix the message or content and re-run `git commit`. Do not bypass with `--no-verify`. Do not amend; create a new commit.
