# Ryoku Live Recovery And Niri Transition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the live machine to Ryoku under Hyprland first, then install and verify Niri/iNiR before any Ryoku source changes for the compositor transition.

**Architecture:** Treat `/home/carlos/prowl/ryoku-arch` as the read-only source checkout during live recovery. Bootstrap a clean live Ryoku checkout under `~/.local/share/ryoku`, copy Ryoku defaults into live config paths, let `ryoku-migrate` bridge already-applied Omarchy migration markers, then remove Omarchy paths after Ryoku commands verify. Install iNiR as a separate live-system reference shell after Hyprland-based Ryoku recovery is working.

**Tech Stack:** Bash 5, Ryoku shell commands, pacman/AUR helpers, systemd user services, SDDM, Hyprland/UWSM temporary session, Niri, iNiR, Quickshell.

---

## Design Spec

- `docs/superpowers/specs/2026-05-02-ryoku-live-recovery-niri-transition-design.md`

## Global Rules

- Do not edit `/home/carlos/prowl/ryoku-arch` during live recovery or iNiR setup.
- Do not delete Omarchy live paths until Ryoku paths and commands verify.
- Do not remove Hyprland or its SDDM sessions until Niri/iNiR is confirmed working.
- Do not start Ryoku source changes for Niri/iNiR integration until Phase 2 is complete.
- Commands that use `sudo`, `rm -rf`, package installs, or service changes are live-system actions and must be run deliberately from an interactive terminal.

## File And Path Responsibilities

- `/home/carlos/prowl/ryoku-arch` - development repo, source only during Phase 1 and Phase 2.
- `$HOME/.local/share/ryoku` - live Ryoku repo checkout and command source.
- `$HOME/.local/share/ryoku/bin` - canonical live `ryoku-*` command directory.
- `$HOME/.config/ryoku` - canonical live Ryoku config namespace.
- `$HOME/.local/state/ryoku` - canonical live Ryoku state namespace and migration markers.
- `$HOME/.local/share/omarchy` - disposable legacy live repo path, removed after Ryoku verifies.
- `$HOME/.config/omarchy` - disposable legacy config path, removed after Ryoku verifies.
- `$HOME/.local/state/omarchy` - legacy migration marker source, removed only after `ryoku-migrate`.
- `$HOME/.config/hypr` - temporary Hyprland session config copied from Ryoku defaults.
- `$HOME/.config/quickshell/ryoku` - Ryoku shell config copied by `ryoku-refresh-quickshell`.
- `$HOME/prowl/inir` - recommended temporary iNiR source checkout for live setup.

---

### Task 1: Confirm Live Baseline

**Files:**
- Read: `/home/carlos/prowl/ryoku-arch`
- Read: `$HOME/.local/share/omarchy`
- Read: `$HOME/.config/omarchy`
- Read: `$HOME/.config/hypr`

- [ ] **Step 1: Verify the dev repo is clean before live work**

Run:

```bash
cd /home/carlos/prowl/ryoku-arch
git status --short --branch
```

Expected output starts with:

```text
## main...origin/main
```

Expected output has no modified, deleted, or untracked file lines below the
branch line.

- [ ] **Step 2: Confirm the live system is still Omarchy/Hyprland**

Run:

```bash
printf 'XDG_CURRENT_DESKTOP=%s\n' "${XDG_CURRENT_DESKTOP:-}"
printf 'DESKTOP_SESSION=%s\n' "${DESKTOP_SESSION:-}"
printf 'OMARCHY_PATH=%s\n' "${OMARCHY_PATH:-}"
printf 'RYOKU_PATH=%s\n' "${RYOKU_PATH:-}"
```

Expected output:

```text
XDG_CURRENT_DESKTOP=Hyprland
DESKTOP_SESSION=hyprland-uwsm
OMARCHY_PATH=/home/carlos/.local/share/omarchy
RYOKU_PATH=
```

- [ ] **Step 3: Confirm current command availability**

Run:

```bash
for cmd in omarchy-update ryoku-update niri inir qs quickshell hyprctl uwsm uwsm-app; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf 'present %s -> %s\n' "$cmd" "$(command -v "$cmd")"
  else
    printf 'missing %s\n' "$cmd"
  fi
done
```

Expected output includes:

```text
present omarchy-update -> /home/carlos/.local/share/omarchy/bin/omarchy-update
missing ryoku-update
missing niri
missing inir
present hyprctl -> /usr/bin/hyprctl
present uwsm -> /usr/bin/uwsm
present uwsm-app -> /usr/bin/uwsm-app
```

