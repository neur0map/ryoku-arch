# SKWD-Style Wallpaper Selector With Ryoku IPC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current simple wallpaper strip with a Ryoku-native SKWD-style wallpaper selector and route shell/wallpaper actions through a stable `ryoku-ipc` facade.

**Architecture:** `bin/ryoku-ipc` becomes the public CLI contract for Quickshell and Hyprland keybinds. Focused `ryoku-wallpaper-*` helpers own listing, cache, Wallhaven search, and apply logic, while Quickshell consumes JSON/JSONL models and renders the SKWD-style selector. The first implementation is Bash plus QML; the command contract is designed so `ryoku-ipc` can later become a compiled binary without changing keybinds or QML call sites.

**Tech Stack:** Bash 5, `jq`, `magick`, `ffmpegthumbnailer`, `curl`, Quickshell QML, QtQuick Shapes/Effects, QtMultimedia, Hyprland layer-shell, `swaybg`, optional `mpvpaper` for video wallpaper apply.

---

## Scope

Implement these features in this plan:

- `ryoku-ipc` Bash dispatcher with stable subcommands for shell popup toggles and wallpaper operations.
- Local wallpaper indexing for image and video files from Ryoku theme/user background directories.
- Thumbnail and color metadata cache under `$RYOKU_STATE_PATH/wallpaper`.
- SKWD-style full-screen selector overlay with skewed cards, animated card transitions, local video preview, search, type filters, color filters, and settings.
- Wallhaven search integration with SFW defaults, optional API key, result preview, download, and apply.
- Static apply through existing `ryoku-theme-bg-set`.
- Video apply through `mpvpaper` when installed, with a clear failure if unavailable.

Do not implement:

- A second shell process.
- Any SKWD binary, FIFO, config root, Matugen pipeline, Ollama tagging pipeline, or `awww`.
- Wallpaper Engine scene support in the first pass. Keep the type model extensible so a later task can add it.

## File Structure

- Create `bin/ryoku-ipc`
  - Public CLI facade for shell and wallpaper commands.
- Create `bin/ryoku-wallpaper-list`
  - Emits local indexed wallpaper rows as JSONL.
- Create `bin/ryoku-wallpaper-cache`
  - Builds thumbnails, dominant-color metadata, and `list.jsonl`.
- Create `bin/ryoku-wallpaper-apply`
  - Applies image/video wallpapers through Ryoku backends.
- Create `bin/ryoku-wallhaven-search`
  - Searches Wallhaven and optionally downloads selected results.
- Modify `bin/ryoku-theme-bg-set`
  - Stop video wallpaper processes before returning to a static image.
- Modify `config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml`
  - Replace path-array state with JSONL-backed model state, filters, settings, and process calls through `ryoku-ipc`.
- Create `config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperSkewCard.qml`
  - A reusable skewed wallpaper card with image/video preview.
- Create `config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperFilterBar.qml`
  - Type, color, sort, search, Wallhaven/local mode, and settings controls.
- Create `config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperSettingsPane.qml`
  - Settings panel for dirs, Wallhaven filters/API key, cache rebuild, and video backend status.
- Modify `config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperPopup.qml`
  - Replace the current bottom strip content with the full-screen SKWD-style overlay while preserving `Popups.wallpaperOpen`.
- Modify `config/quickshell/ryoku/vendor/brain-shell/src/services/qmldir`
  - Register any new QML types only if they live in `services/`; popup-local components do not need this.
- Modify `default/hypr/bindings/utilities.conf`
  - Keep the existing keybind but call `ryoku-ipc shell toggle wallpaper`.
- Modify `install/ryoku-base.packages`
  - Add explicit `curl` if absent; keep `jq`, `imagemagick`, `ffmpegthumbnailer`, and `qt6-multimedia-ffmpeg`.
- Modify `install/ryoku-aur.packages`
  - Add `mpvpaper` only after verifying the Arch/AUR package source in the implementation environment.
- Create `tests/ryoku-ipc.sh`
  - Static and CLI checks for the dispatcher contract.
- Create `tests/ryoku-wallpaper-cache.sh`
  - Fixture-based checks for listing, thumbnails, and color metadata.
- Create `tests/ryoku-wallhaven-search.sh`
  - Mocked/offline checks for Wallhaven URL/query construction and result parsing.
- Create `tests/quickshell-wallpaper-skwd.sh`
  - Static QML checks for the selector, filters, video preview, and `ryoku-ipc` integration.
- Modify `tests/quickshell-wallpaper-switcher.sh`
  - Retain popup wiring checks and adapt them to the full-screen selector.
- Create or update `docs/superpowers/logs/YYYY-MM-DD-skwd-wallpaper-ryoku-ipc.md`
  - Log implementation, verification, live apply, and any package/backend gaps.

---

### Task 1: Lock The `ryoku-ipc` Contract In Tests

**Files:**
- Create: `tests/ryoku-ipc.sh`
- Modify: `tests/quickshell-wallpaper-switcher.sh`

- [ ] **Step 1: Write the failing dispatcher contract test**

Create `tests/ryoku-ipc.sh`:

```bash
#!/bin/bash

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

ipc="bin/ryoku-ipc"

[[ -f $ipc ]] || fail "bin/ryoku-ipc missing"
[[ -x $ipc ]] || fail "bin/ryoku-ipc should be executable"

"$ipc" --help | grep -q "ryoku-ipc shell toggle wallpaper" \
  || fail "help should document shell wallpaper toggle"
"$ipc" --help | grep -q "ryoku-ipc wallpaper list --jsonl" \
  || fail "help should document wallpaper list JSONL"
"$ipc" --help | grep -q "ryoku-ipc wallpaper wallhaven search" \
  || fail "help should document wallhaven search"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/config/current/theme/backgrounds" "$tmpdir/config/backgrounds/test"
printf '%s\n' "test" > "$tmpdir/config/current/theme.name"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" wallpaper settings get --json \
  | jq -e '.wallpaper_dirs | length >= 2' >/dev/null \
  || fail "settings get should emit wallpaper dirs as JSON"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command wallpaper \
  | grep -q 'qs -c ryoku ipc call popups toggleWallpaper' \
  || fail "shell command wallpaper should print the Quickshell IPC command"

pass "ryoku-ipc contract"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/ryoku-ipc.sh
```

Expected: `FAIL: bin/ryoku-ipc missing`.

