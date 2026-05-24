#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -x $ROOT_DIR/bin/ryoku-call911now ]] || \
  fail "ryoku-call911now should be the canonical portable MedEvac command"
grep -Fq 'requested_medevac_branch="${RYOKU_UPDATE_BRANCH:-}"' "$ROOT_DIR/bin/ryoku-update-bootstrap" || \
  fail "bootstrap compatibility wrapper should track whether the caller explicitly selected a branch"
grep -Fq 'medevac_branch="${requested_medevac_branch:-unstable-dev}"' "$ROOT_DIR/bin/ryoku-update-bootstrap" || \
  fail "bootstrap compatibility wrapper should default its raw MedEvac URL to unstable-dev"
grep -Fq "WARN: ignoring invalid Ryoku MedEvac branch" "$ROOT_DIR/bin/ryoku-update-bootstrap" || \
  fail "bootstrap compatibility wrapper should warn when correcting invalid MedEvac branches"
grep -Fq 'requested_medevac_branch="$medevac_branch"' "$ROOT_DIR/bin/ryoku-update-bootstrap" || \
  fail "bootstrap compatibility wrapper should pass the corrected branch after invalid input"
grep -Fq 'medevac_env+=(RYOKU_UPDATE_BRANCH="$medevac_branch")' "$ROOT_DIR/bin/ryoku-update-bootstrap" || \
  fail "bootstrap compatibility wrapper should pass an explicit matched channel only when the caller selected one"
grep -Fq 'exec env "${medevac_env[@]}" "$local_medevac"' "$ROOT_DIR/bin/ryoku-update-bootstrap" || \
  fail "bootstrap compatibility wrapper should execute local MedEvac through the compatibility environment"
grep -Fq '$medevac_branch/bin/ryoku-call911now' "$ROOT_DIR/bin/ryoku-update-bootstrap" || \
  fail "bootstrap compatibility wrapper should download the channel-matched MedEvac command"
grep -Fq 'env "${medevac_env[@]}" bash' "$ROOT_DIR/bin/ryoku-update-bootstrap" || \
  fail "bootstrap compatibility wrapper should execute downloaded MedEvac through the compatibility environment"
grep -Fq 'set -o pipefail' "$ROOT_DIR/bin/ryoku-update-bootstrap" || \
  fail "bootstrap compatibility wrapper should fail when the MedEvac download pipeline fails"

