#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

target="shell/ryokuSettings.qml"
[[ -f "$target" ]] || fail "shell/ryokuSettings.qml must exist"

# 1. Lock button - invokes ryoku-shell lock activate via shellPath().
# The call is multi-line so grep two distinct anchors rather than a same-line concat.
grep -q 'tooltipText: "Lock screen"' "$target" \
  || fail "entrypoint chrome missing: lock button tooltip"
grep -q '"activate"' "$target" \
  || fail "entrypoint chrome missing: lock button activate argument"

# 2. Easy/Advanced mode toggle - writes settingsUi.easyMode and uses the school/tune icons.
grep -q 'settingsUi\.easyMode' "$target" \
  || fail "entrypoint chrome missing: easy mode binding (settingsUi.easyMode)"
grep -q '"school"' "$target" \
  || fail "entrypoint chrome missing: easy mode school icon"

# 3. Ctrl+F search-focus shortcut.
grep -q 'StandardKey\.Find' "$target" \
  || fail "entrypoint chrome missing: Ctrl+F shortcut (StandardKey.Find)"

# Page-cycle shortcuts (Ctrl+PgUp/PgDn/Tab/Shift+Tab) were intentionally dropped
# from this sub-spec during verification.

# 4. FAB "Config file" - open + alt copy + 1500ms revert timer.
grep -q 'Directories\.shellConfigPath' "$target" \
  || fail "entrypoint chrome missing: Config file open (Directories.shellConfigPath)"
grep -q 'clipboardText.*shellConfigPath' "$target" \
  || fail "entrypoint chrome missing: Config file copy-to-clipboard"
grep -q 'interval: 1500' "$target" \
  || fail "entrypoint chrome missing: FAB revert timer (interval: 1500)"

# Overlay-mode toggle was intentionally dropped from this sub-spec (centered
# is the only supported mode for the new UI). No grep invariant for it.

echo "PASS: entrypoint chrome restored"