- [ ] **Step 3: Update existing wallpaper wiring test**

In `tests/quickshell-wallpaper-switcher.sh`, change the binding expectation from direct `qs` to `ryoku-ipc`:

```bash
grep -q 'bindd = SUPER CTRL, SPACE, Theme background menu, exec, ryoku-ipc shell toggle wallpaper' "$bindings" \
  || fail "SUPER+CTRL+SPACE should open the Quickshell wallpaper switcher through ryoku-ipc"
! grep -q 'bindd = SUPER CTRL, SPACE, Theme background menu, exec, qs -c ryoku ipc call popups toggleWallpaper' "$bindings" \
  || fail "SUPER+CTRL+SPACE should no longer call qs directly"
```

- [ ] **Step 4: Run the existing test to verify the binding assertion fails**

Run:

```bash
bash tests/quickshell-wallpaper-switcher.sh
```

Expected: FAIL on the new `ryoku-ipc` binding assertion.

- [ ] **Step 5: Commit the failing tests**

```bash
git add tests/ryoku-ipc.sh tests/quickshell-wallpaper-switcher.sh
git commit -m "test: define ryoku ipc wallpaper contract"
```

---

### Task 2: Implement `bin/ryoku-ipc`

**Files:**
- Create: `bin/ryoku-ipc`
- Modify: `default/hypr/bindings/utilities.conf`

- [ ] **Step 1: Create the Bash dispatcher**

Create `bin/ryoku-ipc`:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

usage() {
  cat <<'EOF'
Usage:
  ryoku-ipc --help
  ryoku-ipc shell command wallpaper
  ryoku-ipc shell command launcher
  ryoku-ipc shell toggle wallpaper
  ryoku-ipc shell toggle launcher
  ryoku-ipc wallpaper settings get --json
  ryoku-ipc wallpaper list --jsonl
  ryoku-ipc wallpaper cache rebuild
  ryoku-ipc wallpaper apply --type image PATH
  ryoku-ipc wallpaper apply --type video PATH
  ryoku-ipc wallpaper wallhaven search --query QUERY --page PAGE --json
  ryoku-ipc wallpaper wallhaven download ID URL
EOF
}

shell_command() {
  local target="${1:-}"

  case "$target" in
    wallpaper)
      printf '%s\n' "qs -c ryoku ipc call popups toggleWallpaper"
      ;;
    launcher)
      printf '%s\n' "qs -c ryoku ipc call popups toggleLauncher"
      ;;
    *)
      echo "ryoku-ipc: unknown shell command target: $target" >&2
      return 2
      ;;
  esac
}

shell_toggle() {
  local target="${1:-}"
  local command

  command="$(shell_command "$target")"
  exec bash -lc "$command"
}

wallpaper_settings_get() {
  local theme_name=""
  local theme_dir=""
  local user_dir=""

  theme_name="$(cat "$RYOKU_CONFIG_PATH/current/theme.name" 2>/dev/null || true)"
  theme_dir="$RYOKU_CONFIG_PATH/current/theme/backgrounds"
  user_dir="$RYOKU_CONFIG_PATH/backgrounds/$theme_name"

  jq -n \
    --arg theme_dir "$theme_dir" \
    --arg user_dir "$user_dir" \
    --arg state_dir "$RYOKU_STATE_PATH/wallpaper" \
    '{
      wallpaper_dirs: [$user_dir, $theme_dir],
      state_dir: $state_dir,
      wallhaven: {
        categories: "111",
        purity: "100",
        sorting: "date_added",
        order: "desc",
        api_key_env: "WALLHAVEN_API_KEY"
      },
      video: {
        backend: "mpvpaper",
        mute: true
      }
    }'
}

wallpaper_dispatch() {
  local action="${1:-}"
  shift || true

  case "$action" in
    settings)
      [[ ${1:-} == "get" && ${2:-} == "--json" ]] || {
        echo "ryoku-ipc: expected wallpaper settings get --json" >&2
        return 2
      }
      wallpaper_settings_get
      ;;
    list)
      [[ ${1:-} == "--jsonl" ]] || {
        echo "ryoku-ipc: expected wallpaper list --jsonl" >&2
        return 2
      }
      exec "$RYOKU_PATH/bin/ryoku-wallpaper-list" --jsonl
      ;;
    cache)
      [[ ${1:-} == "rebuild" ]] || {
        echo "ryoku-ipc: expected wallpaper cache rebuild" >&2
        return 2
      }
      exec "$RYOKU_PATH/bin/ryoku-wallpaper-cache" rebuild
      ;;
    apply)
      exec "$RYOKU_PATH/bin/ryoku-wallpaper-apply" "$@"
      ;;
    wallhaven)
      exec "$RYOKU_PATH/bin/ryoku-wallhaven-search" "$@"
      ;;
    *)
      echo "ryoku-ipc: unknown wallpaper action: $action" >&2
      return 2
      ;;
  esac
}

main() {
  case "${1:-}" in
    --help|-h|"")
      usage
      ;;
    shell)
      shift
      case "${1:-}" in
        command)
          shift
          shell_command "${1:-}"
          ;;
        toggle)
          shift
          shell_toggle "${1:-}"
          ;;
        *)
          echo "ryoku-ipc: unknown shell action: ${1:-}" >&2
          return 2
          ;;
      esac
      ;;
    wallpaper)
      shift
      wallpaper_dispatch "$@"
      ;;
    *)
      echo "ryoku-ipc: unknown namespace: ${1:-}" >&2
      return 2
      ;;
  esac
}

main "$@"
```

- [ ] **Step 2: Make it executable**

Run:

```bash
chmod +x bin/ryoku-ipc
```

- [ ] **Step 3: Update the keybind**

In `default/hypr/bindings/utilities.conf`, replace:

```conf
bindd = SUPER CTRL, SPACE, Theme background menu, exec, qs -c ryoku ipc call popups toggleWallpaper
```

with:

```conf
bindd = SUPER CTRL, SPACE, Theme background menu, exec, ryoku-ipc shell toggle wallpaper
```

- [ ] **Step 4: Run tests**

Run:

```bash
bash tests/ryoku-ipc.sh
bash tests/quickshell-wallpaper-switcher.sh
```

Expected: `tests/ryoku-ipc.sh` passes. `tests/quickshell-wallpaper-switcher.sh` may still fail later QML assertions until the selector is updated.

- [ ] **Step 5: Commit**

```bash
git add bin/ryoku-ipc default/hypr/bindings/utilities.conf tests/ryoku-ipc.sh tests/quickshell-wallpaper-switcher.sh
git commit -m "feat: add ryoku ipc facade"
```

---

### Task 3: Add Wallpaper Cache Helpers

**Files:**
- Create: `tests/ryoku-wallpaper-cache.sh`
- Create: `bin/ryoku-wallpaper-cache`
- Create: `bin/ryoku-wallpaper-list`

- [ ] **Step 1: Write fixture test**

Create `tests/ryoku-wallpaper-cache.sh`:

```bash
#!/bin/bash

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

