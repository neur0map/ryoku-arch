#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  [[ -f $ROOT_DIR/$file ]] || fail "$file should exist"
  grep -qF "$needle" "$ROOT_DIR/$file" || fail "$file should contain: $needle"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  [[ -f $ROOT_DIR/$file ]] || fail "$file should exist"
  ! grep -qF "$needle" "$ROOT_DIR/$file" || fail "$file should not contain: $needle"
}

assert_file_absent() {
  local file="$1"
  [[ ! -e $ROOT_DIR/$file ]] || fail "$file should not exist"
}

assert_package_present() {
  local package="$1"
  assert_contains "install/ryoku-base.packages" "$package"
}

assert_package_present_any() {
  local package="$1"
  if ! grep -qxF "$package" "$ROOT_DIR/install/ryoku-base.packages" &&
     ! grep -qxF "$package" "$ROOT_DIR/install/ryoku-aur.packages"; then
    fail "default package manifests should include: $package"
  fi
}

assert_package_absent() {
  local package="$1"
  assert_not_contains "install/ryoku-base.packages" "$package"
  assert_not_contains "install/ryoku-aur.packages" "$package"
}

kept_webapps=(
  YouTube
  GitHub
  Discord
)

removed_webapps=(
  HEY
  Basecamp
  WhatsApp
  "Google Photos"
  "Google Contacts"
  "Google Messages"
  "Google Maps"
  X
  Figma
  Zoom
  Fizzy
)

for webapp in "${kept_webapps[@]}"; do
  assert_contains "install/packaging/webapps.sh" "ryoku-webapp-install \"$webapp\""
  assert_not_contains "bin/ryoku-remove-preinstalls" "ryoku-webapp-remove \"$webapp\""
done

for webapp in "${removed_webapps[@]}"; do
  assert_not_contains "install/packaging/webapps.sh" "ryoku-webapp-install \"$webapp\""
  assert_contains "bin/ryoku-remove-preinstalls" "ryoku-webapp-remove"
  assert_contains "bin/ryoku-remove-preinstalls" "\"$webapp\""
done

assert_contains "install/packaging/tuis.sh" 'ryoku-tui-install "Docker"'
assert_not_contains "install/packaging/tuis.sh" 'ryoku-tui-install "Disk Usage"'
assert_contains "bin/ryoku-remove-preinstalls" "ryoku-tui-remove"
assert_contains "bin/ryoku-remove-preinstalls" '"Disk Usage"'
assert_not_contains "bin/ryoku-remove-preinstalls" 'ryoku-tui-remove "Docker"'

kept_packages=(
  docker
  docker-buildx
  docker-compose
  gradia
  lazydocker
  localsend
  obsidian
  obs-studio
  trayscale
)

removed_packages=(
  1password-beta
  1password-cli
  bluetui
  impala
  kdenlive
  libreoffice-fresh
  pinta
  plocate
  signal-desktop
  spotify
  typora
  usage
  wiremix
  xournalpp
  xmlstarlet
)

for package in "${kept_packages[@]}"; do
  assert_package_present_any "$package"
  assert_not_contains "bin/ryoku-remove-preinstalls" "    $package \\"
  assert_not_contains "bin/ryoku-remove-preinstalls" "  $package"
done

for package in "${removed_packages[@]}"; do
  assert_package_absent "$package"
  assert_contains "bin/ryoku-remove-preinstalls" "  $package"
done

assert_not_contains "bin/ryoku-remove-preinstalls" "ryoku-webapp-remove-all"
assert_not_contains "bin/ryoku-remove-preinstalls" "ryoku-tui-remove-all"

assert_file_absent "applications/typora.desktop"
assert_not_contains "install/config/mimetypes.sh" "HEY.desktop"
assert_not_contains "bin/ryoku-font-set" "xmlstarlet"
assert_contains "install/first-run/firewall.sh" "LocalSend"
assert_contains "install/first-run/firewall.sh" "53317"
assert_contains "install/config/localdb.sh" "ryoku-cmd-missing updatedb"
assert_contains "install/config/plocate-ac-only.sh" "ryoku-cmd-missing updatedb"