- [ ] **Step 4: Confirm session files**

Run:

```bash
ls -1 /usr/share/wayland-sessions
```

Expected output contains:

```text
hyprland-uwsm.desktop
hyprland.desktop
```

If `niri.desktop` is already present, keep it. Do not remove Hyprland.

---

### Task 2: Bootstrap Live Ryoku Checkout

**Files:**
- Create: `$HOME/.local/share/ryoku`
- Modify: `$HOME/.local/share/ryoku/.git/config`
- Modify: shell environment through Ryoku default config in later tasks

- [ ] **Step 1: Prepare live share directory**

Run:

```bash
mkdir -p "$HOME/.local/share"
```

Expected: exit 0.

- [ ] **Step 2: Remove any incomplete Ryoku live checkout**

Run only if `$HOME/.local/share/ryoku` exists and `command -v ryoku-update`
does not resolve to that path:

```bash
rm -rf "$HOME/.local/share/ryoku"
```

Expected: exit 0 and `$HOME/.local/share/ryoku` no longer exists.

- [ ] **Step 3: Clone the dev checkout into the live Ryoku path**

Run:

```bash
git clone --branch main /home/carlos/prowl/ryoku-arch "$HOME/.local/share/ryoku"
```

Expected output contains:

```text
Cloning into '/home/carlos/.local/share/ryoku'...
done.
```

- [ ] **Step 4: Point the live checkout at the GitHub remote**

Run:

```bash
git -C "$HOME/.local/share/ryoku" remote set-url origin https://github.com/neur0map/ryoku-arch.git
git -C "$HOME/.local/share/ryoku" remote -v
```

Expected output:

```text
origin	https://github.com/neur0map/ryoku-arch.git (fetch)
origin	https://github.com/neur0map/ryoku-arch.git (push)
```

- [ ] **Step 5: Export Ryoku for the current terminal**

Run:

```bash
export RYOKU_PATH="$HOME/.local/share/ryoku"
export PATH="$RYOKU_PATH/bin:$PATH"
source "$RYOKU_PATH/lib/runtime-env.sh"
command -v ryoku-update
command -v ryoku-migrate
```

Expected output:

```text
/home/carlos/.local/share/ryoku/bin/ryoku-update
/home/carlos/.local/share/ryoku/bin/ryoku-migrate
```

---

### Task 3: Install Ryoku Packages And Defaults Under Hyprland

**Files:**
- Read: `$HOME/.local/share/ryoku/install/ryoku-base.packages`
- Modify: `/etc/pacman.conf`
- Modify: `/etc/pacman.d/mirrorlist`
- Modify: `$HOME/.config`
- Modify: `$HOME/.bashrc`
- Modify: `$HOME/.bash_profile`
- Modify: `/boot/limine.conf`
- Modify: `/usr/share/plymouth/themes/ryoku`

- [ ] **Step 1: Refresh pacman to the Ryoku stable channel**

Run:

```bash
ryoku-refresh-pacman stable
```

Expected output contains:

```text
Setting channel to stable
```

Expected: pacman completes with exit 0.

- [ ] **Step 2: Install all Ryoku official-repo packages**

Run:

```bash
mapfile -t packages < <(
  grep -v '^#' "$RYOKU_PATH/install/ryoku-base.packages" |
    grep -v '^$' |
    grep -vx 'limine-mkinitcpio-hook' |
    grep -vx 'limine-snapper-sync'
)
sudo pacman -Syu --noconfirm --needed "${packages[@]}"
```

Expected: pacman exits 0. If a package no longer exists, capture the exact
package name and stop before deleting Omarchy paths.

- [ ] **Step 3: Install important AUR/default shell packages if available**

Run:

```bash
if ryoku-cmd-present yay && ryoku-pkg-aur-accessible; then
  ryoku-pkg-aur-add tofi bibata-cursor-theme-bin ttf-ia-writer ttf-phosphor-icons yaru-icon-theme limine-mkinitcpio-hook limine-snapper-sync
fi
```

Expected: exit 0. If AUR is unavailable, continue with Hyprland recovery and
record the missing AUR packages for a later `ryoku-update`.

- [ ] **Step 4: Overwrite live user config with Ryoku defaults**

Run:

```bash
ryoku-reinstall-configs
```

Expected output contains:

```text
Resetting all Ryoku configs
```

Expected: command exits 0. This command intentionally overwrites the disposable
fresh Omarchy user config.

