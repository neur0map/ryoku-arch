# Category 1 Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename Category 1 `omarchy` runtime surfaces to Ryoku in small verified chunks without breaking update flow, installed-system migration, or the graphical session.

**Architecture:** Use a dependency-first migration with temporary compatibility bridges. Establish one shared runtime contract first, migrate live repo, state, and config namespaces safely, then flip command families and finally move display-critical consumers after their Ryoku targets are already stable.

**Tech Stack:** Bash shell scripts, Arch Linux tooling, Hyprland, Waybar, UWSM, systemd, udev, sudoers, mkinitcpio, grep, git, `bash -n`, `systemd-analyze`, `visudo`

---

## Scope Check

This is still one plan, not multiple independent plans, because the rename surfaces are tightly coupled:

- command names depend on the runtime path and env contract
- Hyprland, Waybar, and UWSM depend on the command rename being stable first
- migrations and installer scripts must reflect the same namespace contract as live runtime code

## File Structure Map

### Shared runtime contract

- Create: `lib/runtime-env.sh`
- Modify: `install.sh`
- Modify: `default/bash/envs`
- Modify: `config/uwsm/env`
- Modify: `bin/ryoku-version`

Responsibility:

- `lib/runtime-env.sh` becomes the single source of truth for repo path, state path, config path, and temporary legacy bridges.
- `install.sh`, interactive shells, and UWSM all source the same contract instead of each inventing their own path logic.

### Core lifecycle commands

- Create: `bin/ryoku-update`
- Create: `bin/ryoku-update-confirm`
- Create: `bin/ryoku-update-git`
- Create: `bin/ryoku-update-perform`
- Create: `bin/ryoku-update-restart`
- Create: `bin/ryoku-update-available`
- Create: `bin/ryoku-update-available-reset`
- Create: `bin/ryoku-update-system-pkgs`
- Create: `bin/ryoku-update-keyring`
- Create: `bin/ryoku-update-aur-pkgs`
- Create: `bin/ryoku-update-orphan-pkgs`
- Create: `bin/ryoku-update-firmware`
- Create: `bin/ryoku-update-time`
- Create: `bin/ryoku-migrate`
- Create: `bin/ryoku-state`
- Create: `bin/ryoku-hook`
- Create: `bin/ryoku-snapshot`
- Create: `bin/ryoku-version-branch`
- Create: `bin/ryoku-version-channel`
- Create: `bin/ryoku-version-pkgs`
- Create: `bin/ryoku-branch-set`
- Create: `bin/ryoku-channel-set`
- Modify: matching `bin/omarchy-*` files above into thin wrappers

Responsibility:

- Ryoku becomes the canonical operational surface.
- Legacy `omarchy-*` commands remain as one-line compatibility wrappers until final bridge removal.

### Namespace and command consumers

- Modify: `bin/omarchy-refresh-config`
- Modify: all `bin/omarchy-refresh-*`
- Modify: all `bin/omarchy-restart-*`
- Modify: all `bin/omarchy-theme-*`
- Modify: all `bin/omarchy-font-*`
- Modify: `bin/omarchy-menu`
- Modify: `bin/omarchy-launch-*`
- Modify: `bin/omarchy-cmd-*`
- Modify: all `bin/omarchy-hw-*`
- Modify: `bin/omarchy-hyprland-*`
- Modify: `bin/omarchy-toggle*`
- Modify: `bin/omarchy-battery-*`
- Modify: `bin/omarchy-powerprofiles-*`
- Modify: `bin/omarchy-brightness-*`
- Modify: `bin/omarchy-hibernation-*`
- Modify: `bin/omarchy-pkg-*`
- Modify: `bin/omarchy-install-*`
- Modify: `bin/omarchy-webapp-*`
- Modify: `bin/omarchy-tui-*`
- Modify: `bin/omarchy-voxtype-*`
- Modify: `bin/omarchy-dev-*`

Responsibility:

- Each command family flips to Ryoku names and Ryoku namespaces only after the shared contract exists.
- Legacy names remain wrappers until Task 11.

### Display and dotfile consumers

- Modify: `config/hypr/hyprland.conf`
- Modify: `config/hypr/hyprlock.conf`
- Modify: `default/hypr/autostart.conf`
- Modify: `default/hypr/apps.conf`
- Modify: `default/hypr/bindings.conf`
- Modify: `default/hypr/bindings/media.conf`
- Modify: `default/hypr/bindings/tiling.conf`
- Modify: `default/hypr/bindings/tiling-v2.conf`
- Modify: `default/hypr/bindings/utilities.conf`
- Modify: `config/waybar/config.jsonc`
- Modify: `config/waybar/style.css`
- Modify: `config/walker/config.toml`
- Create: `default/walker/themes/ryoku-default/style.css`
- Modify: `default/walker/themes/omarchy-default/style.css`
- Modify: `default/mako/core.ini`
- Modify: `config/alacritty/alacritty.toml`
- Modify: `config/ghostty/config`
- Modify: `config/kitty/kitty.conf`
- Modify: `config/fastfetch/config.jsonc`
- Modify: `config/brave-flags.conf`
- Modify: `config/chromium-flags.conf`
- Modify: `config/omarchy/hooks/*.sample`
- Modify: `config/omarchy/themed/*.sample`
- Modify: `config/omarchy/extensions/menu.sh`