write_executable() {
  local path="$1"
  local content="$2"

  printf '%s\n' "$content" > "$path"
  chmod 755 "$path"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

remote="$tmp/remote.git"
seed="$tmp/seed"
home="$tmp/home"
install="$home/.local/share/ryoku"
state="$home/.local/state/ryoku"
log="$tmp/bootstrap.log"

mkdir -p "$home/.local/bin" "$state"
git init --bare "$remote" >/dev/null
git clone "$remote" "$seed" >/dev/null 2>&1
git -C "$seed" config user.email test@example.invalid
git -C "$seed" config user.name "Ryoku Test"

mkdir -p "$seed/bin" "$seed/lib" "$seed/shell/scripts"
printf '%s\n' '# runtime env' > "$seed/lib/runtime-env.sh"
write_executable "$seed/bin/ryoku-update" '#!/bin/bash
set -euo pipefail
printf "fresh-update:%s\n" "$*" >> "$RYOKU_TEST_LOG"
printf "doctor-command:%s\n" "${RYOKU_UPDATE_DOCTOR_COMMAND:-missing}" >> "$RYOKU_TEST_LOG"'
write_executable "$seed/bin/ryoku-doctor" '#!/bin/bash
exit 0'
write_executable "$seed/bin/ryoku-call911now" '#!/bin/bash
exit 0'
write_executable "$seed/shell/scripts/ryoku-shell" '#!/bin/bash
exit 0'
write_executable "$seed/shell/scripts/ryoku" '#!/bin/bash
exit 0'

git -C "$seed" add bin lib shell
git -C "$seed" commit -m "bootstrap payload" >/dev/null
git -C "$seed" push origin HEAD:main >/dev/null 2>&1
git -C "$seed" checkout -b unstable-dev >/dev/null 2>&1
printf '%s\n' "unstable bootstrap" > "$seed/unstable.txt"
git -C "$seed" add unstable.txt
git -C "$seed" commit -m "unstable bootstrap payload" >/dev/null
git -C "$seed" push origin HEAD:unstable-dev >/dev/null 2>&1

printf '%s\n' '# stale local doctor copy' > "$home/.local/bin/ryoku-doctor"
chmod 755 "$home/.local/bin/ryoku-doctor"
printf '%s\n' '# stale local ryoku bridge' > "$home/.local/bin/ryoku"
chmod 755 "$home/.local/bin/ryoku"

output=$(
  HOME="$home" \
  RYOKU_PATH="$install" \
  RYOKU_STATE_PATH="$state" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  RYOKU_UPDATE_BRANCH=unstable-dev \
  RYOKU_TEST_LOG="$log" \
  PATH="/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-update-bootstrap" 2>&1
) || fail "bootstrap should clone, repair command bridges, and start refreshed updater: $output"

remote_tip="$(git -C "$install" rev-parse --short origin/unstable-dev)"
grep -Fq 'Ryoku bootstrap result:' <<< "$output" || \
  fail "bootstrap should print installed checkout provenance"
grep -Fq 'Channel: unstable-dev' <<< "$output" || \
  fail "bootstrap should use the requested update channel"
grep -Fq "Remote tip: origin/unstable-dev@$remote_tip" <<< "$output" || \
  fail "bootstrap should print the fetched remote tip for the selected channel"
grep -Fq "Updater: $install/bin/ryoku-update" <<< "$output" || \
  fail "bootstrap should show the refreshed updater path"
grep -Fq "Expected doctor: $install/bin/ryoku-doctor" <<< "$output" || \
  fail "bootstrap should show the expected installed doctor path"
grep -Fq "Active doctor: $install/bin/ryoku-doctor" <<< "$output" || \
  fail "bootstrap should show that PATH resolves doctor from the installed checkout"
grep -Fq "Doctor command: $install/bin/ryoku-doctor" <<< "$output" || \
  fail "bootstrap should print a path-safe doctor command for the next step"
grep -Fq 'fresh-update:-y' "$log" || \
  fail "bootstrap should exec the refreshed installed updater with -y"
grep -Fq "doctor-command:$install/bin/ryoku-doctor" "$log" || \
  fail "bootstrap should pass the path-safe installed doctor command to the refreshed updater"
[[ -r $state/channel ]] || \
  fail "bootstrap should persist the selected update channel"
[[ $(<"$state/channel") == "unstable-dev" ]] || \
  fail "bootstrap should persist the requested unstable-dev channel"
grep -Fq 'skipped /usr/local Ryoku command shim repair' <<< "$output" || \
  fail "bootstrap should report when non-interactive system shim repair is skipped"
grep -Fq 'System shims: skipped:' <<< "$output" || \
  fail "bootstrap result should include system shim status for stale PATH diagnosis"
grep -Fq 'System shim next step: run sudo -v and this bootstrap again' <<< "$output" || \
  fail "bootstrap should explain how to repair skipped system command shims"

[[ $(git -C "$install" branch --show-current) == "unstable-dev" ]] || \
  fail "bootstrap should leave the checkout on the requested branch"
grep -qx 'unstable bootstrap' "$install/unstable.txt" || \
  fail "bootstrap should install files from the requested branch"
[[ -L $home/.local/bin/ryoku-doctor ]] || \
  fail "bootstrap should replace stale local doctor copies with a checkout symlink"
[[ $(readlink "$home/.local/bin/ryoku-doctor") == "$install/bin/ryoku-doctor" ]] || \
  fail "bootstrap doctor shim should point to the installed checkout"
[[ -L $home/.local/bin/ryoku ]] || \
  fail "bootstrap should replace stale local ryoku bridge copies with a checkout symlink"
[[ $(readlink "$home/.local/bin/ryoku") == "$install/shell/scripts/ryoku" ]] || \
  fail "bootstrap ryoku bridge should point to the installed checkout"
[[ -L $home/.local/bin/ryoku-call911now ]] || \
  fail "bootstrap should expose the canonical MedEvac command"
[[ $(readlink "$home/.local/bin/ryoku-call911now") == "$install/bin/ryoku-call911now" ]] || \
  fail "MedEvac command bridge should point to the installed checkout"
[[ -L $home/.local/lib/runtime-env.sh ]] || \
  fail "bootstrap should repair the local runtime-env bridge"

echo "PASS: ryoku-update-bootstrap repairs stale updater installs"

default_home="$tmp/default-home"
default_install="$default_home/.local/share/ryoku"
default_state="$default_home/.local/state/ryoku"
default_log="$tmp/default-bootstrap.log"

mkdir -p "$default_home/.local/bin" "$default_state"

output=$(
  HOME="$default_home" \
  RYOKU_PATH="$default_install" \
  RYOKU_STATE_PATH="$default_state" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  RYOKU_TEST_LOG="$default_log" \
  PATH="/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-update-bootstrap" 2>&1
) || fail "bootstrap should default unconfigured rebirth recovery to unstable-dev: $output"

grep -Fq 'no Ryoku update channel configured; bootstrap is using unstable-dev' <<< "$output" || \
  fail "bootstrap should explain the rebirth recovery default channel"
grep -Fq 'Channel: unstable-dev' <<< "$output" || \
  fail "bootstrap should default to unstable-dev when no state or config channel exists"
[[ $(git -C "$default_install" branch --show-current) == "unstable-dev" ]] || \
  fail "unconfigured bootstrap should leave the checkout on unstable-dev"
[[ $(<"$default_state/channel") == "unstable-dev" ]] || \
  fail "unconfigured bootstrap should persist the rebirth recovery channel"
grep -Fq 'fresh-update:-y' "$default_log" || \
  fail "unconfigured bootstrap should still exec the refreshed installed updater"

echo "PASS: ryoku-update-bootstrap defaults to rebirth recovery channel"

config_home="$tmp/config-home"
config_install="$config_home/.local/share/ryoku"
config_state="$config_home/.local/state/ryoku"
config_log="$tmp/config-bootstrap.log"

mkdir -p "$config_home/.config/ryoku-shell" "$config_state"
printf '%s\n' "unstable-dev" >"$config_state/channel"
printf '%s\n' '{"shellUpdates":{"channel":"main"}}' >"$config_home/.config/ryoku-shell/config.json"

output=$(
  HOME="$config_home" \
  RYOKU_PATH="$config_install" \
  RYOKU_STATE_PATH="$config_state" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  RYOKU_TEST_LOG="$config_log" \
  PATH="/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-update-bootstrap" 2>&1
) || fail "bootstrap should let explicit shell config override stale channel state: $output"

grep -Fq 'Channel: main' <<< "$output" || \
  fail "bootstrap should report the explicit configured main channel"
[[ $(git -C "$config_install" branch --show-current) == "main" ]] || \
  fail "configured bootstrap should leave the checkout on main"
[[ $(<"$config_state/channel") == "main" ]] || \
  fail "configured bootstrap should rewrite stale channel state to main"
[[ ! -e $config_install/unstable.txt ]] || \
  fail "configured bootstrap should not install unstable-only files when config selects main"

echo "PASS: ryoku-update-bootstrap lets shell config override stale channel state"

legacy_home="$tmp/legacy-home"
legacy_install="$legacy_home/.local/share/omarchy"
legacy_canonical="$legacy_home/.local/share/ryoku"
legacy_state="$legacy_home/.local/state/ryoku"
legacy_log="$tmp/legacy-bootstrap.log"

mkdir -p "$legacy_home/.local/share" "$legacy_state"
git clone "$remote" "$legacy_install" >/dev/null 2>&1
git -C "$legacy_install" checkout unstable-dev >/dev/null 2>&1

output=$(
  HOME="$legacy_home" \
  RYOKU_PATH="" \
  RYOKU_STATE_PATH="$legacy_state" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  RYOKU_UPDATE_BRANCH=unstable-dev \
  RYOKU_TEST_LOG="$legacy_log" \
  PATH="/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-update-bootstrap" 2>&1
) || fail "bootstrap should expose legacy omarchy installs at the canonical Ryoku path: $output"

[[ -L $legacy_canonical ]] || \
  fail "legacy bootstrap should create ~/.local/share/ryoku canonical link"
[[ $(readlink "$legacy_canonical") == "$legacy_install" ]] || \
  fail "legacy bootstrap canonical link should point at the legacy installed checkout"
[[ -x $legacy_canonical/bin/ryoku-doctor ]] || \
  fail "legacy bootstrap should make the canonical doctor path usable"

echo "PASS: ryoku-update-bootstrap exposes legacy installs at canonical path"

system_home="$tmp/system-home"
system_install="$system_home/.local/share/ryoku"
system_state="$system_home/.local/state/ryoku"
system_log="$tmp/system-bootstrap.log"
system_bin="$tmp/system-bin"
system_lib="$tmp/system-lib"
sudo_bin="$tmp/sudo-bin"

mkdir -p "$system_home/.local/bin" "$system_state" "$system_bin" "$system_lib" "$sudo_bin"
cat > "$sudo_bin/sudo" <<'SH'
#!/bin/bash
if [[ ${1:-} == "-n" ]]; then
  shift
fi

if [[ ${1:-} == "true" && $# == 1 ]]; then
  exit 0
fi

exec "$@"
SH
chmod 755 "$sudo_bin/sudo"

output=$(
  HOME="$system_home" \
  RYOKU_PATH="$system_install" \
  RYOKU_STATE_PATH="$system_state" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  RYOKU_UPDATE_BRANCH=unstable-dev \
  RYOKU_TEST_LOG="$system_log" \
  RYOKU_SYSTEM_BIN_DIR="$system_bin" \
  RYOKU_SYSTEM_LIB_DIR="$system_lib" \
  PATH="$sudo_bin:/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-update-bootstrap" 2>&1
) || fail "bootstrap should repair system Ryoku shims when sudo is already authorized: $output"

grep -Fq "System shims: repaired: $system_bin" <<< "$output" || \
  fail "bootstrap should report repaired system command shims"
[[ -L $system_bin/ryoku-doctor ]] || \
  fail "bootstrap should create the system doctor shim when sudo is authorized"
[[ $(readlink "$system_bin/ryoku-doctor") == "$system_install/bin/ryoku-doctor" ]] || \
  fail "system doctor shim should point at the installed checkout"
[[ -L $system_bin/ryoku ]] || \
  fail "bootstrap should create the system ryoku bridge when sudo is authorized"
[[ $(readlink "$system_bin/ryoku") == "$system_install/shell/scripts/ryoku" ]] || \
  fail "system ryoku bridge should point at the installed checkout"
[[ -L $system_lib/runtime-env.sh ]] || \
  fail "bootstrap should create the system runtime-env bridge when sudo is authorized"
[[ $(readlink "$system_lib/runtime-env.sh") == "$system_install/lib/runtime-env.sh" ]] || \
  fail "system runtime-env bridge should point at the installed checkout"

echo "PASS: ryoku-update-bootstrap repairs system command shims"
