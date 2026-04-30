# Ambxst Toolbox For Ryoku Center Pill

**Status:** Approved for implementation
**Date:** 2026-04-30
**Scope:** Add an Ambxst-style toolbox popup to Ryoku's Quickshell center pill and bind it to `SUPER+S`.

## Goal

Ryoku should have the Ambxst toolbox experience available from the center pill. Pressing `SUPER+S` opens a compact topbar-attached row of tool buttons. The row should use Ambxst's current toolbox as the source of truth, with one Ryoku-requested addition: Caffeine.

The toolbox should feel native to Ryoku's current Brain Shell based topbar instead of importing Ambxst's whole shell state system. The implementation should keep Ryoku's existing command names, package lists, IPC facade, and center-pill popup architecture.

Primary upstream references:

- `https://github.com/Axenide/Ambxst/blob/main/modules/widgets/tools/ToolsMenu.qml`
- `https://github.com/Axenide/Ambxst/blob/main/modules/components/ActionGrid.qml`
- `https://github.com/Axenide/Ambxst/blob/main/modules/tools/MirrorWindow.qml`
- `https://github.com/Axenide/Ambxst/blob/main/scripts/ocr.sh`
- `https://github.com/Axenide/Ambxst/blob/main/scripts/qr_scan.sh`
- `https://github.com/Axenide/Ambxst/blob/main/scripts/google_lens.sh`

## User-Approved Direction

Use the Ryoku-native port approach.

Do not directly import Ambxst's full subsystem. Ambxst's menu depends on its own `GlobalStates`, `Config`, `Icons`, `Styling`, screenshot services, and loaders. Ryoku should copy the menu behavior and tool set while wiring each action into Ryoku-owned services or small helpers.

The toolbox row includes:

- Screenshot
- Open Screenshots
- Screen Recorder or Stop Recording
- Open Recordings
- Color Picker
- OCR
- QR Code
- Google Lens
- Mirror
- Caffeine

## User Experience

`SUPER+S` opens and closes the toolbox from the center pill.

The popup is a compact horizontal button row attached to the topbar center notch. It should match the established Ryoku popup language: dark themed surface, small rounded controls, hover highlights, tooltips, keyboard navigation where practical, and click-outside or Escape dismissal.

The menu should close after launching one-shot tools such as screenshot, color picker, OCR, QR, and Google Lens. Persistent toggles such as Mirror and Caffeine can update their active state immediately; closing the row after activation is acceptable and matches the action-menu flow.

When recording is active, the screen-record button changes from "Screen Recorder" to "Stop Recording" and shows the active/error visual state, mirroring Ambxst's behavior.

## Architecture

### Popup State

Extend `Popups.qml` with toolbox state:

- `toolboxOpen`
- `toolboxVisible`

Update `Popups.anyOpen` and `Popups.closeAll()` to include `toolboxOpen`.

`toolboxVisible` is driven by the popup window while it is visually present. `TopBar.qml` should promote to `Overlay` while `toolboxVisible` is true, matching the existing launcher, system menu, settings menu, and dashboard behavior.

### IPC

Extend `config/quickshell/ryoku/shell.qml` with:

- `toggleToolbox()`

Extend `bin/ryoku-ipc` with:

- `ryoku-ipc shell command toolbox`
- `ryoku-ipc shell toggle toolbox`

The shell command should resolve to `qs -c ryoku ipc call popups toggleToolbox`.

### Keybind

Bind `SUPER+S` to the toolbox:

```conf
bindd = SUPER, S, Toolbox, exec, ryoku-ipc shell toggle toolbox
```

### Popup Component

Add a new popup component:

- `config/quickshell/ryoku/vendor/brain-shell/src/popups/ToolboxPopup.qml`

Instantiate it from:

- `config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml`

The popup should follow the same mapped-surface pattern used by current topbar-attached popups:

- remain transparent outside the card
- expose input only over the visible card
- stay mapped through close animation using a visible-state timer if needed
- avoid interfering with `PopupDismiss`

### Shared Action Row

Either add a small local `ToolboxActionRow` component or implement the row inside `ToolboxPopup.qml`.

The row should preserve Ambxst's grouping:

1. Screenshot and Open Screenshots
2. Screen Recorder or Stop Recording and Open Recordings
3. Color Picker, OCR, QR Code, Google Lens, Mirror
4. Caffeine as the Ryoku extra

Separators should visually split those groups.

## Tool Actions

### Screenshot

Initial implementation should launch Ryoku's existing screenshot command:

```bash
ryoku-cmd-screenshot
```

This preserves the existing `grim`/`slurp`/`satty` flow, saves to the configured screenshots path, and copies the image to the clipboard.

### Open Screenshots

Open the screenshots folder, creating it first if needed.

Use XDG Pictures when available, falling back to `$HOME/Pictures`. Ryoku's current screenshot command saves directly into the pictures directory unless overridden by `RYOKU_SCREENSHOT_DIR`, so the opener should prefer:

1. `$RYOKU_SCREENSHOT_DIR`
2. `$XDG_PICTURES_DIR`
3. `$HOME/Pictures`

### Screen Recorder And Stop Recording

Use Ryoku's existing screen-record command for the default action:

```bash
ryoku-cmd-screenrecord
```

When a `gpu-screen-recorder` process is active, the same button becomes Stop Recording and calls the same command, which already toggles stop behavior.

