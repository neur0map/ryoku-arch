# Toolbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a tools menu to Ryoku's center pill, expose it through `ryoku-ipc shell toggle toolbox`, bind it to `SUPER+S`, and ship the helper commands needed by every toolbox action.

**Architecture:** The toolbox is a new Quickshell popup attached to the center topbar notch, with state tracked in `Popups.qml` alongside the launcher. Tool actions call small Ryoku `bin/ryoku-cmd-*` helpers for shell-driven features, reuse the existing Quickshell screen recording service for recording, and use a shared Caffeine singleton so the dashboard tile and toolbox stay synchronized.

**Tech Stack:** Quickshell/QML, Hyprland `bindd`, Bash 5, Wayland tools (`grim`, `slurp`, `wl-clipboard`, `hyprpicker`), OCR/QR tools (`tesseract`, `zbarimg`), `curl`/`jq`, `xdg-open`, `notify-send`.

**Implementation note:** Review changed a few original plan details: the toolbox and launcher are excluded from `Popups.anyOpen` so topbar popups are not swallowed by the full-screen dismiss layer, the active `SUPER+S` binding lives only in `default/hypr/bindings/utilities.conf`, Google Lens upload is explicit-consent only, recording paths are unified under `screen_recordings`, and mirror windows target the monitor that opened the toolbox.

---

## File Map

- Create `tests/quickshell-toolbox.sh`: static regression coverage for popup state, IPC, keybinding, packages, helper scripts, Caffeine singleton, and mirror wiring.
- Create `config/quickshell/ryoku/vendor/brain-shell/src/popups/ToolboxPopup.qml`: center-pill popup with tool actions plus Caffeine.
- Create `config/quickshell/ryoku/vendor/brain-shell/src/windows/MirrorWindow.qml`: webcam mirror window opened from the toolbox.
- Create `config/quickshell/ryoku/vendor/brain-shell/src/services/CaffeineService.qml`: shared singleton for `systemd-inhibit` Caffeine state.
- Create `bin/ryoku-cmd-colorpicker`: copied-to-clipboard color picker helper.
- Create `bin/ryoku-cmd-ocr`: region OCR helper.
- Create `bin/ryoku-cmd-qr-scan`: region QR scanner helper.
- Create `bin/ryoku-cmd-google-lens`: selected-image Google Lens reverse image search helper.
- Modify `config/quickshell/ryoku/shell.qml`: add `toggleToolbox()`.
- Modify `bin/ryoku-ipc`: add `toolbox` to shell command/toggle help and dispatch.
- Modify `config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml`: add `toolboxOpen`, `toolboxVisible`, and `mirrorOpen`.
- Modify `config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml`: keep the bar on overlay while the toolbox animates.
- Modify `config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml`: instantiate `ToolboxPopup` and `MirrorWindow`.
- Modify `config/quickshell/ryoku/vendor/brain-shell/src/services/qmldir`: register `CaffeineService`.
- Modify `config/quickshell/ryoku/vendor/brain-shell/src/state/ShellState.qml`: update the Caffeine ownership comment.
- Modify `config/quickshell/ryoku/vendor/brain-shell/src/services/home/QuickSettings.qml`: replace local Caffeine process state with `CaffeineService`.
- Modify `default/hypr/bindings/utilities.conf`: bind `SUPER+S` to `ryoku-ipc shell toggle toolbox`.
- Modify `install/ryoku-base.packages`: add missing runtime packages.

Do not modify or stage these unrelated dirty files unless the user explicitly redirects the task:

- `config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml`
- `tests/dashboard-top-controls.sh`

---

## Task 1: Static Toolbox Contract Test

**Files:**
- Create: `tests/quickshell-toolbox.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/quickshell-toolbox.sh` with executable mode:

```bash
#!/bin/bash
# Static regression checks for the center-pill toolbox.

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

shell="config/quickshell/ryoku/shell.qml"
popups="config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml"
shell_state="config/quickshell/ryoku/vendor/brain-shell/src/state/ShellState.qml"
topbar="config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml"
layer="config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml"
toolbox="config/quickshell/ryoku/vendor/brain-shell/src/popups/ToolboxPopup.qml"
mirror="config/quickshell/ryoku/vendor/brain-shell/src/windows/MirrorWindow.qml"
caffeine="config/quickshell/ryoku/vendor/brain-shell/src/services/CaffeineService.qml"
services_qmldir="config/quickshell/ryoku/vendor/brain-shell/src/services/qmldir"
quick_settings="config/quickshell/ryoku/vendor/brain-shell/src/services/home/QuickSettings.qml"
ipc="bin/ryoku-ipc"
bindings="default/hypr/bindings/utilities.conf"
plain_bindings="default/hypr/plain-bindings.conf"
packages="install/ryoku-base.packages"

helpers=(
  bin/ryoku-cmd-colorpicker
  bin/ryoku-cmd-ocr
  bin/ryoku-cmd-qr-scan
  bin/ryoku-cmd-google-lens
)

for path in "$shell" "$popups" "$shell_state" "$topbar" "$layer" "$toolbox" "$mirror" "$caffeine" "$services_qmldir" "$quick_settings" "$ipc" "$bindings" "$plain_bindings" "$packages"; do
  [[ -f $path ]] || fail "$path missing"
done

for path in "${helpers[@]}"; do
  [[ -f $path ]] || fail "$path missing"
  [[ -x $path ]] || fail "$path should be executable"
  bash -n "$path" || fail "$path has a syntax error"
done

grep -q 'function toggleToolbox' "$shell" \
  || fail "shell IPC should expose toggleToolbox"
grep -q 'BS.Popups.toolboxOpen = opening' "$shell" \
  || fail "toggleToolbox should open toolbox after closing other popups"

grep -q 'property bool toolboxOpen' "$popups" \
  || fail "Popups should track toolboxOpen"
grep -q 'property bool toolboxVisible' "$popups" \
  || fail "Popups should track toolbox visual presence"
grep -q 'property bool mirrorOpen' "$popups" \
  || fail "Popups should track mirrorOpen"
awk '/readonly property bool anyOpen:/,/function closeAll/' "$popups" | grep -q 'toolboxOpen' \
  || fail "anyOpen should include toolboxOpen for global close behavior"
grep -q 'toolboxOpen       = false' "$popups" \
  || fail "closeAll should close the toolbox"
grep -q 'mirrorOpen        = false' "$popups" \
  || fail "closeAll should close the mirror"

grep -q 'Popups.toolboxVisible' "$topbar" \
  || fail "TopBar should stay on overlay while toolbox animates"
grep -q 'ToolboxPopup' "$layer" \
  || fail "PopupLayer should instantiate ToolboxPopup"
grep -q 'MirrorWindow' "$layer" \
  || fail "PopupLayer should instantiate MirrorWindow"

grep -q 'Binding { target: Popups; property: "toolboxVisible"' "$toolbox" \
  || fail "ToolboxPopup should expose visual presence"
grep -q 'attachedEdge: "top"' "$toolbox" \
  || fail "ToolboxPopup should attach to the topbar"
grep -q 'ListModel {' "$toolbox" \
  || fail "ToolboxPopup should use stable ListModel roles"
for label in "Screenshot" "Open Screenshots" "Screen Recorder" "Open Recordings" "Color Picker" "OCR" "QR Code" "Google Lens" "Mirror" "Caffeine"; do
  grep -q "$label" "$toolbox" || fail "ToolboxPopup should include $label"
done
grep -q 'ScreenRecService.recording' "$toolbox" \
  || fail "ToolboxPopup should reuse ScreenRecService recording state"
grep -q 'ShellState.screenRecord = true' "$toolbox" \
  || fail "ToolboxPopup should open the existing recording setup surface"
grep -q 'ryoku-cmd-screenrecord", "--stop-recording"' "$toolbox" \
  || fail "ToolboxPopup should stop legacy gpu-screen-recorder as fallback"
grep -q 'CaffeineService.toggle()' "$toolbox" \
  || fail "ToolboxPopup should toggle shared CaffeineService"
grep -q 'Popups.mirrorOpen = true' "$toolbox" \
  || fail "ToolboxPopup should open the mirror window"

grep -q 'Camera {' "$mirror" \
  || fail "MirrorWindow should use QtMultimedia Camera"
grep -q 'VideoOutput {' "$mirror" \
  || fail "MirrorWindow should render a video preview"
grep -q 'xScale: -1' "$mirror" \
  || fail "MirrorWindow preview should be mirrored horizontally"
grep -q 'Popups.mirrorOpen' "$mirror" \
  || fail "MirrorWindow should be controlled by Popups.mirrorOpen"

grep -q 'singleton CaffeineService 1.0 CaffeineService.qml' "$services_qmldir" \
  || fail "services qmldir should register CaffeineService"
grep -q 'pragma Singleton' "$caffeine" \
  || fail "CaffeineService should be a singleton"
grep -q 'systemd-inhibit' "$caffeine" \
  || fail "CaffeineService should use systemd-inhibit"
grep -q 'pgrep -f' "$caffeine" \
  || fail "CaffeineService should poll existing inhibitor state"
grep -q 'pkill -f' "$caffeine" \
  || fail "CaffeineService should stop existing inhibitor processes"
grep -q 'CaffeineService' "$quick_settings" \
  || fail "QuickSettings should use shared CaffeineService"
! grep -q 'property bool caffeineOn' "$quick_settings" \
  || fail "QuickSettings should not keep separate Caffeine state"
grep -q 'Caffeine          - owned by CaffeineService' "$shell_state" \
  || fail "ShellState comment should name CaffeineService ownership"

"$ipc" --help | grep -q "ryoku-ipc shell toggle toolbox" \
  || fail "ryoku-ipc help should document toolbox toggle"
"$ipc" shell command toolbox | grep -q 'qs -c ryoku ipc call popups toggleToolbox' \
  || fail "ryoku-ipc should print the toolbox IPC command"

grep -q 'bindd = SUPER, S, Toolbox, exec, ryoku-ipc shell toggle toolbox' "$bindings" \
  || fail "SUPER+S should open the toolbox"
active_super_s_count="$(grep -Rhs '^bindd = SUPER, S,' default/hypr/bindings/*.conf | wc -l)"
(( active_super_s_count == 1 )) \
  || fail "there should be exactly one active SUPER+S binding in default/hypr/bindings"
grep -q 'bindd = SUPER, S, Toolbox, exec, ryoku-ipc shell toggle toolbox' "$plain_bindings" \
  || fail "plain bindings should document SUPER+S toolbox"

for pkg in libnotify tesseract tesseract-data-eng tesseract-data-spa xdg-user-dirs xdg-utils zbar; do
  grep -qx "$pkg" "$packages" || fail "$pkg should be in ryoku-base packages"
done

grep -q 'hyprpicker' bin/ryoku-cmd-colorpicker \
  || fail "color picker helper should use hyprpicker"
grep -q 'tesseract' bin/ryoku-cmd-ocr \
  || fail "OCR helper should use tesseract"
grep -q 'zbarimg' bin/ryoku-cmd-qr-scan \
  || fail "QR helper should use zbarimg"
grep -q 'lens.google.com/uploadbyurl' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should open uploadbyurl"
grep -q 'https://uguu.se/upload' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should upload the selected image"
grep -q 'Uploading selected image' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should notify before upload"

pass "toolbox static contract"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
chmod +x tests/quickshell-toolbox.sh
tests/quickshell-toolbox.sh
```