cache_bin="bin/ryoku-wallpaper-cache"
list_bin="bin/ryoku-wallpaper-list"

[[ -x $cache_bin ]] || fail "ryoku-wallpaper-cache should be executable"
[[ -x $list_bin ]] || fail "ryoku-wallpaper-list should be executable"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/config/current/theme/backgrounds" "$tmpdir/config/backgrounds/test"
printf '%s\n' "test" > "$tmpdir/config/current/theme.name"

magick -size 64x36 xc:'#cc3333' "$tmpdir/config/current/theme/backgrounds/red.png"
magick -size 64x36 xc:'#3366cc' "$tmpdir/config/backgrounds/test/blue.jpg"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$cache_bin" rebuild >/dev/null

[[ -f $tmpdir/state/wallpaper/list.jsonl ]] \
  || fail "cache should write list.jsonl"

line_count=$(wc -l < "$tmpdir/state/wallpaper/list.jsonl")
(( line_count == 2 )) || fail "expected two wallpaper rows, got $line_count"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$list_bin" --jsonl \
  | jq -e 'select(.type == "image" and .hue >= 0 and .thumb != "")' >/dev/null \
  || fail "list should emit image rows with hue and thumbnail"

pass "ryoku wallpaper cache"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/ryoku-wallpaper-cache.sh
```

Expected: `FAIL: ryoku-wallpaper-cache should be executable`.

- [ ] **Step 3: Implement `bin/ryoku-wallpaper-cache`**

Create `bin/ryoku-wallpaper-cache`:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

usage() {
  echo "Usage: ryoku-wallpaper-cache rebuild" >&2
}

json_string() {
  jq -Rn --arg v "$1" '$v'
}

wallpaper_dirs() {
  local theme_name=""

  theme_name="$(cat "$RYOKU_CONFIG_PATH/current/theme.name" 2>/dev/null || true)"
  printf '%s\0' "$RYOKU_CONFIG_PATH/backgrounds/$theme_name"
  printf '%s\0' "$RYOKU_CONFIG_PATH/current/theme/backgrounds"
}

file_type() {
  local path="$1"

  case "${path,,}" in
    *.jpg|*.jpeg|*.png|*.webp|*.gif)
      echo "image"
      ;;
    *.mp4|*.webm|*.mkv|*.mov)
      echo "video"
      ;;
    *)
      echo ""
      ;;
  esac
}

thumb_for() {
  local path="$1"
  local name

  name="$(printf '%s' "$path" | sha256sum | awk '{ print $1 }')"
  printf '%s/thumbs/%s.jpg\n' "$RYOKU_STATE_PATH/wallpaper" "$name"
}

hue_for_thumb() {
  local thumb="$1"
  local color

  color="$(magick "$thumb" -resize 1x1\! -format '%[pixel:p{0,0}]' info: 2>/dev/null || echo "srgb(128,128,128)")"
  python - "$color" <<'PY'
import colorsys
import re
import sys

text = sys.argv[1]
nums = [int(x) for x in re.findall(r"\d+", text)[:3]]
if len(nums) < 3:
  print(99)
  raise SystemExit
r, g, b = [n / 255 for n in nums]
h, s, _ = colorsys.rgb_to_hsv(r, g, b)
print(99 if s < 0.12 else int(h * 12) % 12)
PY
}

build_thumb() {
  local type="$1"
  local path="$2"
  local thumb="$3"

  mkdir -p "$(dirname "$thumb")"
  if [[ $type == "video" ]]; then
    ffmpegthumbnailer -i "$path" -o "$thumb" -s 640 -q 8 >/dev/null 2>&1
  else
    magick "$path" -auto-orient -resize '640x360^' -gravity center -extent 640x360 "$thumb"
  fi
}

rebuild() {
  local list="$RYOKU_STATE_PATH/wallpaper/list.jsonl"
  local tmp="$list.tmp"
  local path type thumb hue mtime name

  mkdir -p "$RYOKU_STATE_PATH/wallpaper/thumbs"
  : > "$tmp"

  while IFS= read -r -d '' path; do
    [[ -f $path ]] || continue
    type="$(file_type "$path")"
    [[ -n $type ]] || continue
    thumb="$(thumb_for "$path")"
    if [[ ! -f $thumb || $path -nt $thumb ]]; then
      build_thumb "$type" "$path" "$thumb"
    fi
    hue="$(hue_for_thumb "$thumb")"
    mtime="$(stat -c '%Y' "$path" 2>/dev/null || echo 0)"
    name="$(basename "$path")"
    jq -cn \
      --arg type "$type" \
      --arg path "$path" \
      --arg thumb "$thumb" \
      --arg name "$name" \
      --argjson hue "$hue" \
      --argjson mtime "$mtime" \
      '{source:"local", type:$type, path:$path, thumb:$thumb, name:$name, hue:$hue, mtime:$mtime}' \
      >> "$tmp"
  done < <(
    while IFS= read -r -d '' dir; do
      find -L "$dir" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) \
        -print0 2>/dev/null
    done < <(wallpaper_dirs)
  )

  sort -u "$tmp" > "$list"
  rm -f "$tmp"
  echo "rebuilt"
}

case "${1:-}" in
  rebuild)
    rebuild
    ;;
  *)
    usage
    exit 2
    ;;
esac
```

- [ ] **Step 4: Implement `bin/ryoku-wallpaper-list`**

Create `bin/ryoku-wallpaper-list`:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

list="$RYOKU_STATE_PATH/wallpaper/list.jsonl"

if [[ ${1:-} != "--jsonl" ]]; then
  echo "Usage: ryoku-wallpaper-list --jsonl" >&2
  exit 2
fi

if [[ ! -f $list ]]; then
  "$RYOKU_PATH/bin/ryoku-wallpaper-cache" rebuild >/dev/null
