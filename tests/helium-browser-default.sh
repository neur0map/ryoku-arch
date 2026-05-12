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

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq -- "$pattern" "$file"; then
    fail "$message"
  fi
}

assert_package_present() {
  local package="$1"

  grep -qxF "$package" install/ryoku-base.packages \
    || fail "install/ryoku-base.packages should include $package"
}

assert_package_absent() {
  local package="$1"

  if grep -qxF "$package" install/ryoku-base.packages; then
    fail "install/ryoku-base.packages should not include old default package: $package"
  fi
}

assert_executable bin/ryoku-install-helium-browser
assert_file install/config/helium-browser.sh
bash -n bin/ryoku-install-helium-browser || fail "Helium installer has a syntax error"
bash -n install/config/helium-browser.sh || fail "Helium config installer has a syntax error"

assert_package_present fuse2
assert_package_absent chromium

assert_contains install/config/all.sh 'config/helium-browser\.sh' \
  "fresh installs should install and register Helium"
assert_contains install/config/helium-browser.sh 'ryoku-install-helium-browser' \
  "Helium config step should delegate to the shared installer"

assert_file iso/builder/ryoku-offline-appimages.tsv
assert_contains iso/builder/ryoku-offline-appimages.tsv '^helium[[:space:]]+imputnet/helium-linux[[:space:]]+\^helium-\.\*-x86_64\\\.AppImage\$' \
  "offline ISO AppImage manifest should include Helium"
assert_contains iso/builder/build-iso.sh 'ryoku-offline-appimages\.tsv' \
  "ISO builder should read the offline AppImage manifest"
assert_contains iso/builder/build-iso.sh '/var/cache/ryoku/appimages' \
  "ISO builder should stage offline AppImages"
assert_contains iso/configs/airootfs/root/.automated_script.sh '/var/cache/ryoku/appimages' \
  "offline AppImage cache should be bind-mounted into the target install"
assert_contains iso/configs/profiledef.sh '/var/cache/ryoku/appimages/' \
  "ISO should preserve AppImage cache permissions"

assert_contains bin/ryoku-install-helium-browser 'https://api\.github\.com/repos/imputnet/helium-linux/releases/latest' \
  "Helium installer should use official Linux release metadata"
assert_contains bin/ryoku-install-helium-browser '/var/cache/ryoku/appimages/helium/helium\.AppImage' \
  "Helium installer should prefer the offline ISO AppImage cache"
assert_contains bin/ryoku-install-helium-browser 'helium-\$\{version\}-\$\{arch\}\.AppImage' \
  "Helium installer should resolve architecture-specific AppImages"
assert_contains bin/ryoku-install-helium-browser 'helium\.desktop' \
  "Helium installer should create a desktop entry"
assert_contains bin/ryoku-install-helium-browser 'xdg-settings set default-web-browser helium\.desktop' \
  "Helium installer should set the xdg default browser"
assert_contains bin/ryoku-install-helium-browser 'x-scheme-handler/http' \
  "Helium installer should claim HTTP links"
assert_contains bin/ryoku-install-helium-browser 'x-scheme-handler/https' \
  "Helium installer should claim HTTPS links"

assert_contains install/config/mimetypes.sh 'default-web-browser helium\.desktop' \
  "fresh MIME defaults should use Helium"
assert_contains install/config/mimetypes.sh 'helium\.desktop x-scheme-handler/http' \
  "HTTP links should open in Helium"
assert_contains install/config/mimetypes.sh 'helium\.desktop x-scheme-handler/https' \
  "HTTPS links should open in Helium"
assert_not_contains install/config/mimetypes.sh 'chromium\.desktop x-scheme-handler/http' \
  "Chromium should not remain the HTTP default"

assert_contains shell/defaults/config.json '"browser": "helium"' \
  "shell JSON defaults should use Helium"
assert_contains shell/defaults/config.json '"pinnedApps": \["org\.gnome\.Nautilus", "helium", "kitty"\]' \
  "default pinned apps should pin Helium"