The button state should poll or process-check `gpu-screen-recorder` so it stays accurate when recording starts or stops outside the toolbox.

### Open Recordings

Open the recordings folder, creating it first if needed.

Use:

1. `$RYOKU_SCREENRECORD_DIR`
2. `$XDG_VIDEOS_DIR`
3. `$HOME/Videos`

Ryoku's existing `ryoku-cmd-screenrecord` saves directly into that directory.

### Color Picker

The toolbox should launch a richer color picker helper based on Ambxst's `colorpicker.py`, adapted to Ryoku style and command naming.

Add:

- `bin/ryoku-cmd-colorpicker`

Behavior:

- use `slurp -p` to pick a pixel
- capture it with `grim`
- read RGB with ImageMagick `magick`
- copy HEX to clipboard by default
- show a notification with actions to copy HEX, RGB, or HSV

The existing direct keybind using `hyprpicker -a` can stay as a separate shortcut unless implementation explicitly consolidates it later.

### OCR

Add:

- `bin/ryoku-cmd-ocr`

Behavior:

- select a region with `slurp`
- capture the region with `grim`
- OCR with `tesseract`
- copy detected text to the clipboard
- notify success, no text, or missing dependency

Default languages should match Ambxst's default: `eng+spa`.

### QR Code

Add:

- `bin/ryoku-cmd-qr-scan`

Behavior:

- select a region with `slurp`
- capture the region with `grim`
- decode with `zbarimg -q --raw -`
- copy decoded content to the clipboard
- notify success, no code, or missing dependency

### Google Lens

Add:

- `bin/ryoku-cmd-google-lens`

Behavior:

- select a region with `slurp`
- save it to a temp image path
- upload it to a temporary image host as Ambxst does
- open `https://lens.google.com/uploadbyurl?url=<uploaded-url>`
- clean up the temp file
- notify upload or browser errors

The helper must make clear through notification text that the selected image is uploaded to a third-party host for Google Lens. This is necessary because the feature cannot work by local file path alone.

### Mirror

Add a Quickshell mirror window based on Ambxst's `MirrorWindow.qml`, adapted to Ryoku theme imports and state.

New state:

- `ShellState.mirrorVisible` or a dedicated `ToolboxState.mirrorVisible`

New component:

- `config/quickshell/ryoku/vendor/brain-shell/src/windows/MirrorWindow.qml`

Behavior:

- visible when mirror state is true
- uses Qt Multimedia camera capture
- starts as a 300x300 rounded square near the right side of the current screen
- mirrored horizontally by default
- can be dragged
- can be resized from corners
- hover controls can toggle square/wide mode, flip horizontally, or close

The implementation should reuse `QtMultimedia` already present in Ryoku's package list.

### Caffeine

Caffeine is the Ryoku extra item. It should use the existing systemd-inhibit pattern already present in `QuickSettings.qml`.

Recommended implementation:

- centralize caffeine state into a small service, or minimally duplicate the process pattern in the toolbox if extraction is too large for this feature
- check for `systemd-inhibit.*Caffeine`
- start `systemd-inhibit --what=idle:sleep --who=Ryoku --why="Caffeine mode" sleep infinity`
- stop with `pkill -f 'systemd-inhibit.*Caffeine'`
- show active state in the toolbox icon/tooltip

If a shared service is extracted, update dashboard Quick Settings to use it too. That reduces duplicated state and prevents the dashboard tile from disagreeing with the toolbox item.

## Packages

Ryoku already includes most required packages:

- `grim`
- `slurp`
- `wl-clipboard`
- `imagemagick`
- `gpu-screen-recorder`
- `hyprpicker`
- `qt6-multimedia`
- `qt6-multimedia-ffmpeg`

Add default packages if absent:

- `tesseract`
- `tesseract-data-eng`
- `tesseract-data-spa`
- `zbar`

`curl`, `jq`, `xdg-utils`, `libnotify`, and XDG user-dir support should be verified before adding. If they are already installed transitively or listed elsewhere, do not duplicate them unnecessarily.

## Testing

Add focused static tests for:

- `Popups.qml` includes toolbox open/visible state and `closeAll()` closes it
- `shell.qml` exposes `toggleToolbox()`
- `bin/ryoku-ipc` supports `shell command toolbox` and `shell toggle toolbox`
- default Hyprland bindings include `SUPER+S` toolbox
- package list includes OCR/QR dependencies
- new helper scripts use `#!/bin/bash`, pass `bash -n`, and use Ryoku command naming

Runtime verification should include:

- `ryoku-ipc shell command toolbox`
- `qs -c ryoku ipc call popups toggleToolbox`
- `SUPER+S` opens and closes the row in the live session
- Screenshot launches and saves/copies
- Open Screenshots opens the intended folder
- Screen Recorder starts/stops or opens the existing recording setup flow
- Open Recordings opens the intended folder
- Color Picker copies a HEX value
- OCR copies selected text
- QR copies decoded content
- Google Lens opens the browser after upload
- Mirror opens, flips, resizes, drags, and closes
- Caffeine toggles inhibit state and reflects active state

## Non-Goals

This feature does not replace Ryoku's dashboard, launcher, wallpaper selector, system menu, settings menu, or standalone capture keybinds.

This feature does not import Ambxst's full shell architecture, configuration system, global state service, or styling system.

This feature does not redesign the existing screen-record center-pill active recording carousel. The toolbox can launch or stop recording, while the existing center-pill recording status remains responsible for active recording controls.