fi

cat "$list"
```

- [ ] **Step 5: Make helpers executable**

Run:

```bash
chmod +x bin/ryoku-wallpaper-cache bin/ryoku-wallpaper-list
```

- [ ] **Step 6: Run test**

Run:

```bash
bash tests/ryoku-wallpaper-cache.sh
```

Expected: `OK: ryoku wallpaper cache`.

- [ ] **Step 7: Commit**

```bash
git add bin/ryoku-wallpaper-cache bin/ryoku-wallpaper-list tests/ryoku-wallpaper-cache.sh
git commit -m "feat: add ryoku wallpaper cache"
```

---

### Task 4: Add Wallpaper Apply Helper

**Files:**
- Create: `bin/ryoku-wallpaper-apply`
- Modify: `bin/ryoku-theme-bg-set`
- Modify: `tests/ryoku-ipc.sh`

- [ ] **Step 1: Extend IPC test for apply routing**

Append to `tests/ryoku-ipc.sh` before `pass`:

```bash
grep -q 'ryoku-wallpaper-apply' "$ipc" \
  || fail "ryoku-ipc should route wallpaper apply to ryoku-wallpaper-apply"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/ryoku-ipc.sh
```

Expected: FAIL until `bin/ryoku-ipc` routes apply.

- [ ] **Step 3: Implement `bin/ryoku-wallpaper-apply`**

Create `bin/ryoku-wallpaper-apply`:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  ryoku-wallpaper-apply --type image PATH
  ryoku-wallpaper-apply --type video PATH
EOF
}

json_error() {
  jq -cn --arg error "$1" '{ok:false,error:$error}'
}

json_ok() {
  jq -cn --arg type "$1" --arg path "$2" '{ok:true,type:$type,path:$path}'
}

apply_image() {
  local path="$1"

  [[ -f $path ]] || {
    json_error "image file not found"
    return 1
  }

  pkill -x mpvpaper 2>/dev/null || true
  "$RYOKU_PATH/bin/ryoku-theme-bg-set" "$path" >/dev/null
  json_ok "image" "$path"
}

apply_video() {
  local path="$1"
  local poster="$RYOKU_STATE_PATH/wallpaper/current-video-poster.jpg"

  [[ -f $path ]] || {
    json_error "video file not found"
    return 1
  }

  command -v mpvpaper >/dev/null || {
    json_error "mpvpaper is required for video wallpapers"
    return 3
  }

  mkdir -p "$(dirname "$poster")"
  ffmpegthumbnailer -i "$path" -o "$poster" -s 1280 -q 9 >/dev/null 2>&1 || true
  if [[ -f $poster ]]; then
    ln -nsf "$poster" "$RYOKU_CONFIG_PATH/current/background"
  fi

  pkill -x swaybg 2>/dev/null || true
  pkill -x mpvpaper 2>/dev/null || true
  setsid uwsm-app -- mpvpaper -o "loop --mute=yes" "*" "$path" >/dev/null 2>&1 &
  json_ok "video" "$path"
}

type=""
path=""

while (($#)); do
  case "$1" in
    --type)
      type="${2:-}"
      shift 2
      ;;
    *)
      path="$1"
      shift
      ;;
  esac
done

case "$type" in
  image)
    apply_image "$path"
    ;;
  video)
    apply_video "$path"
    ;;
  *)
    usage
    exit 2
    ;;
esac
```

- [ ] **Step 4: Make helper executable**

Run:

```bash
chmod +x bin/ryoku-wallpaper-apply
```

- [ ] **Step 5: Modify static background setter to stop video backends**

In `bin/ryoku-theme-bg-set`, before killing/restarting `swaybg`, add:

```bash
pkill -x mpvpaper 2>/dev/null || true
```

- [ ] **Step 6: Run tests**

Run:

```bash
bash tests/ryoku-ipc.sh
```

Expected: `OK: ryoku-ipc contract`.

- [ ] **Step 7: Commit**

```bash
git add bin/ryoku-wallpaper-apply bin/ryoku-theme-bg-set tests/ryoku-ipc.sh
git commit -m "feat: add ryoku wallpaper apply helper"
```

---

### Task 5: Add Wallhaven Search Helper

**Files:**
- Create: `tests/ryoku-wallhaven-search.sh`
- Create: `bin/ryoku-wallhaven-search`

- [ ] **Step 1: Write mocked Wallhaven test**

Create `tests/ryoku-wallhaven-search.sh`:

```bash
#!/bin/bash

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

script="bin/ryoku-wallhaven-search"
[[ -x $script ]] || fail "ryoku-wallhaven-search should be executable"

url=$("$script" search --query "samurai city" --page 2 --print-url)
case "$url" in
  *"https://wallhaven.cc/api/v1/search"*q=samurai%20city*page=2*purity=100*categories=111*) ;;
  *) fail "unexpected Wallhaven URL: $url" ;;
esac

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/response.json" <<'JSON'
{
  "data": [
    {
      "id": "abc123",
      "url": "https://wallhaven.cc/w/abc123",
      "path": "https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg",
      "file_type": "image/jpeg",
      "resolution": "1920x1080",
      "colors": ["#cc3333", "#333333"]
    }
  ],
  "meta": {"current_page": 1, "last_page": 1}
}
JSON

"$script" parse "$tmpdir/response.json" \
  | jq -e 'select(.source == "wallhaven" and .id == "abc123" and .type == "image")' >/dev/null \
  || fail "parse should emit normalized wallhaven rows"

pass "ryoku wallhaven search"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/ryoku-wallhaven-search.sh
```

Expected: `FAIL: ryoku-wallhaven-search should be executable`.

- [ ] **Step 3: Implement `bin/ryoku-wallhaven-search`**

Create `bin/ryoku-wallhaven-search`:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

urlencode() {
  jq -rn --arg v "$1" '$v|@uri'
}

