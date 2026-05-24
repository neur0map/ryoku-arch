#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  grep -Fq "$needle" "$ROOT_DIR/$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  ! grep -Fq "$needle" "$ROOT_DIR/$file" || fail "$message"
}

pane="shell/modules/controlcenter/about/AboutPane.qml"

assert_not_contains "$pane" "SectionContainer" \
  "about pane should not keep generic section containers"
assert_contains "$pane" "component AboutPanel: StyledRect" \
  "about pane should expose a Ryoku-specific panel shell"
assert_contains "$pane" "RyokuAbout.checkUpdates()" \
  "about pane should preserve update check backend"
assert_contains "$pane" "RyokuAbout.runDoctor()" \
  "about pane should preserve doctor backend"
assert_contains "$pane" "RyokuAbout.startMedevac(root.currentChannel())" \
  "about pane should preserve MedEvac backend"
assert_contains "$pane" "RyokuAbout.switchChannel(root.pendingChannel)" \
  "about pane should preserve channel switch backend"
assert_contains "$pane" "RyokuAbout.openUrl(creditRow.creditUrl)" \
  "about pane should preserve credit link backend"

echo "PASS: tests/settings-about-surface-remake.sh"
