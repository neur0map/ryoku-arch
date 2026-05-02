# Ryoku Niri iNiR Merge Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `niri-inir-transition` branch clean and safe to merge to `main` by moving Ryoku's default desktop backend from Hyprland to the confirmed live Niri/iNiR baseline, without running an ISO build and without doing the full visual rebrand in this session.

**Architecture:** Keep Ryoku as the owner of install flow, `ryoku-*` command names, package manifests, boot branding, and screensaver assets. Use upstream iNiR as the Niri shell backend under `~/.local/share/inir` for this merge, with Ryoku wrappers and tests proving the source tree no longer defaults to Hyprland, Waybar, Mako, SwayOSD, Elephant, Walker, or the old Ryoku Quickshell shell. Treat ISO build proof and iNiR visual rebranding as explicit follow-up sessions.

**Tech Stack:** Bash 5, Arch package manifests, Ryoku installer scripts, systemd user services, SDDM, Niri, iNiR, Quickshell, shell-based static tests.

**Post-review correction:** The final implementation removes `xdg-desktop-portal-hyprland` from the default stack, validates iNiR's `ii-pixel` SDDM theme, reconciles default package manifests during `ryoku-update`, bundles iNiR into production ISO builds before install time, and guards the screensaver migration against self-copies.

---

## Source Spec

- `docs/superpowers/specs/2026-05-02-ryoku-niri-inir-integration-design.md`

## Scope For This Merge

In scope:

- Update Ryoku source defaults so a fresh install targets Niri/iNiR.
- Update package manifests so the source-of-truth package lists include the live Niri/iNiR package set and remove old default Hyprland shell packages.
- Add a Ryoku installer bridge that installs or updates upstream iNiR as the shell backend.
- Replace Ryoku command wrappers that currently call Hyprland, Hyprlock, Waybar, Mako, SwayOSD, Elephant, Walker, or Ryoku Brain Shell IPC.
- Remove old default source configs that would be copied into a fresh install.
- Preserve Ryoku screensaver assets and boot branding assets.
- Update shell tests so merge readiness is proven by static repo checks and command contract tests.

Out of scope:

- Running `ryoku-iso-make`, `mkarchiso`, or a VM install.
- Proving a fully offline ISO install.
- Rebranding iNiR QML, images, icon names, settings labels, or upstream docs.
- Rebuilding Ryoku Brain Shell features inside iNiR.
- Removing commit history or squashing the branch.

## Merge Gates

This branch is safe to merge to `main` only when all of these are true:

- `git diff --name-status main..HEAD` shows source changes, tests, and docs only.
- No default install path copies `config/hypr`, `config/waybar`, `config/mako`, `config/swayosd`, `config/quickshell/ryoku`, `config/elephant`, or `config/uwsm`.
- `install/ryoku-base.packages` excludes old default Hyprland shell packages and includes Niri/iNiR runtime packages.
- `install/ryoku-aur.packages` includes `darkly-bin`.
- `bin/ryoku-restart-ui`, `bin/ryoku-restart-shell`, `bin/ryoku-lock-screen`, `bin/ryoku-system-logout`, and `bin/ryoku-ipc` route to iNiR/Niri.
- Ryoku screensaver files remain present:
  - `default/alacritty/screensaver.toml`
  - `default/ghostty/screensaver`
  - `bin/ryoku-cmd-screensaver`
  - `bin/ryoku-launch-screensaver`
- Repo shell tests pass with `for test in tests/*.sh; do bash "$test"; done`.
- Live smoke still passes with `inir status`.

---

## File And Path Responsibilities

- `install/ryoku-base.packages` - official Arch default package source for fresh installs and future offline mirror input.
- `install/ryoku-aur.packages` - AUR default package source for fresh installs and future offline mirror input.
- `install/config/inir.sh` - Ryoku-owned bridge that installs or updates upstream iNiR after package installation.
- `install/config/all.sh` - installer phase ordering; calls `install/config/inir.sh`.
- `install/config/config.sh` - copies only remaining Ryoku configs to `~/.config`.
- `bin/ryoku-restart-ui` - restarts iNiR and session UI helpers without touching user applications.
- `bin/ryoku-restart-shell` - restarts `inir.service` or falls back to `inir restart`.
- `bin/ryoku-ipc` - keeps Ryoku CLI routes and delegates shell actions to `inir`.
- `bin/ryoku-lock-screen` - locks through `inir lock activate`.
- `bin/ryoku-system-logout` - opens the iNiR session menu.
- `bin/ryoku-sddm-autologin` - writes `Session=niri.desktop`.
- `bin/ryoku-refresh-sddm` - applies the iNiR `ii-pixel` SDDM theme through the iNiR installer.
- `config/alacritty/alacritty.toml` - imports iNiR-generated terminal colors.
- `config/hypr`, `default/hypr`, `config/quickshell/ryoku`, `config/waybar`, `default/waybar`, `config/swayosd`, `default/mako`, `config/elephant` - removed from default source because they are old backend defaults.
- `tests/niri-inir-merge-readiness.sh` - static merge gate for packages, defaults, commands, and preserved screensavers.
- `tests/ryoku-ipc.sh` - Ryoku IPC command contract.
- `tests/ryoku-restart-ui.sh` - iNiR restart contract.
- Hyprland and Brain Shell tests - removed or rewritten when their source paths are removed.