search_url() {
  local query=""
  local page="1"
  local categories="111"
  local purity="100"
  local sorting="date_added"
  local order="desc"
  local api_key="${WALLHAVEN_API_KEY:-}"

  while (($#)); do
    case "$1" in
      --query) query="${2:-}"; shift 2 ;;
      --page) page="${2:-1}"; shift 2 ;;
      --categories) categories="${2:-111}"; shift 2 ;;
      --purity) purity="${2:-100}"; shift 2 ;;
      --sorting) sorting="${2:-date_added}"; shift 2 ;;
      --order) order="${2:-desc}"; shift 2 ;;
      *) shift ;;
    esac
  done

  printf 'https://wallhaven.cc/api/v1/search?q=%s&page=%s&categories=%s&purity=%s&sorting=%s&order=%s' \
    "$(urlencode "$query")" "$page" "$categories" "$purity" "$sorting" "$order"
  if [[ -n $api_key ]]; then
    printf '&apikey=%s' "$(urlencode "$api_key")"
  fi
  printf '\n'
}

parse_response() {
  local file="$1"

  jq -c '
    .data[] |
    {
      source: "wallhaven",
      type: "image",
      id: .id,
      name: ("wallhaven-" + .id),
      path: .path,
      thumb: .path,
      wallhaven_url: .url,
      resolution: .resolution,
      colors: .colors,
      hue: 99,
      mtime: 0
    }
  ' "$file"
}

download_wallpaper() {
  local id="$1"
  local url="$2"
  local theme_name=""
  local target_dir=""
  local ext="jpg"

  theme_name="$(cat "$RYOKU_CONFIG_PATH/current/theme.name" 2>/dev/null || true)"
  target_dir="$RYOKU_CONFIG_PATH/backgrounds/$theme_name"
  mkdir -p "$target_dir"

  case "$url" in
    *.png) ext="png" ;;
    *.webp) ext="webp" ;;
    *.jpg|*.jpeg) ext="jpg" ;;
  esac

  curl -fL --retry 2 --connect-timeout 10 -o "$target_dir/wallhaven-$id.$ext" "$url"
  printf '%s\n' "$target_dir/wallhaven-$id.$ext"
}

case "${1:-}" in
  search)
    shift
    if [[ ${*: -1} == "--print-url" ]]; then
      set -- "${@:1:$(($# - 1))}"
      search_url "$@"
    else
      url="$(search_url "$@")"
      tmp="$(mktemp)"
      trap 'rm -f "$tmp"' EXIT
      curl -fsSL "$url" -o "$tmp"
      parse_response "$tmp"
    fi
    ;;
  parse)
    parse_response "${2:-}"
    ;;
  download)
    download_wallpaper "${2:-}" "${3:-}"
    ;;
  *)
    echo "Usage: ryoku-wallhaven-search search|parse|download ..." >&2
    exit 2
    ;;
esac
```

- [ ] **Step 4: Make helper executable**

Run:

```bash
chmod +x bin/ryoku-wallhaven-search
```

- [ ] **Step 5: Run test**

Run:

```bash
bash tests/ryoku-wallhaven-search.sh
```

Expected: `OK: ryoku wallhaven search`.

- [ ] **Step 6: Commit**

```bash
git add bin/ryoku-wallhaven-search tests/ryoku-wallhaven-search.sh
git commit -m "feat: add wallhaven wallpaper search helper"
```

---

### Task 6: Remodel WallpaperService Around JSONL Models

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml`
- Modify: `tests/quickshell-wallpaper-skwd.sh`

- [ ] **Step 1: Write static QML service test**

Create `tests/quickshell-wallpaper-skwd.sh`:

```bash
#!/bin/bash

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

service="config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml"
popup="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperPopup.qml"
card="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperSkewCard.qml"
filter="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperFilterBar.qml"
settings="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperSettingsPane.qml"

for path in "$service" "$popup" "$card" "$filter" "$settings"; do
  [[ -f $path ]] || fail "$path missing"
done

grep -q 'property var wallpaperModel: ListModel' "$service" \
  || fail "WallpaperService should expose wallpaperModel"
grep -q 'property var filteredModel: ListModel' "$service" \
  || fail "WallpaperService should expose filteredModel"
grep -q 'ryoku-ipc' "$service" \
  || fail "WallpaperService should call ryoku-ipc"
grep -q 'wallpaper list --jsonl' "$service" \
  || fail "WallpaperService should load JSONL wallpaper list"
grep -q 'wallpaper wallhaven search' "$service" \
  || fail "WallpaperService should support wallhaven search"
grep -q 'selectedTypeFilter' "$service" \
  || fail "WallpaperService should filter by type"
grep -q 'selectedColorFilter' "$service" \
  || fail "WallpaperService should filter by color"

pass "quickshell skwd wallpaper wiring"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/quickshell-wallpaper-skwd.sh
```

Expected: FAIL because new QML components are missing.

- [ ] **Step 3: Replace WallpaperService state**

In `WallpaperService.qml`, keep `currentWall`, `previewWall`, `applying`, and `wallpaperApplied`, but replace `wallpapers: []` with:

```qml
property var wallpaperModel: ListModel {}
property var filteredModel: ListModel {}

property string selectedSourceFilter: "local"
property string selectedTypeFilter: ""
property int selectedColorFilter: -1
property string searchQuery: ""
property string statusText: ""
property bool cacheLoading: false
property bool wallhavenLoading: false
```

- [ ] **Step 4: Add JSONL loading process**

Add:

```qml
function refresh() {
    if (listProc.running) return
    wallpaperModel.clear()
    statusText = ""
    listProc.command = [
        Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
        "wallpaper", "list", "--jsonl"
    ]
    listProc.running = true
}

property var listProc: Process {
    stdout: SplitParser {
        onRead: function(line) {
            var t = line.trim()
            if (t === "") return
            try {
                var obj = JSON.parse(t)
                root.wallpaperModel.append(obj)
            } catch(e) {
                root.statusText = "Could not parse wallpaper cache"
            }
        }
    }
    onExited: function() {
        root.updateFilteredModel()
    }
}
```

- [ ] **Step 5: Add filter function**

Add:

```qml
function updateFilteredModel() {
    var rows = []
    var q = searchQuery.toLowerCase()
    for (var i = 0; i < wallpaperModel.count; i++) {
        var item = wallpaperModel.get(i)
        if (selectedSourceFilter !== "" && item.source !== selectedSourceFilter) continue
        if (selectedTypeFilter !== "" && item.type !== selectedTypeFilter) continue
        if (selectedColorFilter >= 0 && item.hue !== selectedColorFilter) continue
        if (q !== "" && item.name.toLowerCase().indexOf(q) === -1) continue
        rows.push(item)
    }
    rows.sort(function(a, b) {
        var ah = a.hue === 99 ? 100 : a.hue
        var bh = b.hue === 99 ? 100 : b.hue
        if (ah !== bh) return ah - bh
        return b.mtime - a.mtime
    })
    filteredModel.clear()
    for (var j = 0; j < rows.length; j++) filteredModel.append(rows[j])
}

onSelectedSourceFilterChanged: updateFilteredModel()
onSelectedTypeFilterChanged: updateFilteredModel()
onSelectedColorFilterChanged: updateFilteredModel()
onSearchQueryChanged: updateFilteredModel()
```