Expected: FAIL with `config/quickshell/ryoku/vendor/brain-shell/src/popups/ToolboxPopup.qml missing`.

---

## Task 2: Popup State, IPC, and Keybinding Plumbing

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml`
- Modify: `config/quickshell/ryoku/shell.qml`
- Modify: `bin/ryoku-ipc`
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml`
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml`
- Modify: `default/hypr/bindings/utilities.conf`
- Modify: `default/hypr/plain-bindings.conf`

- [ ] **Step 1: Add popup state**

In `config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml`, add these properties beside the other topbar popup states:

```qml
    property bool toolboxOpen:      false
    property bool mirrorOpen:       false
```

Add visual state beside `launcherVisible`:

```qml
    property bool toolboxVisible:   false
```

Update `anyOpen` so the toolbox participates in global close behavior:

```qml
    readonly property bool anyOpen: audioOpen || networkOpen || batteryOpen
                                    || notificationsOpen || archMenuOpen
                                    || dashboardOpen || launcherOpen
                                    || toolboxOpen || wallpaperOpen || quickOpen
```

Update `closeAll()`:

```qml
        launcherOpen      = false
        toolboxOpen       = false
        mirrorOpen        = false
        systemMenuOpen     = false
```

- [ ] **Step 2: Add Quickshell IPC entry point**

In `config/quickshell/ryoku/shell.qml`, add this function inside the existing `IpcHandler { target: "popups" }` block:

```qml
        function toggleToolbox(): void {
            const opening = !BS.Popups.toolboxOpen
            BS.Popups.closeAll()
            BS.Popups.toolboxOpen = opening
        }
```

- [ ] **Step 3: Add `ryoku-ipc` shell target**

In `bin/ryoku-ipc`, add `toolbox` to the usage text:

```bash
  ryoku-ipc shell command toolbox
```

```bash
  ryoku-ipc shell toggle toolbox
```

Update the `shell_command()` argument error:

```bash
    echo "ryoku-ipc: expected shell command wallpaper|launcher|toolbox|themes|dotfiles|system-menu|settings-menu" >&2
```

Add this case arm after `launcher)`:

```bash
    toolbox)
      printf '%s\n' "qs -c ryoku ipc call popups toggleToolbox"
      ;;
```

Update the `shell_toggle()` argument error:

```bash
    echo "ryoku-ipc: expected shell toggle wallpaper|launcher|toolbox|themes|dotfiles|system-menu|settings-menu" >&2
```

Add this case arm after `launcher)`:

```bash
    toolbox)
      exec qs -c ryoku ipc call popups toggleToolbox
      ;;
```

- [ ] **Step 4: Keep the topbar visually joined during animation**

In `config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml`, update the layer expression:

```qml
    WlrLayershell.layer: Popups.dashboardVisible || Popups.launcherVisible || Popups.toolboxVisible || Popups.systemMenuVisible || Popups.settingsMenuVisible
                         ? WlrLayer.Overlay : WlrLayer.Top
```

- [ ] **Step 5: Instantiate toolbox and mirror windows**

In `config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml`, add the new windows with the other active popup windows:

```qml
    AppLauncherPopup {}
    ToolboxPopup {}
    WallpaperPopup {}
    SystemMenuPopup {}
    SettingsMenuPopup {}
    DotfilesHubPopup {}
    MirrorWindow {}
```

Add the import if `MirrorWindow` is not visible through the current imports:

```qml
import "../windows"
```

- [ ] **Step 6: Add the default keybinding**

In `default/hypr/bindings/utilities.conf`, add the toolbox binding under `# Menus`, immediately after the launcher binding:

```conf
bindd = SUPER, S, Toolbox, exec, ryoku-ipc shell toggle toolbox
```

In `default/hypr/plain-bindings.conf`, add the same reference under `# Application bindings` after the terminal binding:

```conf
bindd = SUPER, S, Toolbox, exec, ryoku-ipc shell toggle toolbox
```

- [ ] **Step 7: Verify the plumbing is not enough yet**

Run:

```bash
tests/quickshell-toolbox.sh
```

Expected: FAIL with `config/quickshell/ryoku/vendor/brain-shell/src/popups/ToolboxPopup.qml missing`.

---

## Task 3: Helper Commands and Package List

**Files:**
- Create: `bin/ryoku-cmd-colorpicker`
- Create: `bin/ryoku-cmd-ocr`
- Create: `bin/ryoku-cmd-qr-scan`
- Create: `bin/ryoku-cmd-google-lens`
- Modify: `install/ryoku-base.packages`

