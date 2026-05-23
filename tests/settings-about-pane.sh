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

  grep -qF -- "$needle" "$ROOT_DIR/$file" || fail "$file should contain: $needle"
}

assert_json_expr() {
  local json_file="$1"
  local jq_expr="$2"
  local message="$3"

  jq -e "$jq_expr" "$json_file" >/dev/null || fail "$message"
}

helper="$ROOT_DIR/shell/scripts/ryoku-settings-about"
[[ -x $helper ]] || fail "ryoku-settings-about helper should be executable"

assert_contains "shell/modules/controlcenter/PaneRegistry.qml" 'readonly property string id: "about"'
assert_contains "shell/modules/controlcenter/PaneRegistry.qml" 'readonly property string group: "about"'
assert_contains "shell/modules/controlcenter/Panes.qml" 'import "about"'
assert_contains "shell/modules/controlcenter/NavRail.qml" 'group: "about"'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'https://github.com/basecamp/omarchy'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'https://github.com/caelestia-dots/shell'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'https://github.com/BlueManCZ/hyprmod'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'https://github.com/Darkkal44/qylock'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'RyokuAbout.startUpdate'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'Update now'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'Update available'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'No updates available'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'Commit descriptions'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'pendingChannel'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'showChannelSwitch'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'Package mirror'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'RyokuAbout.switchChannel(root.pendingChannel)'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'disabled: !root.modalReport.canStartUpdate'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'Update blocked'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'Update state'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'updateStateLabel'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'blockReason'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'readonly property real doctorOutputInset'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'x: root.doctorOutputInset'
assert_contains "shell/scripts/ryoku-settings-about" 'update-current-run'
assert_contains "shell/setup" '.ryoku-source-path'

if grep -Fq 'onClicked: RyokuAbout.switchChannel(channelButton.channel)' "$ROOT_DIR/shell/modules/controlcenter/about/AboutPane.qml"; then
  fail "channel cards should select intent, not launch a branch switch directly"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

direct_status_json="$tmp_dir/direct-status.json"
RYOKU_PATH="$tmp_dir/not-the-repo" \
RYOKU_STATE_PATH="$tmp_dir/direct-state" \
XDG_CONFIG_HOME="$tmp_dir/direct-config" \
  "$helper" status >"$direct_status_json"

assert_json_expr "$direct_status_json" ".ok == true and .path == \"$ROOT_DIR\"" \
  "repo helper should prefer its own checkout over a stale RYOKU_PATH"

runtime_home="$tmp_dir/runtime-home"
runtime_shell="$tmp_dir/runtime-shell"
runtime_source="$tmp_dir/runtime-source"
runtime_remote="$tmp_dir/runtime-remote.git"
runtime_remote_work="$tmp_dir/runtime-remote-work"
runtime_installed="$runtime_home/.local/share/ryoku"

mkdir -p "$runtime_shell/scripts" "$runtime_home/.local/share"
cp "$helper" "$runtime_shell/scripts/ryoku-settings-about"
chmod 755 "$runtime_shell/scripts/ryoku-settings-about"

git init "$runtime_source" >/dev/null
git -C "$runtime_source" config user.email test@example.invalid
git -C "$runtime_source" config user.name "Ryoku Test"
printf '0.2.0-source\n' >"$runtime_source/VERSION"
git -C "$runtime_source" add VERSION
git -C "$runtime_source" commit -m "source current" >/dev/null
git -C "$runtime_source" switch -q -c unstable-dev

git init --bare "$runtime_remote" >/dev/null
git -C "$runtime_source" remote add origin "$runtime_remote"
git -C "$runtime_source" push -u origin unstable-dev >/dev/null 2>&1
git clone "$runtime_remote" "$runtime_installed" >/dev/null 2>&1
git -C "$runtime_installed" switch -q unstable-dev
git clone "$runtime_remote" "$runtime_remote_work" >/dev/null 2>&1
git -C "$runtime_remote_work" switch -q unstable-dev
git -C "$runtime_remote_work" config user.email test@example.invalid
git -C "$runtime_remote_work" config user.name "Ryoku Test"
printf '%s\n' "installed update" >"$runtime_remote_work/CHANGELOG"
git -C "$runtime_remote_work" add CHANGELOG
git -C "$runtime_remote_work" commit -m "runtime installed update" >/dev/null
git -C "$runtime_remote_work" push origin unstable-dev >/dev/null 2>&1

printf '%s\n' "$runtime_source" >"$runtime_shell/.ryoku-source-path"

