#!/bin/bash
# Static validation for the Settings -> Login screen page and its
# privileged helpers. Pure shell assertions; does not run quickshell,
# does not start SDDM, does not call any helper.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f $ROOT_DIR/$path ]] || fail "missing file: $path"
}

assert_executable() {
  local path="$1"
  [[ -x $ROOT_DIR/$path ]] || fail "not executable: $path"
}

assert_grep() {
  local pattern="$1" file="$2"
  grep -qE "$pattern" "$ROOT_DIR/$file" || fail "$file: missing pattern /$pattern/"
}

assert_grep_abs() {
  local pattern="$1" file="$2"
  [[ -f $file ]] || fail "missing file: $file"
  grep -qE "$pattern" "$file" || fail "$file: missing pattern /$pattern/"
}

assert_no_grep() {
  local pattern="$1" file="$2"
  if grep -qE "$pattern" "$ROOT_DIR/$file"; then
    fail "$file: should not contain pattern /$pattern/"
  fi
}

assert_grep_count() {
  local expected="$1" pattern="$2" file="$3"
  local count
  count="$(grep -cE "$pattern" "$ROOT_DIR/$file" || true)"
  (( count == expected )) \
    || fail "$file: expected $expected matches for /$pattern/, found $count"
}

assert_order() {
  local first_pattern="$1" second_pattern="$2" file="$3"
  local first_line second_line
  first_line="$(grep -nE "$first_pattern" "$ROOT_DIR/$file" | head -n1 | cut -d: -f1 || true)"
  second_line="$(grep -nE "$second_pattern" "$ROOT_DIR/$file" | head -n1 | cut -d: -f1 || true)"
  [[ -n $first_line ]] || fail "$file: missing first ordered pattern /$first_pattern/"
  [[ -n $second_line ]] || fail "$file: missing second ordered pattern /$second_pattern/"
  (( first_line < second_line )) \
    || fail "$file: pattern /$first_pattern/ must appear before /$second_pattern/"
}

assert_png() {
  local path="$1"
  assert_file "$path"
  file -b "$ROOT_DIR/$path" | grep -q "PNG image data" \
    || fail "$path: not a PNG"
}

assert_image() {
  # Accepts PNG or GIF. Use this for theme-preview assets that may be
  # animated (qylock ships GIFs; ii-pixel ships a static PNG).
  local path="$1"
  assert_file "$path"
  file -b "$ROOT_DIR/$path" | grep -qE "PNG image data|GIF image data" \
    || fail "$path: not a PNG or GIF"
}

assert_image_abs() {
  local path="$1"
  [[ -f $path ]] || fail "missing file: $path"
  file -b "$path" | grep -qE "PNG image data|JPEG image data|GIF image data" \
    || fail "$path: not an image"
}

# ---------------------------------------------------------------------
# Assertions (filled in as tasks land code).
# ---------------------------------------------------------------------

# -- ryoku-set-sddm-theme ----------------------------------------------
assert_file       "bin/ryoku-set-sddm-theme"
assert_executable "bin/ryoku-set-sddm-theme"
# Must validate the theme exists under /usr/share/sddm/themes
assert_grep "/usr/share/sddm/themes/" "bin/ryoku-set-sddm-theme"
# Must write to /etc/sddm.conf.d/theme.conf
assert_grep "/etc/sddm\\.conf\\.d/theme\\.conf" "bin/ryoku-set-sddm-theme"
# Must remove stale legacy Ryoku/iNiR Current= drop-ins before writing the
# selected theme. Some SDDM versions effectively keep the first Current=,
# so leaving these files behind can pin ii-pixel over qylock.
assert_grep "/etc/sddm\\.conf\\.d/inir-theme\\.conf" "bin/ryoku-set-sddm-theme"
assert_grep "/etc/sddm\\.conf\\.d/ryoku-shell-theme\\.conf" "bin/ryoku-set-sddm-theme"
# Must NOT call sudo: pkexec already runs it as root
assert_no_grep "^[[:space:]]*sudo " "bin/ryoku-set-sddm-theme"
# Must refuse to run unprivileged
assert_grep "EUID" "bin/ryoku-set-sddm-theme"

