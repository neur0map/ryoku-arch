#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

script=shell/scripts/ryoku-shell
registry=shell/scripts/lib/ipc-registry.sh
fish_completion=shell/scripts/completions/ryoku-shell.fish

[[ -f $script ]] || fail "ryoku-shell launcher missing"
[[ -f $registry ]] || fail "IPC registry missing"
[[ -f $fish_completion ]] || fail "fish completion missing"

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
rg -q '\[globalActions\]="run runWithArgs list search open"' "$registry" \
  || fail "globalActions should expose single-arg and args-aware run functions"
rg -q '\["globalActions:run"\]="<actionId>"' "$registry" \
  || fail "globalActions run should take one action ID"
rg -q '\["globalActions:runWithArgs"\]="<actionId> <args>"' "$registry" \
  || fail "globalActions runWithArgs should take action ID plus args"
rg -q "globalActions global-actions.*run runWithArgs list search open" "$fish_completion" \
  || fail "fish completion should include globalActions runWithArgs"
rg -q "shellUpdate shell-update.*diagnose refresh" "$fish_completion" \
  || fail "fish completion should include shellUpdate refresh"
legacy_cmd="i""nir"
! rg -q "spawn \"$legacy_cmd\"" "$registry" \
  || fail "generated IPC help examples should use ryoku-shell"

echo "PASS: ryoku-shell IPC wrapper handles reserved function names"