assert_contains shell/modules/common/Config.qml 'property string browser: "helium"' \
  "shell typed defaults should use Helium"
assert_contains shell/modules/common/Config.qml '"org\.gnome\.Nautilus", "helium", "kitty"' \
  "typed dock defaults should pin Helium"
assert_contains shell/modules/common/Config.qml '"cmd": "helium"' \
  "typed quick launch should open Helium"
assert_contains shell/modules/sidebarLeft/widgets/QuickLaunch.qml 'cmd: "helium"' \
  "quick launch defaults should open Helium"
assert_contains shell/modules/settings/InterfaceConfig.qml 'cmd: "helium"' \
  "quick launch editor defaults should open Helium"
assert_not_contains shell/shell.qml 'Migrating dock\.pinnedApps default browser to Helium' \
  "shell startup should not switch existing users to Helium before migration/install"
assert_contains bin/ryoku-default-app-migrate 'dock\.pinnedApps = \["org\.gnome\.Nautilus", \$target, "kitty"\]' \
  "browser migration helper should move old defaults to Helium after opt-in"
assert_contains migrations/1778617021.sh 'ryoku-default-app-migrate browser helium' \
  "browser migration should run through the opt-in helper"

assert_contains shell/services/AppLauncher.qml 'defaultCommand: "helium"' \
  "browser launcher should default to Helium"
assert_contains shell/services/AppLauncher.qml '\{ id: "helium", label: "Helium", command: "helium" \}' \
  "browser presets should include Helium"
assert_contains shell/services/AppLauncher.qml '"helium": "helium\.desktop"' \
  "browser preset should sync Helium to xdg-settings"
assert_contains bin/ryoku-launch-browser 'helium\.desktop' \
  "generic browser launcher should fall back to Helium"
assert_contains bin/ryoku-launch-webapp 'helium\.desktop' \
  "webapp launcher should fall back to Helium-capable browsers"

assert_contains shell/services/AppSearch.qml '"helium": "helium"' \
  "app icon lookup should recognize Helium"
assert_contains shell/services/RedditService.qml 'helium' \
  "URL open focus helper should recognize Helium windows"
assert_contains shell/modules/common/functions/NotificationUtils.qml 'helium' \
  "notification cleanup should treat Helium as Chromium-based"
assert_contains shell/modules/waffle/looks/WIcons.qml 'case "helium":' \
  "Waffle icons should classify Helium as a browser"
assert_contains shell/modules/sidebarRight/CompactMediaPlayer.qml 'helium' \
  "compact media player should classify Helium as a browser"
assert_contains shell/services/MprisController.qml 'helium' \
  "MPRIS browser heuristics should include Helium"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
test_home="$tmp_dir/userdir"
mkdir -p "$test_home" "$tmp_dir/offline"
printf '%s\n' "offline helium appimage" > "$tmp_dir/offline/helium.AppImage"
chmod 0755 "$tmp_dir/offline/helium.AppImage"

HOME="$test_home" \
XDG_DATA_HOME="$test_home/.local/share" \
HELIUM_OFFLINE_APPIMAGE="$tmp_dir/offline/helium.AppImage" \
  bash bin/ryoku-install-helium-browser > "$tmp_dir/install.log"

assert_contains "$tmp_dir/install.log" 'Installing Helium from offline cache' \
  "Helium installer should use offline cache without network"
[[ -x "$test_home/.local/bin/helium" ]] \
  || fail "Helium installer should create an executable helium command"
cmp -s "$tmp_dir/offline/helium.AppImage" "$test_home/.local/share/ryoku/apps/helium/helium.AppImage" \
  || fail "Helium installer should copy the offline AppImage"
assert_contains "$test_home/.local/share/applications/helium.desktop" 'Exec=.*/\.local/bin/helium %U' \
  "Helium desktop entry should launch the installed AppImage"

pass "Helium browser default contract"