- [ ] **Step 6: Add Wallhaven process and apply dispatch**

Add:

```qml
function searchWallhaven(query, page) {
    if (wallhavenProc.running) return
    wallhavenLoading = true
    wallhavenProc.command = [
        Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
        "wallpaper", "wallhaven", "search",
        "--query", query,
        "--page", String(page || 1),
        "--json"
    ]
    wallhavenProc.running = true
}

property var wallhavenProc: Process {
    stdout: SplitParser {
        onRead: function(line) {
            var t = line.trim()
            if (t === "") return
            try {
                var obj = JSON.parse(t)
                root.wallpaperModel.append(obj)
            } catch(e) {
                root.statusText = "Could not parse Wallhaven result"
            }
        }
    }
    onExited: function() {
        root.wallhavenLoading = false
        root.updateFilteredModel()
    }
}

function applyItem(item) {
    if (root.applying || !item) return
    root.applying = true
    root.currentWall = item.path
    applyProc.command = [
        Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
        "wallpaper", "apply",
        "--type", item.type === "video" ? "video" : "image",
        item.path
    ]
    applyProc.running = true
}
```

- [ ] **Step 7: Run test**

Run:

```bash
bash tests/quickshell-wallpaper-skwd.sh
```

Expected: still fails because QML card/filter/settings components are not created. The service assertions should pass.

- [ ] **Step 8: Commit service changes**

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml tests/quickshell-wallpaper-skwd.sh
git commit -m "feat: model wallpapers through ryoku ipc"
```

---

### Task 7: Build SKWD-Style QML Components

**Files:**
- Create: `config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperSkewCard.qml`
- Create: `config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperFilterBar.qml`
- Create: `config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperSettingsPane.qml`

- [ ] **Step 1: Create skew card component**

Create `WallpaperSkewCard.qml` with these structural requirements:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import QtMultimedia
import "../"

Item {
    id: root

    required property var itemData
    property bool selected: false
    property int skewOffset: 28
    signal activated()

    width: selected ? 360 : 118
    height: 300
    clip: false

    Behavior on width { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }

    Item {
        id: cardContent
        anchors.fill: parent
        visible: false

        Image {
            anchors.fill: parent
            source: "file://" + (root.itemData.thumb || root.itemData.path)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: root.itemData.type !== "video" || !root.selected
        }

        MediaPlayer {
            id: player
            source: root.selected && root.itemData.type === "video" ? "file://" + root.itemData.path : ""
            videoOutput: videoOutput
            loops: MediaPlayer.Infinite
            muted: true
            autoPlay: root.selected && root.itemData.type === "video"
        }

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            visible: root.itemData.type === "video" && root.selected
        }
    }

    Shape {
        id: maskShape
        anchors.fill: parent
        visible: false
        layer.enabled: true
        ShapePath {
            fillColor: "white"
            strokeColor: "transparent"
            startX: root.skewOffset
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width - root.skewOffset; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: root.skewOffset; y: 0 }
        }
    }

    MultiEffect {
        source: cardContent
        anchors.fill: parent
        maskEnabled: true
        maskSource: maskShape
        maskThresholdMin: 0.3
        maskSpreadAtMin: 0.3
    }

    Shape {
        anchors.fill: parent
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.selected ? Theme.active : Qt.rgba(1, 1, 1, 0.18)
            strokeWidth: root.selected ? 3 : 1
            startX: root.skewOffset
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width - root.skewOffset; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: root.skewOffset; y: 0 }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.skewOffset + 10
        anchors.bottomMargin: 10
        width: typeText.implicitWidth + 16
        height: 20
        radius: 4
        color: Qt.rgba(0, 0, 0, 0.62)
        Text {
            id: typeText
            anchors.centerIn: parent
            text: root.itemData.type === "video" ? "VID" : (root.itemData.source === "wallhaven" ? "WEB" : "IMG")
            color: Theme.active
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }

    TapHandler {
        onTapped: root.activated()
    }
}
```

- [ ] **Step 2: Create filter bar component**

Create `WallpaperFilterBar.qml` with:

```qml
import QtQuick
import QtQuick.Controls
import "../"
import "../services"

Rectangle {
    id: root

    signal settingsRequested()
    signal rebuildRequested()

    height: 46
    radius: 23
    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.86)

    Row {
        anchors.centerIn: parent
        spacing: 10

        Repeater {
            model: [
                {label: "All", type: ""},
                {label: "Images", type: "image"},
                {label: "Videos", type: "video"}
            ]
            Rectangle {
                width: label.implicitWidth + 18
                height: 28
                radius: 6
                color: WallpaperService.selectedTypeFilter === modelData.type ? Theme.active : Qt.rgba(1, 1, 1, 0.08)
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.label
                    color: WallpaperService.selectedTypeFilter === modelData.type ? Theme.background : Theme.text
                    font.pixelSize: 12
                }
                TapHandler {
                    onTapped: WallpaperService.selectedTypeFilter = modelData.type
                }
            }
        }

        TextInput {
            id: searchInput
            width: 260
            height: 30
            color: Theme.text
            font.pixelSize: 13
            verticalAlignment: TextInput.AlignVCenter
            onTextChanged: WallpaperService.searchQuery = text
            Keys.onReturnPressed: WallpaperService.searchWallhaven(text, 1)
            Keys.onEscapePressed: Popups.wallpaperOpen = false
        }

        Repeater {
            model: 13
            Rectangle {
                width: 22
                height: 22
                radius: 11
                color: index === 12 ? "#777777" : Qt.hsla(index / 12.0, 0.72, 0.52, 1.0)
                border.width: WallpaperService.selectedColorFilter === (index === 12 ? 99 : index) ? 3 : 1
                border.color: Theme.text
                TapHandler {
                    onTapped: {
                        var value = index === 12 ? 99 : index
                        WallpaperService.selectedColorFilter =
                            WallpaperService.selectedColorFilter === value ? -1 : value
                    }
                }
            }
        }

        Button {
            text: "Settings"
            onClicked: root.settingsRequested()
        }
    }
}
```