---

### Task 1: Add The Merge Readiness Gate Test

**Files:**
- Create: `tests/niri-inir-merge-readiness.sh`
- Test: `tests/niri-inir-merge-readiness.sh`

- [ ] **Step 1: Create the static merge readiness test**

Create `tests/niri-inir-merge-readiness.sh` with:

```bash
#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  assert_file "$path"
  [[ -x $path ]] || fail "$path should be executable"
}

assert_package_present() {
  local file="$1"
  local package="$2"

  grep -qxF "$package" "$file" || fail "$file should include package: $package"
}

assert_package_absent() {
  local file="$1"
  local package="$2"

  if grep -qxF "$package" "$file"; then
    fail "$file should not include old default package: $package"
  fi
}

assert_path_absent() {
  local path="$1"

  [[ ! -e $path ]] || fail "$path should not be a default source path after Niri/iNiR migration"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$file"; then
    fail "$message"
  fi
}

base_packages="install/ryoku-base.packages"
aur_packages="install/ryoku-aur.packages"

assert_file "$base_packages"
assert_file "$aur_packages"

removed_packages=(
  elephant
  hypridle
  hyprland
  hyprland-guiutils
  hyprlock
  hyprsunset
  mako
  swayosd
  walker
  waybar
)

required_base_packages=(
  awww
  cliphist
  fuzzel
  grim
  hyprpicker
  kdialog
  kdecoration
  kirigami
  mission-center
  niri
  plasma-integration
  qt5-graphicaleffects
  qt6ct
  quickshell
  slurp
  swayidle
  swaylock
  swappy
  syntax-highlighting
  ttf-material-symbols-variable
  uv
  wf-recorder
  wl-clipboard
  wlsunset
  wtype
  xdg-desktop-portal
  xdg-desktop-portal-gnome
  xdg-desktop-portal-gtk
  xdg-desktop-portal-hyprland
  xwayland-satellite
  ydotool
)

required_aur_packages=(
  darkly-bin
)

for package in "${removed_packages[@]}"; do
  assert_package_absent "$base_packages" "$package"
done

for package in "${required_base_packages[@]}"; do
  assert_package_present "$base_packages" "$package"
done

for package in "${required_aur_packages[@]}"; do
  assert_package_present "$aur_packages" "$package"
done

old_default_paths=(
  config/elephant
  config/hypr
  config/hyprland-preview-share-picker
  config/quickshell/ryoku
  config/swayosd
  config/uwsm
  config/waybar
  default/hypr
  default/mako
  default/themed/hyprland-preview-share-picker.css.tpl
  default/themed/hyprland.conf.tpl
  default/themed/hyprlock.conf.tpl
  default/themed/mako.ini.tpl
  default/themed/swayosd.css.tpl
  default/themed/walker.css.tpl
  default/themed/waybar.css.tpl
  default/waybar
)

for path in "${old_default_paths[@]}"; do
  assert_path_absent "$path"
done

preserved_screensaver_paths=(
  bin/ryoku-cmd-screensaver
  bin/ryoku-launch-screensaver
  default/alacritty/screensaver.toml
  default/ghostty/screensaver
)

for path in "${preserved_screensaver_paths[@]}"; do
  assert_file "$path"
done

assert_executable bin/ryoku-restart-ui
assert_executable bin/ryoku-restart-shell
assert_executable bin/ryoku-ipc
assert_executable bin/ryoku-lock-screen
assert_executable bin/ryoku-system-logout
assert_executable bin/ryoku-sddm-autologin
assert_executable bin/ryoku-refresh-sddm
assert_executable install/config/inir.sh

bash -n bin/ryoku-restart-ui
bash -n bin/ryoku-restart-shell
bash -n bin/ryoku-ipc
bash -n bin/ryoku-lock-screen
bash -n bin/ryoku-system-logout
bash -n bin/ryoku-sddm-autologin
bash -n bin/ryoku-refresh-sddm
bash -n install/config/inir.sh

assert_contains install/config/all.sh 'config/inir\.sh' "installer should run the iNiR bridge"
assert_contains bin/ryoku-restart-ui 'inir\.service|inir restart' "ryoku-restart-ui should restart iNiR"
assert_not_contains bin/ryoku-restart-ui 'hyprctl reload|restart_always "mako"|swayosd-server|restart_if_running "waybar"|restart_if_running "hypridle"' "ryoku-restart-ui should not restart old Hyprland-era UI services"
assert_contains bin/ryoku-restart-shell 'inir\.service|inir restart' "ryoku-restart-shell should target iNiR"
assert_not_contains bin/ryoku-restart-shell 'qs -c ryoku|ryoku-launch-shell|pkill -x quickshell' "ryoku-restart-shell should not target the old Ryoku Quickshell shell"
assert_contains bin/ryoku-lock-screen 'inir lock activate' "lock screen should use iNiR lock"
assert_not_contains bin/ryoku-lock-screen 'hyprlock|hyprctl' "lock screen should not use Hyprland lock helpers"
assert_contains bin/ryoku-system-logout 'inir session (toggle|open)' "logout command should open the iNiR session UI"
assert_contains bin/ryoku-sddm-autologin 'Session=niri\.desktop' "SDDM autologin should target niri.desktop"
assert_contains bin/ryoku-refresh-sddm 'ii-pixel|install-pixel-sddm|inir' "SDDM refresh should apply the iNiR ii-pixel theme"
assert_contains config/alacritty/alacritty.toml '~/.config/alacritty/colors\.toml' "Alacritty should import iNiR generated colors"
assert_not_contains config/alacritty/alacritty.toml '~/.config/ryoku/current/theme/alacritty\.toml' "Alacritty should not import the old Ryoku theme symlink"

"$PWD/bin/ryoku-ipc" --help | grep -Fq 'ryoku-ipc overview toggle' || fail "ryoku-ipc help should document overview toggle"
"$PWD/bin/ryoku-ipc" --help | grep -Fq 'ryoku-ipc clipboard toggle' || fail "ryoku-ipc help should document clipboard toggle"
"$PWD/bin/ryoku-ipc" --help | grep -Fq 'ryoku-ipc settings open' || fail "ryoku-ipc help should document settings open"
"$PWD/bin/ryoku-ipc" --help | grep -Fq 'ryoku-ipc settings toggle' || fail "ryoku-ipc help should document settings toggle"

pass "Niri/iNiR merge readiness contract"
```

