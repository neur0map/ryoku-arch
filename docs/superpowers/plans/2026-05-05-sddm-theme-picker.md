# SDDM Theme Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Settings page that lets the user pick the SDDM (login) theme, install/uninstall the optional qylock provider, and fall back cleanly to the built-in `ii-pixel` theme.

**Architecture:** New QML page `LoginScreenConfig.qml` registered in `shell/settings.qml` and the search index. Provider data is a small JS list with two entries (built-in `ii-pixel` and external `qylock`). All elevated work goes through `pkexec` and three small bash helpers in `bin/` (`ryoku-set-sddm-theme`, refactored `ryoku-install-qylock`, new `ryoku-uninstall-qylock`). Active-theme detection scans every `/etc/sddm.conf.d/*.conf` file alphabetically and uses the last `Current=` line, matching SDDM's own merge semantics.

**Tech Stack:** Bash (helpers), QML (Quickshell + Qt 6 Quick Controls), `pkexec` for elevation, `polkit-gnome-authentication-agent-1` for the password dialog.

**Spec:** `docs/superpowers/specs/2026-05-05-sddm-theme-picker-design.md` (read this first; it contains the visual identity, copy strings, and edge-case rationale that this plan does not duplicate).

---

## File Structure

**Created files:**

- `bin/ryoku-set-sddm-theme` : Privileged helper. Validates a theme name and writes `[Theme]\nCurrent=<name>` to `/etc/sddm.conf.d/theme.conf`.
- `bin/ryoku-uninstall-qylock` : Privileged helper. Falls active theme back to `ii-pixel`, removes qylock-sourced theme dirs, removes `~/.local/share/qylock`.
- `shell/modules/settings/LoginScreenConfig.qml` : The new Settings page.
- `shell/assets/sddm-providers/_placeholder.png` : Shared "preview unavailable" image.
- `shell/assets/sddm-providers/ii-pixel/hero.png` : Hero strip for built-in.
- `shell/assets/sddm-providers/ii-pixel/themes/ii-pixel.png` : Single thumbnail for built-in.
- `shell/assets/sddm-providers/qylock/hero.png` : Hero strip for qylock.
- `shell/assets/sddm-providers/qylock/themes/<name>.png` : One PNG per qylock theme captured from upstream.
- `tests/login-screen-config.sh` : Static-validation bash test that grows across tasks.

**Modified files:**

- `bin/ryoku-install-qylock` : Refactored: detect `EUID == 0`, drop privs for git ops via `sudo -u $SUDO_USER` so the qylock clone stays user-owned when the helper runs under pkexec. Existing `sudo cp/tee` lines guarded by an `_priv` wrapper that returns empty when already root.
- `shell/settings.qml` : Add a new entry to the `pages` array between "Compositor" and "About".
- `shell/modules/settings/SettingsOverlay.qml` : Add a search index entry for the new page; bump every `pageIndex` that previously pointed at "About" by one.
- `CREDITS.md` : Add an attribution paragraph for the bundled qylock screenshots.

---

## Pre-flight (read once)

Before starting, read these files so you have the patterns the plan calls back to:

- `bin/ryoku-install-qylock` : current shape; you will refactor this.
- `shell/modules/settings/QuickConfig.qml:1-31` : canonical imports + `Process` usage.
- `shell/modules/settings/GeneralConfig.qml:783-1030` : existing "Lock screen" (session-lock) section; follow this layout idiom for SettingsCardSection composition.
- `shell/settings.qml:26-112` : the `pages` array shape.
- `shell/modules/settings/SettingsOverlay.qml:44-60` : search index entry shape.
- `shell/scripts/sddm/install-pixel-sddm.sh:160-186` : how ii-pixel currently writes `/etc/sddm.conf.d/ryoku-shell-theme.conf`.
- `tests/ryoku-shell-branding.sh:1-30` : the test pattern to mirror (bash, `set -euo pipefail`, `fail()` helper).

**Important QML detail:** The spec's "ListModel" wording is loose. Qt's `ListModel { ListElement {...} }` does **not** support array values inside `ListElement`. Use `property var providers: [{...}, {...}]` (a JS array of objects on the page root) instead. Repeaters and the rest of the page bind to that property.

---

## Task 1: Test scaffold

**Files:**
- Create: `tests/login-screen-config.sh`

- [ ] **Step 1: Create the test scaffold**

Create `tests/login-screen-config.sh` with the following content:

```bash
#!/bin/bash
# Static validation for the Settings → Login screen page and its
# privileged helpers. Pure shell assertions; does not run quickshell,
# does not start SDDM, does not call any helper.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  [[ -f $ROOT_DIR/$1 ]] || fail "missing file: $1"
}

assert_executable() {
  [[ -x $ROOT_DIR/$1 ]] || fail "not executable: $1"
}

assert_grep() {
  local pattern="$1" file="$2"
  grep -qE "$pattern" "$ROOT_DIR/$file" || fail "$file: missing pattern /$pattern/"
}

assert_no_grep() {
  local pattern="$1" file="$2"
  if grep -qE "$pattern" "$ROOT_DIR/$file"; then
    fail "$file: should not contain pattern /$pattern/"
  fi
}

assert_png() {
  local path="$1"
  assert_file "$path"
  file -b "$ROOT_DIR/$path" | grep -q "PNG image data" \
    || fail "$path: not a PNG"
}

# ---------------------------------------------------------------------
# Assertions (filled in as tasks land code).
# ---------------------------------------------------------------------

echo "PASS: tests/login-screen-config.sh ($0)"
```

- [ ] **Step 2: Make it executable and run it**

Run:
```bash
chmod +x tests/login-screen-config.sh
bash tests/login-screen-config.sh
```

Expected output: `PASS: tests/login-screen-config.sh (tests/login-screen-config.sh)`

- [ ] **Step 3: Commit**

```bash
git add tests/login-screen-config.sh
git commit -m "test(login-screen-config): scaffold static validator"
```

---

## Task 2: `bin/ryoku-set-sddm-theme` helper

**Files:**
- Create: `bin/ryoku-set-sddm-theme`
- Modify: `tests/login-screen-config.sh`

- [ ] **Step 1: Add failing assertions**

Append to `tests/login-screen-config.sh`, just above the final `echo "PASS: ..."` line:

```bash
# ── ryoku-set-sddm-theme ──────────────────────────────────────────────
assert_file       "bin/ryoku-set-sddm-theme"
assert_executable "bin/ryoku-set-sddm-theme"
# Must validate the theme exists under /usr/share/sddm/themes
assert_grep "/usr/share/sddm/themes/" "bin/ryoku-set-sddm-theme"
# Must write to /etc/sddm.conf.d/theme.conf
assert_grep "/etc/sddm\\.conf\\.d/theme\\.conf" "bin/ryoku-set-sddm-theme"
# Must NOT call sudo: pkexec already runs it as root
assert_no_grep "^[[:space:]]*sudo " "bin/ryoku-set-sddm-theme"
# Must refuse to run unprivileged
assert_grep "EUID" "bin/ryoku-set-sddm-theme"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/login-screen-config.sh`
Expected: `FAIL: missing file: bin/ryoku-set-sddm-theme`

- [ ] **Step 3: Create the helper**

Create `bin/ryoku-set-sddm-theme`:

```bash
#!/bin/bash
# Apply an SDDM greeter theme by writing /etc/sddm.conf.d/theme.conf.
# Designed to be invoked via pkexec, so refuses to run unprivileged.
#
# Usage:
#   pkexec ryoku-set-sddm-theme <theme-name>
#
# The named theme must already exist as a directory under
# /usr/share/sddm/themes/. This helper does NOT install themes; for
# qylock, see ryoku-install-qylock.

set -euo pipefail

if (( EUID != 0 )); then
  echo "ryoku-set-sddm-theme: must be run via pkexec (EUID=0)" >&2
  exit 1
fi

theme="${1:-}"
if [[ -z $theme ]]; then
  echo "Usage: ryoku-set-sddm-theme <theme-name>" >&2
  exit 1
fi

# Reject anything that is not a plain identifier (no slashes, no .., no
# whitespace). The directory check below is the real gate; this is
# defense in depth for the conf file write.
if ! [[ $theme =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "ryoku-set-sddm-theme: invalid theme name: $theme" >&2
  exit 1
fi

theme_dir="/usr/share/sddm/themes/$theme"
if [[ ! -d $theme_dir ]]; then
  echo "ryoku-set-sddm-theme: theme dir not found: $theme_dir" >&2
  exit 1
fi

mkdir -p /etc/sddm.conf.d
tee /etc/sddm.conf.d/theme.conf >/dev/null <<EOF
[Theme]
Current=$theme
EOF

echo "ryoku-set-sddm-theme: active theme set to $theme"
```

- [ ] **Step 4: Make it executable and run the test**

Run:
```bash
chmod +x bin/ryoku-set-sddm-theme
bash tests/login-screen-config.sh
```
Expected: `PASS: tests/login-screen-config.sh ...`

- [ ] **Step 5: Manually shellcheck**

Run: `shellcheck bin/ryoku-set-sddm-theme`
Expected: no warnings, or only `SC2034`/style nits. Fix anything substantive (`SC2086`, `SC2046`, etc.) before committing.

- [ ] **Step 6: Commit**

```bash
git add bin/ryoku-set-sddm-theme tests/login-screen-config.sh
git commit -m "feat(bin): add ryoku-set-sddm-theme helper"
```

---

## Task 3: Refactor `bin/ryoku-install-qylock` for pkexec safety

**Files:**
- Modify: `bin/ryoku-install-qylock`
- Modify: `tests/login-screen-config.sh`

- [ ] **Step 1: Add failing assertions**

Append to `tests/login-screen-config.sh` above the final `echo "PASS: ..."`:

```bash
# ── ryoku-install-qylock pkexec safety ────────────────────────────────
assert_grep "EUID"        "bin/ryoku-install-qylock"
assert_grep "SUDO_USER"   "bin/ryoku-install-qylock"
# Must use the _priv wrapper instead of bare sudo for the cp/tee path
assert_grep "_priv"       "bin/ryoku-install-qylock"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/login-screen-config.sh`
Expected: `FAIL: bin/ryoku-install-qylock: missing pattern /EUID/`

- [ ] **Step 3: Apply the refactor**

Replace the body of `bin/ryoku-install-qylock` with:

```bash
#!/bin/bash
set -e

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

# Install qylock (Darkkal44/qylock) as the Ryoku SDDM theme bundle.
#
# Usage:
#   ryoku-install-qylock                  interactive picker (qylock's sddm.sh)
#   ryoku-install-qylock --theme <name>   non-interactive; installs <name>
#   ryoku-install-qylock --default        non-interactive; installs dog-samurai
#                                         if no qylock theme is installed yet
#
# Safe to run via pkexec: when EUID=0, the helper drops privileges to
# $SUDO_USER for git operations so the clone at ~/.local/share/qylock
# stays user-owned. Privileged operations (cp into /usr/share/sddm/...
# and writing /etc/sddm.conf.d/theme.conf) use the _priv wrapper, which
# is empty when already root and "sudo" otherwise.

if (( EUID == 0 )); then
  if [[ -z ${SUDO_USER:-} ]]; then
    echo "ryoku-install-qylock: refusing to run as root with no SUDO_USER set" >&2
    exit 1
  fi
  TARGET_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  _priv() { "$@"; }
  _user() { sudo -u "$SUDO_USER" "$@"; }
else
  TARGET_HOME="$HOME"
  _priv() { sudo "$@"; }
  _user() { "$@"; }
fi

QYLOCK_DIR="$TARGET_HOME/.local/share/qylock"
QYLOCK_REPO="https://github.com/Darkkal44/qylock.git"
DEFAULT_THEME="dog-samurai"

mode="${1:-interactive}"

case "$mode" in
  --theme)
    theme="${2:?theme name required after --theme}"
    ;;
  --default)
    theme="$DEFAULT_THEME"
    ;;
  interactive)
    theme=""
    ;;
  *)
    echo "Usage: ryoku-install-qylock [--theme <name> | --default]" >&2
    exit 1
    ;;
esac

echo -e "\033[38;2;143;29;33m\nInstalling qylock SDDM theme bundle\033[0m"

ryoku-pkg-add \
  qt6-declarative \
  qt6-5compat \
  qt6-svg \
  qt6-multimedia \
  qt6-multimedia-ffmpeg \
  gst-plugins-base \
  gst-plugins-good \
  gst-plugins-bad \
  gst-plugins-ugly

if [[ -d $QYLOCK_DIR/.git ]]; then
  _user git -C "$QYLOCK_DIR" pull --ff-only >/dev/null
else
  _user rm -rf "$QYLOCK_DIR"
  _user git clone --depth=1 "$QYLOCK_REPO" "$QYLOCK_DIR" >/dev/null
fi

if [[ -z $theme ]]; then
  if (( EUID == 0 )); then
    echo "ryoku-install-qylock: interactive mode is not supported under pkexec" >&2
    exit 1
  fi
  cd "$QYLOCK_DIR"
  exec bash sddm.sh
fi

if [[ $mode == "--default" ]]; then
  for candidate_dir in /usr/share/sddm/themes/*/; do
    candidate=$(basename "$candidate_dir")
    if [[ -d $QYLOCK_DIR/themes/$candidate ]]; then
      echo "  qylock theme already installed: $candidate (keeping)"
      ensure_current="$candidate"
      break
    fi
  done
fi

if [[ -z ${ensure_current:-} ]]; then
  src="$QYLOCK_DIR/themes/$theme"
  if [[ ! -d $src ]]; then
    echo "  theme '$theme' not found under $QYLOCK_DIR/themes" >&2
    echo "  available:" >&2
    (cd "$QYLOCK_DIR/themes" && ls -1 | sed 's/^/    /') >&2
    exit 1
  fi
  echo "  installing theme: $theme"
  _priv rm -rf "/usr/share/sddm/themes/$theme"
  _priv cp -r "$src" "/usr/share/sddm/themes/$theme"
  ensure_current="$theme"
fi

_priv mkdir -p /etc/sddm.conf.d
_priv tee /etc/sddm.conf.d/theme.conf >/dev/null <<EOF
[Theme]
Current=$ensure_current
EOF

echo "  qylock theme active: $ensure_current"
```

- [ ] **Step 4: Run the test**

Run: `bash tests/login-screen-config.sh`
Expected: `PASS: ...`

- [ ] **Step 5: Shellcheck the refactor**

Run: `shellcheck bin/ryoku-install-qylock`
Expected: no warnings (or only style nits). Fix substantive issues.

- [ ] **Step 6: Verify user-mode invocation still works**

