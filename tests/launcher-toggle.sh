#!/bin/bash

# Dynamic coverage for the Settings > Launcher toggle: exercises the
# ryoku-launch-app dispatcher against real config values (the OFF path is where
# the jq `// empty` bug lived) and runs migration 1780374622 against each prior
# hyprland.conf state to assert in-place conversion + idempotency (where the sed
# `|` delimiter bug lived).

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# ── Dispatcher behaviour ──────────────────────────────────────────────
# ryoku-launch-app sources ../lib/runtime-env.sh relative to itself, so place a
# stub copy under an app/ prefix. Stub the launchers + systemctl to record what
# the dispatcher would invoke; jq is used for real.
mkdir -p "$tmp/app/bin" "$tmp/app/lib" "$tmp/stub" "$tmp/cfg/ambxst/config"
: >"$tmp/app/lib/runtime-env.sh"
cp "$ROOT_DIR/bin/ryoku-launch-app" "$tmp/app/bin/ryoku-launch-app"
chmod +x "$tmp/app/bin/ryoku-launch-app"
for c in vicinae ryoku-shell systemctl; do
  cat >"$tmp/stub/$c" <<EOF
#!/bin/bash
printf '%s %s\n' "$c" "\$*" >>"$tmp/calls"
EOF
  chmod +x "$tmp/stub/$c"
done

sys="$tmp/cfg/ambxst/config/system.json"
set_uv() { printf '{ "useVicinaeLauncher": %s }\n' "$1" >"$sys"; }
dispatch() {
  : >"$tmp/calls"
  PATH="$tmp/stub:/usr/bin:/bin" XDG_CONFIG_HOME="$tmp/cfg" \
    "$tmp/app/bin/ryoku-launch-app" "$@" >/dev/null 2>&1 || true
  cat "$tmp/calls" 2>/dev/null || true
}

set_uv true
dispatch open | grep -q '^vicinae toggle$' || fail "open + useVicinaeLauncher=true should run 'vicinae toggle'"
set_uv false
dispatch open | grep -q '^ryoku-shell launcher$' || fail "open + useVicinaeLauncher=false should run 'ryoku-shell launcher'"
rm -f "$sys"
dispatch open | grep -q '^vicinae toggle$' || fail "open with no config should default to Vicinae"

# apply honours an explicit backend (the race-free path the toggle uses),
# ignoring whatever is currently on disk.
set_uv false
dispatch apply vicinae | grep -q 'systemctl --user start vicinae.service' || \
  fail "apply vicinae should start the server even when the saved value is still false"
set_uv true
dispatch apply quickshell | grep -q 'systemctl --user stop vicinae.service' || \
  fail "apply quickshell should stop the server even when the saved value is still true"
# apply with no argument reads the persisted setting.
set_uv false
dispatch apply | grep -q 'systemctl --user stop vicinae.service' || \
  fail "apply (no arg) should honour useVicinaeLauncher=false"

echo "PASS: ryoku-launch-app dispatch"

# ── Migration convergence + idempotency ───────────────────────────────
mkdir -p "$tmp/mig/stubbin" "$tmp/home/.config/hypr"
for h in ryoku-pkg-add ryoku-pkg-aur-add ryoku-cmd-present ryoku-launch-app ryoku-cmd-missing; do
  printf '#!/bin/bash\nexit 0\n' >"$tmp/mig/stubbin/$h"
  chmod +x "$tmp/mig/stubbin/$h"
done
conf="$tmp/home/.config/hypr/hyprland.conf"

run_mig() {
  local _
  for _ in 1 2; do
    PATH="$tmp/mig/stubbin:$PATH" HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" \
      RYOKU_PATH="$ROOT_DIR" bash "$ROOT_DIR/migrations/1780374622.sh" >/dev/null 2>&1
  done
}

assert_converged() {
  local what="$1"
  grep -Fq "\$menu = sh -lc '\$HOME/.local/share/ryoku/bin/ryoku-launch-app'" "$conf" || \
    fail "$what: \$menu was not converted to the dispatcher"
  ! grep -q 'systemctl --user start vicinae.service' "$conf" || \
    fail "$what: a stale unconditional 'systemctl start vicinae.service' survived (would defeat the toggle)"
  (( $(grep -cE '^exec-once = .*ryoku-launch-app apply' "$conf") == 1 )) || \
    fail "$what: expected exactly one ryoku-launch-app apply exec-once"
  (( $(grep -cF 'match:namespace ^(vicinae)$, blur true' "$conf") == 1 )) || \
    fail "$what: expected exactly one vicinae blur layerrule"
}

printf "%s\nbind = SUPER, Space, exec, \$menu\n" \
  "\$menu = sh -lc '\$HOME/.local/bin/ryoku-shell launcher'" >"$conf"
run_mig
assert_converged "from the original quickshell launcher"

cat >"$conf" <<'HYPR'
$menu = sh -lc 'vicinae toggle'
exec-once = sh -lc 'systemctl --user reset-failed vicinae.service >/dev/null 2>&1 || true; systemctl --user start vicinae.service'
bind = SUPER, Space, exec, $menu
HYPR
run_mig
assert_converged "from an earlier 'vicinae toggle' + unconditional autostart"

echo "PASS: launcher migration convergence"
echo "PASS: launcher toggle"