- [ ] **Step 2: Make the test executable**

Run:

```bash
chmod +x tests/niri-inir-merge-readiness.sh
```

Expected: exit 0.

- [ ] **Step 3: Run the test to confirm it fails against current source**

Run:

```bash
bash tests/niri-inir-merge-readiness.sh
```

Expected: FAIL. The first failure should identify an old Hyprland-era package or source path still present.

- [ ] **Step 4: Commit the failing merge gate**

Run:

```bash
git add tests/niri-inir-merge-readiness.sh
git commit -m "test: add niri inir merge readiness gate"
```

Expected: commit succeeds and only `tests/niri-inir-merge-readiness.sh` is committed.

---

### Task 2: Update Default Package Manifests

**Files:**
- Modify: `install/ryoku-base.packages`
- Modify: `install/ryoku-aur.packages`
- Test: `tests/niri-inir-merge-readiness.sh`

- [ ] **Step 1: Replace the Hyprland package section**

In `install/ryoku-base.packages`, replace the section headed:

```text
# -- Hyprland window manager + Wayland desktop stack
```

with this section, keeping one package per line:

```text
# -- Niri compositor + iNiR desktop stack
awww
bc
breeze-icons
ddcutil
fprintd
frameworkintegration
geoclue
hicolor-icon-theme
hyprpicker
kdialog
kdecoration
kirigami
kvantum
libdbusmenu-gtk3
mission-center
mpv-mpris
niri
pacman-contrib
papirus-icon-theme
pavucontrol
plasma-integration
python-evdev
python-pillow
qt5-graphicaleffects
qt6ct
quickshell
swayidle
swaylock
swappy
syntax-highlighting
ttf-dejavu
ttf-liberation
ttf-material-symbols-variable
ttf-roboto
ttf-roboto-mono
upower
uv
wf-recorder
wlsunset
wtype
xdg-desktop-portal
xdg-desktop-portal-gnome
xdg-desktop-portal-gtk
xwayland-satellite
ydotool
yt-dlp
```

Keep `hyprpicker` for iNiR color picking. Do not keep `xdg-desktop-portal-hyprland`; Niri uses the GNOME and GTK portal stack here.

- [ ] **Step 2: Remove old package entries from the full base manifest**

Remove these exact entries from `install/ryoku-base.packages` if they appear anywhere:

```text
elephant
hypridle
hyprland
hyprland-guiutils
hyprlock
hyprsunset
mako
swayosd
walker
waybar
```

- [ ] **Step 3: Add the AUR package needed by live iNiR theming**

In `install/ryoku-aur.packages`, add `darkly-bin` under the eye-candy, utilities, or theming section:

```text
darkly-bin
```

Do not add `ttf-material-symbols-variable-git`; the confirmed live package is the official repo package `ttf-material-symbols-variable`.

- [ ] **Step 4: Remove duplicate package lines**

Run:

```bash
awk 'NF && $1 !~ /^#/ { count[$1]++ } END { for (pkg in count) if (count[pkg] > 1) print pkg }' install/ryoku-base.packages install/ryoku-aur.packages
```

Expected: no output.

- [ ] **Step 5: Run package gate**

Run:

```bash
bash tests/niri-inir-merge-readiness.sh
```

Expected: the package assertions pass. The test may still fail on old config paths or command wrappers.

- [ ] **Step 6: Commit package manifest changes**

Run:

```bash
git add install/ryoku-base.packages install/ryoku-aur.packages
git commit -m "feat: switch default packages to niri inir"
```

Expected: commit succeeds with only the two package manifests.

---

### Task 3: Add The Ryoku iNiR Installer Bridge