- [ ] **Step 3: Create settings pane component**

Create `WallpaperSettingsPane.qml` with:

```qml
import QtQuick
import QtQuick.Controls
import "../"
import "../services"

Rectangle {
    id: root

    property bool open: false
    signal closeRequested()

    width: open ? 340 : 0
    opacity: open ? 1 : 0
    radius: 8
    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.94)
    clip: true

    Behavior on width { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration } }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            text: "Wallpaper Settings"
            color: Theme.text
            font.pixelSize: 16
            font.weight: Font.Bold
        }

        Text {
            text: "Video backend: mpvpaper"
            color: Theme.text
            font.pixelSize: 12
        }

        Button {
            text: "Rebuild Cache"
            onClicked: WallpaperService.rebuildCache()
        }

        Button {
            text: "Close"
            onClicked: root.closeRequested()
        }
    }
}
```

- [ ] **Step 4: Run static test**

Run:

```bash
bash tests/quickshell-wallpaper-skwd.sh
```

Expected: component existence assertions pass. Popup assertions may still fail until Task 8.

- [ ] **Step 5: Commit**

```bash
git add \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperSkewCard.qml \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperFilterBar.qml \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperSettingsPane.qml \
  tests/quickshell-wallpaper-skwd.sh
git commit -m "feat: add skwd wallpaper selector components"
```

---

### Task 8: Replace WallpaperPopup Content With Full-Screen Selector

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperPopup.qml`
- Modify: `tests/quickshell-wallpaper-skwd.sh`
- Modify: `tests/quickshell-wallpaper-switcher.sh`

- [ ] **Step 1: Extend QML tests**

Append to `tests/quickshell-wallpaper-skwd.sh` before `pass`:

```bash
grep -q 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive' "$popup" \
  || fail "WallpaperPopup should own keyboard focus"
grep -q 'anchors.fill: parent' "$popup" \
  || fail "WallpaperPopup should use a fullscreen overlay content area"
grep -q 'WallpaperSkewCard' "$popup" \
  || fail "WallpaperPopup should render skew cards"
grep -q 'WallpaperFilterBar' "$popup" \
  || fail "WallpaperPopup should render filter bar"
grep -q 'WallpaperSettingsPane' "$popup" \
  || fail "WallpaperPopup should render settings pane"
grep -q 'WallpaperService.filteredModel' "$popup" \
  || fail "WallpaperPopup should bind to filtered model"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/quickshell-wallpaper-skwd.sh
```

Expected: FAIL on missing popup bindings.

- [ ] **Step 3: Change popup window geometry**

In `WallpaperPopup.qml`, change from bottom-panel `implicitHeight` and mask to a full-screen overlay:

```qml
anchors {
    top: true
    left: true
    right: true
    bottom: true
}

visible: Popups.wallpaperOpen || windowVisible
color: "transparent"
WlrLayershell.layer: WlrLayer.Overlay
WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
```

Remove the bottom-only `mask: Region { item: maskProxy }`.

- [ ] **Step 4: Replace content body**

Replace the current `sizer` strip content with:

```qml
Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, Popups.wallpaperOpen ? 0.50 : 0.0)
    Behavior on color { ColorAnimation { duration: 220 } }

    MouseArea {
        anchors.fill: parent
        onClicked: Popups.wallpaperOpen = false
    }
}

Item {
    id: selector
    anchors.centerIn: parent
    width: Math.min(parent.width - 80, 1540)
    height: Math.min(parent.height - 120, 620)
    opacity: Popups.wallpaperOpen ? 1 : 0
    scale: Popups.wallpaperOpen ? 1 : 0.96

    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    MouseArea {
        anchors.fill: parent
        onClicked: mouse.accepted = true
    }

    WallpaperFilterBar {
        id: filterBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        onSettingsRequested: settingsPane.open = !settingsPane.open
        onRebuildRequested: WallpaperService.rebuildCache()
    }

    ListView {
        id: cardList
        anchors.left: parent.left
        anchors.right: settingsPane.open ? settingsPane.left : parent.right
        anchors.top: filterBar.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 34
        orientation: ListView.Horizontal
        spacing: -22
        clip: true
        model: WallpaperService.filteredModel
        currentIndex: 0

        delegate: WallpaperSkewCard {
            required property var model
            required property int index
            itemData: model
            selected: ListView.isCurrentItem
            onActivated: {
                if (cardList.currentIndex === index) {
                    WallpaperService.applyItem(model)
                    Popups.wallpaperOpen = false
                } else {
                    cardList.currentIndex = index
                    cardList.positionViewAtIndex(index, ListView.Center)
                }
            }
        }
    }

    WallpaperSettingsPane {
        id: settingsPane
        anchors.right: parent.right
        anchors.top: filterBar.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 34
        onCloseRequested: open = false
    }
}
```

- [ ] **Step 5: Preserve open lifecycle**

Keep the existing `Connections { target: Popups ... onWallpaperOpenChanged ... }`, but on open call:

```qml
WallpaperService.refresh()
```

and on close keep `closeTimer.restart()` so the fade-out can finish.

- [ ] **Step 6: Run tests**

Run:

```bash
bash tests/quickshell-wallpaper-skwd.sh
bash tests/quickshell-wallpaper-switcher.sh
```

Expected: both pass after adapting the old bottom-panel assertions in `tests/quickshell-wallpaper-switcher.sh` to the full-screen SKWD overlay.

- [ ] **Step 7: Commit**

```bash
git add \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperPopup.qml \
  tests/quickshell-wallpaper-skwd.sh \
  tests/quickshell-wallpaper-switcher.sh
git commit -m "feat: replace wallpaper strip with skwd selector"
```

---

### Task 9: Package And Dependency Integration

**Files:**
- Modify: `install/ryoku-base.packages`
- Modify: `install/ryoku-aur.packages`
- Modify: `tests/quickshell-wallpaper-skwd.sh`

- [ ] **Step 1: Extend package test assertions**

Append to `tests/quickshell-wallpaper-skwd.sh`:

```bash
base_packages="install/ryoku-base.packages"
aur_packages="install/ryoku-aur.packages"

grep -q '^curl$' "$base_packages" \
  || fail "curl should be explicitly installed for Wallhaven integration"
