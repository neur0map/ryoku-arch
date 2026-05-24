#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

write_executable() {
  local path="$1"
  local content="$2"

  printf '%s\n' "$content" > "$path"
  chmod 755 "$path"
}

command -v script >/dev/null 2>&1 || fail "script command is required for PTY coverage"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
checkout="$tmp/checkout"
state="$tmp/state"
system_bin="$tmp/system-bin"
system_lib="$tmp/system-lib"
sudo_bin="$tmp/sudo-bin"
sudo_state="$tmp/sudo-authorized"
test_log="$tmp/update.log"
pty_log="$tmp/pty.log"

mkdir -p \
  "$home/.local/bin" \
  "$checkout/bin" \
  "$checkout/lib" \
  "$checkout/shell/scripts" \
  "$state" \
  "$system_bin" \
  "$system_lib" \
  "$sudo_bin"

printf '%s\n' '# runtime env' > "$checkout/lib/runtime-env.sh"

write_executable "$checkout/bin/ryoku-call911now" '#!/bin/bash
exit 0'
write_executable "$checkout/bin/ryoku-doctor" '#!/bin/bash
exit 0'
write_executable "$checkout/bin/ryoku-snapshot" '#!/bin/bash
set -euo pipefail
printf "snapshot:%s\n" "$*" >> "$RYOKU_TEST_LOG"'
write_executable "$checkout/bin/ryoku-update-git" '#!/bin/bash
exit 0'
write_executable "$checkout/bin/ryoku-update-perform" '#!/bin/bash
set -euo pipefail
printf "perform\n" >> "$RYOKU_TEST_LOG"'
write_executable "$checkout/shell/scripts/ryoku" '#!/bin/bash
exit 0'
write_executable "$checkout/shell/scripts/ryoku-shell" '#!/bin/bash
exit 0'

cat > "$sudo_bin/sudo" <<'SH'
#!/bin/bash
set -euo pipefail

state="${RYOKU_FAKE_SUDO_STATE:?}"

if [[ ${1:-} == "-n" ]]; then
  shift

  if [[ ${1:-} == "true" && $# == 1 ]]; then
    [[ -e $state ]]
    exit
  fi

  [[ -e $state ]] || exit 1
  exec "$@"
fi

if [[ ${1:-} == "-v" && $# == 1 ]]; then
  : > "$state"
  exit 0
fi

[[ -e $state ]] || exit 1
exec "$@"
SH
chmod 755 "$sudo_bin/sudo"

printf -v update_command \
  'HOME=%q RYOKU_PATH=%q RYOKU_STATE_PATH=%q RYOKU_SYSTEM_BIN_DIR=%q RYOKU_SYSTEM_LIB_DIR=%q RYOKU_FAKE_SUDO_STATE=%q RYOKU_TEST_LOG=%q RYOKU_UPDATE_LOGGED=1 RYOKU_UPDATE_INHIBITED=1 RYOKU_UPDATE_POWER_CHECKED=1 PATH=%q %q --resume-after-git -y' \
  "$home" \
  "$checkout" \
  "$state" \
  "$system_bin" \
  "$system_lib" \
  "$sudo_state" \
  "$test_log" \
  "$sudo_bin:$checkout/bin:$ROOT_DIR/bin:/usr/bin:/bin" \
  "$ROOT_DIR/bin/ryoku-update"

output="$(script -qefc "$update_command" "$pty_log" 2>&1)" || \
  fail "update should complete while repairing system shims through sudo in a PTY: $output"

[[ -e $sudo_state ]] || \
  fail "update should prime sudo before checking system command shim authorization"
[[ -L $system_bin/ryoku-call911now ]] || \
  fail "update should create the system MedEvac command shim when sudo can authenticate"
[[ $(readlink "$system_bin/ryoku-call911now") == "$checkout/bin/ryoku-call911now" ]] || \
  fail "system MedEvac shim should point at the installed checkout"
[[ -L $system_bin/ryoku ]] || \
  fail "update should create the system ryoku command bridge when sudo can authenticate"
[[ -L $system_lib/runtime-env.sh ]] || \
  fail "update should create the system runtime-env bridge when sudo can authenticate"
grep -Fq 'snapshot:create' "$test_log" || \
  fail "update should continue to snapshot after repairing system shims"
grep -Fq 'perform' "$test_log" || \
  fail "update should continue to perform after repairing system shims"

echo "PASS: ryoku-update repairs system shims through sudo in a PTY"