**Files:**
- Create: `install/config/inir.sh`
- Modify: `install/config/all.sh`
- Test: `tests/niri-inir-merge-readiness.sh`

- [ ] **Step 1: Create the installer bridge**

Create `install/config/inir.sh`:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

INIR_REPO="${RYOKU_INIR_REPO:-https://github.com/snowarch/iNiR.git}"
INIR_PATH="${RYOKU_INIR_PATH:-$HOME/.local/share/inir}"
INIR_SOURCE="${RYOKU_INIR_SOURCE:-$INIR_REPO}"

if [[ -d $INIR_PATH/.git ]]; then
  git -C "$INIR_PATH" pull --ff-only
elif [[ -e $INIR_PATH ]]; then
  echo "install/config/inir.sh: $INIR_PATH exists but is not a git checkout" >&2
  exit 1
else
  mkdir -p "$(dirname "$INIR_PATH")"
  git clone "$INIR_SOURCE" "$INIR_PATH"
fi

(
  cd "$INIR_PATH"
  ./setup install -y --skip-deps --skip-sysupdate
)

if ryoku-cmd-present inir; then
  inir service enable niri >/dev/null 2>&1 || true
fi
```

This gives the future ISO session a clean hook: set `RYOKU_INIR_SOURCE` to a local source path before running the installer. This plan does not build or verify that ISO source path.

- [ ] **Step 2: Make the bridge executable**

Run:

```bash
chmod +x install/config/inir.sh
```

Expected: exit 0.

- [ ] **Step 3: Wire the bridge into the installer**

In `install/config/all.sh`, add the bridge directly after `config/config.sh`:

```bash
run_logged $RYOKU_INSTALL/config/config.sh
run_logged $RYOKU_INSTALL/config/inir.sh
```

Expected: `install/config/inir.sh` runs before theme, branding, Git, GPG, and hardware config steps.

- [ ] **Step 4: Verify syntax and gate**

Run:

```bash
bash -n install/config/inir.sh
bash tests/niri-inir-merge-readiness.sh
```

Expected: syntax passes. The merge gate may still fail on old config paths or command wrappers.

- [ ] **Step 5: Commit installer bridge**

Run:

```bash
git add install/config/inir.sh install/config/all.sh
git commit -m "feat: install inir as ryoku shell backend"
```

Expected: commit succeeds with the installer bridge and installer ordering change.

---

### Task 4: Remove Old Default Backend Source Paths

**Files:**
- Delete: `config/elephant`
- Delete: `config/hypr`
- Delete: `config/hyprland-preview-share-picker`
- Delete: `config/quickshell/ryoku`
- Delete: `config/swayosd`
- Delete: `config/uwsm`
- Delete: `config/waybar`
- Delete: `default/hypr`
- Delete: `default/mako`
- Delete: `default/waybar`
- Delete: `default/themed/hyprland-preview-share-picker.css.tpl`
- Delete: `default/themed/hyprland.conf.tpl`
- Delete: `default/themed/hyprlock.conf.tpl`
- Delete: `default/themed/mako.ini.tpl`
- Delete: `default/themed/swayosd.css.tpl`
- Delete: `default/themed/walker.css.tpl`
- Delete: `default/themed/waybar.css.tpl`
- Modify: `config/alacritty/alacritty.toml`
- Test: `tests/niri-inir-merge-readiness.sh`

- [ ] **Step 1: Remove old default source paths**

Run:

```bash
git rm -r config/elephant config/hypr config/hyprland-preview-share-picker config/quickshell/ryoku config/swayosd config/uwsm config/waybar default/hypr default/mako default/waybar
git rm default/themed/hyprland-preview-share-picker.css.tpl default/themed/hyprland.conf.tpl default/themed/hyprlock.conf.tpl default/themed/mako.ini.tpl default/themed/swayosd.css.tpl default/themed/walker.css.tpl default/themed/waybar.css.tpl
```

Expected: each listed path is staged for deletion.

- [ ] **Step 2: Preserve Ryoku screensaver assets**

Run:

```bash
test -f default/alacritty/screensaver.toml
test -f default/ghostty/screensaver
test -x bin/ryoku-cmd-screensaver
test -x bin/ryoku-launch-screensaver
```

Expected: exit 0.

- [ ] **Step 3: Point Alacritty at iNiR colors**

Replace the first line of `config/alacritty/alacritty.toml`:

```toml
general.import = [ "~/.config/ryoku/current/theme/alacritty.toml" ]
```

with:

```toml
[general]
import = ["~/.config/alacritty/colors.toml"]
```

Keep the existing terminal, font, window, and keyboard settings below the import.

- [ ] **Step 4: Run the source cleanup gate**

Run:

```bash
bash tests/niri-inir-merge-readiness.sh
```

Expected: package and old-path assertions pass. The test may still fail on command wrappers.

- [ ] **Step 5: Commit source cleanup**

Run:

```bash
git add config default bin/ryoku-cmd-screensaver bin/ryoku-launch-screensaver tests/niri-inir-merge-readiness.sh
git commit -m "refactor: remove old hyprland shell defaults"
```

Expected: commit succeeds. Screensaver files are not deleted.

---

### Task 5: Convert Ryoku Session Commands To iNiR

**Files:**
- Modify: `bin/ryoku-restart-shell`
- Modify: `bin/ryoku-restart-ui`
- Modify: `bin/ryoku-lock-screen`
- Modify: `bin/ryoku-system-logout`
- Modify: `bin/ryoku-cmd-colorpicker`
- Modify: `bin/ryoku-cmd-ocr`
- Modify: `bin/ryoku-cmd-qr-scan`
- Modify: `bin/ryoku-cmd-screenrecord`
- Modify: `bin/ryoku-cmd-share`
- Test: `tests/ryoku-restart-ui.sh`
- Test: `tests/niri-inir-merge-readiness.sh`

- [ ] **Step 1: Replace `bin/ryoku-restart-shell`**

Use this command body:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

if ryoku-cmd-present systemctl && systemctl --user status inir.service >/dev/null 2>&1; then
  systemctl --user try-restart inir.service
elif ryoku-cmd-present inir; then
  inir restart
else
  echo "ryoku-restart-shell: inir is not installed or not on PATH" >&2
  exit 127
fi
```