- [ ] **Step 1: Create color picker helper**

Create `bin/ryoku-cmd-colorpicker`:

```bash
#!/bin/bash

set -euo pipefail

if ryoku-cmd-missing hyprpicker; then
  notify-send -u normal "Color Picker" "hyprpicker is not installed"
  exit 1
fi

pkill hyprpicker 2>/dev/null || true
exec hyprpicker -a
```

Run:

```bash
chmod +x bin/ryoku-cmd-colorpicker
bash -n bin/ryoku-cmd-colorpicker
```

Expected: no output and exit code 0.

- [ ] **Step 2: Create OCR helper**

Create `bin/ryoku-cmd-ocr`:

```bash
#!/bin/bash

set -euo pipefail

for cmd in grim slurp tesseract wl-copy notify-send; do
  if ryoku-cmd-missing "$cmd"; then
    notify-send -u normal "OCR" "$cmd is not installed"
    exit 1
  fi
done

tmp="${XDG_RUNTIME_DIR:-/tmp}/ryoku-ocr-$$.png"

cleanup() {
  rm -f "$tmp"
}
trap cleanup EXIT

if ! geometry="$(slurp 2>/dev/null)"; then
  exit 130
fi

if [[ -z $geometry ]]; then
  exit 0
fi

grim -g "$geometry" "$tmp"

if ! text="$(tesseract "$tmp" stdout -l eng+spa 2>/dev/null | sed '/^[[:space:]]*$/d')"; then
  notify-send -u normal "OCR" "Could not read text from the selected area"
  exit 1
fi

if [[ -z $text ]]; then
  notify-send -u normal "OCR" "No text found in the selected area"
  exit 0
fi

printf '%s\n' "$text" | wl-copy
notify-send -u normal "OCR" "Copied recognized text to clipboard"
```

Run:

```bash
chmod +x bin/ryoku-cmd-ocr
bash -n bin/ryoku-cmd-ocr
```

Expected: no output and exit code 0.

- [ ] **Step 3: Create QR scanner helper**

Create `bin/ryoku-cmd-qr-scan`:

```bash
#!/bin/bash

set -euo pipefail

for cmd in grim slurp zbarimg wl-copy notify-send; do
  if ryoku-cmd-missing "$cmd"; then
    notify-send -u normal "QR Code" "$cmd is not installed"
    exit 1
  fi
done

tmp="${XDG_RUNTIME_DIR:-/tmp}/ryoku-qr-$$.png"

cleanup() {
  rm -f "$tmp"
}
trap cleanup EXIT

if ! geometry="$(slurp 2>/dev/null)"; then
  exit 130
fi

if [[ -z $geometry ]]; then
  exit 0
fi

grim -g "$geometry" "$tmp"
result="$(zbarimg --raw "$tmp" 2>/dev/null | head -n 1 || true)"

if [[ -z $result ]]; then
  notify-send -u normal "QR Code" "No QR code found in the selected area"
  exit 0
fi

printf '%s\n' "$result" | wl-copy

case "$result" in
  http://*|https://*)
    notify-send -u normal "QR Code" "Copied URL to clipboard" -A "default=Open" | while read -r action; do
      [[ $action == "default" ]] && xdg-open "$result" >/dev/null 2>&1
    done
    ;;
  *)
    notify-send -u normal "QR Code" "Copied result to clipboard"
    ;;
esac
```

Run:

```bash
chmod +x bin/ryoku-cmd-qr-scan
bash -n bin/ryoku-cmd-qr-scan
```

Expected: no output and exit code 0.

- [ ] **Step 4: Create Google Lens helper**

Create `bin/ryoku-cmd-google-lens`:

```bash
#!/bin/bash

set -euo pipefail

for cmd in curl grim jq notify-send slurp xdg-open; do
  if ryoku-cmd-missing "$cmd"; then
    notify-send -u normal "Google Lens" "$cmd is not installed"
    exit 1
  fi
done

tmp="${XDG_RUNTIME_DIR:-/tmp}/ryoku-google-lens-$$.png"

cleanup() {
  rm -f "$tmp"
}
trap cleanup EXIT

if ! geometry="$(slurp 2>/dev/null)"; then
  exit 130
fi

if [[ -z $geometry ]]; then
  exit 0
fi

grim -g "$geometry" "$tmp"
notify-send -u normal "Google Lens" "Uploading selected image for reverse image search"

if ! response="$(curl -fsS -F "files[]=@$tmp" https://uguu.se/upload)"; then
  notify-send -u critical "Google Lens" "Image upload failed"
  exit 1
fi

remote_url="$(printf '%s' "$response" | jq -r '.files[0].url // .files[0].src // empty')"

if [[ -z $remote_url ]]; then
  notify-send -u critical "Google Lens" "Upload response did not include an image URL"
  exit 1
fi

encoded_url="$(jq -nr --arg url "$remote_url" '$url|@uri')"
xdg-open "https://lens.google.com/uploadbyurl?url=$encoded_url" >/dev/null 2>&1
```

Run:

```bash
chmod +x bin/ryoku-cmd-google-lens
bash -n bin/ryoku-cmd-google-lens
```

Expected: no output and exit code 0.

- [ ] **Step 5: Add missing package dependencies**

In `install/ryoku-base.packages`, add these lines in alphabetical order inside the most relevant sections:

Under `# Shell, CLI tooling, fuzzy finders`:

```text
xdg-user-dirs
xdg-utils
```

Under `# GUI apps - multimedia editing & screen capture`:

```text
libnotify
```

Under `# Screenshot / clipboard / region picker`:

```text
tesseract
tesseract-data-eng
tesseract-data-spa
zbar
```

- [ ] **Step 6: Verify helpers and packages**

Run:

```bash
bash -n bin/ryoku-cmd-colorpicker
bash -n bin/ryoku-cmd-ocr
bash -n bin/ryoku-cmd-qr-scan
bash -n bin/ryoku-cmd-google-lens
tests/quickshell-toolbox.sh
```

Expected: helper syntax checks pass; static test still fails because `ToolboxPopup.qml`, `MirrorWindow.qml`, and `CaffeineService.qml` do not exist yet.

---

## Task 4: Shared Caffeine Service

**Files:**
- Create: `config/quickshell/ryoku/vendor/brain-shell/src/services/CaffeineService.qml`
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/services/qmldir`
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/state/ShellState.qml`
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/services/home/QuickSettings.qml`

- [ ] **Step 1: Create singleton service**

Create `config/quickshell/ryoku/vendor/brain-shell/src/services/CaffeineService.qml`:

```qml
pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
  id: root

  property bool active: false
  property bool busy: false

  Process {
    id: caffeineCheck
    command: ["bash", "-c", "pgrep -f 'systemd-inhibit.*Caffeine'"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.active = text.trim() !== ""
    }
  }

  Process {
    id: caffeineProc
    command: ["systemd-inhibit", "--what=idle:sleep", "--who=Ryoku", "--why=Caffeine mode", "sleep", "infinity"]
    running: false
    onRunningChanged: if (!running && root.active && !root.busy) root.refresh()
  }

  Process {
    id: caffeineKill
    command: ["bash", "-c", "pkill -f 'systemd-inhibit.*Caffeine'"]
    running: false
    onRunningChanged: if (!running) {
      root.active = false
      root.busy = false
      root.refresh()
    }
  }

  Timer {
    id: refreshTimer
    interval: 800
    repeat: false
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()

  function refresh() {
    caffeineCheck.running = false
    caffeineCheck.running = true
  }

  function start() {
    if (root.active) return
    root.busy = true
    caffeineKill.running = false
    caffeineProc.running = false
    caffeineProc.running = true
    root.active = true
    root.busy = false
    refreshTimer.restart()
  }

  function stop() {
    root.busy = true
    caffeineProc.running = false
    caffeineKill.running = false
    caffeineKill.running = true
  }

  function toggle() {
    if (root.active) root.stop()
    else root.start()
  }
}
```

- [ ] **Step 2: Register singleton**

Add this line to `config/quickshell/ryoku/vendor/brain-shell/src/services/qmldir` near the other singleton services:

```text
singleton CaffeineService 1.0 CaffeineService.qml
```

- [ ] **Step 3: Update state ownership comment**

In `config/quickshell/ryoku/vendor/brain-shell/src/state/ShellState.qml`, replace the Caffeine comment line with:

```qml
// Caffeine          - owned by CaffeineService
```

- [ ] **Step 4: Remove local Caffeine process state from QuickSettings**

In `config/quickshell/ryoku/vendor/brain-shell/src/services/home/QuickSettings.qml`, delete this local block:

```qml
    // ─────────────────────────────────────────────────────────────────────────
    //  Caffeine  (systemd-inhibit)
    // ─────────────────────────────────────────────────────────────────────────
    property bool caffeineOn: false

    Process { id: caffeineCheck
        command: ["bash", "-c", "pgrep -f 'systemd-inhibit.*Caffeine'"]; running: false
        stdout: SplitParser { onRead: function(l) { if (l.trim() !== "") root.caffeineOn = true } } }
    Process { id: caffeineProc
        command: ["systemd-inhibit","--what=idle:sleep",
                  "--who=Brain Shell","--why=Caffeine mode","sleep","infinity"]
        running: false }
    Process { id: caffeineKill
        command: ["bash", "-c", "pkill -f 'systemd-inhibit.*Caffeine'"]; running: false
        onRunningChanged: if (!running) root.caffeineOn = false }
    function _caffeineToggle() {
        if (root.caffeineOn) {
            caffeineProc.running = false
            caffeineKill.running = false; caffeineKill.running = true
        } else { caffeineProc.running = true; root.caffeineOn = true }
    }
```

In `Component.onCompleted`, remove this line:

```qml
        caffeineCheck.running   = true
```

Update the Caffeine tile:

```qml
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: CaffeineService.active; icon: "󰅶"; label: "Caffeine"
                        onToggled: CaffeineService.toggle()
                    }
```

- [ ] **Step 5: Verify Caffeine contract**

Run:

```bash
tests/quickshell-toolbox.sh
```

Expected: static test still fails because `ToolboxPopup.qml` and `MirrorWindow.qml` do not exist yet, but all Caffeine-specific checks pass.

---

## Task 5: Toolbox Popup UI and Actions

**Files:**
- Create: `config/quickshell/ryoku/vendor/brain-shell/src/popups/ToolboxPopup.qml`

- [ ] **Step 1: Create the toolbox popup**

Create `config/quickshell/ryoku/vendor/brain-shell/src/popups/ToolboxPopup.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"
import "../services/"
import "../shapes"

