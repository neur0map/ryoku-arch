#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "browser-managed-policy: $*" >&2
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

assert_not_contains install/config/theme.sh '/etc/(chromium|brave)/policies/managed' \
  "fresh installs should not create managed browser policy directories for theming"
assert_not_contains bin/ryoku-theme-set-browser 'policies/managed|BrowserThemeColor|BrowserColorScheme' \
  "ryoku-theme-set-browser should not write enterprise browser policy"
assert_not_contains shell/scripts/colors/apply-chrome-theme.sh 'policies/managed|BrowserThemeColor|ii-theme\.json|refresh-platform-policy' \
  "shell color pipeline should not write or refresh enterprise browser policy"

assert_contains migrations/1778630817.sh 'Remove Ryoku browser theme policy files' \
  "migration should describe browser policy cleanup"
assert_contains migrations/1778630817.sh '/etc/chromium/policies/managed/color\.json' \
  "migration should remove the old Ryoku Chromium color policy"
assert_contains migrations/1778630817.sh '/etc/chromium/policies/managed/ii-theme\.json' \
  "migration should remove the old Ryoku Chromium shell theme policy"
assert_contains migrations/1778630817.sh '/etc/brave/policies/managed/color\.json' \
  "migration should remove the old Ryoku Brave color policy"
assert_contains migrations/1778630817.sh '/etc/opt/chrome/policies/managed/ii-theme\.json' \
  "migration should remove the old Ryoku Chrome shell theme policy"
assert_contains migrations/1778631354.sh 'Harden leftover browser policy directories' \
  "follow-up migration should harden empty browser policy directories"
assert_contains migrations/1778631354.sh 'chmod 0755' \
  "leftover browser policy directories should not remain world-writable"

echo "browser-managed-policy: ok"