- [ ] **Step 2: Replace `bin/ryoku-restart-ui`**

Keep the current option parsing, logging helpers, environment refresh, clipboard watcher restart, portal restart, and notification code. Remove `reset_hyprland`, `restart_always "mako"`, `restart_always "swayosd-server"`, `restart_if_running "waybar"`, and `restart_if_running "hypridle"`.

The end of the script must become:

```bash
log "Ryoku hard refresh"
refresh_activation_environment
ryoku-restart-shell >/dev/null 2>&1 || true
restart_clipboard_watchers
restart_portals
notify_finished
```

The `restart_portals` function must restart these services:

```bash
try_restart_user_service xdg-desktop-portal.service
try_restart_user_service xdg-desktop-portal-gnome.service
try_restart_user_service xdg-desktop-portal-gtk.service
```

- [ ] **Step 3: Replace `bin/ryoku-lock-screen`**

Use this command body:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

if pgrep -x "1password" >/dev/null; then
  1password --lock >/dev/null 2>&1 &
fi

pkill -f org.ryoku.screensaver >/dev/null 2>&1 || true

exec inir lock activate
```

- [ ] **Step 4: Replace `bin/ryoku-system-logout`**

Use this command body:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

exec inir session toggle
```

- [ ] **Step 5: Route region tools through iNiR**

Update the command scripts with these mappings:

```text
bin/ryoku-cmd-colorpicker    -> exec inir colorpicker
bin/ryoku-cmd-ocr            -> exec inir region ocr
bin/ryoku-cmd-qr-scan        -> exec inir region screenshot
bin/ryoku-cmd-screenrecord   -> exec inir region record
bin/ryoku-cmd-share          -> exec inir region screenshot
```

Keep any Ryoku-specific post-processing only when it still has a valid Niri/iNiR input. Remove direct `hyprctl` calls from these command paths.

- [ ] **Step 6: Rewrite the restart UI test for iNiR**

Replace `tests/ryoku-restart-ui.sh` assertions so it checks:

```bash
grep -q 'ryoku-restart-shell' "$script" \
  || fail "hard refresh should restart the iNiR shell through ryoku-restart-shell"
grep -q 'restart_clipboard_watchers' "$script" \
  || fail "hard refresh should repair duplicate clipboard watchers"
grep -q 'xdg-desktop-portal-gnome.service' "$script" \
  || fail "hard refresh should try-restart the GNOME portal used by Niri"
grep -q 'xdg-desktop-portal-gtk.service' "$script" \
  || fail "hard refresh should try-restart the GTK portal"
if grep -Eq 'hyprctl reload|xdg-desktop-portal-hyprland|restart_always "mako"|swayosd-server|restart_if_running "waybar"|restart_if_running "hypridle"' "$script"; then
  fail "hard refresh should not manage old Hyprland-era UI daemons"
fi
```

- [ ] **Step 7: Run command tests**

Run:

```bash
bash tests/ryoku-restart-ui.sh
bash tests/niri-inir-merge-readiness.sh
```

Expected: both tests pass except for any IPC assertions that Task 6 has not implemented yet.

- [ ] **Step 8: Commit command conversion**

Run:

```bash
git add bin tests/ryoku-restart-ui.sh
git commit -m "feat: route ryoku session commands to inir"
```

Expected: commit succeeds with command wrapper and restart test changes.

---

### Task 6: Convert Ryoku IPC To iNiR Routes

**Files:**
- Modify: `bin/ryoku-ipc`
- Modify: `tests/ryoku-ipc.sh`
- Test: `tests/ryoku-ipc.sh`
- Test: `tests/niri-inir-merge-readiness.sh`

- [ ] **Step 1: Add top-level iNiR routes to help**

Add these lines to `usage()` in `bin/ryoku-ipc`:

```text
  ryoku-ipc overview toggle
  ryoku-ipc clipboard toggle
  ryoku-ipc settings open
  ryoku-ipc settings toggle
  ryoku-ipc lock activate
  ryoku-ipc session toggle
```

