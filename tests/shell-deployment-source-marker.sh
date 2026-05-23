#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

ryoku_path="$tmp_dir/ryoku"
shell_src="$ryoku_path/shell"
home_dir="$tmp_dir/home"
config_dir="$tmp_dir/config"
bin_dir="$tmp_dir/bin"
marker_file="$config_dir/quickshell/ryoku-shell/.ryoku-source-path"

mkdir -p "$shell_src/scripts" "$ryoku_path/bin" "$ryoku_path/lib" "$home_dir" "$config_dir" "$bin_dir"

cat >"$shell_src/scripts/ryoku-shell" <<'SH'
#!/bin/bash
exit 0
SH
chmod 755 "$shell_src/scripts/ryoku-shell"
printf '%s\n' 'shell payload' >"$shell_src/shell.qml"
printf '%s\n' 'runtime env' >"$ryoku_path/lib/runtime-env.sh"

cat >"$bin_dir/sudo" <<'SH'
#!/bin/bash
if [[ ${1:-} == "tee" ]]; then
  cat >/dev/null
fi
exit 0
SH
chmod 755 "$bin_dir/sudo"

cat >"$bin_dir/systemctl" <<'SH'
#!/bin/bash
exit 0
SH
chmod 755 "$bin_dir/systemctl"

PATH="$bin_dir:$PATH" \
HOME="$home_dir" \
XDG_CONFIG_HOME="$config_dir" \
RYOKU_PATH="$ryoku_path" \
  bash "$ROOT_DIR/install/preflight/ensure-shell-deployment.sh" >/dev/null

[[ -f $marker_file ]] || fail "shell deployment safety net should stamp the runtime source path"
[[ $(<"$marker_file") == "$ryoku_path" ]] || \
  fail "runtime source path should point at the installed Ryoku checkout"

echo "PASS: shell deployment stamps runtime source marker"