PanelWindow {
  id: root

  Binding { target: Popups; property: "toolboxVisible"; value: card.visible }

  readonly property int fw: Theme.notchRadius
  readonly property int fh: Theme.notchRadius
  readonly property int menuWidth: 454
  readonly property int menuHeight: 244
  readonly property int fullCardWidth: root.menuWidth + 2 * root.fw
  readonly property int fullCardHeight: Theme.notchHeight + root.menuHeight
  readonly property int initialCardWidth: ShellState.topBarCWidth + 2 * root.fw
  readonly property int initialCardHeight: Theme.notchHeight

  property bool windowVisible: false
  property real openProgress: Popups.toolboxOpen ? 1 : 0

  Behavior on openProgress {
    enabled: !Theme.staticMode
    NumberAnimation {
      duration: Theme.motionExpandDuration
      easing.type: Popups.toolboxOpen ? Easing.OutBack : Easing.OutQuart
      easing.overshoot: 1.10
    }
  }

  color: "transparent"
  visible: root.windowVisible
  implicitHeight: root.fullCardHeight + 8
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  ListModel {
    id: toolActions

    ListElement { label: "Screenshot";       hint: "Capture"; icon: "󰹑"; action: "screenshot";       separatorBefore: false }
    ListElement { label: "Open Screenshots"; hint: "Folder";  icon: "󰉋"; action: "screenshots";      separatorBefore: false }
    ListElement { label: "Screen Recorder";  hint: "Record";  icon: "󰻂"; action: "screenrecord";     separatorBefore: true }
    ListElement { label: "Open Recordings";  hint: "Folder";  icon: "󰉋"; action: "recordings";       separatorBefore: false }
    ListElement { label: "Color Picker";     hint: "Pick";    icon: "󰈋"; action: "colorpicker";      separatorBefore: true }
    ListElement { label: "OCR";              hint: "Text";    icon: "󰷊"; action: "ocr";              separatorBefore: false }
    ListElement { label: "QR Code";          hint: "Scan";    icon: "󰐲"; action: "qr";               separatorBefore: false }
    ListElement { label: "Google Lens";      hint: "Search";  icon: "󰊭"; action: "google-lens";      separatorBefore: false }
    ListElement { label: "Mirror";           hint: "Camera";  icon: "󰄀"; action: "mirror";           separatorBefore: true }
    ListElement { label: "Caffeine";         hint: "Awake";   icon: "󰅶"; action: "caffeine";         separatorBefore: false }
  }

  Connections {
    target: Popups

    function onToolboxOpenChanged() {
      if (Popups.toolboxOpen) {
        closeTimer.stop()
        root.windowVisible = true
      } else {
        closeTimer.restart()
      }
    }
  }

  Timer {
    id: closeTimer
    interval: Theme.motionExpandDuration + 50
    onTriggered: root.windowVisible = false
  }

  Process {
    id: actionRunner
    command: []
    running: false
    onRunningChanged: if (!running) command = []
  }

  Process {
    id: legacyRecorderStop
    command: ["ryoku-cmd-screenrecord", "--stop-recording"]
    running: false
  }

  function runAction(action) {
    switch (action) {
    case "screenshot":
      actionRunner.command = ["ryoku-cmd-screenshot"]
      break
    case "screenshots":
      actionRunner.command = ["bash", "-c", "source ~/.config/user-dirs.dirs 2>/dev/null || true; dir=\"${RYOKU_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}\"; mkdir -p \"$dir\"; xdg-open \"$dir\""]
      break
    case "screenrecord":
      if (ScreenRecService.recording) {
        ScreenRecService.stopRecording()
        legacyRecorderStop.running = false
        legacyRecorderStop.running = true
      } else if (ShellState.screenRecord) {
        ScreenRecService.cancelSetup()
      } else {
        Popups.closeAll()
        ShellState.screenRecord = true
        return
      }
      break
    case "recordings":
      actionRunner.command = ["bash", "-c", "dir=\"$HOME/Videos/screen_recordings\"; mkdir -p \"$dir\"; xdg-open \"$dir\""]
      break
    case "colorpicker":
      actionRunner.command = ["ryoku-cmd-colorpicker"]
      break
    case "ocr":
      actionRunner.command = ["ryoku-cmd-ocr"]
      break
    case "qr":
      actionRunner.command = ["ryoku-cmd-qr-scan"]
      break
    case "google-lens":
      actionRunner.command = ["ryoku-cmd-google-lens"]
      break
    case "mirror":
      Popups.closeAll()
      Popups.mirrorOpen = true
      return
    case "caffeine":
      CaffeineService.toggle()
      return
    default:
      return
    }

    actionRunner.running = true
    Popups.closeAll()
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.windowVisible
    onClicked: Popups.closeAll()
  }

  Item {
    id: card

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top

    width: root.initialCardWidth + (root.fullCardWidth - root.initialCardWidth) * root.openProgress
    height: root.initialCardHeight + (root.fullCardHeight - root.initialCardHeight) * root.openProgress
    visible: root.openProgress > 0
    clip: true

    PopupShape {
      anchors.fill: parent
      attachedEdge: "top"
      color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.96)
      strokeColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.24)
      strokeWidth: 1
      radius: Theme.cornerRadius
      flareWidth: root.fw
      flareHeight: root.fh
    }

    MouseArea {
      anchors.fill: parent
      onClicked: mouse.accepted = true
    }

    Item {
      anchors {
        fill: parent
        topMargin: Theme.notchHeight + 8
        leftMargin: root.fw + 10
        rightMargin: root.fw + 10
        bottomMargin: 10
      }

      opacity: Math.min(1, root.openProgress * 1.35)

      Behavior on opacity {
        enabled: !Theme.staticMode
        NumberAnimation { duration: Theme.motionEffectsDuration }
      }

      Grid {
        id: grid
        width: parent.width
        columns: 2
        rowSpacing: 6
        columnSpacing: 6

        readonly property int buttonWidth: (width - columnSpacing) / 2
        readonly property int buttonHeight: 38

        Repeater {
          model: toolActions

          delegate: Rectangle {
            id: button

            required property string label
            required property string hint
            required property string icon
            required property string action
            required property bool separatorBefore

            width: grid.buttonWidth
            height: grid.buttonHeight
            radius: 8
            color: hover.hovered
              ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
              : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.04)
            border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
              id: iconBadge
              anchors {
                left: parent.left
                leftMargin: 8
                verticalCenter: parent.verticalCenter
              }
              width: 24
              height: 24
              radius: 8
              color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)

              Text {
                anchors.centerIn: parent
                text: button.action === "screenrecord" && ScreenRecService.recording ? "⏹" : button.icon
                color: Theme.active
                font.pixelSize: 13
              }
            }

            Column {
              anchors {
                left: iconBadge.right
                leftMargin: 8
                right: parent.right
                rightMargin: 8
                verticalCenter: parent.verticalCenter
              }
              spacing: -1

              Text {
                width: parent.width
                text: button.action === "screenrecord" && ScreenRecService.recording ? "Stop Recording" : button.label
                color: Theme.text
                font.pixelSize: 10
                font.weight: Font.Medium
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: button.action === "caffeine" && CaffeineService.active ? "On" : button.hint
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.44)
                font.pixelSize: 8
                elide: Text.ElideRight
              }
            }

            HoverHandler {
              id: hover
              cursorShape: Qt.PointingHandCursor
            }

            MouseArea {
              anchors.fill: parent
              onClicked: root.runAction(button.action)
            }
          }
        }
      }
    }
  }
}
```

- [ ] **Step 2: Verify toolbox UI contract**

Run:

```bash
tests/quickshell-toolbox.sh
```

Expected: static test still fails because `MirrorWindow.qml` does not exist yet, but toolbox-specific checks pass.

---

## Task 6: Mirror Window

**Files:**
- Create: `config/quickshell/ryoku/vendor/brain-shell/src/windows/MirrorWindow.qml`

- [ ] **Step 1: Create mirror window**

Create `config/quickshell/ryoku/vendor/brain-shell/src/windows/MirrorWindow.qml`:

```qml
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
  id: root

  property bool windowVisible: Popups.mirrorOpen

  color: "transparent"
  visible: root.windowVisible
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  MediaDevices {
    id: devices
  }

  Camera {
    id: camera
    active: root.windowVisible
    cameraDevice: devices.defaultVideoInput
  }

  CaptureSession {
    camera: camera
    videoOutput: preview
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.42)

    MouseArea {
      anchors.fill: parent
      onClicked: Popups.mirrorOpen = false
    }
  }

  Rectangle {
    id: panel
    width: Math.min(560, parent.width - 48)
    height: Math.min(420, parent.height - 96)
    anchors.centerIn: parent
    radius: 10
    color: Theme.background
    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)
    border.width: 1
    clip: true

    VideoOutput {
      id: preview
      anchors.fill: parent
      fillMode: VideoOutput.PreserveAspectCrop
      transform: Scale {
        origin.x: preview.width / 2
        xScale: -1
      }
    }

    Rectangle {
      anchors {
        top: parent.top
        left: parent.left
        right: parent.right
      }
      height: 38
      color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.76)

      Text {
        anchors {
          left: parent.left
          leftMargin: 12
          verticalCenter: parent.verticalCenter
        }
        text: "Mirror"
        color: Theme.text
        font.pixelSize: 12
        font.weight: Font.Medium
      }

      Text {
        anchors {
          right: parent.right
          rightMargin: 12
          verticalCenter: parent.verticalCenter
        }
        text: "Close"
        color: Theme.active
        font.pixelSize: 11

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: Popups.mirrorOpen = false
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: mouse.accepted = true
    }
  }

  Keys.onEscapePressed: Popups.mirrorOpen = false
}
```

- [ ] **Step 2: Verify full static contract**

Run:

```bash
tests/quickshell-toolbox.sh
```

Expected: `OK: toolbox static contract`.

---

## Task 7: Runtime Smoke Verification

**Files:**
- No source edits unless a verification command exposes a defect in files from earlier tasks.

- [ ] **Step 1: Run static tests**

Run:

```bash
tests/quickshell-toolbox.sh
tests/quickshell-topbar-settings-menus.sh
```

Expected:

```text
OK: toolbox static contract
```

The existing topbar settings menu test should keep passing. If it fails because of pre-existing dirty local edits, inspect the failure and avoid reverting unrelated changes.

- [ ] **Step 2: Check helper scripts with shell syntax**

Run:

```bash
bash -n bin/ryoku-cmd-colorpicker
bash -n bin/ryoku-cmd-ocr
bash -n bin/ryoku-cmd-qr-scan
bash -n bin/ryoku-cmd-google-lens
```

Expected: no output and exit code 0 for each command.

- [ ] **Step 3: Confirm IPC command output**

Run:

```bash
bin/ryoku-ipc shell command toolbox
```

Expected:

```text
qs -c ryoku ipc call popups toggleToolbox
```

- [ ] **Step 4: Refresh and restart the live shell**

Run:

```bash
env RYOKU_PATH=/home/omi/prowl/ryoku-arch bin/ryoku-refresh-quickshell
bin/ryoku-restart-shell
```

Expected: Quickshell restarts without a QML parse error.

- [ ] **Step 5: Apply Hyprland binding to the live config**

Refresh the live binding file, then reload Hyprland:

```bash
ryoku-refresh-config hypr/bindings/utilities.conf
hyprctl reload
```

Expected: `hyprctl reload` exits 0.

- [ ] **Step 6: Install missing packages on the live system**

Run:

```bash
ryoku-pkg-add libnotify tesseract tesseract-data-eng tesseract-data-spa xdg-user-dirs xdg-utils zbar
```

Expected: packages are installed or already present.

- [ ] **Step 7: Exercise the toolbox**

Run:

```bash
ryoku-ipc shell toggle toolbox
```

Expected: center-pill toolbox opens. Then press `SUPER+S` and confirm it toggles closed/open.

Manual checks:

- Screenshot opens the existing screenshot flow.
- Open Screenshots opens the configured pictures directory.
- Screen Recorder opens the existing center-pill recording setup when not recording.
- Screen Recorder changes to Stop Recording while `ScreenRecService.recording` is true.
- Open Recordings opens `$HOME/Videos/screen_recordings`.
- Color Picker copies a color through `hyprpicker`.
- OCR copies selected text to clipboard.
- QR Code copies selected QR content to clipboard.
- Google Lens shows an upload notification and opens the Lens URL.
- Mirror opens the camera window and closes with Escape or the close control.
- Caffeine toggles the same state as the dashboard Quick Settings tile.

---

## Task 8: Commit Relevant Changes Only

**Files:**
- All files created or modified by this plan.

- [ ] **Step 1: Review the worktree**

Run:

```bash
git status --short
```

Expected: the task files from this plan are shown. The unrelated dirty files below may still appear and must not be staged:

```text
 M config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml
 M tests/dashboard-top-controls.sh