- [ ] **Step 2: Add an iNiR execution helper**

Add this function near the existing IPC helpers:

```bash
exec_inir() {
  if ! ryoku-cmd-present inir; then
    echo "ryoku-ipc: inir is not installed or not on PATH" >&2
    return 127
  fi

  exec inir "$@"
}
```

- [ ] **Step 3: Add route dispatchers**

Add these functions:

```bash
overview_dispatch() {
  local action="${1:-}"

  if (( $# != 1 )) || [[ $action != "toggle" ]]; then
    echo "ryoku-ipc: expected overview toggle" >&2
    return 2
  fi

  exec_inir overview toggle
}

clipboard_dispatch() {
  local action="${1:-}"

  if (( $# != 1 )) || [[ $action != "toggle" ]]; then
    echo "ryoku-ipc: expected clipboard toggle" >&2
    return 2
  fi

  exec_inir clipboard toggle
}

settings_dispatch() {
  local action="${1:-}"

  if (( $# != 1 )); then
    echo "ryoku-ipc: expected settings open|toggle" >&2
    return 2
  fi

  case "$action" in
    open)
      exec_inir settings
      ;;
    toggle)
      exec_inir settings toggle
      ;;
    *)
      echo "ryoku-ipc: unknown settings action: $action" >&2
      return 2
      ;;
  esac
}

lock_dispatch() {
  local action="${1:-}"

  if (( $# != 1 )) || [[ $action != "activate" ]]; then
    echo "ryoku-ipc: expected lock activate" >&2
    return 2
  fi

  exec_inir lock activate
}

session_dispatch() {
  local action="${1:-}"

  if (( $# != 1 )) || [[ $action != "toggle" ]]; then
    echo "ryoku-ipc: expected session toggle" >&2
    return 2
  fi

  exec_inir session toggle
}
```

- [ ] **Step 4: Wire the new namespaces into `main()`**

Add these cases before the old `shell)` namespace:

```bash
overview)
  shift
  overview_dispatch "$@"
  ;;
clipboard)
  shift
  clipboard_dispatch "$@"
  ;;
settings)
  shift
  settings_dispatch "$@"
  ;;
lock)
  shift
  lock_dispatch "$@"
  ;;
session)
  shift
  session_dispatch "$@"
  ;;
```

Keep the old `theme`, `font`, `cursor`, and `wallpaper` namespaces if they still power Ryoku user data.

- [ ] **Step 5: Update IPC tests with a fake `inir` binary**

In `tests/ryoku-ipc.sh`, add a fake `inir` next to the existing fake `qs`:

```bash
cat >"$tmpdir/path/inir" <<'EOF'
#!/bin/bash
mkdir -p "$RYOKU_STATE_PATH"
printf '%s\n' "$@" >"$RYOKU_STATE_PATH/inir.args"
exit 0
EOF
chmod +x "$tmpdir/path/inir"
```

Add an assertion helper:

```bash
assert_inir_call() {
  local description="$1"
  local expected="$2"
  shift 2
  local actual

  rm -f "$tmpdir/state/inir.args"
  RYOKU_PATH="$PWD" \
  RYOKU_CONFIG_PATH="$tmpdir/config" \
  RYOKU_STATE_PATH="$tmpdir/state" \
  PATH="$tmpdir/path:$PATH" \
    "$ipc" "$@" >/dev/null \
    || fail "$description should be accepted by the parser"

  [[ -f $tmpdir/state/inir.args ]] \
    || fail "$description should invoke inir"
  mapfile -t inir_args < "$tmpdir/state/inir.args"
  actual="${inir_args[*]}"
  [[ $actual == $expected ]] \
    || fail "$description should call: $expected"
}
```

Add these assertions:

```bash
assert_has_route "overview toggle"
assert_has_route "clipboard toggle"
assert_has_route "settings open"
assert_has_route "settings toggle"
assert_has_route "lock activate"
assert_has_route "session toggle"

assert_inir_call "overview toggle" "overview toggle" overview toggle
assert_inir_call "clipboard toggle" "clipboard toggle" clipboard toggle
assert_inir_call "settings open" "settings" settings open
assert_inir_call "settings toggle" "settings toggle" settings toggle
assert_inir_call "lock activate" "lock activate" lock activate
assert_inir_call "session toggle" "session toggle" session toggle
```

- [ ] **Step 6: Run IPC tests**

Run:

```bash
bash tests/ryoku-ipc.sh
bash tests/niri-inir-merge-readiness.sh
```

Expected: both tests pass.

- [ ] **Step 7: Commit IPC conversion**

Run:

```bash
git add bin/ryoku-ipc tests/ryoku-ipc.sh
git commit -m "feat: delegate ryoku ipc shell routes to inir"
```

Expected: commit succeeds with IPC script and IPC tests.

---

### Task 7: Switch SDDM And Autologin Defaults To Niri

**Files:**
- Modify: `bin/ryoku-sddm-autologin`
- Modify: `bin/ryoku-refresh-sddm`
- Test: `tests/niri-inir-merge-readiness.sh`

- [ ] **Step 1: Update autologin session**