runtime_status_json="$tmp_dir/runtime-status.json"
HOME="$runtime_home" \
RYOKU_STATE_PATH="$tmp_dir/runtime-state" \
RYOKU_UPDATE_REMOTE_URL="$runtime_remote" \
XDG_CONFIG_HOME="$tmp_dir/runtime-config" \
  "$runtime_shell/scripts/ryoku-settings-about" check-updates >"$runtime_status_json"

assert_json_expr "$runtime_status_json" ".ok == true and .path == \"$runtime_installed\"" \
  "runtime helper should check updates against the installed checkout, not the live source path"
assert_json_expr "$runtime_status_json" '.updateAvailable == true and .behindCount == 1 and .incoming[0].subject == "runtime installed update"' \
  "runtime helper should report updates that are pending for the installed checkout"
assert_json_expr "$runtime_status_json" ".sourcePath == \"$runtime_source\" and .updatePath == \"$runtime_installed\"" \
  "runtime helper should expose both live source path and installed update path"

repo="$tmp_dir/repo"
git init "$repo" >/dev/null
git -C "$repo" config user.email test@example.invalid
git -C "$repo" config user.name "Ryoku Test"
printf '0.1.0-test\n' >"$repo/VERSION"
git -C "$repo" add VERSION
git -C "$repo" commit -m "initial" >/dev/null
git -C "$repo" switch -q -c rebirth

status_json="$tmp_dir/status.json"
RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" status >"$status_json"

assert_json_expr "$status_json" '.ok == true and (.version | startswith("0.1.0-test"))' \
  "status output should include Ryoku version"
assert_json_expr "$status_json" '.currentBranch == "rebirth" and .updateBranch == "rebirth"' \
  "status output should report the checkout branch as the update branch"
assert_json_expr "$status_json" '.configuredChannel == "main"' \
  "status output should default to main channel"
assert_json_expr "$status_json" '.packageChannel == "main" and .officialCheckout == false and .channelMatchesCheckout == false and .checkoutMode == "custom"' \
  "status output should distinguish custom checkouts from official update channels"
assert_json_expr "$status_json" '([.channels[].id] | index("main") and index("unstable-dev") and (index("rebirth") | not))' \
  "channel options should remain limited to main and unstable-dev"

git -C "$repo" switch -q -c unstable-dev
mkdir -p "$tmp_dir/state"
printf '%s\n' "main" >"$tmp_dir/state/channel"

RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" status >"$status_json"

assert_json_expr "$status_json" '.currentBranch == "unstable-dev" and .configuredChannel == "main" and .updateBranch == "unstable-dev"' \
  "status output should keep update checks on the current checkout branch when channel state drifts"
assert_json_expr "$status_json" '.officialCheckout == true and .channelMatchesCheckout == false and .checkoutMode == "mismatch"' \
  "status output should report official checkout/channel mismatches"

printf '%s\n' "unstable-dev" >"$tmp_dir/state/channel"

RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" status >"$status_json"

assert_json_expr "$status_json" '.officialCheckout == true and .channelMatchesCheckout == true and .checkoutMode == "official"' \
  "status output should report official checkouts when branch and channel match"

remote_repo="$tmp_dir/remote.git"
remote_work="$tmp_dir/remote-work"
git init --bare "$remote_repo" >/dev/null
git -C "$repo" remote add origin "$remote_repo"
git -C "$repo" push -u origin unstable-dev >/dev/null 2>&1
git clone "$remote_repo" "$remote_work" >/dev/null 2>&1
git -C "$remote_work" switch -q unstable-dev
git -C "$remote_work" config user.email test@example.invalid
git -C "$remote_work" config user.name "Ryoku Test"
printf '%s\n' "incoming update" >"$remote_work/CHANGELOG"
git -C "$remote_work" add CHANGELOG
git -C "$remote_work" commit -m "describe incoming update" >/dev/null
git -C "$remote_work" push origin unstable-dev >/dev/null 2>&1

RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
RYOKU_UPDATE_REMOTE_URL="$remote_repo" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" check-updates >"$status_json"

assert_json_expr "$status_json" '.ok == true and .updateAvailable == true and .canStartUpdate == true and .behindCount == 1' \
  "check-updates should expose an available fast-forward update"
assert_json_expr "$status_json" '.incoming[0].subject == "describe incoming update"' \
  "check-updates should include incoming commit descriptions"
assert_json_expr "$status_json" '.updateState == "ready" and .updateStateLabel == "Ready to update"' \
  "check-updates should classify fast-forward updates as ready"

launcher_log="$tmp_dir/launcher.log"
mkdir -p "$tmp_dir/bin"
cat >"$tmp_dir/bin/ryoku-launch-floating-terminal-with-presentation" <<SH
#!/bin/bash
printf '%s\n' "\$*" >>"$launcher_log"
SH
chmod 755 "$tmp_dir/bin/ryoku-launch-floating-terminal-with-presentation"