- [ ] **Step 5: Refresh the Ryoku Quickshell tree**

Run:

```bash
ryoku-refresh-quickshell
```

Expected output contains:

```text
refreshed /home/carlos/.config/quickshell/ryoku from /home/carlos/.local/share/ryoku/config/quickshell/ryoku
```

- [ ] **Step 6: Refresh applications and SDDM**

Run:

```bash
ryoku-refresh-applications
ryoku-refresh-sddm
```

Expected: both commands exit 0.

---

### Task 4: Run Ryoku Migrations Before Removing Omarchy State

**Files:**
- Read: `$HOME/.local/state/omarchy/migrations`
- Modify: `$HOME/.local/state/ryoku/migrations`
- Modify: system/user state touched by pending Ryoku migrations

- [ ] **Step 1: Confirm legacy migration markers exist before bridge**

Run:

```bash
if [[ -d "$HOME/.local/state/omarchy/migrations" ]]; then
  find "$HOME/.local/state/omarchy/migrations" -maxdepth 1 -type f | wc -l
else
  echo 0
fi
```

Expected: a number prints. Any number is acceptable.

- [ ] **Step 2: Run Ryoku migrations**

Run:

```bash
ryoku-migrate
```

Expected: command exits 0. If a migration prompts to skip, do not skip by
default. Capture the failing migration filename and error output, then decide
whether it blocks desktop recovery.

- [ ] **Step 3: Verify Ryoku migration state exists**

Run:

```bash
test -d "$HOME/.local/state/ryoku/migrations"
find "$HOME/.local/state/ryoku/migrations" -maxdepth 1 -type f | wc -l
```

Expected: exit 0 and a number prints.

---

### Task 5: Validate Ryoku Under Hyprland

**Files:**
- Read: `$HOME/.local/share/ryoku`
- Read: `$HOME/.config/ryoku`
- Read: `$HOME/.local/state/ryoku`
- Read: `$HOME/.config/hypr`
- Read: `$HOME/.config/quickshell/ryoku`

- [ ] **Step 1: Verify canonical Ryoku paths**

Run:

```bash
test -d "$HOME/.local/share/ryoku"
test -d "$HOME/.config/ryoku"
test -d "$HOME/.local/state/ryoku"
test -d "$HOME/.config/hypr"
test -d "$HOME/.config/quickshell/ryoku"
```

Expected: exit 0.

- [ ] **Step 2: Verify Ryoku commands resolve**

Run:

```bash
command -v ryoku-update
command -v ryoku-refresh-hyprland
command -v ryoku-refresh-quickshell
command -v ryoku-restart-ui
```

Expected output:

```text
/home/carlos/.local/share/ryoku/bin/ryoku-update
/home/carlos/.local/share/ryoku/bin/ryoku-refresh-hyprland
/home/carlos/.local/share/ryoku/bin/ryoku-refresh-quickshell
/home/carlos/.local/share/ryoku/bin/ryoku-restart-ui
```

- [ ] **Step 3: Verify critical packages**

Run:

```bash
for pkg in hyprland quickshell xdg-desktop-portal-hyprland xdg-desktop-portal-gtk mako hypridle hyprlock; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    printf 'pkg present %s\n' "$pkg"
  else
    printf 'pkg missing %s\n' "$pkg"
  fi
done
```

Expected output contains:

```text
pkg present hyprland
pkg present quickshell
pkg present xdg-desktop-portal-hyprland
pkg present xdg-desktop-portal-gtk
pkg present mako
pkg present hypridle
pkg present hyprlock
```

- [ ] **Step 4: Restart Ryoku UI under the current Hyprland session**

Run:

```bash
ryoku-restart-ui --quiet
```

Expected: exit 0. The desktop may briefly restart UI components.

- [ ] **Step 5: If Quickshell does not appear, capture logs**

Run only if the Ryoku shell is not visible:

```bash
pgrep -af 'qs -c ryoku|quickshell' || true
journalctl --user -n 200 --no-pager | rg -n 'ryoku|quickshell|qs|qml' || true
```

Expected: output identifies either a running shell process or the next concrete
QML/package blocker.

---

### Task 6: Delete Omarchy Live Files After Ryoku Verifies

**Files:**
- Delete: `$HOME/.local/share/omarchy`
- Delete: `$HOME/.config/omarchy`
- Delete: `$HOME/.local/state/omarchy`
- Modify: shell profile files only if they still reference Omarchy

- [ ] **Step 1: Confirm Ryoku command surface still works**

