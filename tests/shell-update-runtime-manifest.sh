#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SETUP="$ROOT_DIR/shell/setup"
SHELL_UPDATES_QML="$ROOT_DIR/shell/services/ShellUpdates.qml"
FUNCTIONS_SH="$ROOT_DIR/shell/sdata/lib/functions.sh"
ROBUST_UPDATE_SH="$ROOT_DIR/shell/sdata/lib/robust-update.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

extract_sync_launcher_function() {
  awk '
    /^sync_launcher_from_repo\(\) \{/ { capture = 1 }
    capture { print }
    capture && /^}/ { exit }
  ' "$SETUP"
}

extract_cp_file_function() {
  awk '
    /^cp_file\(\)\{/ { capture = 1 }
    capture { print }
    capture && /^}/ { exit }
  ' "$FUNCTIONS_SH"
}

[[ -f $SETUP ]] || fail "missing shell/setup"
[[ -f $SHELL_UPDATES_QML ]] || fail "missing ShellUpdates.qml"
[[ -f $FUNCTIONS_SH ]] || fail "missing functions.sh"
[[ -f $ROBUST_UPDATE_SH ]] || fail "missing robust-update.sh"

rg -q 'sync_launcher_from_repo' "$SETUP" || \
  fail "setup should install or refresh the ryoku-shell launcher"

! rg -q 'cp -f "\$\{REPO_ROOT\}/scripts/ryoku-shell" "\$launcher_target"' "$SETUP" || \
  fail "setup should not use direct launcher cp that fails when source and destination are the same file"

rg -q 'readlink -f "\$launcher_src"' "$SETUP" || \
  fail "launcher sync should compare real paths before copying"

rg -q 'readlink -f "\$src"' "$FUNCTIONS_SH" || \
  fail "shared file copy helper should follow symlinks before copying"

rg -q 'generate_manifest "\$II_SOURCE" "\$\{II_TARGET\}/\.ryoku-manifest"' "$SETUP" || \
  fail "setup update should regenerate the manifest path used by the shell"

! rg -q '\.ryoku-shell-manifest' "$SETUP" || \
  fail "setup update should not write a stale alternate shell manifest"

rg -q "manifest_v2='false'" "$SHELL_UPDATES_QML" || \
  fail "shell local-mod detection should detect v2 manifests"

rg -q '\[\[ \\"\$manifest_v2\\" != \\"true\\" && -d \\"\$repo/\.git\\" \]\]' "$SHELL_UPDATES_QML" || \
  fail "v2 manifest entries without checksums should not be compared against moving repo HEAD"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/repo/scripts" "$tmp_dir/bin" "$tmp_dir/home"
printf '%s\n' '#!/bin/bash' 'exit 0' > "$tmp_dir/repo/scripts/ryoku-shell"
chmod +x "$tmp_dir/repo/scripts/ryoku-shell"
ln -s "$tmp_dir/repo/scripts/ryoku-shell" "$tmp_dir/bin/ryoku-shell"

REPO_ROOT="$tmp_dir/repo"
XDG_BIN_HOME="$tmp_dir/bin"
HOME="$tmp_dir/home"
PATH="$tmp_dir/bin:$PATH"
ensure_launcher_path_in_shells() { :; }

eval "$(extract_sync_launcher_function)"

if ! sync_launcher_from_repo >/dev/null 2>"$tmp_dir/launcher.err"; then
  fail "launcher sync should not fail when target is a symlink to the repo launcher"
fi

[[ ! -s $tmp_dir/launcher.err ]] || \
  fail "launcher sync should not emit cp same-file errors"

STY_BLUE=""
STY_RST=""
INSTALLED_LISTFILE="$tmp_dir/installed-list"
x() { "$@"; }

eval "$(extract_cp_file_function)"

if ! cp_file "$tmp_dir/repo/scripts/ryoku-shell" "$tmp_dir/bin/ryoku-shell" >/dev/null 2>"$tmp_dir/cp-file.err"; then
  fail "shared file copy helper should not fail when target is a symlink to source"
fi

[[ ! -s $tmp_dir/cp-file.err ]] || \
  fail "shared file copy helper should not emit cp same-file errors"

XDG_CONFIG_HOME="$tmp_dir/xdg-config"
XDG_STATE_HOME="$tmp_dir/xdg-state"
runtime_target="$tmp_dir/runtime"
mkdir -p \
  "$REPO_ROOT/sdata" \
  "$runtime_target/docs/javascripts" \
  "$runtime_target/distro/arch/inir-shell-git"

printf '%s\n' '# ryoku-manifest v2' 'shell.qml:' > "$runtime_target/.ryoku-manifest"
touch \
  "$runtime_target/shell.qml" \
  "$runtime_target/docs/javascripts/mathjax.js" \
  "$runtime_target/distro/arch/inir-shell-git/publish-aur.sh"

log_info() { :; }
source "$ROBUST_UPDATE_SH"

cleanup_orphans "$runtime_target" "$runtime_target/.ryoku-manifest"

[[ ! -e $runtime_target/docs/javascripts/mathjax.js ]] || \
  fail "orphan cleanup should remove tracked files outside current payload directories"

[[ ! -e $runtime_target/distro/arch/inir-shell-git/publish-aur.sh ]] || \
  fail "orphan cleanup should remove stale full-repo runtime files"

echo "PASS: shell update runtime manifest stays authoritative"