Responsibility:

- These files are consumers, not sources of truth.
- They must move after their Ryoku command and namespace targets already work outside the GUI.

### Privileged and install-time consumers

- Create: `config/systemd/user/ryoku-battery-monitor.service`
- Create: `config/systemd/user/ryoku-battery-monitor.timer`
- Modify: `config/systemd/user/omarchy-battery-monitor.service`
- Modify: `config/systemd/user/omarchy-battery-monitor.timer`
- Modify: `install/config/wifi-powersave-rules.sh`
- Modify: `install/config/powerprofilesctl-rules.sh`
- Modify: `install/config/timezones.sh`
- Modify: `install/config/theme.sh`
- Modify: `install/config/branding.sh`
- Modify: `install/config/config.sh`
- Modify: `install/config/walker-elephant.sh`
- Modify: `install/login/plymouth.sh`
- Modify: `install/login/sddm.sh`
- Modify: `install/login/limine-snapper.sh`
- Modify: `install/preflight/*`
- Modify: `install/post-install/*`
- Modify: `install/packaging/*`
- Create: `install/ryoku-base.packages`
- Modify: `install/omarchy-base.packages`

Responsibility:

- Rename root-owned files, service names, sudoers fragments, theme names, and installer entrypoints only after runtime consumers are stable.

### Migration backlog

- Modify: `migrations/*.sh` that still write `~/.local/share/omarchy`, `~/.local/state/omarchy`, `.config/omarchy`, or `omarchy-*` names into the live system
- Create: one or more new migration files via `omarchy-dev-add-migration --no-edit` until `ryoku-dev-add-migration` exists

Responsibility:

- Upgrades must converge existing installed systems onto the Ryoku namespace.
- No old migration may reintroduce Category 1 `omarchy` references after the owning chunk has moved.

### Verification utilities

- Create: `bin/ryoku-dev-verify-category1`
- Create: `bin/ryoku-dev-verify-display`

Responsibility:

- Make repeated grep, syntax, and display-safety checks fast enough to use after every chunk.

## Task 1: Create Verification Helpers and Display Recovery Checks

**Files:**
- Create: `bin/ryoku-dev-verify-category1`
- Create: `bin/ryoku-dev-verify-display`

- [ ] **Step 1: Write the chunk verifier**

```bash
#!/bin/bash
set -euo pipefail

chunk="${1:?chunk name required}"

doc_globs=(
  "--glob" "!docs/specs/*"
  "--glob" "!docs/plans/*"
  "--glob" "!docs/superpowers/specs/*"
)

existing_paths=()

collect_existing_paths() {
  local path

  for path in "$@"; do
    if [[ -e $path ]]; then
      existing_paths+=("$path")
    fi
  done
}

case "$chunk" in
  foundation)
    collect_existing_paths install.sh default/bash/envs config/uwsm/env

    if (( ${#existing_paths[@]} == 0 )); then
      echo "no target paths exist for chunk: $chunk" >&2
      exit 1
    fi

    if rg -n "${doc_globs[@]}" 'OMARCHY_PATH|~/.local/share/omarchy' "${existing_paths[@]}"; then
      exit 1
    fi
    ;;
  hypr)
    collect_existing_paths config/hypr default/hypr

    if (( ${#existing_paths[@]} == 0 )); then
      echo "no target paths exist for chunk: $chunk" >&2
      exit 1
    fi

    if rg -n "${doc_globs[@]}" 'omarchy-|/omarchy|\\.config/omarchy|\\.local/state/omarchy' "${existing_paths[@]}"; then
      exit 1
    fi
    ;;
  waybar)
    collect_existing_paths config/waybar config/walker default/mako config/fastfetch

    if (( ${#existing_paths[@]} == 0 )); then
      echo "no target paths exist for chunk: $chunk" >&2
      exit 1
    fi

    if rg -n "${doc_globs[@]}" 'omarchy-|OMARCHY_PATH|/omarchy|\\.config/omarchy' "${existing_paths[@]}"; then
      exit 1
    fi
    ;;
  *)
    echo "unknown chunk: $chunk" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 2: Run the verifier against the current repo**

Run: `bin/ryoku-dev-verify-category1 foundation`
Expected: non-zero exit or matches printed, because the repo still contains the old foundation references.

- [ ] **Step 3: Write the display verifier**

```bash
#!/bin/bash
set -euo pipefail

required_commands=(
  xdg-terminal-exec
  walker
  waybar
  hyprctl
)

for cmd in "${required_commands[@]}"; do
  command -v "$cmd" >/dev/null
done