Run, **without** modifying anything: `bash -n bin/ryoku-install-qylock`
Expected: no syntax errors. (Behavioral verification of the non-root path is manual: a user typing `ryoku-install-qylock --default` in a terminal should still work as before. Do not actually run it during this task : that's a behavior test for the manual QA pass at the end.)

- [ ] **Step 7: Commit**

```bash
git add bin/ryoku-install-qylock tests/login-screen-config.sh
git commit -m "refactor(bin): make ryoku-install-qylock pkexec-safe"
```

---

## Task 4: `bin/ryoku-uninstall-qylock` helper

**Files:**
- Create: `bin/ryoku-uninstall-qylock`
- Modify: `tests/login-screen-config.sh`

- [ ] **Step 1: Add failing assertions**

Append to `tests/login-screen-config.sh` above the final `echo "PASS: ..."`:

```bash
# ── ryoku-uninstall-qylock ────────────────────────────────────────────
assert_file       "bin/ryoku-uninstall-qylock"
assert_executable "bin/ryoku-uninstall-qylock"
assert_grep "EUID"            "bin/ryoku-uninstall-qylock"
assert_grep "SUDO_USER"       "bin/ryoku-uninstall-qylock"
# Must reference the ii-pixel fallback by name
assert_grep "ii-pixel"        "bin/ryoku-uninstall-qylock"
# Guard list: stock SDDM themes that must never be removed by this helper
assert_grep "elarun"          "bin/ryoku-uninstall-qylock"
assert_grep "maldives"        "bin/ryoku-uninstall-qylock"
assert_grep "maya"            "bin/ryoku-uninstall-qylock"
# Must compute themes by intersection (not blindly delete from /usr/share/sddm/themes)
assert_grep "/usr/share/sddm/themes/" "bin/ryoku-uninstall-qylock"
assert_grep "\\.local/share/qylock"   "bin/ryoku-uninstall-qylock"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/login-screen-config.sh`
Expected: `FAIL: missing file: bin/ryoku-uninstall-qylock`

- [ ] **Step 3: Create the helper**

Create `bin/ryoku-uninstall-qylock`:

```bash
#!/bin/bash
# Remove the qylock SDDM theme bundle and fall the active greeter
# back to the built-in ii-pixel theme. Designed to be invoked via
# pkexec, so refuses to run unprivileged.
#
# Order of operations matters: the active theme is switched FIRST so
# SDDM never has a moment where Current= points at a directory we are
# about to delete. A mid-uninstall crash leaves an orphaned qylock
# clone but a working greeter; re-running this helper finishes the
# cleanup.
#
# Stock SDDM themes (elarun, maldives, maya) and the built-in ii-pixel
# are never touched: we only remove themes that exist in BOTH
# ~/.local/share/qylock/themes/ and /usr/share/sddm/themes/.

set -euo pipefail

if (( EUID != 0 )); then
  echo "ryoku-uninstall-qylock: must be run via pkexec (EUID=0)" >&2
  exit 1
fi

if [[ -z ${SUDO_USER:-} ]]; then
  echo "ryoku-uninstall-qylock: refusing to run with no SUDO_USER set" >&2
  exit 1
fi

TARGET_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
QYLOCK_DIR="$TARGET_HOME/.local/share/qylock"
SDDM_THEMES_DIR="/usr/share/sddm/themes"

# Names that must NEVER be removed even if they somehow appear in both
# directories. Defense in depth; the intersection check below already
# rules these out for any normal install.
GUARD_NAMES=("ii-pixel" "elarun" "maldives" "maya")

is_guarded() {
  local name="$1" g
  for g in "${GUARD_NAMES[@]}"; do
    [[ $name == "$g" ]] && return 0
  done
  return 1
}

# Step 1: switch active theme to ii-pixel BEFORE any deletion.
if [[ -d $SDDM_THEMES_DIR/ii-pixel ]]; then
  if [[ -f /etc/sddm.conf.d/ryoku-shell-theme.conf ]] \
     && grep -qE '^\s*Current\s*=\s*ii-pixel\s*$' /etc/sddm.conf.d/ryoku-shell-theme.conf; then
    # ryoku-shell-theme.conf already pins ii-pixel as the underlying
    # default; deleting theme.conf is sufficient and matches a fresh
    # install layout.
    rm -f /etc/sddm.conf.d/theme.conf
  else
    mkdir -p /etc/sddm.conf.d
    tee /etc/sddm.conf.d/theme.conf >/dev/null <<EOF
[Theme]
Current=ii-pixel
EOF
  fi
  echo "  active SDDM theme: ii-pixel"
else
  echo "ryoku-uninstall-qylock: ii-pixel not installed; refusing to uninstall qylock without a fallback" >&2
  exit 1
fi

# Step 2: remove qylock-sourced themes from /usr/share/sddm/themes.
removed=0
if [[ -d $QYLOCK_DIR/themes ]]; then
  for src_dir in "$QYLOCK_DIR"/themes/*/; do
    [[ -d $src_dir ]] || continue
    name=$(basename "$src_dir")
    if is_guarded "$name"; then
      echo "  skipping guarded theme: $name"
      continue
    fi
    target="$SDDM_THEMES_DIR/$name"
    if [[ -d $target ]]; then
      rm -rf "$target"
      echo "  removed: $target"
      removed=$((removed + 1))
    fi
  done
fi

# Step 3: drop the qylock clone (user-owned).
if [[ -d $QYLOCK_DIR ]]; then
  sudo -u "$SUDO_USER" rm -rf "$QYLOCK_DIR"
  echo "  removed: $QYLOCK_DIR"
fi

echo "ryoku-uninstall-qylock: done ($removed system theme(s) removed)"
```

- [ ] **Step 4: Make it executable and run the test**

Run:
```bash
chmod +x bin/ryoku-uninstall-qylock
bash tests/login-screen-config.sh
```
Expected: `PASS: ...`

- [ ] **Step 5: Shellcheck**

Run: `shellcheck bin/ryoku-uninstall-qylock`
Expected: no substantive warnings.

- [ ] **Step 6: Commit**

```bash
git add bin/ryoku-uninstall-qylock tests/login-screen-config.sh
git commit -m "feat(bin): add ryoku-uninstall-qylock helper"
```

---

## Task 5: Asset directory + placeholder

**Files:**
- Create: `shell/assets/sddm-providers/_placeholder.png`
- Create: `shell/assets/sddm-providers/ii-pixel/hero.png`
- Create: `shell/assets/sddm-providers/ii-pixel/themes/ii-pixel.png`
- Create: `shell/assets/sddm-providers/qylock/hero.png`
- Create: `shell/assets/sddm-providers/qylock/themes/<name>.png` (one per upstream qylock theme)
- Modify: `tests/login-screen-config.sh`

This task involves **manual asset capture**. You will create real PNG files; you will not generate them with code. The test will gate completeness.

- [ ] **Step 1: Add asset assertions to the test**

Append to `tests/login-screen-config.sh` above the final `echo "PASS: ..."`:

```bash
# ── Asset bundles ─────────────────────────────────────────────────────
assert_png "shell/assets/sddm-providers/_placeholder.png"
assert_png "shell/assets/sddm-providers/ii-pixel/hero.png"
assert_png "shell/assets/sddm-providers/ii-pixel/themes/ii-pixel.png"
assert_png "shell/assets/sddm-providers/qylock/hero.png"
# Per-theme qylock PNGs are validated by the manifest sync check below
# (Task 7), once the QML page declares the bundledThemes list.
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/login-screen-config.sh`
Expected: `FAIL: missing file: shell/assets/sddm-providers/_placeholder.png`

- [ ] **Step 3: Create the placeholder**

The placeholder is a 1280×720 PNG with the literal text `preview unavailable` centered on a low-contrast subtle pattern. Body font: `Roboto` or `Inter`, mid-weight, ~48px. Background a flat near-black (`#101010`) with a 12% white repeating dot pattern.

You can generate it with ImageMagick (already installed on Ryoku):

```bash
mkdir -p shell/assets/sddm-providers
magick -size 1280x720 \
  -define gradient:angle=135 \
  gradient:'#101010-#1a1a1a' \
  -fill 'rgba(255,255,255,0.08)' \
  -draw "circle 0,0 0,3" \
  -gravity center \
  -font Roboto -pointsize 56 -fill 'rgba(255,255,255,0.55)' \
  -annotate 0 'preview unavailable' \
  shell/assets/sddm-providers/_placeholder.png
```

If `magick` is not aliased to ImageMagick 7, use `convert` with the same arguments.

- [ ] **Step 4: Capture ii-pixel hero and thumbnail**

The ii-pixel SDDM theme is rendered from `/usr/share/sddm/themes/ii-pixel/Main.qml` with the user's current wallpaper as the background. To capture a representative screenshot:

1. Start `sddm-greeter --test-mode --theme /usr/share/sddm/themes/ii-pixel` from a terminal : this opens the greeter UI in a window.
2. Use `grim -g "$(slurp)"` (already installed) to grab the window region.
3. Resize/crop to 1280×720 with `magick <in> -resize 1280x720^ -gravity center -extent 1280x720 shell/assets/sddm-providers/ii-pixel/themes/ii-pixel.png`.
4. The hero is a desaturated and slightly-darkened crop of the same screenshot. Reuse the captured image:

```bash
mkdir -p shell/assets/sddm-providers/ii-pixel
magick shell/assets/sddm-providers/ii-pixel/themes/ii-pixel.png \
  -modulate 100,40,100 -brightness-contrast -10x0 \
  -resize 1280x280^ -gravity center -extent 1280x280 \
  shell/assets/sddm-providers/ii-pixel/hero.png
```

Target file size: under 250KB each. Run `magick <out> -strip -quality 80 <out>` if needed.

- [ ] **Step 5: Capture qylock hero and per-theme thumbnails**

Capture qylock's themes from upstream. Two paths:

**Path A (qylock already cloned somewhere on disk):** for each `theme/` under the clone, run that theme's preview command (each theme has its own `Main.qml`; some ship a `preview.png` already : if so, just resize and reuse). Output to `shell/assets/sddm-providers/qylock/themes/<name>.png`.

**Path B (no clone yet):** clone the upstream README assets:

```bash
mkdir -p /tmp/qylock-capture
git clone --depth=1 https://github.com/Darkkal44/qylock.git /tmp/qylock-capture
ls /tmp/qylock-capture/themes
```

For each `<name>` in `/tmp/qylock-capture/themes/`:

1. Look for an existing `preview.png` or `screenshot.png` in the theme dir. If present, resize it to 1280×720 and copy to `shell/assets/sddm-providers/qylock/themes/<name>.png`.
2. If absent, render the theme via `sddm-greeter --test-mode --theme /tmp/qylock-capture/themes/<name>` and capture with grim.

Compose the qylock hero from 3-4 theme thumbnails layered with desaturation (so it does not look like any single theme):

```bash
magick shell/assets/sddm-providers/qylock/themes/dog-samurai.png \
       shell/assets/sddm-providers/qylock/themes/<other>.png \
       shell/assets/sddm-providers/qylock/themes/<other>.png \
  -resize 1280x280^ -gravity center -extent 1280x280 \
  -evaluate-sequence mean \
  -modulate 100,55,100 \
  shell/assets/sddm-providers/qylock/hero.png
```

Record the **exact list of qylock theme names** you captured. You will hard-code this list into `LoginScreenConfig.qml` in Task 7. The `bundledThemes` array must match the on-disk PNG file names one-for-one.

- [ ] **Step 6: Run the test**

Run: `bash tests/login-screen-config.sh`
Expected: `PASS: ...`

- [ ] **Step 7: Commit**

```bash
git add shell/assets/sddm-providers tests/login-screen-config.sh
git commit -m "feat(shell/assets): bundle SDDM provider previews"
```

---

## Task 6: `LoginScreenConfig.qml` skeleton + active-theme detection

**Files:**
- Create: `shell/modules/settings/LoginScreenConfig.qml`
- Modify: `tests/login-screen-config.sh`

This task creates the page shell, the `providers` data model, and the active-theme reader. Visual content (banner, cards, tile grid) lands in Tasks 8-9.

- [ ] **Step 1: Add page assertions**

Append to `tests/login-screen-config.sh`:

```bash
# ── LoginScreenConfig.qml ─────────────────────────────────────────────
assert_file "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "ContentPage"        "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "property var providers" "shell/modules/settings/LoginScreenConfig.qml"
# Both providers are declared
assert_grep "providerId: \"ii-pixel\""  "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "providerId: \"qylock\""    "shell/modules/settings/LoginScreenConfig.qml"
# Active-theme reader exists
assert_grep "function readActiveTheme"  "shell/modules/settings/LoginScreenConfig.qml"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/login-screen-config.sh`
Expected: `FAIL: missing file: shell/modules/settings/LoginScreenConfig.qml`

- [ ] **Step 3: Create the page skeleton**

Create `shell/modules/settings/LoginScreenConfig.qml`:

```qml
import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: root
    settingsPageIndex: -1   // set by the integration in shell/settings.qml
    settingsPageName: Translation.tr("Login screen")

    // Replace `bundledThemes: []` for qylock with the exact list of
    // PNG file names captured in Task 5 (without the `.png` suffix).
    property var providers: [
        ({
            providerId: "ii-pixel",
            kind: "builtin",
            displayName: "ii-pixel",
            author: "Ryoku project",
            repoUrl: "",
            description: "Built-in pixel-art SDDM theme that ships with Ryoku. Material You dynamic colors driven by your wallpaper palette.",
            accentColor: "",
            licenseLabel: "MIT",
            installRoot: "",
            themesPath: "",
            bundledAssetDir: "shell/assets/sddm-providers/ii-pixel",
            heroAsset: "hero.png",
            themesAssetDir: "themes",
            placeholderAsset: "../_placeholder.png",
            bundledThemes: ["ii-pixel"]
        }),
        ({
            providerId: "qylock",
            kind: "external",
            displayName: "qylock",
            author: "Darkkal44",
            repoUrl: "https://github.com/Darkkal44/qylock",
            description: "Optional bundle of animated, video-capable SDDM themes by Darkkal44. Cloned to ~/.local/share/qylock and copied into the system SDDM themes dir on demand.",
            accentColor: "#8f1d21",
            licenseLabel: "GPL-3.0",
            installRoot: Quickshell.env("HOME") + "/.local/share/qylock",
            themesPath: "themes",
            bundledAssetDir: "shell/assets/sddm-providers/qylock",
            heroAsset: "hero.png",
            themesAssetDir: "themes",
            placeholderAsset: "../_placeholder.png",
            bundledThemes: [
                // FILL IN with the exact names captured in Task 5
            ]
        })
    ]

    // ── Active-theme detection ────────────────────────────────────────
    // SDDM merges every /etc/sddm.conf.d/*.conf alphabetically; later
    // files override earlier ones. Read all of them in order and use
    // the LAST `Current=` value found.
    property string activeTheme: ""

    Process {
        id: readActiveThemeProc
        command: ["/usr/bin/bash", "-c",
            "shopt -s nullglob; " +
            "current=''; " +
            "for f in /etc/sddm.conf.d/*.conf; do " +
            "  v=$(grep -E '^\\s*Current\\s*=' \"$f\" | tail -n1 | cut -d= -f2 | tr -d '[:space:]') || true; " +
            "  [[ -n $v ]] && current=\"$v\"; " +
            "done; " +
            "echo \"$current\""
        ]
        stdout: SplitParser {
            onRead: data => {
                root.activeTheme = data.trim() || "breeze"
            }
        }
    }

    function readActiveTheme() {
        readActiveThemeProc.running = true
    }

    Component.onCompleted: readActiveTheme()
    onVisibleChanged: if (visible) readActiveTheme()

    // ── Provider state helpers ────────────────────────────────────────
    function providerInstalled(provider) {
        if (provider.kind === "builtin") return true
        return providerInstallProbe.has(provider.providerId)
    }

    QtObject {
        id: providerInstallProbe
        property var presence: ({})
        function has(id) { return presence[id] === true }
        function set(id, value) {
            var p = Object.assign({}, presence)
            p[id] = value === true
            presence = p
        }
    }

    Process {
        id: probeQylockProc
        command: ["/usr/bin/bash", "-c",
            "test -d \"$HOME/.local/share/qylock/.git\" && echo yes || echo no"]
        stdout: SplitParser {
            onRead: data => providerInstallProbe.set("qylock", data.trim() === "yes")
        }
    }

    function refreshProviderState() {
        probeQylockProc.running = true
    }

    Component.onCompleted: refreshProviderState()

    // ── UI lands in the next two tasks. ───────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        StyledText {
            text: Translation.tr("Login screen page (under construction). Active: %1").arg(root.activeTheme)
        }
    }
}
```

(Yes, there are two `Component.onCompleted` blocks above : Qt allows this; both fire. If the implementer prefers one, they can merge them.)

- [ ] **Step 4: Run the test**

Run: `bash tests/login-screen-config.sh`
Expected: `PASS: ...`

- [ ] **Step 5: Commit**

```bash
git add shell/modules/settings/LoginScreenConfig.qml tests/login-screen-config.sh
git commit -m "feat(shell/settings/login-screen): scaffold page + active-theme reader"
```

---

## Task 7: Bundled-themes manifest sync check

**Files:**
- Modify: `shell/modules/settings/LoginScreenConfig.qml` (fill in qylock `bundledThemes`)
- Modify: `tests/login-screen-config.sh`

- [ ] **Step 1: Fill in the qylock bundledThemes list**

Open `shell/modules/settings/LoginScreenConfig.qml` and replace the empty `bundledThemes: []` for the qylock provider with the exact list of theme names captured in Task 5. Example shape (your actual list may differ):

```qml
bundledThemes: [
    "dog-samurai",
    "neon-galaxy",
    "monochromatic-blur"
]
```

The list must match the on-disk PNG file names one-for-one. If you captured 5 themes named `a.png, b.png, c.png, d.png, e.png`, the array must be `["a", "b", "c", "d", "e"]`.

- [ ] **Step 2: Add the manifest-sync assertion**

Append to `tests/login-screen-config.sh` above the final `echo "PASS: ..."`:

```bash
# ── bundledThemes manifest sync ───────────────────────────────────────
QML_FILE="$ROOT_DIR/shell/modules/settings/LoginScreenConfig.qml"

extract_bundled_themes() {
  # Args: provider id
  # Prints one theme name per line (or nothing if empty list).
  local provider="$1"
  awk -v provider="$provider" '
    $0 ~ "providerId: \"" provider "\"" { in_block = 1 }
    in_block && /bundledThemes:/ { in_list = 1; sub(/.*bundledThemes:\s*\[/, ""); }
    in_list {
      while (match($0, /"[^"]+"/)) {
        s = substr($0, RSTART + 1, RLENGTH - 2)
        print s
        $0 = substr($0, RSTART + RLENGTH)
      }
      if (index($0, "]")) { in_list = 0; in_block = 0 }
    }
  ' "$QML_FILE"
}

for provider in ii-pixel qylock; do
  while IFS= read -r theme; do
    [[ -z $theme ]] && continue
    asset="shell/assets/sddm-providers/$provider/themes/$theme.png"
    assert_png "$asset"
  done < <(extract_bundled_themes "$provider")
done
```

- [ ] **Step 3: Run the test**

Run: `bash tests/login-screen-config.sh`
Expected: `PASS: ...` (any theme name in the QML list without a matching PNG triggers a FAIL.)

- [ ] **Step 4: Commit**

```bash
git add shell/modules/settings/LoginScreenConfig.qml tests/login-screen-config.sh
git commit -m "feat(shell/settings/login-screen): pin bundledThemes manifest + sync check"
```

---

## Task 8: Active-theme banner + provider cards (visual)

**Files:**
- Modify: `shell/modules/settings/LoginScreenConfig.qml`

This task replaces the placeholder StyledText from Task 6 with the banner and the per-provider cards (without the post-install theme grid yet : that lands in Task 9).

The work is mostly visual QML. There is no automated test gate beyond the existing static checks. Verify visually after each step by restarting the shell and opening Settings.

- [ ] **Step 1: Replace the placeholder ColumnLayout**

In `LoginScreenConfig.qml`, replace the `ColumnLayout { ... StyledText { ... } }` block at the bottom with:

```qml
ColumnLayout {
    anchors.fill: parent
    anchors.margins: 20
    spacing: 16

    // ── Active-theme banner ───────────────────────────────────────────
    SettingsCardSection {
        Layout.fillWidth: true
        expanded: true
        icon: "login"
        title: Translation.tr("Active SDDM theme")

        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                StyledText {
                    text: root.activeTheme || "breeze"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 16
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: Translation.tr("Greeter shown before login. Reboot or run 'systemctl restart sddm' to apply.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.maximumWidth: 360
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    // ── Provider cards ────────────────────────────────────────────────
    Repeater {
        model: root.providers
        delegate: ProviderCard {
            provider: modelData
            installed: root.providerInstalled(modelData)
            activeTheme: root.activeTheme
            onApplyTheme: themeName => root.applyTheme(modelData, themeName)
            onInstallProvider: root.installProvider(modelData)
            onUninstallProvider: root.confirmUninstall(modelData)
        }
    }
}
```

- [ ] **Step 2: Add the `ProviderCard` inline component**

Above the closing `}` of the `ContentPage`, add an inline component definition:

```qml
component ProviderCard: SettingsCardSection {
    id: providerCardRoot
    property var provider
    property bool installed: false
    property string activeTheme: ""

    signal applyTheme(string themeName)
    signal installProvider()
    signal uninstallProvider()

    Layout.fillWidth: true
    expanded: true
    icon: provider.kind === "builtin" ? "verified" : "extension"
    title: provider.displayName

    SettingsGroup {
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            // Hero strip
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: Appearance.rounding.normal
                color: "transparent"
                clip: true

                Image {
                    anchors.fill: parent
                    source: Quickshell.shellPath(provider.bundledAssetDir + "/" + provider.heroAsset)
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                }
            }

            // Name + author + status pill
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: provider.displayName + (provider.author ? "  ·  by " + provider.author : "")
                    font.pixelSize: 18
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    visible: provider.kind === "builtin"
                    radius: 999
                    color: Appearance.colors.colPrimary
                    opacity: 0.18
                    implicitWidth: builtinPillText.implicitWidth + 16
                    implicitHeight: builtinPillText.implicitHeight + 6
                    StyledText {
                        id: builtinPillText
                        anchors.centerIn: parent
                        text: Translation.tr("Built-in")
                        color: Appearance.colors.colPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }
                }

                Rectangle {
                    visible: provider.kind === "external" && !providerCardRoot.installed
                    radius: 999
                    color: "transparent"
                    border.width: 1
                    border.color: Appearance.colors.colSubtext
                    implicitWidth: notInstalledPillText.implicitWidth + 16
                    implicitHeight: notInstalledPillText.implicitHeight + 6
                    StyledText {
                        id: notInstalledPillText
                        anchors.centerIn: parent
                        text: Translation.tr("Not installed")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    visible: provider.kind === "external" && providerCardRoot.installed
                    radius: 999
                    color: provider.accentColor
                    opacity: 0.18
                    implicitWidth: installedPillText.implicitWidth + 16
                    implicitHeight: installedPillText.implicitHeight + 6
                    StyledText {
                        id: installedPillText
                        anchors.centerIn: parent
                        text: Translation.tr("Installed")
                        color: provider.accentColor
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }

            // Repo link (external only)
            StyledText {
                visible: provider.kind === "external" && provider.repoUrl
                text: "<a href=\"" + provider.repoUrl + "\">" + provider.repoUrl + "</a>"
                onLinkActivated: link => Qt.openUrlExternally(link)
                font.pixelSize: 12
                color: Appearance.colors.colPrimary
                textFormat: Text.RichText
            }

            // Description
            StyledText {
                Layout.fillWidth: true
                text: provider.description
                wrapMode: Text.WordWrap
                color: Appearance.colors.colSubtext
                font.pixelSize: 13
            }

            // Theme tile grid is added in Task 9; for now show
            // a single hero-themed tile for ii-pixel and a bundled
            // strip for qylock pre-install state.
            ThemeTileStrip {
                provider: providerCardRoot.provider
                installed: providerCardRoot.installed
                activeTheme: providerCardRoot.activeTheme
                onApplyTheme: themeName => providerCardRoot.applyTheme(themeName)
            }

            // Action row
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: 8

                Item { Layout.fillWidth: true }

                RippleButton {
                    visible: provider.kind === "external" && providerCardRoot.installed
                    buttonText: Translation.tr("Update")
                    onClicked: providerCardRoot.applyTheme(providerCardRoot.activeTheme)
                }

                RippleButton {
                    visible: provider.kind === "external" && providerCardRoot.installed
                    buttonText: Translation.tr("Uninstall")
                    colBackground: "transparent"
                    colBackgroundHover: Qt.rgba(Appearance.colors.colError.r,
                                                Appearance.colors.colError.g,
                                                Appearance.colors.colError.b, 0.18)
                    onClicked: providerCardRoot.uninstallProvider()
                }

                RippleButton {
                    visible: provider.kind === "external" && !providerCardRoot.installed
                    buttonText: Translation.tr("Install %1").arg(provider.displayName)
                    colBackground: provider.accentColor
                    colBackgroundHover: provider.accentColor
                    onClicked: providerCardRoot.installProvider()
                }
            }
        }
    }
}
```

- [ ] **Step 3: Add a stub `ThemeTileStrip` component**

Below `ProviderCard`, add a placeholder `ThemeTileStrip` that just renders the hero asset (full grid lands in Task 9):

```qml
component ThemeTileStrip: Item {
    property var provider
    property bool installed: false
    property string activeTheme: ""
    signal applyTheme(string themeName)

    Layout.fillWidth: true
    Layout.preferredHeight: 80

    StyledText {
        anchors.centerIn: parent
        text: Translation.tr("Theme grid lands in next task")
        color: Appearance.colors.colSubtext
        font.italic: true
    }
}
```

- [ ] **Step 4: Add page-level handlers (stubs filled in Task 10)**

Above `Component.onCompleted: readActiveTheme()`, add:

```qml
function applyTheme(provider, themeName) {
    console.log("applyTheme stub:", provider.providerId, themeName)
}

function installProvider(provider) {
    console.log("installProvider stub:", provider.providerId)
}

function confirmUninstall(provider) {
    console.log("confirmUninstall stub:", provider.providerId)
}
```

- [ ] **Step 5: Restart the shell and verify visually**

Run: `systemctl --user restart ryoku-shell.service`

Then:
1. Open Settings (Mod+,).
2. Navigate to the "Login screen" page.

Expected: the page is **not yet reachable** (Task 11 wires registration). For now, verify QML parses without errors:

```bash
journalctl --user -u ryoku-shell.service -n 50 --no-pager | grep -E "qml: |Error" | head -20
```

Expected: no parse errors mentioning `LoginScreenConfig.qml`.

- [ ] **Step 6: Commit**

```bash
git add shell/modules/settings/LoginScreenConfig.qml
git commit -m "feat(shell/settings/login-screen): banner + provider cards"
```

---

## Task 9: Theme tile grid

**Files:**
- Modify: `shell/modules/settings/LoginScreenConfig.qml`

This replaces the `ThemeTileStrip` stub with the full grid: pre-install previews from bundled assets, post-install live themes scanned from `~/.local/share/qylock/themes/`.

- [ ] **Step 1: Add a Process to list installed qylock themes**

Below `probeQylockProc`, add:

```qml
property var qylockThemes: []

Process {
    id: listQylockThemesProc
    command: ["/usr/bin/bash", "-c",
        "dir=\"$HOME/.local/share/qylock/themes\"; " +
        "[[ -d $dir ]] || exit 0; " +
        "(cd \"$dir\" && for d in */; do echo \"${d%/}\"; done)"
    ]
    stdout: SplitParser {
        property var collected: []
        onRead: data => {
            var line = data.trim()
            if (line.length > 0) collected.push(line)
        }
        onCollectedChanged: { /* unused */ }
    }
    onExited: exitCode => {
        // Read collected list off the parser
        root.qylockThemes = stdout.collected
        stdout.collected = []
    }
}

function refreshQylockThemes() {
    listQylockThemesProc.running = true
}
```

Update `refreshProviderState()` to also call this:

```qml
function refreshProviderState() {
    probeQylockProc.running = true
    refreshQylockThemes()
}
```

- [ ] **Step 2: Replace `ThemeTileStrip` with the full grid**

Replace the stub `component ThemeTileStrip: ...` with:

```qml
component ThemeTileStrip: ColumnLayout {
    id: stripRoot
    property var provider
    property bool installed: false
    property string activeTheme: ""
    signal applyTheme(string themeName)

    Layout.fillWidth: true
    spacing: 8

    // Build the list of theme entries to render.
    property var themeList: {
        if (provider.kind === "builtin") {
            // Built-in: render bundled themes only (no live scan).
            return provider.bundledThemes.map(name => ({
                name: name,
                source: Quickshell.shellPath(provider.bundledAssetDir + "/" + provider.themesAssetDir + "/" + name + ".png")
            }))
        }
        if (!stripRoot.installed) {
            // External pre-install: bundled themes only.
            if (provider.bundledThemes.length === 0) {
                return [{ name: "preview-after-install", source: Quickshell.shellPath("shell/assets/sddm-providers/_placeholder.png") }]
            }
            return provider.bundledThemes.map(name => ({
                name: name,
                source: Quickshell.shellPath(provider.bundledAssetDir + "/" + provider.themesAssetDir + "/" + name + ".png")
            }))
        }
        // External post-install: live themes from disk; preview source
        // resolves bundled or placeholder fallback in the delegate.
        return root.qylockThemes.map(name => ({
            name: name,
            source: ""    // resolved by ThemeTile.previewSource()
        }))
    }

    GridLayout {
        Layout.fillWidth: true
        columns: stripRoot.installed ? 4 : 4
        rowSpacing: 8
        columnSpacing: 8

        Repeater {
            model: stripRoot.themeList
            delegate: ThemeTile {
                provider: stripRoot.provider
                themeName: modelData.name
                presetSource: modelData.source
                isActive: stripRoot.activeTheme === modelData.name
                clickable: stripRoot.provider.kind === "builtin" || stripRoot.installed
                onClicked: stripRoot.applyTheme(themeName)
            }
        }
    }
}

component ThemeTile: Rectangle {
    id: tileRoot
    property var provider
    property string themeName: ""
    property string presetSource: ""
    property bool isActive: false
    property bool clickable: true
    signal clicked()

    Layout.preferredWidth: 200
    Layout.preferredHeight: 112
    radius: Appearance.rounding.small
    color: "transparent"
    clip: true

    border.width: isActive ? 2 : 0
    border.color: provider.kind === "builtin"
                  ? Appearance.colors.colPrimary
                  : provider.accentColor

    function previewSource() {
        if (presetSource) return presetSource
        var live = Quickshell.env("HOME")
                   + "/.local/share/qylock/themes/" + themeName + "/preview.png"
        // We can't easily test file existence from QML; let Image's
        // onStatusChanged fall back if the live preview fails to load.
        return "file://" + live
    }

    Image {
        id: previewImage
        anchors.fill: parent
        source: tileRoot.previewSource()
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true

        onStatusChanged: {
            if (status === Image.Error) {
                // Fallback chain: bundled <provider>/themes/<name>.png,
                // then shared placeholder.
                var bundled = Quickshell.shellPath(
                    tileRoot.provider.bundledAssetDir + "/"
                    + tileRoot.provider.themesAssetDir + "/"
                    + tileRoot.themeName + ".png")
                if (source.toString() !== bundled) {
                    source = bundled
                    return
                }
                source = Quickshell.shellPath("shell/assets/sddm-providers/_placeholder.png")
            }
        }
    }

    // "Active" chip
    Rectangle {
        visible: tileRoot.isActive
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        radius: 999
        color: tileRoot.provider.kind === "builtin"
               ? Appearance.colors.colPrimary
               : tileRoot.provider.accentColor
        implicitWidth: activeChipText.implicitWidth + 14
        implicitHeight: activeChipText.implicitHeight + 4
        StyledText {
            id: activeChipText
            anchors.centerIn: parent
            text: Translation.tr("Active")
            color: "white"
            font.pixelSize: 10
            font.bold: true
        }
    }

    // Theme name overlay (bottom-left) on a gradient strip
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 24
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: "#cc000000" }
        }
        StyledText {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            anchors.bottomMargin: 4
            text: tileRoot.themeName
            color: "white"
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font Mono"
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: tileRoot.clickable
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: tileRoot.clicked()
    }
}
```

- [ ] **Step 3: Restart the shell and verify**

```bash
systemctl --user restart ryoku-shell.service
journalctl --user -u ryoku-shell.service -n 50 --no-pager | grep -E "qml: |Error"
```

Expected: no parse errors. The page is still not reachable yet (Task 11).

- [ ] **Step 4: Run the static test**

Run: `bash tests/login-screen-config.sh`
Expected: `PASS: ...`

- [ ] **Step 5: Commit**

```bash
git add shell/modules/settings/LoginScreenConfig.qml
git commit -m "feat(shell/settings/login-screen): theme tile grid + fallback chain"
```

---

## Task 10: Install/apply/uninstall workflows

**Files:**
- Modify: `shell/modules/settings/LoginScreenConfig.qml`

Wire the Install/Apply/Uninstall buttons to real `Process` invocations. Replace the stub `applyTheme/installProvider/confirmUninstall` from Task 8.

- [ ] **Step 1: Add a single Process per workflow**

Below `listQylockThemesProc`, add:

```qml
property string busyMessage: ""

Process {
    id: applyProc
    property string targetTheme: ""
    onExited: code => {
        if (code === 0) {
            root.refreshProviderState()
            root.readActiveTheme()
            root.toast(Translation.tr("Theme applied. Reboot or run 'systemctl restart sddm'."))
        } else if (code === 126 || code === 127) {
            // user cancelled polkit dialog
        } else {
            root.toast(Translation.tr("Apply failed (exit %1).").arg(code))
        }
        root.busyMessage = ""
    }
}

Process {
    id: installProc
    onExited: code => {
        if (code === 0) {
            root.refreshProviderState()
            root.readActiveTheme()
            root.toast(Translation.tr("qylock installed. Reboot or run 'systemctl restart sddm'."))
        } else if (code === 126 || code === 127) {
            root.toast(Translation.tr("Install cancelled."))
        } else {
            root.toast(Translation.tr("Install failed (exit %1). Run ryoku-install-qylock in a terminal to see output.").arg(code))
        }
        root.busyMessage = ""
    }
}

Process {
    id: uninstallProc
    onExited: code => {
        if (code === 0) {
            root.refreshProviderState()
            root.readActiveTheme()
            root.toast(Translation.tr("qylock removed. ii-pixel is now active. Reboot or run 'systemctl restart sddm'."))
        } else if (code === 126 || code === 127) {
            // user cancelled polkit dialog
        } else {
            root.toast(Translation.tr("Uninstall failed (exit %1).").arg(code))
        }
        root.busyMessage = ""
    }
}
```

- [ ] **Step 2: Replace stub handlers**

Replace the three stub functions from Task 8 with:

```qml
function applyTheme(provider, themeName) {
    if (applyProc.running) return
    applyProc.targetTheme = themeName
    if (provider.kind === "builtin") {
        applyProc.command = ["pkexec", "ryoku-set-sddm-theme", themeName]
    } else {
        applyProc.command = ["pkexec", "ryoku-install-qylock", "--theme", themeName]
    }
    busyMessage = Translation.tr("Applying %1...").arg(themeName)
    applyProc.running = true
}

function installProvider(provider) {
    if (installProc.running) return
    if (provider.providerId !== "qylock") return
    installProc.command = ["pkexec", "ryoku-install-qylock", "--default"]
    busyMessage = Translation.tr("Installing %1...").arg(provider.displayName)
    installProc.running = true
}

function confirmUninstall(provider) {
    if (provider.providerId !== "qylock") return
    uninstallDialog.providerToRemove = provider
    uninstallDialog.open()
}
```

- [ ] **Step 3: Add the confirmation dialog**

Above the closing `}` of `ContentPage`, add:

```qml
Dialog {
    id: uninstallDialog
    property var providerToRemove
    modal: true
    title: providerToRemove ? Translation.tr("Remove %1?").arg(providerToRemove.displayName) : ""
    standardButtons: Dialog.Cancel | Dialog.Ok
    Component.onCompleted: {
        // Rename the OK button to "Remove" and apply danger styling.
        var okBtn = standardButton(Dialog.Ok)
        if (okBtn) {
            okBtn.text = Translation.tr("Remove")
        }
    }

    contentItem: ColumnLayout {
        spacing: 12
        StyledText {
            Layout.maximumWidth: 480
            wrapMode: Text.WordWrap
            text: Translation.tr("This removes the qylock theme bundle and all qylock-installed SDDM themes from your system. Your active greeter will fall back to the built-in ii-pixel theme.")
        }
        StyledText {
            Layout.maximumWidth: 480
            wrapMode: Text.WordWrap
            color: Appearance.colors.colSubtext
            font.pixelSize: 12
            text: Translation.tr("Stock SDDM themes (elarun, maldives, maya) and the built-in ii-pixel theme are not affected. This cannot be undone, but you can re-install qylock at any time from this page.")
        }
    }

    onAccepted: {
        if (uninstallProc.running) return
        uninstallProc.command = ["pkexec", "ryoku-uninstall-qylock"]
        root.busyMessage = Translation.tr("Removing %1...").arg(providerToRemove.displayName)
        uninstallProc.running = true
    }
}
```

- [ ] **Step 4: Add a minimal toast helper**

At the page root level, add:

```qml
property string toastText: ""
Timer {
    id: toastTimer
    interval: 4000
    onTriggered: root.toastText = ""
}
function toast(text) {
    toastText = text
    toastTimer.restart()
}
```

And inside the bottom of the main ColumnLayout, append:

```qml
Rectangle {
    visible: root.toastText.length > 0
    Layout.fillWidth: true
    Layout.preferredHeight: 36
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer1
    StyledText {
        anchors.centerIn: parent
        text: root.toastText
        font.pixelSize: 12
    }
}

Rectangle {
    visible: root.busyMessage.length > 0
    Layout.fillWidth: true
    Layout.preferredHeight: 36
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer1
    StyledText {
        anchors.centerIn: parent
        text: root.busyMessage
        font.italic: true
    }
}
```

- [ ] **Step 5: Restart and verify QML parses**

Run:
```bash
systemctl --user restart ryoku-shell.service
journalctl --user -u ryoku-shell.service -n 50 --no-pager | grep -E "qml: |Error"
```

Expected: no parse errors.

- [ ] **Step 6: Commit**

```bash
git add shell/modules/settings/LoginScreenConfig.qml
git commit -m "feat(shell/settings/login-screen): wire install/apply/uninstall via pkexec"
```

---

## Task 11: Page registration in `settings.qml` + search index

**Files:**
- Modify: `shell/settings.qml`
- Modify: `shell/modules/settings/SettingsOverlay.qml`
- Modify: `shell/modules/settings/LoginScreenConfig.qml`
- Modify: `tests/login-screen-config.sh`

The "About" page is currently the last entry. We insert the new "Login screen" page **before** "About". This shifts the About page's `pageIndex` from 13 to 14 (verify by counting pages : 14 entries before → 15 after, About goes from index 13 to index 14, Login screen takes index 13).

- [ ] **Step 1: Add registration assertions**

Append to `tests/login-screen-config.sh`:

```bash
# ── Page registration ─────────────────────────────────────────────────
assert_grep "LoginScreenConfig\\.qml"            "shell/settings.qml"
# Search index has at least one entry referencing the new keyword
assert_grep "qylock"                             "shell/modules/settings/SettingsOverlay.qml"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/login-screen-config.sh`
Expected: `FAIL: shell/settings.qml: missing pattern /LoginScreenConfig\.qml/`

- [ ] **Step 3: Insert the page in `shell/settings.qml`**

Edit `shell/settings.qml`. Find the closing `}` of the "Compositor" entry (around line 105) and the opening `{` of the "About" entry (line 106). Insert a new entry between them:

```qml
        {
            name: Translation.tr("Login screen"),
            icon: "login",
            essential: false,
            component: "modules/settings/LoginScreenConfig.qml"
        },
        {
            name: Translation.tr("About"),
            // ... existing About entry continues unchanged ...
        }
```

The new entry sits at array index 13. About moves to index 14.

- [ ] **Step 4: Update the page's settingsPageIndex**

In `LoginScreenConfig.qml`, replace `settingsPageIndex: -1` with the literal page index where the entry lives. Count the entries in `pages` array; the new entry should be index 13 (zero-based, with About now at 14).

```qml
settingsPageIndex: 13
settingsPageName: Translation.tr("Login screen")
```

If your insertion landed at a different index (because you inserted somewhere else), use that number.

- [ ] **Step 5: Update `SettingsOverlay.qml`**

Open `shell/modules/settings/SettingsOverlay.qml`. Find every line where `pageIndex` references the About page (search for entries with `Translation.tr("About")` in the `pageName` field, or grep for the highest pageIndex currently in the file). Bump each occurrence's `pageIndex` by one.

For example, if the file has:

```qml
{ pageIndex: 13, pageName: overlayPages[13].name, ... },   // About entries
```

change those to:

```qml
{ pageIndex: 14, pageName: overlayPages[14].name, ... },
```

Then add a new search index entry for the Login screen page. Insert near the bottom of the `settingsSearchIndex` array (above the About entries):

```qml
{ pageIndex: 13, pageName: overlayPages[13].name, section: Translation.tr("Login screen"), label: Translation.tr("SDDM theme"), description: Translation.tr("Greeter theme shown before login"), keywords: ["sddm", "login", "greeter", "theme", "qylock", "lockscreen"] },
```

- [ ] **Step 6: Run the test**

Run: `bash tests/login-screen-config.sh`
Expected: `PASS: ...`

- [ ] **Step 7: Restart shell and reach the page**

Run: `systemctl --user restart ryoku-shell.service`

Open Settings (Mod+,) and verify:
- "Login screen" appears in the sidebar between "Compositor" and "About"
- Clicking it loads the page (banner + ii-pixel card + qylock card render)
- Searching "qylock" in the Settings search bar surfaces the page

If anything is missing, recount the pageIndex shift in `SettingsOverlay.qml` : every search entry must point at the right page after the insertion.

- [ ] **Step 8: Commit**

```bash
git add shell/settings.qml shell/modules/settings/SettingsOverlay.qml shell/modules/settings/LoginScreenConfig.qml tests/login-screen-config.sh
git commit -m "feat(shell/settings): register Login screen page + search index"
```

---

## Task 12: CREDITS.md attribution + final verification

**Files:**
- Modify: `CREDITS.md`
- Modify: `tests/login-screen-config.sh`

- [ ] **Step 1: Add the attribution paragraph**

Open `CREDITS.md` and find the existing `## qylock` section. Append a new paragraph after the existing content:

```markdown

Preview screenshots in `shell/assets/sddm-providers/qylock/themes/` are
derived from qylock's upstream theme directories
(https://github.com/Darkkal44/qylock) and are redistributed under
qylock's GPL-3.0 license. The hero composite at
`shell/assets/sddm-providers/qylock/hero.png` is an original Ryoku
composition assembled from those screenshots.
```

- [ ] **Step 2: Add a credits-attribution test**

Append to `tests/login-screen-config.sh`:

```bash
# ── Credits attribution ───────────────────────────────────────────────
assert_grep "shell/assets/sddm-providers/qylock/themes/" "CREDITS.md"
```

- [ ] **Step 3: Run the test**

Run: `bash tests/login-screen-config.sh`
Expected: `PASS: ...`

- [ ] **Step 4: Manual behavioural QA**

This is the gate before commit. Walk through every workflow:

1. **Active-theme banner.** Open Settings → Login screen. Banner shows the current theme in monospace. Run `cat /etc/sddm.conf.d/*.conf | tail` and confirm the banner matches the alphabetically-last `Current=` line.

2. **ii-pixel apply (built-in).** Click the ii-pixel tile. Polkit dialog appears, authenticate. Toast says "Theme applied...". Run `cat /etc/sddm.conf.d/theme.conf` and confirm `Current=ii-pixel`.

3. **qylock install.** Click "Install qylock" on the qylock card. Polkit dialog appears, authenticate. After completion (1-3 minutes for first install), card flips to post-install state with theme tile grid. Banner now shows `dog-samurai`.

4. **qylock theme apply.** Click a different qylock theme tile. Polkit, authenticate. Banner updates. Active border moves to the new tile.

5. **qylock uninstall.** Click "Uninstall" on the qylock card. Confirmation dialog appears. Click "Remove". Polkit, authenticate. Card returns to pre-install state. Banner says `ii-pixel`. Run:
   ```bash
   ls /usr/share/sddm/themes/
   ls ~/.local/share/qylock 2>/dev/null
   cat /etc/sddm.conf.d/theme.conf 2>/dev/null
   ```
   Expected: only `elarun, maldives, maya, ii-pixel` under `/usr/share/sddm/themes/`. The qylock dir is gone. `theme.conf` either does not exist or contains `Current=ii-pixel`.

6. **Polkit cancel.** Click Install qylock again, but click Cancel on the polkit dialog. Toast says "Install cancelled.", card stays in pre-install state.

7. **Search.** Type "qylock" in the Settings search bar. Verify the Login screen page surfaces in results.

8. **Easy mode.** Toggle easy mode in Settings. Confirm the Login screen entry **does not** appear (it has `essential: false`).

If any step fails, debug and fix. The plan is not done until all eight steps pass on a real machine.

- [ ] **Step 5: Commit**

```bash
git add CREDITS.md tests/login-screen-config.sh
git commit -m "docs(credits): attribute bundled qylock screenshots"
```

- [ ] **Step 6: Final test run**

Run: `bash tests/login-screen-config.sh`
Expected: `PASS: tests/login-screen-config.sh ...`

---

## What this plan does NOT do

- **No new migration.** Existing systems retain their `inir-theme.conf` stale file. The picker's writes to `theme.conf` override it via SDDM's alphabetical merge. Cleanup is a future migration (mentioned in spec's Future Work).

- **No SDDM service restart.** All workflows tell the user to reboot or `systemctl restart sddm` themselves. Restarting SDDM kicks every logged-in user, which is destructive and not the picker's call to make.

- **No automated end-to-end test.** Behavioral verification is the manual QA in Task 12 Step 4. Building an SDDM E2E harness is out of scope.

- **No per-theme settings UI.** D1/D2 from the spec's Future Work are deferred.
