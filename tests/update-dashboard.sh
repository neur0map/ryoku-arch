#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT_DIR/lib/update-dashboard.sh"
UPDATE="$ROOT_DIR/bin/ryoku-update"
PERFORM="$ROOT_DIR/bin/ryoku-update-perform"
SHELL_UPDATES_QML="$ROOT_DIR/shell/services/ShellUpdates.qml"
INSTALL_SHELL="$ROOT_DIR/install/config/shell.sh"
SHELL_SETUP="$ROOT_DIR/shell/setup"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $HELPER ]] || fail "missing shared update dashboard helper"
[[ -f $UPDATE ]] || fail "missing ryoku-update"
[[ -f $PERFORM ]] || fail "missing ryoku-update-perform"
[[ -f $SHELL_UPDATES_QML ]] || fail "missing ShellUpdates.qml"
[[ -f $INSTALL_SHELL ]] || fail "missing shell config installer"
[[ -f $SHELL_SETUP ]] || fail "missing shell setup entrypoint"

rg -q 'ryoku_update_brand_logo' "$HELPER" \
  || fail "dashboard helper should render the Ryoku brand logo"
rg -q 'https://discord.gg/8KjBmUEyKA' "$HELPER" \
  || fail "dashboard success footer should include the Ryoku Discord link"
rg -q 'https://www.reddit.com/r/RyokuArch/' "$HELPER" \
  || fail "dashboard success footer should include the Ryoku subreddit link"

rg -q 'ryoku_update_default_log' "$UPDATE" \
  || fail "core updater should default to the shell-visible update log"
rg -q 'quickshell/user' "$UPDATE" && rg -q 'update\.log' "$UPDATE" \
  || fail "core updater should refresh ~/.local/state/quickshell/user/update.log by default"
rg -q 'ryoku_update_run_stage' "$PERFORM" \
  || fail "core updater should route visible phases through the dashboard stage helper"

for label in \
  "Arch signing keys" \
  "System packages" \
  "Ryoku base packages" \
  "AUR packages" \
  "Ryoku shell" \
  "Migrations" \
  "Cleanup and restart"; do
  rg -q "$label" "$PERFORM" \
    || fail "core updater should expose the '$label' stage to the dashboard"
done

rg -q 'ryoku-update -y' "$SHELL_UPDATES_QML" \
  || fail "shell updater should keep launching the core ryoku-update pipeline"
rg -q './bin/ryoku-update -y' "$SHELL_UPDATES_QML" \
  || fail "shell updater should prefer the repo core updater before shell-only fallback"
rg -q "RYOKU_UPDATE_LOG='/tmp/ryoku-update.log' ryoku-update -y" "$SHELL_UPDATES_QML" \
  || fail "shell updater should keep the inner pty log separate from its visible tee log"
rg -q "RYOKU_UPDATE_LOG='/tmp/ryoku-update.log' ./bin/ryoku-update -y" "$SHELL_UPDATES_QML" \
  || fail "shell updater repo fallback should keep the inner pty log separate from its visible tee log"

rg -q 'RYOKU_CORE_UPDATE_CHILD=1 IS_UPDATE=true ./setup install -y -q --skip-deps --skip-setups --skip-sysupdate' "$INSTALL_SHELL" \
  || fail "core shell update should run shell setup in quiet child mode"
rg -q 'run_install_core_update_child' "$SHELL_SETUP" \
  || fail "shell setup should have a non-nested updater path"
rg -q 'RYOKU_CORE_UPDATE_CHILD:-0' "$SHELL_SETUP" \
  || fail "shell setup should detect core updater child mode"
rg -q 'RYOKU_SHELL_VENV' "$ROOT_DIR/config/niri/config.d/40-environment.kdl" \
  || fail "Ryoku Niri defaults should export canonical RYOKU_SHELL_VENV"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

XDG_STATE_HOME="$tmp/state"
export XDG_STATE_HOME

setup_output=$(
  HOME="$tmp/home" \
  XDG_CONFIG_HOME="$tmp/config" \
  XDG_DATA_HOME="$tmp/data" \
  XDG_STATE_HOME="$tmp/setup-state" \
  XDG_CACHE_HOME="$tmp/cache" \
  XDG_BIN_HOME="$tmp/bin" \
  RYOKU_CORE_UPDATE_CHILD=1 \
  IS_UPDATE=true \
  TERM=xterm \
  bash "$SHELL_SETUP" install -y -q --skip-deps --skip-setups --skip-files --skip-sysupdate
)

[[ $setup_output != *"Setup bootstrap"* ]] \
  || fail "core updater child mode should not render setup bootstrap"