```

- [ ] **Step 2: Stage only toolbox files**

Run:

```bash
git add tests/quickshell-toolbox.sh \
  config/quickshell/ryoku/shell.qml \
  bin/ryoku-ipc \
  config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml \
  config/quickshell/ryoku/vendor/brain-shell/src/state/ShellState.qml \
  config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml \
  config/quickshell/ryoku/vendor/brain-shell/src/windows/MirrorWindow.qml \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/ToolboxPopup.qml \
  config/quickshell/ryoku/vendor/brain-shell/src/services/CaffeineService.qml \
  config/quickshell/ryoku/vendor/brain-shell/src/services/qmldir \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/QuickSettings.qml \
  default/hypr/bindings/utilities.conf \
  default/hypr/plain-bindings.conf \
  install/ryoku-base.packages \
  bin/ryoku-cmd-colorpicker \
  bin/ryoku-cmd-ocr \
  bin/ryoku-cmd-qr-scan \
  bin/ryoku-cmd-google-lens
```

- [ ] **Step 3: Confirm staged diff excludes unrelated dirty files**

Run:

```bash
git diff --cached --name-only
```

Expected: output contains only the files listed in Step 2.

- [ ] **Step 4: Commit**

Run:

```bash
git commit -m "feat: add center pill toolbox"
```

Expected: commit succeeds.

---

## Self-Review Notes

Spec coverage:

- Toolbox menu set is covered by `ToolboxPopup.qml`: Screenshot, Open Screenshots, Screen Recorder, Open Recordings, Color Picker, OCR, QR Code, Google Lens, Mirror, and Caffeine.
- Center pill behavior is covered by `Popups.toolboxOpen`, `Popups.toolboxVisible`, `TopBar.qml`, and `ToolboxPopup.qml`.
- `SUPER+S` is covered by `default/hypr/bindings/utilities.conf` and `default/hypr/plain-bindings.conf`.
- IPC is covered by `shell.qml`, `bin/ryoku-ipc`, and the static test.
- Caffeine common-state gap is covered by `CaffeineService.qml` and the Quick Settings migration.
- Existing Ryoku screen recording common-sense gap is covered by `ScreenRecService` reuse and legacy `ryoku-cmd-screenrecord --stop-recording` fallback.
- Google Lens upload disclosure is covered by the helper notification before calling `https://uguu.se/upload`.
- Live system rollout is covered by refresh, restart, Hypr reload, package install, and manual verification steps.

Red-flag scan: each task names concrete files, commands, expected outcomes, and code snippets.

Type and name consistency:

- IPC target is `toggleToolbox` in `shell.qml` and `bin/ryoku-ipc`.
- Popup state names are `toolboxOpen`, `toolboxVisible`, and `mirrorOpen`.
- Shared service name is `CaffeineService` in `qmldir`, `QuickSettings.qml`, and `ToolboxPopup.qml`.
- Helper command names match Ryoku command naming and the toolbox action wiring.