# -- ryoku-install-qylock pkexec safety --------------------------------
assert_grep "EUID"        "bin/ryoku-install-qylock"
assert_grep "SUDO_USER"   "bin/ryoku-install-qylock"
assert_grep "PKEXEC_UID"  "bin/ryoku-install-qylock"
assert_file       "bin/ryoku-refresh-qylock-previews"
assert_executable "bin/ryoku-refresh-qylock-previews"
assert_grep "ryoku-refresh-qylock-previews" "bin/ryoku-install-qylock"
assert_grep "refresh_qylock_clone" "bin/ryoku-install-qylock"
assert_grep "pull --ff-only" "bin/ryoku-install-qylock"
assert_grep "refreshing qylock clone after pull failed" "bin/ryoku-install-qylock"
assert_grep "valid_qylock_theme" "bin/ryoku-install-qylock"
assert_grep "Main\\.qml" "bin/ryoku-install-qylock"
assert_grep "preview\\.png" "bin/ryoku-refresh-qylock-previews"
assert_grep "bg\\.mp4" "bin/ryoku-refresh-qylock-previews"
assert_grep "background/A Glow\\.jpg" "bin/ryoku-refresh-qylock-previews"
assert_grep "ter1\\.png" "bin/ryoku-refresh-qylock-previews"
assert_grep "ffmpeg" "bin/ryoku-refresh-qylock-previews"
assert_grep "magick" "bin/ryoku-refresh-qylock-previews"
qylock_preview_migration=$(grep -l "Refresh qylock previews" "$ROOT_DIR"/migrations/*.sh 2>/dev/null | sort -n | tail -n1 || true)
[[ -n $qylock_preview_migration ]] || fail "qylock preview refresh migration should exist"
qylock_preview_migration=${qylock_preview_migration#"$ROOT_DIR/"}
assert_grep "ryoku-refresh-qylock-previews" "$qylock_preview_migration"
assert_no_grep "LoginScreenConfig\\.qml" "$qylock_preview_migration"
assert_grep "read_active_sddm_theme" "bin/ryoku-install-qylock"
assert_grep "RYOKU_SDDM_CONF_DIR:-/etc/sddm\\.conf\\.d" "bin/ryoku-install-qylock"
# Must use the _priv wrapper instead of bare sudo for the cp/tee path
assert_grep "_priv"       "bin/ryoku-install-qylock"
# Must pin RYOKU_PATH from the helper's own install location before
# sourcing runtime-env; pkexec runs with HOME=/root, so runtime-env
# cannot safely infer the user install path from HOME.
assert_grep "script_root="       "bin/ryoku-install-qylock"
assert_grep "export RYOKU_PATH=" "bin/ryoku-install-qylock"
# Must clean stale ii-pixel theme drop-ins before activating qylock.
assert_grep "/etc/sddm\\.conf\\.d/inir-theme\\.conf" "bin/ryoku-install-qylock"
assert_grep "/etc/sddm\\.conf\\.d/ryoku-shell-theme\\.conf" "bin/ryoku-install-qylock"

# -- SDDM refresh must preserve qylock ---------------------------------
assert_file       "bin/ryoku-refresh-sddm"
assert_executable "bin/ryoku-refresh-sddm"
# Refreshing/updating Ryoku's bundled ii-pixel files must not force
# ii-pixel back over a selected qylock theme.
assert_grep "RYOKU_SHELL_SDDM_AUTO_APPLY=\"\\$\\{RYOKU_SHELL_SDDM_AUTO_APPLY:-preserve\\}\"" "bin/ryoku-refresh-sddm"
assert_no_grep "RYOKU_SHELL_SDDM_AUTO_APPLY=yes" "bin/ryoku-refresh-sddm"
assert_grep '\$RYOKU_PATH/shell' "bin/ryoku-refresh-sddm"
assert_no_grep 'SHELL_PATH="\$\{RYOKU_SHELL_PATH:-\$HOME/\.local/share/ryoku-shell\}"' "bin/ryoku-refresh-sddm"
assert_grep "^#!/bin/bash$" "shell/scripts/sddm/install-pixel-sddm.sh"
assert_grep "AUTO_APPLY_MODE=.*preserve" "shell/scripts/sddm/install-pixel-sddm.sh"
assert_grep "for f in /etc/sddm\\.conf\\.d/\\*\\.conf" "shell/scripts/sddm/install-pixel-sddm.sh"
assert_grep "Preserving current SDDM theme" "shell/scripts/sddm/install-pixel-sddm.sh"
assert_grep "SDDM_CONF=\"/etc/sddm\\.conf\\.d/theme\\.conf\"" "shell/scripts/sddm/install-pixel-sddm.sh"
assert_grep "LEGACY_SDDM_CONFS" "shell/scripts/sddm/install-pixel-sddm.sh"
assert_grep "Qt\\.inputMethod\\.hide\\(\\)" "shell/dots/sddm/pixel/Main.qml"
assert_grep "Qt\\.ImhNoAutoUppercase" "shell/dots/sddm/pixel/Main.qml"

# -- ryoku-uninstall-qylock --------------------------------------------
assert_file       "bin/ryoku-uninstall-qylock"
assert_executable "bin/ryoku-uninstall-qylock"
assert_grep "EUID"            "bin/ryoku-uninstall-qylock"
assert_grep "SUDO_USER"       "bin/ryoku-uninstall-qylock"
assert_grep "PKEXEC_UID"      "bin/ryoku-uninstall-qylock"
# Must reference the ii-pixel fallback by name
assert_grep "ii-pixel"        "bin/ryoku-uninstall-qylock"
# Guard list: stock SDDM themes that must never be removed by this helper
assert_grep "elarun"          "bin/ryoku-uninstall-qylock"
assert_grep "maldives"        "bin/ryoku-uninstall-qylock"
assert_grep "maya"            "bin/ryoku-uninstall-qylock"
# Must compute themes by intersection (not blindly delete from /usr/share/sddm/themes)
assert_grep "/usr/share/sddm/themes/" "bin/ryoku-uninstall-qylock"
assert_grep "\\.local/share/qylock"   "bin/ryoku-uninstall-qylock"
# Uninstall must also leave one authoritative Current= rather than
# re-exposing stale legacy drop-ins.
assert_grep "/etc/sddm\\.conf\\.d/inir-theme\\.conf" "bin/ryoku-uninstall-qylock"
assert_grep "/etc/sddm\\.conf\\.d/ryoku-shell-theme\\.conf" "bin/ryoku-uninstall-qylock"

# -- Asset bundles -----------------------------------------------------
assert_png "shell/assets/sddm-providers/_placeholder.png"
assert_png "shell/assets/sddm-providers/ii-pixel/hero.png"
assert_png "shell/assets/sddm-providers/ii-pixel/themes/ii-pixel.png"
assert_png "shell/assets/sddm-providers/qylock/hero.png"
# Per-theme qylock PNGs are validated by the manifest sync check
# (Task 7), once the QML page declares the bundledThemes list.

# -- LoginScreenConfig.qml ---------------------------------------------
assert_file "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "ContentPage"        "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "property var providers" "shell/modules/settings/LoginScreenConfig.qml"
# Both providers are declared
assert_grep "providerId: \"ii-pixel\""  "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "providerId: \"qylock\""    "shell/modules/settings/LoginScreenConfig.qml"
# Active-theme reader exists
assert_grep "function readActiveTheme"  "shell/modules/settings/LoginScreenConfig.qml"
assert_no_grep "systemctl restart sddm" "shell/modules/settings/LoginScreenConfig.qml"
# Elevated helpers must use absolute user-local paths because pkexec
# sanitizes PATH to system directories.
assert_grep "function helperPath" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "RYOKU_PATH" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "pkexec\", helperPath\\(\"ryoku-set-sddm-theme\"\\)" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "pkexec\", helperPath\\(\"ryoku-install-qylock\"\\), \"--theme\"" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "pkexec\", helperPath\\(\"ryoku-install-qylock\"\\), \"--default\"" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "pkexec\", root\\.helperPath\\(\"ryoku-uninstall-qylock\"\\)" "shell/modules/settings/LoginScreenConfig.qml"
# Busy status must be near the top of the page, not below all provider cards.
assert_order "visible: root\\.busyMessage\\.length > 0" "Repeater \\{" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "StyledIndeterminateProgressBar" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "busy: root\\.busyProviderId === modelData\\.providerId" "shell/modules/settings/LoginScreenConfig.qml"
# External polkit agents are normal Wayland windows and can sit behind
# Ryoku's settings layer. The login-screen page must hide that overlay
# before starting pkexec so the auth prompt can always surface.
assert_grep "function yieldSettingsOverlayForPolkit" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "GlobalStates\\.settingsOverlayOpen = false" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep_count 2 "^[[:space:]]*yieldSettingsOverlayForPolkit\\(\\)$" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep_count 1 "^[[:space:]]*root\\.yieldSettingsOverlayForPolkit\\(\\)$" "shell/modules/settings/LoginScreenConfig.qml"
assert_order "yieldSettingsOverlayForPolkit\\(\\)" "applyProc\\.running = true" "shell/modules/settings/LoginScreenConfig.qml"
assert_order "yieldSettingsOverlayForPolkit\\(\\)" "installProc\\.running = true" "shell/modules/settings/LoginScreenConfig.qml"
assert_order "yieldSettingsOverlayForPolkit\\(\\)" "uninstallProc\\.running = true" "shell/modules/settings/LoginScreenConfig.qml"
# If Settings was hidden for the sudo prompt, it must reopen after the
# privileged command exits so users can see the result and continue.
assert_grep "property bool reopenSettingsOverlayAfterPolkit: false" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "reopenSettingsOverlayAfterPolkit = GlobalStates\\.settingsOverlayOpen" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "function restoreSettingsOverlayAfterPolkit" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep "GlobalStates\\.settingsOverlayOpen = true" "shell/modules/settings/LoginScreenConfig.qml"
assert_grep_count 3 "root\\.restoreSettingsOverlayAfterPolkit\\(\\)" "shell/modules/settings/LoginScreenConfig.qml"

# -- bundledThemes manifest sync ---------------------------------------
QML_PATH="shell/modules/settings/LoginScreenConfig.qml"
QML_FILE="$ROOT_DIR/$QML_PATH"

extract_bundled_themes() {
  # Args: provider id
  # Prints one theme name per line (or nothing if empty list).
  local provider="$1"
  awk -v provider="$provider" '
    $0 ~ "providerId: \"" provider "\"" { in_block = 1 }
    in_block && /bundledThemes:/ { in_list = 1; sub(/.*bundledThemes:[[:space:]]*\[/, ""); }
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

declare -A PROVIDER_EXT=( [ii-pixel]=.png [qylock]=.gif )
for provider in ii-pixel qylock; do
  ext="${PROVIDER_EXT[$provider]}"
  while IFS= read -r theme; do
    [[ -z $theme ]] && continue
    asset="shell/assets/sddm-providers/$provider/themes/$theme$ext"
    assert_image "$asset"
  done < <(extract_bundled_themes "$provider")
done

# Installed qylock themes are discovered from the live upstream clone,
# so their previews must also be able to resolve from that clone instead
# of only from Ryoku's bundled preview subset.
assert_grep "function qylockAssetBaseNames" "$QML_PATH"
assert_grep "\\.local/share/qylock/Assets" "$QML_PATH"
assert_no_grep "\"clockwork\"" "$QML_PATH"
assert_grep "Main\\.qml" "$QML_PATH"
assert_grep "previewFallbackTimer" "$QML_PATH"
assert_grep "previewFallbackTimer\\.restart\\(\\)" "$QML_PATH"
assert_grep "pixel_skyscrapers" "$QML_PATH"
assert_grep "star_rail" "$QML_PATH"
assert_grep "the_last_of_us" "$QML_PATH"
assert_grep "win7" "$QML_PATH"
assert_grep "background/A Glow.jpg" "$QML_PATH"

# -- Page registration -------------------------------------------------
assert_grep "LoginScreenConfig\\.qml"            "shell/settings.qml"
assert_grep "LoginScreenConfig\\.qml"            "shell/modules/settings/SettingsOverlay.qml"
# Search index has at least one entry referencing the new keyword
assert_grep "qylock"                             "shell/modules/settings/SettingsOverlay.qml"

# -- Settings About qylock attribution --------------------------------
assert_grep "Darkkal44/qylock" "shell/modules/settings/About.qml"
assert_grep "Darkkal44/qylock" "shell/modules/waffle/settings/pages/WAboutPage.qml"
assert_grep "import qs\\.modules\\.common\\.functions" "shell/modules/settings/About.qml"
assert_grep "GridLayout \\{" "shell/modules/settings/About.qml"
assert_grep "columns: 2" "shell/modules/settings/About.qml"
assert_order "GridLayout \\{" "qylock credit card" "shell/modules/settings/About.qml"
assert_grep "pageIndex: 14, pageName: pages\\[14\\]\\.name" "shell/settings.qml"
assert_grep 'keywords: \["about", "version", "credits", "github", "info", "qylock", "sddm"\]' "shell/settings.qml"
assert_grep 'keywords: \["about", "version", "credits", "github", "info", "qylock", "sddm"\]' "shell/modules/settings/SettingsOverlay.qml"
assert_grep 'keywords: \["about", "version", "credits", "github", "info", "qylock", "sddm"\]' "shell/modules/waffle/settings/WSettingsContent.qml"

# -- Credits attribution -----------------------------------------------
assert_grep "shell/assets/sddm-providers/qylock/themes/" "CREDITS.md"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/qylock/themes/women-umbrella" "$tmp_dir/qylock/Assets"
cp "$ROOT_DIR/shell/assets/sddm-providers/_placeholder.png" "$tmp_dir/qylock/themes/women-umbrella/bg.png"
: >"$tmp_dir/qylock/Assets/women-umbrella.gif"
mkdir -p "$tmp_dir/qylock/themes/future-release/media"
cp "$ROOT_DIR/shell/assets/sddm-providers/_placeholder.png" "$tmp_dir/qylock/themes/future-release/media/future-art.png"
bash "$ROOT_DIR/bin/ryoku-refresh-qylock-previews" "$tmp_dir/qylock" >/dev/null
assert_image_abs "$tmp_dir/qylock/themes/future-release/preview.png"
assert_image_abs "$tmp_dir/qylock/themes/women-umbrella/preview.png"
if command -v identify >/dev/null 2>&1 && command -v magick >/dev/null 2>&1; then
  dimensions=$(identify -format '%wx%h' "$tmp_dir/qylock/themes/future-release/preview.png")
  [[ $dimensions == "480x270" ]] || fail "future qylock preview should be 480x270, got $dimensions"
fi
cp "$ROOT_DIR/shell/assets/sddm-providers/_placeholder.png" "$tmp_dir/qylock/themes/future-release/preview.png"
touch -d '@1000000000' "$tmp_dir/qylock/themes/future-release/preview.png"
touch -d '@1000000100' "$tmp_dir/qylock/themes/future-release/media/future-art.png"
bash "$ROOT_DIR/bin/ryoku-refresh-qylock-previews" "$tmp_dir/qylock" >/dev/null
if [[ ! $tmp_dir/qylock/themes/future-release/preview.png -nt $tmp_dir/qylock/themes/future-release/media/future-art.png ]]; then
  fail "future qylock preview should refresh when upstream theme assets change"
fi

live_home="$tmp_dir/live-user"
mkdir -p \
  "$live_home/.local/share/qylock/themes/field" \
  "$live_home/.local/share/qylock/Assets"
cp "$ROOT_DIR/shell/assets/sddm-providers/_placeholder.png" "$live_home/.local/share/qylock/themes/field/bg.png"
HOME="$live_home" RYOKU_PATH="$ROOT_DIR" bash "$ROOT_DIR/$qylock_preview_migration" >/dev/null
assert_image_abs "$live_home/.local/share/qylock/themes/field/preview.png"
[[ ! -f $live_home/.config/quickshell/ryoku-shell/modules/settings/LoginScreenConfig.qml ]] \
  || fail "qylock preview migration should not rewrite runtime shell QML after manifest generation"
[[ ! -f $live_home/.local/share/ryoku-shell/modules/settings/LoginScreenConfig.qml ]] \
  || fail "qylock preview migration should not rewrite installed shell QML after manifest generation"

echo "PASS: tests/login-screen-config.sh ($0)"
