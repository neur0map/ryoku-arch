#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

script=shell/scripts/ryoku-shell
registry=shell/scripts/lib/ipc-registry.sh

[[ -f $script ]] || fail "ryoku-shell launcher missing"
[[ -f $registry ]] || fail "IPC registry missing"

bash -n "$script" || fail "ryoku-shell launcher has a syntax error"

[[ $(head -n 1 "$registry") == "#!/bin/bash" ]] \
  || fail "generated IPC registry should use the repo bash shebang convention"

rg -q 'ipc call -- settings open' "$script" \
  || fail "settings IPC call should pass -- before target/function"
rg -q 'ipc call -- "\$target" "\$@"' "$script" \
  || fail "target IPC wrapper should pass -- before target/function"
rg -q 'ipc call -- "\$@"' "$script" \
  || fail "generic IPC wrapper should pass -- before target/function"

rg -q '\[recordingOsd\]="toggle show hide"' "$registry" \
  || fail "recordingOsd show/hide functions should remain registered"
rg -q '\["recordingOsd:show"\]' "$registry" \
  || fail "recordingOsd:show registry entry missing"
legacy_cmd="i""nir"
! rg -q "spawn \"$legacy_cmd\"" "$registry" \
  || fail "generated IPC help examples should use ryoku-shell"

echo "PASS: ryoku-shell IPC wrapper handles reserved function names"