grep -q '^jq$' "$base_packages" \
  || fail "jq should be installed for wallpaper JSON helpers"
grep -q '^imagemagick$' "$base_packages" \
  || fail "imagemagick should be installed for image thumbnails"
grep -q '^ffmpegthumbnailer$' "$base_packages" \
  || fail "ffmpegthumbnailer should be installed for video thumbnails"
grep -q '^qt6-multimedia-ffmpeg$' "$base_packages" \
  || fail "qt6 multimedia ffmpeg backend should be installed for QML video preview"
```

Do not assert `mpvpaper` until the implementation verifies whether it is available from the configured Arch/AUR sources.

- [ ] **Step 2: Run package test to verify curl fails if absent**

Run:

```bash
bash tests/quickshell-wallpaper-skwd.sh
```

Expected: FAIL on `curl` if it is not already listed.

- [ ] **Step 3: Add explicit package entries**

In `install/ryoku-base.packages`, add `curl` inside the CLI tooling section alphabetically.

If `pacman -Ss '^mpvpaper$'` or the AUR lookup confirms an installable package source, add `mpvpaper` in the appropriate package manifest and update this plan log with the source used. If no Arch/AUR source is available, leave package manifests unchanged and keep `ryoku-wallpaper-apply --type video` returning the explicit `mpvpaper is required for video wallpapers` JSON error.

Implementation note: `yay -Ss mpvpaper` confirmed `aur/mpvpaper 1.8-1`, so `mpvpaper` is listed in `install/ryoku-aur.packages`.

- [ ] **Step 4: Run tests**

Run:

```bash
bash tests/quickshell-wallpaper-skwd.sh
```

Expected: package assertions pass.

- [ ] **Step 5: Commit**

```bash
git add install/ryoku-base.packages install/ryoku-aur.packages tests/quickshell-wallpaper-skwd.sh
git commit -m "pkg: add wallpaper selector runtime dependencies"
```

---

### Task 10: Live Apply And Runtime Verification

**Files:**
- Modify: `docs/superpowers/logs/2026-04-29-skwd-wallpaper-ryoku-ipc.md`

- [ ] **Step 1: Run full focused test set**

Run:

```bash
bash tests/ryoku-ipc.sh
bash tests/ryoku-wallpaper-cache.sh
bash tests/ryoku-wallhaven-search.sh
bash tests/quickshell-wallpaper-skwd.sh
bash tests/quickshell-wallpaper-switcher.sh
bash tests/quickshell-app-launcher.sh
bash tests/dashboard-top-controls.sh
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 2: Refresh live Quickshell**

Run:

```bash
env RYOKU_PATH=/home/omi/prowl/ryoku-arch bin/ryoku-refresh-quickshell
bin/ryoku-restart-shell
```

Expected: Quickshell restarts with `quickshell -c ryoku`.

- [ ] **Step 3: Apply live Hyprland binding**

Run:

```bash
install -m 0644 default/hypr/bindings/utilities.conf /home/omi/.local/share/ryoku/default/hypr/bindings/utilities.conf
hyprctl reload
```

Expected: `hyprctl reload` prints `ok`.

- [ ] **Step 4: Open selector through `ryoku-ipc`**

Run:

```bash
ryoku-ipc shell toggle wallpaper
hyprctl layers -j
qs -c ryoku log --tail 160
qs -c ryoku ipc call popups closeAll
```

Expected:
- `hyprctl layers -j` shows Quickshell overlay layers while the selector is open.
- Quickshell log has no new QML errors from the wallpaper selector.
- Existing unrelated warnings can be recorded in the log.

- [ ] **Step 5: Verify local cache with real wallpaper dirs**

Run:

```bash
ryoku-ipc wallpaper cache rebuild
ryoku-ipc wallpaper list --jsonl | head -5 | jq -c .
```

Expected: JSON rows for local wallpapers with `source`, `type`, `path`, `thumb`, `name`, `hue`, and `mtime`.

- [ ] **Step 6: Log results**

Create or update `docs/superpowers/logs/2026-04-29-skwd-wallpaper-ryoku-ipc.md`:

```markdown
# SKWD Wallpaper Selector And Ryoku IPC Log

Date: 2026-04-29

## Summary

- Added `ryoku-ipc` as the stable shell/wallpaper command facade.
- Replaced direct Quickshell wallpaper keybind calls with `ryoku-ipc shell toggle wallpaper`.
- Added local wallpaper cache, thumbnails, color grouping, Wallhaven search, and image/video apply helpers.
- Replaced the simple wallpaper strip with a SKWD-style selector rendered inside Ryoku Quickshell.

## Verification

- `bash tests/ryoku-ipc.sh`
- `bash tests/ryoku-wallpaper-cache.sh`
- `bash tests/ryoku-wallhaven-search.sh`
- `bash tests/quickshell-wallpaper-skwd.sh`
- `bash tests/quickshell-wallpaper-switcher.sh`
- `bash tests/quickshell-app-launcher.sh`
- `bash tests/dashboard-top-controls.sh`
- `git diff --check`
- `ryoku-ipc shell toggle wallpaper`
- `hyprctl layers -j`
- `qs -c ryoku log --tail 160`

## Notes

- Static wallpaper apply remains routed through `ryoku-theme-bg-set`.
- Video apply requires `mpvpaper`; if not available in the installed package set, the helper returns a JSON error instead of silently failing.
- Wallhaven defaults to SFW search unless `WALLHAVEN_API_KEY` and settings explicitly allow other purity filters.
```

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/logs/2026-04-29-skwd-wallpaper-ryoku-ipc.md
git commit -m "docs: log skwd wallpaper ipc integration"
```

---

## Self-Review

- Spec coverage: The plan covers `ryoku-ipc`, Quickshell keybinds, SKWD-style cards, animated video preview, image/video categorization, primary-color grouping, Wallhaven search, settings, apply paths, live apply, verification, and logging.
- Placeholder scan: The plan does not rely on open-ended implementation instructions. The only conditional item is `mpvpaper` package availability, and the plan defines both acceptable outcomes.
- Type consistency: The command names are consistent across tests, helpers, QML process calls, and Hyprland keybinds: `ryoku-ipc shell toggle wallpaper`, `ryoku-ipc wallpaper list --jsonl`, `ryoku-ipc wallpaper cache rebuild`, `ryoku-ipc wallpaper apply`, and `ryoku-ipc wallpaper wallhaven search`.