Run:

```bash
command -v ryoku-update
ryoku-version || true
```

Expected: `command -v` prints `/home/carlos/.local/share/ryoku/bin/ryoku-update`.
`ryoku-version` may print version info or fail if package metadata is absent;
that failure does not block deleting Omarchy paths.

- [ ] **Step 2: Remove disposable Omarchy live paths**

Run:

```bash
rm -rf "$HOME/.local/share/omarchy" "$HOME/.config/omarchy" "$HOME/.local/state/omarchy"
```

Expected: exit 0.

- [ ] **Step 3: Remove remaining Omarchy PATH references from user shell files**

Run:

```bash
for file in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc"; do
  [[ -f $file ]] || continue
  if grep -q "$HOME/.local/share/omarchy/bin" "$file"; then
    sed -i "\|$HOME/.local/share/omarchy/bin|d" "$file"
  fi
done
```

Expected: exit 0.

- [ ] **Step 4: Verify Omarchy paths are gone**

Run:

```bash
for path in "$HOME/.local/share/omarchy" "$HOME/.config/omarchy" "$HOME/.local/state/omarchy"; do
  if [[ -e $path ]]; then
    printf 'still exists %s\n' "$path"
  else
    printf 'removed %s\n' "$path"
  fi
done
```

Expected output:

```text
removed /home/carlos/.local/share/omarchy
removed /home/carlos/.config/omarchy
removed /home/carlos/.local/state/omarchy
```

- [ ] **Step 5: Verify Omarchy commands no longer shadow Ryoku**

Run:

```bash
hash -r
for cmd in omarchy-update ryoku-update; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf 'present %s -> %s\n' "$cmd" "$(command -v "$cmd")"
  else
    printf 'missing %s\n' "$cmd"
  fi
done
```

Expected output includes:

```text
missing omarchy-update
present ryoku-update -> /home/carlos/.local/share/ryoku/bin/ryoku-update
```

---

### Task 7: Install Niri And iNiR As A Live Reference Shell

**Files:**
- Create: `$HOME/prowl/inir`
- Create or modify: `$HOME/.config/niri`
- Create or modify: `$HOME/.config/quickshell/inir`
- Modify: system packages and wayland session files

- [ ] **Step 1: Install Niri baseline packages**

Run:

```bash
sudo pacman -Syu --noconfirm --needed niri xwayland-satellite xdg-desktop-portal-gnome xdg-desktop-portal-gtk quickshell kirigami kdialog syntax-highlighting wl-clipboard cliphist grim slurp swayidle swaylock fuzzel foot kitty
```

Expected: pacman exits 0.

- [ ] **Step 2: Clone iNiR outside the Ryoku dev repo**

Run:

```bash
mkdir -p "$HOME/prowl"
if [[ -e "$HOME/prowl/inir" ]]; then
  echo "$HOME/prowl/inir already exists; move it aside manually before cloning iNiR" >&2
  exit 1
fi
git clone https://github.com/snowarch/inir.git "$HOME/prowl/inir"
```

Expected output contains:

```text
Cloning into '/home/carlos/prowl/inir'...
```

- [ ] **Step 3: Run the iNiR Arch installer**

Run:

```bash
cd "$HOME/prowl/inir"
./setup install
```

Expected: the setup script completes. Answer prompts conservatively; keep
Hyprland installed and do not remove Ryoku paths.

- [ ] **Step 4: Reload Niri config if already inside Niri**

Run:

```bash
if [[ ${XDG_CURRENT_DESKTOP:-} == "niri" ]] && command -v niri >/dev/null 2>&1; then
  niri msg action load-config-file
fi
```

Expected: exit 0. If not inside Niri, command does nothing.

- [ ] **Step 5: Verify Niri session file exists**

Run:

```bash
ls -1 /usr/share/wayland-sessions | sort
```

Expected output contains `niri.desktop` and still contains:

```text
hyprland-uwsm.desktop
hyprland.desktop
```

---

### Task 8: Confirm Niri/iNiR Works Before Any Ryoku Source Changes

**Files:**
- Read: `$HOME/.config/niri`
- Read: `$HOME/.config/quickshell/inir`
- Read: `$HOME/prowl/inir`

- [ ] **Step 1: Log out and choose the Niri session in SDDM**

Manual action: log out from Hyprland, select `Niri` in SDDM, and log in.

Expected: the desktop reaches a usable Niri session. If login fails, return to
Hyprland and inspect `journalctl --user -b --no-pager`.

