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

launcher_log="$tmp_dir/launcher.log"
mkdir -p "$tmp_dir/bin"
cat >"$tmp_dir/bin/ryoku-launch-floating-terminal-with-presentation" <<SH
#!/bin/bash
printf '%s\n' "\$*" >>"$launcher_log"
SH
chmod 755 "$tmp_dir/bin/ryoku-launch-floating-terminal-with-presentation"

PATH="$tmp_dir/bin:$PATH" \
RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" start-update unstable-dev >"$status_json"

assert_json_expr "$status_json" '.ok == true and .branch == "unstable-dev"' \
  "start-update should launch only for the current checkout branch"
grep -Fq 'RYOKU_UPDATE_BRANCH=unstable-dev' "$launcher_log" || \
  fail "start-update should pass the selected update branch to ryoku-update"

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

PATH="$tmp_dir/bin:$PATH" \
RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" switch-channel main >"$status_json"

assert_json_expr "$status_json" '.ok == true and .channel == "main"' \
  "switch-channel should report the selected official channel"
tail -n 1 "$launcher_log" | grep -Fxq 'ryoku-channel-set main' || \
  fail "switch-channel should launch the selected channel command only"

echo "PASS: settings about pane"