test -f config/hypr/hyprland.conf
test -f config/waybar/config.jsonc
test -f config/waybar/style.css
```

- [ ] **Step 4: Run the display verifier**

Run: `bin/ryoku-dev-verify-display`
Expected: exits `0` on the current machine.

- [ ] **Step 5: Commit**

```bash
git add bin/ryoku-dev-verify-category1 bin/ryoku-dev-verify-display
git commit -m "chore: add category 1 verification helpers"
```

## Task 2: Establish the Shared Runtime Contract

**Files:**
- Create: `lib/runtime-env.sh`
- Modify: `install.sh`
- Modify: `default/bash/envs`
- Modify: `config/uwsm/env`
- Modify: `bin/ryoku-version`

- [ ] **Step 1: Write the shared runtime helper**

```bash
#!/bin/bash

export RYOKU_PATH_DEFAULT="$HOME/.local/share/ryoku"
export RYOKU_LEGACY_PATH="$HOME/.local/share/omarchy"
export RYOKU_STATE_PATH="${RYOKU_STATE_PATH:-$HOME/.local/state/ryoku}"
export RYOKU_CONFIG_PATH="${RYOKU_CONFIG_PATH:-$HOME/.config/ryoku}"

if [[ -e $RYOKU_PATH_DEFAULT ]]; then
  export RYOKU_PATH="$RYOKU_PATH_DEFAULT"
else
  export RYOKU_PATH="${RYOKU_PATH:-$RYOKU_LEGACY_PATH}"
fi

export OMARCHY_PATH="${OMARCHY_PATH:-$RYOKU_PATH}"
export PATH="$RYOKU_PATH/bin:$PATH"
```

- [ ] **Step 2: Source the helper from installer and shell/session entrypoints**

```bash
# install.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/runtime-env.sh"
export RYOKU_INSTALL="$RYOKU_PATH/install"
export RYOKU_INSTALL_LOG_FILE="/var/log/ryoku-install.log"

# default/bash/envs
source "$HOME/.local/share/ryoku/lib/runtime-env.sh" 2>/dev/null || source "$HOME/.local/share/omarchy/lib/runtime-env.sh"

# config/uwsm/env
source "$HOME/.local/share/ryoku/lib/runtime-env.sh" 2>/dev/null || source "$HOME/.local/share/omarchy/lib/runtime-env.sh"
omarchy-cmd-present mise && eval "$(mise activate bash --shims)"
```

- [ ] **Step 3: Update `bin/ryoku-version` to use the shared helper and Ryoku-facing output**

```bash
#!/bin/bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

echo "Ryoku Arch (pre-alpha)"
if [[ -d $RYOKU_PATH/.git ]]; then
  tip=$(git -C "$RYOKU_PATH" rev-parse --short HEAD 2>/dev/null)
  [[ -n $tip ]] && echo "HEAD: $tip"
fi
```

- [ ] **Step 4: Run syntax and foundation verification**

Run: `bash -n lib/runtime-env.sh install.sh default/bash/envs config/uwsm/env bin/ryoku-version`
Expected: no output

Run: `bin/ryoku-dev-verify-category1 foundation`
Expected: no matches printed for `install.sh`, `default/bash/envs`, and `config/uwsm/env`

- [ ] **Step 5: Commit**

```bash
git add lib/runtime-env.sh install.sh default/bash/envs config/uwsm/env bin/ryoku-version
git commit -m "refactor: add ryoku runtime path contract"
```

## Task 3: Migrate Live Repo, State, and Config Namespaces Safely

**Files:**
- Create: the next migration file from `omarchy-dev-add-migration --no-edit` for share/state/config bridges
- Modify: `bin/omarchy-state`
- Modify: `bin/omarchy-refresh-config`
- Modify: `install/config/theme.sh`
- Modify: `install/config/branding.sh`

- [ ] **Step 1: Create the namespace bridge migration**

```bash
omarchy-dev-add-migration --no-edit
```

Add content like:

```bash
echo "Create Ryoku state and config namespaces with legacy bridges"

mkdir -p "$HOME/.local/state/ryoku" "$HOME/.config/ryoku"

if [[ -d $HOME/.local/state/omarchy && ! -L $HOME/.local/state/omarchy ]]; then
  cp -an "$HOME/.local/state/omarchy/." "$HOME/.local/state/ryoku/"
  rm -rf "$HOME/.local/state/omarchy"
  ln -snf "$HOME/.local/state/ryoku" "$HOME/.local/state/omarchy"
fi

if [[ -d $HOME/.config/omarchy && ! -L $HOME/.config/omarchy ]]; then
  cp -an "$HOME/.config/omarchy/." "$HOME/.config/ryoku/"
fi
```

- [ ] **Step 2: Switch state and refresh helpers to Ryoku-first paths**

```bash
# bin/omarchy-state
STATE_DIR="${RYOKU_STATE_PATH:-$HOME/.local/state/ryoku}"
mkdir -p "$STATE_DIR"

# bin/omarchy-refresh-config
default_config_file="${RYOKU_PATH}/config/$config_file"
echo -e "\e[31mReplaced $user_config_file with new Ryoku default."
```

- [ ] **Step 3: Move installer-owned config writes to Ryoku namespace**

```bash
# install/config/theme.sh
mkdir -p ~/.config/ryoku/themes
ln -snf ~/.config/ryoku/current/theme/btop.theme ~/.config/btop/themes/current.theme
ln -snf ~/.config/ryoku/current/theme/mako.ini ~/.config/mako/config