mkdir -p "$repo/bin"
cat >"$repo/bin/ryoku-update" <<'SH'
#!/bin/bash
exit 0
SH
chmod 755 "$repo/bin/ryoku-update"

PATH="$tmp_dir/bin:$PATH" \
RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
RYOKU_UPDATE_REMOTE_URL="$remote_repo" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" start-update unstable-dev >"$status_json"

assert_json_expr "$status_json" '.ok == true and .branch == "unstable-dev"' \
  "start-update should launch only for the current checkout branch"
grep -Fq 'RYOKU_UPDATE_BRANCH=unstable-dev' "$launcher_log" || \
  fail "start-update should pass the selected update branch to ryoku-update"

printf '%s\n' "local divergent work" >"$repo/LOCAL"
git -C "$repo" add LOCAL
git -C "$repo" commit -m "local divergent work" >/dev/null

RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
RYOKU_UPDATE_REMOTE_URL="$remote_repo" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" check-updates >"$status_json"

assert_json_expr "$status_json" '.ok == true and .updateAvailable == true and .canStartUpdate == false and .updateState == "blocked"' \
  "check-updates should block divergent checkouts"
assert_json_expr "$status_json" '.blockReason | contains("cannot fast-forward")' \
  "blocked update checks should explain the fast-forward problem"

set +e
PATH="$tmp_dir/bin:$PATH" \
RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
RYOKU_UPDATE_REMOTE_URL="$remote_repo" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" start-update unstable-dev >"$status_json"
diverged_start_status=$?
set -e

(( diverged_start_status != 0 )) || fail "start-update should refuse divergent checkouts"
assert_json_expr "$status_json" '.ok == false and (.error | contains("cannot fast-forward"))' \
  "start-update should explain why a divergent checkout is blocked"

set +e
PATH="$tmp_dir/bin:$PATH" \
RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" start-update main >"$status_json"
start_status=$?
set -e

(( start_status != 0 )) || fail "start-update should return non-zero when refusing the wrong checkout branch"

assert_json_expr "$status_json" '.ok == false and (.error | contains("Refusing to update main while checkout is unstable-dev"))' \
  "start-update should refuse to update a branch that is not checked out"

doctor_log="$tmp_dir/doctor.log"
doctor_env_log="$tmp_dir/doctor-env.log"
cat >"$tmp_dir/bin/ryoku-doctor" <<SH
#!/bin/bash
printf '%s\n' "\$*" >"$doctor_log"
printf '%s\n' "\${RYOKU_DOCTOR_ASSUME_NO:-}" >"$doctor_env_log"
printf '%s\n' "Ryoku Doctor: global"
SH
chmod 755 "$tmp_dir/bin/ryoku-doctor"

PATH="$tmp_dir/bin:$PATH" \
RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" doctor >"$status_json"

doctor_args="$(<"$doctor_log")"
[[ $doctor_args == "" ]] || fail "settings doctor should call global ryoku-doctor without forcing the shell subcommand"
doctor_assume_no="$(<"$doctor_env_log")"
[[ $doctor_assume_no == "1" ]] || fail "settings doctor should run global ryoku-doctor in non-interactive mode"
assert_json_expr "$status_json" '.ok == true and (.output | contains("Ryoku Doctor: global"))' \
  "settings doctor should expose global doctor output"

cat >"$repo/bin/ryoku-doctor" <<'SH'
#!/bin/bash
printf '%s\n' "Ryoku Doctor: checkout"
SH
chmod 755 "$repo/bin/ryoku-doctor"

PATH="$tmp_dir/bin:$PATH" \
RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" doctor >"$status_json"

assert_json_expr "$status_json" '.ok == true and (.output | contains("Ryoku Doctor: checkout"))' \
  "settings doctor should prefer the active Ryoku checkout doctor over a stale PATH doctor"

cat >"$repo/bin/ryoku-channel-set" <<'SH'
#!/bin/bash
exit 0
SH
chmod 755 "$repo/bin/ryoku-channel-set"

PATH="$tmp_dir/bin:$PATH" \
RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" switch-channel main >"$status_json"

assert_json_expr "$status_json" '.ok == true and .channel == "main"' \
  "switch-channel should report the selected official channel"
switch_command="$(tail -n 1 "$launcher_log")"
grep -Fq "RYOKU_PATH=$repo" <<<"$switch_command" || \
  fail "switch-channel should pin the active checkout path"
grep -Fq "$repo/bin/ryoku-channel-set main" <<<"$switch_command" || \
  fail "switch-channel should launch the active checkout channel command only"

echo "PASS: settings about pane"
