#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "helium-browser-migration: $*" >&2
  exit 1
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

make_test_bin() {
  local bin_dir="$1"

  mkdir -p "$bin_dir"

  ln -sf "$(command -v jq)" "$bin_dir/jq"

  {
    printf '%s\n' '#!/bin/bash'
    printf '%s\n' 'for command_name in "$@"; do'
    printf '%s\n' '  command -v "$command_name" >/dev/null 2>&1 || exit 1'
    printf '%s\n' 'done'
  } > "$bin_dir/ryoku-cmd-present"

  {
    printf '%s\n' '#!/bin/bash'
    printf '%s\n' 'if [[ $1 == "get" && $2 == "default-web-browser" ]]; then'
    printf '%s\n' '  printf "%s\n" "${RYOKU_TEST_XDG_BROWSER:-chromium.desktop}"'
    printf '%s\n' 'elif [[ $1 == "set" && $2 == "default-web-browser" ]]; then'
    printf '%s\n' '  printf "%s\n" "$3" > "$RYOKU_TEST_XDG_SET"'
    printf '%s\n' 'fi'
  } > "$bin_dir/xdg-settings"

  {
    printf '%s\n' '#!/bin/bash'
    printf '%s\n' 'printf "%s\n" "$*" >> "$RYOKU_TEST_XDG_MIME"'
  } > "$bin_dir/xdg-mime"

  {
    printf '%s\n' '#!/bin/bash'
    printf '%s\n' 'printf "%s\n" "called" > "$RYOKU_TEST_INSTALL_CALLED"'
    printf '%s\n' 'mkdir -p "$HOME/.local/bin"'
    printf '%s\n' 'printf "%s\n" "#!/bin/bash" "exit 0" > "$HOME/.local/bin/helium"'
    printf '%s\n' 'chmod 0755 "$HOME/.local/bin/helium"'
  } > "$bin_dir/ryoku-install-helium-browser"

  find "$bin_dir" -type f -exec chmod 0755 {} +
}

write_config() {
  local config_file="$1"
  local browser="$2"
  local pinned_browser="$3"
  local quick_browser="$4"

  mkdir -p "$(dirname "$config_file")"
  jq -n \
    --arg browser "$browser" \
    --arg pinned_browser "$pinned_browser" \
    --arg quick_browser "$quick_browser" \
    '{
      apps: { browser: $browser },
      dock: { pinnedApps: ["org.gnome.Nautilus", $pinned_browser, "kitty"] },
      sidebar: { widgets: { quickLaunch: [{ name: "Browser", cmd: $quick_browser }] } }
    }' > "$config_file"
}

run_helper() {
  local temp_dir="$1"
  shift

  PATH="$temp_dir/bin:/usr/bin:/bin" \
  HOME="$temp_dir/home" \
  XDG_CONFIG_HOME="$temp_dir/config" \
  RYOKU_TEST_XDG_SET="$temp_dir/xdg-set" \
  RYOKU_TEST_XDG_MIME="$temp_dir/xdg-mime" \
  RYOKU_TEST_INSTALL_CALLED="$temp_dir/install-called" \
  bash bin/ryoku-default-app-migrate browser helium "$@"
}

assert_contains migrations/1778617021.sh 'ryoku-default-app-migrate browser helium' \
  "Helium migration should delegate to the generic default-app migration helper"
assert_contains migrations/1778620986.sh '1778617021\.sh' \
  "Helium repair migration should wait for the primary browser migration state"
assert_contains migrations/1778620986.sh 'ryoku-default-app-migrate browser helium' \
  "Helium repair migration should delegate to the generic default-app migration helper"

[[ ! -e bin/ryoku-browser-migrate-helium ]] \
  || fail "Default app migration command should not be hardcoded to Helium"

assert_not_contains shell/shell.qml 'Migrating dock\.pinnedApps default browser to Helium' \
  "Shell startup should not point existing pinned apps at Helium before migration/install"

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
make_test_bin "$temp_dir/bin"

write_config "$temp_dir/config/ryoku-shell/config.json" "firefox" "firefox" "/usr/bin/firefox"
run_helper "$temp_dir" yes

[[ -f "$temp_dir/install-called" ]] \
  || fail "Opt-in migration should install Helium"
[[ "$(cat "$temp_dir/xdg-set")" == "helium.desktop" ]] \
  || fail "Opt-in migration should make Helium the xdg default browser"
jq -e '
  .apps.browser == "helium"
  and .dock.pinnedApps == ["org.gnome.Nautilus", "helium", "kitty"]
  and (.sidebar.widgets.quickLaunch[] | select(.name == "Browser").cmd) == "helium"
' "$temp_dir/config/ryoku-shell/config.json" >/dev/null \
  || fail "Opt-in migration should update old Ryoku browser defaults to Helium"

temp_dir_optout="$(mktemp -d)"
trap 'rm -rf "$temp_dir" "$temp_dir_optout"' EXIT
make_test_bin "$temp_dir_optout/bin"

write_config "$temp_dir_optout/config/ryoku-shell/config.json" "helium" "helium" "helium"
run_helper "$temp_dir_optout" no

[[ ! -f "$temp_dir_optout/install-called" ]] \
  || fail "Opt-out migration should not install Helium"
jq -e '
  .apps.browser == "chromium"
  and .dock.pinnedApps == ["org.gnome.Nautilus", "chromium", "kitty"]
  and (.sidebar.widgets.quickLaunch[] | select(.name == "Browser").cmd) == "chromium"
' "$temp_dir_optout/config/ryoku-shell/config.json" >/dev/null \
  || fail "Opt-out migration should restore a working browser when Helium is missing"

temp_dir_defer="$(mktemp -d)"
trap 'rm -rf "$temp_dir" "$temp_dir_optout" "$temp_dir_defer"' EXIT
make_test_bin "$temp_dir_defer/bin"

write_config "$temp_dir_defer/config/ryoku-shell/config.json" "firefox" "firefox" "/usr/bin/firefox"
set +e
run_helper "$temp_dir_defer" >/dev/null 2>&1
defer_status=$?
set -e

(( defer_status == 75 )) \
  || fail "Ask-mode migration without an interactive prompt should defer with exit 75"
[[ ! -f "$temp_dir_defer/install-called" ]] \
  || fail "Deferred ask-mode migration should not install Helium"

echo "helium-browser-migration: ok"