- [ ] **Step 2: Verify session identity inside Niri**

Run inside the Niri session:

```bash
printf 'XDG_CURRENT_DESKTOP=%s\n' "${XDG_CURRENT_DESKTOP:-}"
printf 'DESKTOP_SESSION=%s\n' "${DESKTOP_SESSION:-}"
command -v niri
command -v inir
```

Expected output includes:

```text
XDG_CURRENT_DESKTOP=niri
/usr/bin/niri
```

The exact `inir` path may be under `/usr/bin`, `$HOME/.local/bin`, or another
path installed by iNiR setup.

- [ ] **Step 3: Run iNiR diagnostics**

Run:

```bash
inir doctor
inir logs
```

Expected: `inir doctor` exits 0 or reports only non-blocking optional feature
warnings. `inir logs` prints recent shell logs.

- [ ] **Step 4: Start or restart the iNiR shell**

Run:

```bash
inir run
```

Expected: iNiR shell surfaces appear. If another iNiR process is already
running, use `inir restart` if available or follow the diagnostic output from
`inir doctor`.

- [ ] **Step 5: Exercise iNiR IPC basics**

Run:

```bash
inir overview toggle
inir clipboard toggle
inir settings
```

Expected: overview, clipboard, and settings surfaces respond. If target names
have changed upstream, run `inir help` and record the current names before any
Ryoku integration work.

- [ ] **Step 6: Confirm Hyprland fallback still exists**

Run:

```bash
ls -1 /usr/share/wayland-sessions | rg 'hyprland'
```

Expected output:

```text
hyprland-uwsm.desktop
hyprland.desktop
```

---

### Task 9: Open The Future Ryoku Niri Integration Work

**Files:**
- Read: `/home/carlos/prowl/ryoku-arch/bin/ryoku-ipc`
- Read: `/home/carlos/prowl/ryoku-arch/bin/ryoku-restart-ui`
- Read: `/home/carlos/prowl/ryoku-arch/install/login/sddm.sh`
- Read: `/home/carlos/prowl/ryoku-arch/default/hypr`
- Read: `/home/carlos/prowl/ryoku-arch/default/themed`
- Read: `$HOME/prowl/inir/docs/IPC.md`
- Read: `$HOME/prowl/inir/ARCHITECTURE.md`

- [ ] **Step 1: Stop if Niri/iNiR is not confirmed working**

Run:

```bash
command -v niri
command -v inir
inir doctor
```

Expected: commands exit 0. If they do not, do not modify the Ryoku dev repo.

- [ ] **Step 2: Create a new branch for source changes**

Run only after Step 1 passes:

```bash
cd /home/carlos/prowl/ryoku-arch
git switch -c niri-inir-transition
```

Expected output:

```text
Switched to a new branch 'niri-inir-transition'
```

- [ ] **Step 3: Inventory Ryoku Hyprland assumptions**

Run:

```bash
cd /home/carlos/prowl/ryoku-arch
rg -n 'hypr|Hypr|hyprland|hyprctl|xdg-desktop-portal-hyprland|hypridle|hyprlock' bin install default config docs tests
```

Expected: output lists every Hyprland-specific surface that needs abstraction,
replacement, or temporary fallback.

- [ ] **Step 4: Inventory iNiR IPC targets**

Run:

```bash
cd "$HOME/prowl/inir"
inir help
sed -n '1,260p' docs/IPC.md
```

Expected: output shows the current iNiR CLI/IPC targets to map behind Ryoku
commands.

- [ ] **Step 5: Write the next implementation spec before code changes**

Create a new design spec under:

```text
/home/carlos/prowl/ryoku-arch/docs/superpowers/specs/YYYY-MM-DD-ryoku-niri-inir-integration-design.md
```

The spec must decide:

- whether Ryoku wraps `inir` or ports iNiR components;
- how `ryoku-ipc` maps to Niri/iNiR commands;
- which Hyprland helpers remain as compatibility commands;
- which package lists change;
- how SDDM chooses Niri by default without removing Hyprland fallback;
- how tests prove both the Niri path and temporary Hyprland fallback.

- [ ] **Step 6: Commit only the new integration spec**

Run:

```bash
cd /home/carlos/prowl/ryoku-arch
git status --short
git add docs/superpowers/specs/YYYY-MM-DD-ryoku-niri-inir-integration-design.md
git commit -m "docs: design ryoku niri inir integration"
```

Expected: commit exits 0 and contains only the new design spec.