[[ $setup_output != *"Installation progress"* ]] \
  || fail "core updater child mode should not render nested setup progress UI"
[[ $setup_output == *"conflict scan skipped during core update"* ]] \
  || fail "core updater child mode should not run install-time conflict removals"

mkdir -p "$tmp/fake-bin"
cat >"$tmp/fake-bin/uv" <<'UV'
#!/bin/bash
set -e

if [[ ${1:-} == "venv" ]]; then
  venv_dir=""
  for arg in "$@"; do
    [[ $arg == /* ]] && venv_dir="$arg"
  done
  [[ -n $venv_dir ]] || exit 1
  mkdir -p "$venv_dir/bin"
  printf '%s\n' '# no-op test activate' 'deactivate() { :; }' >"$venv_dir/bin/activate"
  printf '%s\n' '#!/bin/bash' 'exec python3 "$@"' >"$venv_dir/bin/python"
  chmod +x "$venv_dir/bin/python"
  exit 0
fi

if [[ ${1:-} == "pip" ]]; then
  exit 0
fi

exit 1
UV
cat >"$tmp/fake-bin/systemctl" <<'SYSTEMCTL'
#!/bin/bash
exit 0
SYSTEMCTL
cat >"$tmp/fake-bin/pkexec" <<'PKEXEC'
#!/bin/bash
exit 1
PKEXEC
cat >"$tmp/fake-bin/sudo" <<'SUDO'
#!/bin/bash
exit 1
SUDO
chmod +x "$tmp/fake-bin/uv"
chmod +x "$tmp/fake-bin/systemctl"
chmod +x "$tmp/fake-bin/pkexec"
chmod +x "$tmp/fake-bin/sudo"
mkdir -p "$tmp/full-home"

full_setup_output=$(
  PATH="$tmp/fake-bin:$PATH" \
  HOME="$tmp/full-home" \
  XDG_CONFIG_HOME="$tmp/full-config" \
  XDG_DATA_HOME="$tmp/full-data" \
  XDG_STATE_HOME="$tmp/full-state" \
  XDG_CACHE_HOME="$tmp/full-cache" \
  XDG_BIN_HOME="$tmp/full-bin" \
  RYOKU_CORE_UPDATE_CHILD=1 \
  IS_UPDATE=true \
  SKIP_MIGRATIONS=true \
  SKIP_VERIFICATION=true \
  TERM=xterm \
  bash "$SHELL_SETUP" install -y -q --skip-deps --skip-setups --skip-backup --skip-sysupdate
)

[[ $full_setup_output != *"Configuring default applications"* ]] \
  || fail "core shell update should not run default-app setup every update"
[[ $full_setup_output != *"Copying wallpapers"* ]] \
  || fail "core shell update should not run wallpaper copy every update"
[[ $full_setup_output != *"RYOKU_SHELL_VENV not found in Niri config"* ]] \
  || fail "Niri env verification should inspect config.d fragments"

# The dashboard helper must keep child commands attached to the caller's stdin.
# sudo, pacman, yay, and migration/reboot prompts rely on this behavior.
# shellcheck source=../lib/update-dashboard.sh
source "$HELPER"

TERM=xterm RYOKU_UPDATE_LOG="$tmp/start.log" bash -lc '
set -e
source "$1"
stages=("Startup")
ryoku_update_dashboard_start 1 "${stages[@]}"
ryoku_update_dashboard_finish success
' _ "$HELPER" >/dev/null

footer_output=$(
  TERM=xterm NO_COLOR=1 RYOKU_UPDATE_DASHBOARD=0 RYOKU_UPDATE_LOG="$tmp/footer.log" bash -lc '
  set -e
  source "$1"
  stages=("Startup")
  ryoku_update_dashboard_start 1 "${stages[@]}"
  ryoku_update_dashboard_finish success
  ' _ "$HELPER"
)

[[ $footer_output == *"Thanks for updating Ryoku."* ]] \
  || fail "success footer should thank users after updates"
[[ $footer_output == *"Discord: https://discord.gg/8KjBmUEyKA"* ]] \
  || fail "success footer should print the Discord link"
[[ $footer_output == *"Subreddit: https://www.reddit.com/r/RyokuArch/"* ]] \
  || fail "success footer should print the subreddit link"

output=$(
  printf 'typed-through\n' | ryoku_update_run_stage 3 7 "Prompt passthrough" \
    bash -c 'read -r answer; printf "answer=%s\n" "$answer"'
)

[[ $output == *"answer=typed-through"* ]] \
  || fail "stage helper should not swallow stdin needed by sudo/package prompts"

status_file="$XDG_STATE_HOME/quickshell/user/update-status"
[[ -f $status_file ]] || fail "stage helper should write shell-visible update progress"
[[ $(<"$status_file") == "progress:3:7:Prompt passthrough" ]] \
  || fail "stage helper should write progress markers in ShellUpdates format"

restart_tmp="$tmp/restart"
mkdir -p "$restart_tmp/bin" "$restart_tmp/state/quickshell/user" "$restart_tmp/home"
cat >"$restart_tmp/bin/systemctl" <<'SYSTEMCTL'
#!/bin/bash

log="${RYOKU_TEST_SYSTEMCTL_LOG:?}"
printf '%s\n' "$*" >>"$log"

if [[ ${1:-} == "--user" && ${2:-} == "is-active" ]]; then
  exit 3
fi

if [[ ${1:-} == "--user" && ${2:-} == "is-enabled" ]]; then
  exit 0
fi

exit 0
SYSTEMCTL
chmod +x "$restart_tmp/bin/systemctl"

RYOKU_STATE_PATH="$restart_tmp/ryoku-state" \
RYOKU_TEST_SYSTEMCTL_LOG="$restart_tmp/systemctl.log" \
XDG_STATE_HOME="$restart_tmp/state" \
HOME="$restart_tmp/home" \
PATH="$restart_tmp/bin:$PATH" \
  bash "$ROOT_DIR/bin/ryoku-update-restart" >/dev/null

grep -Fq -- "--user start ryoku-shell.service" "$restart_tmp/systemctl.log" \
  || fail "update restart should start enabled ryoku-shell.service when setup killed it"
[[ $(<"$restart_tmp/state/quickshell/user/update-status") == "success" ]] \
  || fail "update restart should still mark shell update status successful"

export RYOKU_UPDATE_DASHBOARD_ACTIVE=1
ryoku_update_install_dashboard_gum_shim
if ! printf 'y\n' | bash -c 'gum confirm "Nested migration prompt?"' >/dev/null; then
  fail "dashboard gum confirm shim should keep child Bash migration prompts interactive"
fi

ROOT_DIR="$ROOT_DIR" python - <<'PY'
import os
import pty
import select
import shutil
import subprocess
import sys
import tempfile
import time

repo = os.environ["ROOT_DIR"]
tmp = tempfile.mkdtemp()
cmd = r'''set -e
source lib/update-dashboard.sh
stages=("Prepare" "Prompt passthrough" "Finish")
ryoku_update_dashboard_start 3 "${stages[@]}"
ryoku_update_run_stage 1 3 "Prepare" bash -c 'printf "ready\n"'
ryoku_update_run_stage 2 3 "Prompt passthrough" bash -c 'printf "Prompt> "; read -r answer; printf "got:%s\n" "$answer"'
ryoku_update_run_stage 3 3 "Finish" bash -c 'printf "done\n"'
ryoku_update_dashboard_finish success
'''

controller_fd, child_fd = pty.openpty()
env = os.environ.copy()
env["TERM"] = "xterm"
env["XDG_STATE_HOME"] = os.path.join(tmp, "state")
env["RYOKU_UPDATE_LOG"] = os.path.join(tmp, "update.log")
proc = subprocess.Popen(
  ["bash", "-lc", cmd],
  cwd=repo,
  env=env,
  stdin=child_fd,
  stdout=child_fd,
  stderr=child_fd,
  close_fds=True,
)
os.close(child_fd)

output = bytearray()
sent = False
deadline = time.time() + 5

while time.time() < deadline:
  ready, _, _ = select.select([controller_fd], [], [], 0.1)
  if controller_fd in ready:
    try:
      chunk = os.read(controller_fd, 4096)
    except OSError:
      break
    if not chunk:
      break
    output.extend(chunk)
    if not sent and b"Prompt>" in output:
      os.write(controller_fd, b"typed-through\n")
      sent = True

  if proc.poll() is not None:
    break

try:
  os.close(controller_fd)
except OSError:
  pass

rc = proc.wait(timeout=2)
text = output.decode("utf-8", "replace")
if rc != 0 or not sent or "got:typed-through" not in text:
  sys.stderr.write("dashboard PTY prompt passthrough failed\n")
  sys.stderr.write(text)
  shutil.rmtree(tmp, ignore_errors=True)
  sys.exit(1)
shutil.rmtree(tmp, ignore_errors=True)
PY

echo "PASS: update dashboard stages preserve prompts and shell progress"