# install/config/branding.sh
mkdir -p ~/.config/ryoku/branding
cp "$RYOKU_PATH/icon.txt" ~/.config/ryoku/branding/about.txt
cp "$RYOKU_PATH/logo.txt" ~/.config/ryoku/branding/screensaver.txt
```

- [ ] **Step 4: Run syntax and namespace verification**

Run: `bash -n bin/omarchy-state bin/omarchy-refresh-config install/config/theme.sh install/config/branding.sh migrations/*.sh`
Expected: no output

Run: `rg -n --hidden --glob '!.git/*' --glob '!docs/specs/*' --glob '!docs/plans/*' --glob '!docs/superpowers/specs/*' '\\.local/state/omarchy|\\.config/omarchy' bin/omarchy-state bin/omarchy-refresh-config install/config/theme.sh install/config/branding.sh`
Expected: no matches

- [ ] **Step 5: Commit**

```bash
git add bin/omarchy-state bin/omarchy-refresh-config install/config/theme.sh install/config/branding.sh migrations/*.sh
git commit -m "refactor: bridge ryoku state and config namespaces"
```

## Task 4: Create Ryoku Core Lifecycle Commands and Wrap Legacy Entry Points

**Files:**
- Create: `bin/ryoku-update`
- Create: `bin/ryoku-update-confirm`
- Create: `bin/ryoku-update-git`
- Create: `bin/ryoku-update-perform`
- Create: `bin/ryoku-update-restart`
- Create: `bin/ryoku-update-available`
- Create: `bin/ryoku-update-available-reset`
- Create: `bin/ryoku-update-system-pkgs`
- Create: `bin/ryoku-update-keyring`
- Create: `bin/ryoku-update-aur-pkgs`
- Create: `bin/ryoku-update-orphan-pkgs`
- Create: `bin/ryoku-update-firmware`
- Create: `bin/ryoku-update-time`
- Create: `bin/ryoku-migrate`
- Create: `bin/ryoku-state`
- Create: `bin/ryoku-hook`
- Create: `bin/ryoku-snapshot`
- Create: `bin/ryoku-version-branch`
- Create: `bin/ryoku-version-channel`
- Create: `bin/ryoku-version-pkgs`
- Create: `bin/ryoku-branch-set`
- Create: `bin/ryoku-channel-set`
- Modify: matching `bin/omarchy-*` files into wrappers

- [ ] **Step 1: Copy the existing lifecycle scripts to Ryoku names and retarget their internal calls**

```bash
# bin/ryoku-update
#!/bin/bash
set -e
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

if [[ -z ${RYOKU_UPDATE_LOGGED:-} ]]; then
  script_command=$(printf '%q ' "$0" "$@")
  exec env RYOKU_UPDATE_LOGGED=1 script -qefc "$script_command" "/tmp/ryoku-update.log"
fi

if [[ ${1:-} == "-y" ]] || ryoku-update-confirm; then
  ryoku-snapshot create || (($? == 127))
  ryoku-update-git
  ryoku-update-perform
fi
```

- [ ] **Step 2: Make the legacy names thin wrappers**

```bash
#!/bin/bash
exec ryoku-update "$@"
```

Use the same wrapper pattern for `omarchy-migrate`, `omarchy-state`, `omarchy-hook`, `omarchy-snapshot`, `omarchy-version-*`, `omarchy-branch-set`, and `omarchy-channel-set`.
Use the same wrapper pattern for `omarchy-update-available` and `omarchy-update-available-reset`.

- [ ] **Step 3: Verify the lifecycle command family**

Run: `for f in bin/ryoku-update* bin/ryoku-migrate bin/ryoku-state bin/ryoku-hook bin/ryoku-snapshot bin/ryoku-version* bin/ryoku-branch-set bin/ryoku-channel-set bin/omarchy-update* bin/omarchy-migrate bin/omarchy-state bin/omarchy-hook bin/omarchy-snapshot bin/omarchy-version* bin/omarchy-branch-set bin/omarchy-channel-set; do bash -n "$f"; done`
Expected: no output

Run: `bin/ryoku-update -h 2>/dev/null || true`
Expected: command resolves without `command not found`

- [ ] **Step 4: Commit**

```bash
git add bin/ryoku-update* bin/ryoku-migrate bin/ryoku-state bin/ryoku-hook bin/ryoku-snapshot bin/ryoku-version* bin/ryoku-branch-set bin/ryoku-channel-set bin/omarchy-update* bin/omarchy-migrate bin/omarchy-state bin/omarchy-hook bin/omarchy-snapshot bin/omarchy-version* bin/omarchy-branch-set bin/omarchy-channel-set
git commit -m "refactor: add ryoku lifecycle commands"
```

## Task 5: Rename Package and Install Helper Command Families

**Files:**
- Modify: all `bin/omarchy-pkg-*`
- Modify: all `bin/omarchy-pkg-aur-*`
- Modify: `bin/omarchy-cmd-present`
- Modify: `bin/omarchy-cmd-missing`
- Modify: all `bin/omarchy-install-*`
- Modify: all `bin/omarchy-dev-*`
- Modify: all `install/packaging/*.sh`
- Modify: `install/preflight/pacman.sh`
- Modify: `install/helpers/presentation.sh`

- [ ] **Step 1: Add Ryoku package helper commands and wrap the legacy names**

```bash
#!/bin/bash
exec ryoku-pkg-add "$@"
```

Create Ryoku counterparts first, then reduce the `omarchy-*` versions to wrappers.

- [ ] **Step 2: Retarget install and packaging scripts to the Ryoku names**

```bash
# install/preflight/pacman.sh
ryoku-pkg-add base-devel
ryoku-pkg-add ryoku-keyring

# install/packaging/base.sh
mapfile -t packages < <(grep -v '^#' "$RYOKU_INSTALL/ryoku-base.packages" | grep -v '^$')
ryoku-pkg-add "${packages[@]}"

# install/ryoku-base.packages
base-devel
ryoku-nvim
ryoku-walker
```

- [ ] **Step 3: Verify the family**

Run: `for f in bin/ryoku-pkg* bin/ryoku-install* bin/ryoku-dev-* bin/ryoku-cmd-present bin/ryoku-cmd-missing bin/omarchy-pkg* bin/omarchy-install* bin/omarchy-dev-* bin/omarchy-cmd-present bin/omarchy-cmd-missing install/packaging/*.sh install/preflight/pacman.sh install/helpers/presentation.sh; do bash -n "$f"; done`
Expected: no output

Run: `rg -n --hidden --glob '!.git/*' --glob '!docs/specs/*' --glob '!docs/plans/*' --glob '!docs/superpowers/specs/*' 'omarchy-pkg-|omarchy-install-|omarchy-cmd-present|omarchy-cmd-missing' install/packaging install/preflight/pacman.sh install/helpers/presentation.sh`
Expected: no matches in the owned files

- [ ] **Step 4: Commit**

```bash
git add bin/ryoku-pkg* bin/ryoku-install* bin/ryoku-dev-* bin/ryoku-cmd-present bin/ryoku-cmd-missing bin/omarchy-pkg* bin/omarchy-install* bin/omarchy-dev-* bin/omarchy-cmd-present bin/omarchy-cmd-missing install/packaging/*.sh install/preflight/pacman.sh install/helpers/presentation.sh
git commit -m "refactor: rename package and install helpers"
```

## Task 6: Rename Theme, Config, Menu, Launcher, and Hardware Command Families

**Files:**
- Modify: all `bin/omarchy-theme-*`
- Modify: all `bin/omarchy-font-*`
- Modify: `bin/omarchy-refresh-config`
- Modify: all `bin/omarchy-refresh-*`
- Modify: all `bin/omarchy-restart-*`
- Modify: `bin/omarchy-menu`
- Modify: all `bin/omarchy-launch-*`
- Modify: all `bin/omarchy-cmd-*`
- Modify: all `bin/omarchy-hw-*`
- Modify: all `bin/omarchy-toggle*`
- Modify: all `bin/omarchy-battery-*`
- Modify: all `bin/omarchy-powerprofiles-*`
- Modify: all `bin/omarchy-brightness-*`
- Modify: all `bin/omarchy-hibernation-*`
- Modify: all `bin/omarchy-hyprland-*`
- Modify: all `bin/omarchy-webapp-*`
- Modify: all `bin/omarchy-tui-*`
- Modify: all `bin/omarchy-voxtype-*`

- [ ] **Step 1: Promote each command family to Ryoku and reduce the legacy name to a wrapper**

```bash
#!/bin/bash
exec ryoku-menu "$@"
```

Use the same wrapper pattern for every user-facing family after the Ryoku command exists and passes syntax checks.

- [ ] **Step 2: Retarget internal calls and config paths inside the family**

```bash
# bin/ryoku-menu
export PATH="$RYOKU_PATH/bin:$PATH"
echo -e "$options" | ryoku-launch-walker --dmenu --width 295 --minheight 1 --maxheight 630 -p "$prompt..." "${args[@]}" 2>/dev/null
ryoku-launch-editor "$1"
open_in_editor ~/.config/ryoku/branding/screensaver.txt
open_in_editor ~/.config/ryoku/branding/about.txt
```

- [ ] **Step 3: Verify the family**

Run: `for f in bin/ryoku-theme* bin/ryoku-font-* bin/ryoku-refresh-* bin/ryoku-restart-* bin/ryoku-refresh-config bin/ryoku-menu bin/ryoku-launch-* bin/ryoku-cmd-* bin/ryoku-hw-* bin/ryoku-toggle* bin/ryoku-battery-* bin/ryoku-powerprofiles-* bin/ryoku-brightness-* bin/ryoku-hibernation-* bin/ryoku-hyprland-* bin/ryoku-webapp-* bin/ryoku-tui-* bin/ryoku-voxtype-*; do bash -n "$f"; done`
Expected: no output

Run: `rg -n --hidden --glob '!.git/*' --glob '!docs/specs/*' --glob '!docs/plans/*' --glob '!docs/superpowers/specs/*' 'omarchy-|\\.config/omarchy|\\.local/state/omarchy|\\.local/share/omarchy' bin/ryoku-theme* bin/ryoku-font-* bin/ryoku-refresh-* bin/ryoku-restart-* bin/ryoku-refresh-config bin/ryoku-menu bin/ryoku-launch-* bin/ryoku-cmd-* bin/ryoku-hw-* bin/ryoku-toggle* bin/ryoku-battery-* bin/ryoku-powerprofiles-* bin/ryoku-brightness-* bin/ryoku-hibernation-* bin/ryoku-hyprland-* bin/ryoku-webapp-* bin/ryoku-tui-* bin/ryoku-voxtype-*`
Expected: no matches in the owned files

- [ ] **Step 4: Commit**

```bash
git add bin/ryoku-theme* bin/ryoku-font-* bin/ryoku-refresh-* bin/ryoku-restart-* bin/ryoku-refresh-config bin/ryoku-menu bin/ryoku-launch-* bin/ryoku-cmd-* bin/ryoku-hw-* bin/ryoku-toggle* bin/ryoku-battery-* bin/ryoku-powerprofiles-* bin/ryoku-brightness-* bin/ryoku-hibernation-* bin/ryoku-hyprland-* bin/ryoku-webapp-* bin/ryoku-tui-* bin/ryoku-voxtype-* bin/omarchy-theme* bin/omarchy-font-* bin/omarchy-refresh-* bin/omarchy-restart-* bin/omarchy-refresh-config bin/omarchy-menu bin/omarchy-launch-* bin/omarchy-cmd-* bin/omarchy-hw-* bin/omarchy-toggle* bin/omarchy-battery-* bin/omarchy-powerprofiles-* bin/omarchy-brightness-* bin/omarchy-hibernation-* bin/omarchy-hyprland-* bin/omarchy-webapp-* bin/omarchy-tui-* bin/omarchy-voxtype-*
git commit -m "refactor: rename ryoku interaction commands"
```

## Task 7: Flip Hyprland Consumers After Recovery Path Is Tested

**Files:**
- Modify: `config/hypr/hyprland.conf`
- Modify: `default/hypr/autostart.conf`
- Modify: `default/hypr/apps.conf`
- Modify: `default/hypr/bindings.conf`
- Modify: `default/hypr/bindings/media.conf`
- Modify: `default/hypr/bindings/tiling.conf`
- Modify: `default/hypr/bindings/tiling-v2.conf`
- Modify: `default/hypr/bindings/utilities.conf`
- Modify: `config/hypr/hyprlock.conf`

- [ ] **Step 1: Record and test the non-GUI recovery path before touching Hyprland**

Run: `git rev-parse --short HEAD`
Expected: prints the last-known-good commit

Run: `tty`
Expected: confirm you know which local TTY or remote shell you will use if Hyprland fails

- [ ] **Step 2: Retarget Hyprland includes and commands**

```conf
source = ~/.local/share/ryoku/default/hypr/autostart.conf
source = ~/.config/ryoku/current/theme/hyprland.conf
source = ~/.local/state/ryoku/toggles/hypr/*.conf

bindd = SUPER, SPACE, Launch apps, exec, ryoku-launch-walker
bindd = SUPER ALT, SPACE, Ryoku menu, exec, ryoku-menu
bindd = , PRINT, Screenshot, exec, ryoku-cmd-screenshot
```

- [ ] **Step 3: Verify the Hyprland chunk**

Run: `bin/ryoku-dev-verify-display`
Expected: exits `0`

Run: `bin/ryoku-dev-verify-category1 hypr`
Expected: no matches in `config/hypr` and `default/hypr`

Run: `hyprctl reload`
Expected: exits `0`

Run: `hyprctl monitors >/dev/null`
Expected: exits `0`

- [ ] **Step 4: Commit**

```bash
git add config/hypr/hyprland.conf config/hypr/hyprlock.conf default/hypr/autostart.conf default/hypr/apps.conf default/hypr/bindings.conf default/hypr/bindings/media.conf default/hypr/bindings/tiling.conf default/hypr/bindings/tiling-v2.conf default/hypr/bindings/utilities.conf
git commit -m "refactor: switch hyprland to ryoku commands"
```

## Task 8: Flip Waybar and Remaining Desktop Dotfiles

**Files:**
- Modify: `config/waybar/config.jsonc`
- Modify: `config/waybar/style.css`
- Modify: `config/walker/config.toml`
- Create: `default/walker/themes/ryoku-default/style.css`
- Modify: `default/walker/themes/omarchy-default/style.css`
- Modify: `default/mako/core.ini`
- Modify: `config/alacritty/alacritty.toml`
- Modify: `config/ghostty/config`
- Modify: `config/kitty/kitty.conf`
- Modify: `config/fastfetch/config.jsonc`
- Modify: `config/brave-flags.conf`
- Modify: `config/chromium-flags.conf`
- Modify: `config/omarchy/hooks/*.sample`
- Modify: `config/omarchy/themed/*.sample`
- Modify: `config/omarchy/extensions/menu.sh`

- [ ] **Step 1: Retarget Waybar to Ryoku commands and Ryoku config paths**

```jsonc
"modules-left": ["custom/ryoku", "hyprland/workspaces"],
"custom/ryoku": {
  "format": "<span font='omarchy'>\ue900</span>",
  "on-click": "ryoku-menu",
  "tooltip-format": "Ryoku Menu\n\nSuper + Alt + Space"
},
"custom/update": {
  "exec": "ryoku-update-available",
  "on-click": "ryoku-launch-floating-terminal-with-presentation ryoku-update"
}
```

- [ ] **Step 2: Retarget Walker, Mako, terminal imports, browser flags, and Fastfetch**

```toml
# config/walker/config.toml
theme = "ryoku-default"
additional_theme_location = "~/.local/share/ryoku/default/walker/themes/"
command = "ryoku-restart-walker"
```

```css
/* default/walker/themes/ryoku-default/style.css */
@import "../../../../../../../.config/ryoku/current/theme/walker.css";
```

```ini
# config/kitty/kitty.conf
include ~/.config/ryoku/current/theme/kitty.conf
```

- [ ] **Step 3: Verify the desktop dotfile chunk**

Run: `bin/ryoku-dev-verify-category1 waybar`
Expected: no matches in the owned files

Run: `ryoku-refresh-waybar && pgrep -x waybar >/dev/null`
Expected: exits `0`

Run: `ryoku-launch-walker --help >/dev/null`
Expected: exits `0`

- [ ] **Step 4: Commit**

```bash
git add config/waybar/config.jsonc config/waybar/style.css config/walker/config.toml default/walker/themes/ryoku-default/style.css default/walker/themes/omarchy-default/style.css default/mako/core.ini config/alacritty/alacritty.toml config/ghostty/config config/kitty/kitty.conf config/fastfetch/config.jsonc config/brave-flags.conf config/chromium-flags.conf config/omarchy/hooks/*.sample config/omarchy/themed/*.sample config/omarchy/extensions/menu.sh
git commit -m "refactor: switch desktop configs to ryoku"
```

## Task 9: Rename systemd, udev, and Privileged File Surfaces

**Files:**
- Create: `config/systemd/user/ryoku-battery-monitor.service`
- Create: `config/systemd/user/ryoku-battery-monitor.timer`
- Modify: `config/systemd/user/omarchy-battery-monitor.service`
- Modify: `config/systemd/user/omarchy-battery-monitor.timer`
- Modify: `install/config/wifi-powersave-rules.sh`
- Modify: `install/config/powerprofilesctl-rules.sh`
- Modify: `install/config/timezones.sh`
- Modify: `install/config/increase-file-watchers.sh`
- Modify: `install/login/plymouth.sh`
- Modify: `install/login/sddm.sh`
- Modify: `install/login/limine-snapper.sh`

- [ ] **Step 1: Rename user units, unit references, and root-owned filenames**

```ini
[Unit]
Description=Ryoku Battery Monitor Check

[Service]
ExecStart=%h/.local/share/ryoku/bin/ryoku-battery-monitor
```

```bash
RUN+="/usr/bin/systemd-run --no-block --collect --unit=ryoku-wifi-powersave-on $HOME/.local/share/ryoku/bin/ryoku-wifi-powersave on"
```

- [ ] **Step 2: Validate privileged file types before touching the live system**

Run: `systemd-analyze --user verify config/systemd/user/ryoku-battery-monitor.service config/systemd/user/ryoku-battery-monitor.timer`
Expected: no errors

Run: `bash -n install/config/wifi-powersave-rules.sh install/config/powerprofilesctl-rules.sh install/config/timezones.sh install/config/increase-file-watchers.sh install/login/plymouth.sh install/login/sddm.sh install/login/limine-snapper.sh`
Expected: no output

- [ ] **Step 3: Apply the live checks one subsystem at a time**

Run: `systemctl --user daemon-reload`
Expected: exits `0`

Run: `systemctl --user status ryoku-battery-monitor.timer --no-pager`
Expected: unit loads without `omarchy` references

- [ ] **Step 4: Commit**

```bash
git add config/systemd/user/ryoku-battery-monitor.service config/systemd/user/ryoku-battery-monitor.timer config/systemd/user/omarchy-battery-monitor.service config/systemd/user/omarchy-battery-monitor.timer install/config/wifi-powersave-rules.sh install/config/powerprofilesctl-rules.sh install/config/timezones.sh install/config/increase-file-watchers.sh install/login/plymouth.sh install/login/sddm.sh install/login/limine-snapper.sh
git commit -m "refactor: rename system services and privileged files"
```

## Task 10: Rename Installer Entry Points and Packaging Defaults

**Files:**
- Modify: `install/preflight/*`
- Modify: `install/post-install/*`
- Modify: `install/config/*`
- Modify: `install/login/*`
- Modify: `install/packaging/*`
- Create: `install/ryoku-base.packages`
- Modify: `install/omarchy-base.packages`

- [ ] **Step 1: Move installer-facing commands and paths to Ryoku names**

```bash
# install/post-install/hibernation.sh
ryoku-hibernation-setup --force

# install/config/mimetypes.sh
ryoku-refresh-applications
```

- [ ] **Step 2: Resolve package-facing operational names**

```text
install/ryoku-base.packages
  ryoku-nvim
  ryoku-walker
  ryoku-keyring

install/omarchy-base.packages
  keep only as a temporary compatibility bridge if active code still reads it
```

If a Ryoku-native package does not yet exist, keep the task open and add the compatibility package resolution before removing the old operational name from active code.

- [ ] **Step 3: Verify installer and packaging paths**

Run: `for f in install/preflight/*.sh install/post-install/*.sh install/config/*.sh install/login/*.sh install/packaging/*.sh; do bash -n "$f"; done`
Expected: no output

Run: `rg -n --hidden --glob '!.git/*' --glob '!docs/specs/*' --glob '!docs/plans/*' --glob '!docs/superpowers/specs/*' 'omarchy-|\\.local/share/omarchy|\\.local/state/omarchy|\\.config/omarchy' install/preflight install/post-install install/config install/login install/packaging install/omarchy-base.packages install/ryoku-base.packages`
Expected: only unresolved compatibility-backed package references remain, if any

- [ ] **Step 4: Commit**

```bash
git add install/preflight/*.sh install/post-install/*.sh install/config/*.sh install/login/*.sh install/packaging/*.sh install/ryoku-base.packages install/omarchy-base.packages
git commit -m "refactor: rename installer category 1 surfaces"
```

## Task 11: Sweep the Migration Backlog, Remove Bridges, and Run the Final Gate

**Files:**
- Modify: all `migrations/*.sh` that still write `omarchy` Category 1 surfaces
- Modify: any remaining `bin/omarchy-*` wrapper still needed only for compatibility
- Modify: `docs/rebrand-inventory.md`
- Modify: current session log under `logs/`

- [ ] **Step 1: Sweep the migration backlog**

Run: `rg -n --hidden --glob '!.git/*' --glob '!docs/specs/*' --glob '!docs/plans/*' --glob '!docs/superpowers/specs/*' 'omarchy-|\\.local/share/omarchy|\\.local/state/omarchy|\\.config/omarchy' migrations`
Expected: every match is either fixed in this task or explicitly justified as documentation or legal text

Apply changes like:

```bash
source "$RYOKU_PATH/install/config/powerprofilesctl-rules.sh"
echo -e "\n# Toggle config flags dynamically\nsource = ~/.local/state/ryoku/toggles/hypr/*.conf" >> "$HYPR_CONF"
```

- [ ] **Step 2: Remove compatibility wrappers only after grep and runtime checks are clean**

```bash
rm bin/omarchy-update bin/omarchy-migrate bin/omarchy-state
```

Do not remove a wrapper until `rg` shows no active consumer for that name outside docs and legal text.

- [ ] **Step 3: Run the final Category 1 gate**

Run:

```bash
rg -n --hidden \
  --glob '!.git/*' \
  --glob '!docs/specs/*' \
  --glob '!docs/plans/*' \
  --glob '!docs/superpowers/specs/*' \
  'omarchy-|\\.local/share/omarchy|\\.local/state/omarchy|\\.config/omarchy|OMARCHY_PATH|OMARCHY_INSTALL|OMARCHY_INSTALL_LOG_FILE|OMARCHY_MIGRATIONS_STATE_PATH' \
  .
```

Expected: only Category 2 legal text or explicitly deferred non-Category-1 surfaces remain. If active code still appears, stop and fix it before continuing.

- [ ] **Step 4: Record the result in the source-of-truth docs**

Update `docs/rebrand-inventory.md` to mark the Category 1 chunk queue complete.

Update the current session log with:

```markdown
**Verified:**
- final Category 1 grep suite passed
- display-critical validation passed
- installer/runtime validation passed
```

- [ ] **Step 5: Commit**

```bash
git add migrations/*.sh docs/rebrand-inventory.md logs/*.md bin/omarchy-* bin/ryoku-*
git commit -m "refactor: complete category 1 ryoku rename"
```

## Self-Review

### Spec coverage

- Shared runtime contract: Task 2
- Installed-system migration contract: Task 3
- Category 1 env-var policy: Task 2 and Task 4
- Package-facing name policy: Task 5 and Task 10
- Display-safe rules and non-GUI recovery: Task 7 and Task 8
- Validation matrix: Tasks 2 through 11
- Grep scope rules: Task 1 and Task 11
- Source-of-truth updates: Task 11

### Placeholder scan

- No `TODO`, `TBD`, or "similar to Task N" placeholders remain.
- Dynamic migration filenames are handled via the repo's existing generator command instead of fake filenames.

### Type and name consistency

- Canonical runtime names in this plan are `RYOKU_PATH`, `RYOKU_STATE_PATH`, `RYOKU_CONFIG_PATH`, and `ryoku-*` commands.
- Legacy `omarchy-*` names are wrappers until Task 11 removes them.