In `bin/ryoku-sddm-autologin`, change:

```bash
echo "Session=hyprland-uwsm"
```

to:

```bash
echo "Session=niri.desktop"
```

Update comments in the file so they say Niri instead of Hyprland.

- [ ] **Step 2: Replace SDDM refresh with iNiR theme application**

Replace `bin/ryoku-refresh-sddm` with:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

INIR_PATH="${RYOKU_INIR_PATH:-$HOME/.local/share/inir}"
SDDM_SCRIPT="$INIR_PATH/scripts/sddm/install-pixel-sddm.sh"

if [[ ! -x $SDDM_SCRIPT ]]; then
  echo "ryoku-refresh-sddm: missing iNiR SDDM installer at $SDDM_SCRIPT" >&2
  exit 1
fi

INIR_SDDM_AUTO_APPLY=yes REPO_ROOT="$INIR_PATH" exec "$SDDM_SCRIPT"
```

This keeps the Qt5 `qt5-graphicaleffects` requirement in the package manifest, but delegates theme files to iNiR. The full visual rebrand of `ii-pixel` is not part of this merge.

- [ ] **Step 3: Run SDDM static gate**

Run:

```bash
bash tests/niri-inir-merge-readiness.sh
```

Expected: SDDM assertions pass.

- [ ] **Step 4: Commit SDDM default changes**

Run:

```bash
git add bin/ryoku-sddm-autologin bin/ryoku-refresh-sddm
git commit -m "feat: default sddm to niri inir"
```

Expected: commit succeeds with only SDDM command changes.

---

### Task 8: Retire Obsolete Hyprland And Brain Shell Tests

**Files:**
- Delete or rewrite: `tests/brain-shell-spec1.sh`
- Delete or rewrite: `tests/dashboard-clock-card.sh`
- Delete or rewrite: `tests/dashboard-telemetry-layout.sh`
- Delete or rewrite: `tests/dashboard-top-controls.sh`
- Delete or rewrite: `tests/hypr-cursor-theme.sh`
- Delete or rewrite: `tests/hyprland-focused-app-scratchpad.sh`
- Delete or rewrite: `tests/quickshell-app-launcher.sh`
- Delete or rewrite: `tests/quickshell-battery-warning.sh`
- Delete or rewrite: `tests/quickshell-noctalia-network-providers.sh`
- Delete or rewrite: `tests/quickshell-noctalia-settings.sh`
- Delete or rewrite: `tests/quickshell-player-card.sh`
- Delete or rewrite: `tests/quickshell-right-pill-hover.sh`
- Delete or rewrite: `tests/quickshell-toolbox.sh`
- Delete or rewrite: `tests/quickshell-topbar-settings-menus.sh`
- Delete or rewrite: `tests/quickshell-volume-feedback.sh`
- Delete or rewrite: `tests/quickshell-wallpaper-skwd.sh`
- Delete or rewrite: `tests/quickshell-wallpaper-switcher.sh`
- Test: all remaining `tests/*.sh`

- [ ] **Step 1: Identify tests whose source paths were removed**

Run:

```bash
for test in tests/*.sh; do
  if rg -q 'config/quickshell/ryoku|default/hypr|config/hypr|hyprctl|hyprlock|waybar|mako|swayosd|elephant|walker' "$test"; then
    printf '%s\n' "$test"
  fi
done
```

Expected output includes the files listed in this task.

- [ ] **Step 2: Delete tests that only validate removed source**

Use `git rm` for tests whose entire purpose is the removed Hyprland or Brain Shell implementation:

```bash
git rm tests/brain-shell-spec1.sh tests/dashboard-clock-card.sh tests/dashboard-telemetry-layout.sh tests/dashboard-top-controls.sh tests/hypr-cursor-theme.sh tests/hyprland-focused-app-scratchpad.sh tests/quickshell-app-launcher.sh tests/quickshell-battery-warning.sh tests/quickshell-noctalia-network-providers.sh tests/quickshell-noctalia-settings.sh tests/quickshell-player-card.sh tests/quickshell-right-pill-hover.sh tests/quickshell-toolbox.sh tests/quickshell-topbar-settings-menus.sh tests/quickshell-volume-feedback.sh tests/quickshell-wallpaper-skwd.sh tests/quickshell-wallpaper-switcher.sh
```

Keep tests that validate Ryoku-owned data or commands that still exist, including wallpaper cache/search/apply tests, terminal launcher tests, theme template rendering, ISO source sync tests, AUR offline bootstrap static tests, and battery monitor tests.

- [ ] **Step 3: Run all remaining tests**

Run:

```bash
for test in tests/*.sh; do
  bash "$test"
done
```

Expected: every remaining test prints `OK:` or exits 0.

- [ ] **Step 4: Commit test retirement**

Run:

```bash
git add tests
git commit -m "test: retire old hyprland shell checks"
```

Expected: commit succeeds with only test changes.

---

### Task 9: Add A Guarded Migration For Existing Ryoku Users

**Files:**
- Create: one new file under `migrations/`
- Test: `bash -n migrations/<created-file>.sh`

- [ ] **Step 1: Generate a migration file using the repo helper**

Run:

```bash
ryoku-dev-add-migration --no-edit
git status --short migrations
```

Expected: one new migration file appears under `migrations/`.

- [ ] **Step 2: Replace the new migration content**

Replace the new migration file with:

```bash
echo "Clean old Hyprland shell config after Niri/iNiR migration"

if ! command -v inir >/dev/null 2>&1; then
  echo "iNiR is not installed; leaving old shell config in place"
  exit 0
fi

if ! command -v niri >/dev/null 2>&1; then
  echo "Niri is not installed; leaving old shell config in place"
  exit 0
fi

case "${XDG_CURRENT_DESKTOP:-}" in
  niri|Niri)
    ;;
  *)
    echo "Current desktop is not Niri; leaving old shell config in place"
    exit 0
    ;;
esac

for path in \
  "$HOME/.config/hypr" \
  "$HOME/.config/waybar" \
  "$HOME/.config/mako" \
  "$HOME/.config/swayosd" \
  "$HOME/.config/uwsm" \
  "$HOME/.config/elephant" \
  "$HOME/.config/quickshell/ryoku"
do
  if [[ -e $path ]]; then
    rm -rf "$path"
  fi
done

mkdir -p "$HOME/.config/ryoku/branding"

if [[ -f "$RYOKU_PATH/default/alacritty/screensaver.toml" ]]; then
  mkdir -p "$HOME/.local/share/ryoku/default/alacritty"
  cp -f "$RYOKU_PATH/default/alacritty/screensaver.toml" "$HOME/.local/share/ryoku/default/alacritty/screensaver.toml"
fi

if [[ -f "$RYOKU_PATH/default/ghostty/screensaver" ]]; then
  mkdir -p "$HOME/.local/share/ryoku/default/ghostty"
  cp -f "$RYOKU_PATH/default/ghostty/screensaver" "$HOME/.local/share/ryoku/default/ghostty/screensaver"
fi
```

This migration cleans user config only when the user is already in Niri and both `inir` and `niri` exist. It does not remove packages.

- [ ] **Step 3: Verify migration syntax**

Run:

```bash
bash -n migrations/*.sh
```

Expected: exit 0.

- [ ] **Step 4: Commit migration**

Run:

```bash
git add migrations
git commit -m "chore: migrate old shell configs after niri switch"
```

Expected: commit succeeds with one migration file.

---

### Task 10: Final Merge Verification

**Files:**
- Read: full repo
- Test: all remaining `tests/*.sh`

- [ ] **Step 1: Verify branch and worktree**

Run:

```bash
git status --short --branch
```

Expected output starts with:

```text
## niri-inir-transition...origin/niri-inir-transition
```

Expected output has no unstaged or staged changes.

- [ ] **Step 2: Verify source diff shape**

Run:

```bash
git diff --name-status main..HEAD
```

Expected: output contains package manifests, command wrappers, installer bridge, migrations, tests, and docs. Expected output does not contain generated live-system files, ISO build artifacts, or rebranded iNiR visual assets.

- [ ] **Step 3: Run shell syntax over changed Bash files**

Run:

```bash
git diff --name-only main..HEAD | while IFS= read -r path; do
  case "$path" in
    bin/*|install/*.sh|install/*/*.sh|migrations/*.sh|tests/*.sh)
      [[ -f $path ]] && bash -n "$path"
      ;;
  esac
done
```

Expected: exit 0.

- [ ] **Step 4: Run the full static test suite**

Run:

```bash
for test in tests/*.sh; do
  bash "$test"
done
```

Expected: every test exits 0.

- [ ] **Step 5: Run live iNiR smoke without changing source**

Run:

```bash
inir status
```

Expected output includes:

```text
Shell is running
Niri compositor detected
No pending migrations
Runtime payload state: clean
```

- [ ] **Step 6: Confirm ISO work is clearly deferred**

Run:

```bash
git diff --name-only main..HEAD | rg '^iso/' || true
```

Expected: no ISO builder implementation changes are required for this merge. If ISO package manifest references changed indirectly through `install/ryoku-base.packages` or `install/ryoku-aur.packages`, note that static source coverage is complete but ISO build verification is deferred.

- [ ] **Step 7: Push the branch**

Run:

```bash
git push origin niri-inir-transition
```

Expected: push succeeds without force.

- [ ] **Step 8: Merge cleanly to main**

Run only after the user approves the merge:

```bash
git checkout main
git pull --ff-only origin main
git merge --ff-only niri-inir-transition
git push origin main
```

Expected: fast-forward merge succeeds. If `git merge --ff-only` fails, stop and inspect the divergent commits before choosing a merge strategy.

---

## Self-Review Checklist

- The plan covers package manifests, installer wiring, default config cleanup, command routing, SDDM, migrations, tests, and merge verification.
- ISO build and offline install verification are explicitly deferred.
- Full iNiR visual rebranding is explicitly deferred.
- Ryoku screensaver assets are protected by a test and by the migration.
- The plan does not ask for history rewriting or destructive git operations.
- Every shell snippet uses `#!/bin/bash` where a shebang is present.
- The plan uses static tests first, then implementation, then verification.
