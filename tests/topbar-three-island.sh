#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"
  assert_file "$path"
  [[ -x $ROOT_DIR/$path ]] || fail "$path should be executable"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  local file="$ROOT_DIR/$path"
  [[ -f $file ]] || fail "$path should exist"
  grep -qF "$needle" "$file" || fail "$path should contain: $needle"
}

assert_contains_regex() {
  local path="$1"
  local pattern="$2"
  local file="$ROOT_DIR/$path"
  [[ -f $file ]] || fail "$path should exist"
  grep -qE "$pattern" "$file" || fail "$path should match regex: $pattern"
}

assert_count() {
  local path="$1"
  local needle="$2"
  local expected="$3"
  local file="$ROOT_DIR/$path"
  local actual
  actual=$(grep -cF "$needle" "$file" || true)
  [[ $actual -eq $expected ]] || fail "$path: expected $expected occurrences of '$needle', got $actual"
}

# 1. New files exist under shell/modules/bar/threeIsland/
assert_file "shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml"
assert_file "shell/modules/bar/threeIsland/RyokuIsland.qml"
assert_file "shell/modules/bar/threeIsland/RyokuLeftIsland.qml"
assert_file "shell/modules/bar/threeIsland/RyokuCenterIsland.qml"
assert_file "shell/modules/bar/threeIsland/RyokuRightIsland.qml"
assert_file "shell/modules/bar/threeIsland/RyokuKanjiClock.qml"
assert_file "shell/modules/bar/threeIsland/SecPulseIndicator.qml"

# 2. Singleton service exists and is registered
assert_file "shell/services/RyokuSecPulse.qml"
assert_contains "shell/services/qmldir" "singleton RyokuSecPulse 1.0 RyokuSecPulse.qml"

# 3. Config.qml declares the new keys with documented defaults
assert_contains "shell/modules/common/Config.qml" "property bool kanjiClock: true"
assert_contains "shell/modules/common/Config.qml" "property bool secPulse: true"
assert_contains "shell/modules/common/Config.qml" "property JsonObject kanjiClock"
assert_contains "shell/modules/common/Config.qml" "property JsonObject secPulse"
assert_contains "shell/modules/common/Config.qml" "property bool showDate: true"
assert_contains "shell/modules/common/Config.qml" "property bool useKanjiDigits: true"
assert_contains "shell/modules/common/Config.qml" "property bool showVpn: true"
assert_contains "shell/modules/common/Config.qml" "property bool showPublicIp: false"
assert_contains "shell/modules/common/Config.qml" "property bool showListening: false"

# 4. Bar.qml: Loader wraps BarContent, switches on cornerStyle === 4
assert_contains "shell/modules/bar/Bar.qml" "import qs.modules.bar.threeIsland"
assert_contains "shell/modules/bar/Bar.qml" "RyokuThreeIslandContent"
assert_contains_regex "shell/modules/bar/Bar.qml" "cornerStyle.*===.*4"
# 5. Bar.qml: roundDecorators activates on cornerStyle === 0 || cornerStyle === 4
assert_contains_regex "shell/modules/bar/Bar.qml" "cornerStyle.*===.*0.*\|\|.*cornerStyle.*===.*4|cornerStyle.*===.*4.*\|\|.*cornerStyle.*===.*0"

# 6. BarContent.qml is unchanged compared to HEAD (no edits)
if git -C "$ROOT_DIR" rev-parse HEAD >/dev/null 2>&1; then
  if ! git -C "$ROOT_DIR" diff --quiet HEAD -- shell/modules/bar/BarContent.qml; then
    fail "shell/modules/bar/BarContent.qml must not be modified"
  fi
fi

# 7. Settings UI: each picker has exactly one value: 4 entry
assert_count "shell/modules/settings/BarConfig.qml" "value: 4" 1
assert_count "shell/modules/settings/QuickConfig.qml" "value: 4" 1
assert_count "shell/welcome.qml" "value: 4" 1
assert_contains "shell/modules/settings/BarConfig.qml" "Three-Island"
assert_contains "shell/modules/settings/QuickConfig.qml" "Three-Island"
assert_contains "shell/welcome.qml" "Three-Island"

# 8. BarConfig.qml: Modules toggles for kanjiClock and secPulse
assert_contains "shell/modules/settings/BarConfig.qml" "bar.modules.kanjiClock"
assert_contains "shell/modules/settings/BarConfig.qml" "bar.modules.secPulse"

# 9. RyokuSecPulse: gated subprocess starts (no unconditional process.start in onCompleted)
sec_pulse="$ROOT_DIR/shell/services/RyokuSecPulse.qml"
if [[ -f $sec_pulse ]]; then
  # If onCompleted exists, it must not call .start() / .startDetached() / running = true unconditionally.
  # We check that any .running = true / .start() inside onCompleted is wrapped in a Config.options check.
  if grep -A4 'Component.onCompleted' "$sec_pulse" | grep -E '^\s*(running\s*=\s*true|\.start\(\)|\.startDetached\()' \
     | grep -v 'Config.options' >/dev/null; then
    fail "shell/services/RyokuSecPulse.qml: subprocess starts in onCompleted must be Config.options-gated"
  fi
fi

# 10. Migration script exists and references SHELL_PATH + runtime-payload-dirs.txt
migration_files=$(find "$ROOT_DIR/migrations" -name "*.sh" -newer "$ROOT_DIR/migrations/1778100000.sh" 2>/dev/null || true)
found_migration=0
for m in $migration_files; do
  if grep -qE 'three.?island|threeIsland|RyokuSecPulse' "$m" \
     && grep -qE 'RYOKU_SHELL_PATH|SHELL_PATH=' "$m" \
     && grep -q 'runtime-payload-dirs.txt' "$m"; then
    found_migration=1
    break
  fi
done
[[ $found_migration -eq 1 ]] || fail "migrations/<timestamp>.sh referencing three-island + SHELL_PATH + runtime-payload-dirs.txt should exist"

echo "PASS: tests/topbar-three-island.sh"
