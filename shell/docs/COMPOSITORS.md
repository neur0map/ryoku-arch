# Compositor Integration

iNiR is built for Niri. Secondary Hyprland support is maintained from the project's origins as a fork of end-4's Hyprland dots.

## Detection

`CompositorService` figures out which compositor is running by checking environment variables at startup:

1. `$HYPRLAND_INSTANCE_SIGNATURE` set? Hyprland.
2. `$NIRI_SOCKET` set? Niri.
3. `$XDG_CURRENT_DESKTOP` contains "GNOME"? GNOME (unsupported, but detected).
4. None of the above? Unknown.

Code that behaves differently per compositor uses guards:

```qml
if (CompositorService.isNiri) {
    // niri-only path
}

visible: CompositorService.isHyprland  // hide on other compositors
```

## Niri

Primary compositor. Full IPC integration.

### How it connects

`NiriService` opens a Unix socket at `$NIRI_SOCKET` and subscribes to the event stream. Every workspace change, window open/close, output hotplug, and keyboard layout switch arrives as a JSON event and updates reactive QML properties.

For commands (focus workspace, move window, etc.), a separate socket connection sends requests and reads responses.

### What it exposes

| Property | What it tracks |
|----------|---------------|
| `workspaces` | All workspaces with IDs, names, active state, output assignment |
| `windows` | All windows with title, app ID, position, size, workspace |
| `outputs` | All monitors with name, scale, resolution, position |
| `activeWindow` | Currently focused window |
| `focusedWorkspaceId` | Current workspace on the focused monitor |
| `keyboardLayoutNames` | Available keyboard layouts |
| `displayScales` | Per-monitor scale factors |

### Niri config management

iNiR manages Niri's config through modular KDL files in `~/.config/niri/config.d/`:

| File | What it controls |
|------|-----------------|
| `10-input-and-cursor.kdl` | Mouse, touchpad, keyboard, cursor theme |
| `20-layout-and-overview.kdl` | Workspace layout, gaps, struts |
| `30-window-rules.kdl` | Window rules (floating, size, opacity) |
| `40-environment.kdl` | Environment variables for apps |
| `50-startup.kdl` | Autostart entries (clipboard, polkit, etc.) |
| `60-animations.kdl` | Window animation settings |
| `70-binds.kdl` | All keybinds |
| `80-layer-rules.kdl` | Layer shell rules (for the shell itself) |
| `90-user-extra.kdl` | User overrides. Never touched by updates. |

`scripts/niri-config.py` does surgical edits to these files, preserving comments and unknown settings. It never rewrites entire files.

## Hyprland

Secondary support. Uses the Quickshell Hyprland module (built-in) plus `hyprctl` for queries that the module doesn't cover.

### Differences from Niri

| Aspect | Niri | Hyprland |
|--------|------|----------|
| IPC | Unix socket, JSON events | Quickshell module + hyprctl |
| Window sorting | Native via IPC | Complex 300+ line sort (monitor > workspace > column > Y) |
| Workspace model | Scrolling (infinite horizontal) | Fixed grid |
| Config | KDL, modular files | hyprland.conf |

### What's Hyprland-only

- `HyprlandData.qml`: window list, workspaces, monitors, layers
- `HyprlandKeybinds.qml`: keybind parsing for cheatsheet
- `HyprlandXkb.qml`: keyboard layout tracking

### What doesn't work on Hyprland

Some features require Niri-specific IPC that has no Hyprland equivalent:

- Workspace scrolling gestures
- Column-based window management
- Some Overview features

The shell adapts gracefully. Missing features hide themselves rather than crashing.

## Shared abstractions

`CompositorService` provides compositor-agnostic APIs that modules use instead of talking to Niri/Hyprland directly:

- `sortedToplevels`: sorted window list (delegates to the active compositor's sorting logic)
- `filterCurrentWorkspace(toplevels, screen)`: workspace-aware window filtering
- `powerOffMonitors()` / `powerOnMonitors()`: DPMS control

This means most UI components don't need compositor guards at all. They just read `CompositorService.sortedToplevels` and it works regardless of which compositor is running.

## For contributors

**Always use compositor guards** when writing compositor-specific code. Never assume Niri is running.

**Prefer shared abstractions** over direct NiriService/HyprlandData access when possible. If you need something that only Niri provides, gate it with `CompositorService.isNiri` and provide a fallback (even if the fallback is just hiding the feature).

**Test both** if you're touching compositor-facing code. At minimum, check that the feature doesn't crash on the other compositor.
