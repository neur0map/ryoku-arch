#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SETUP="$ROOT_DIR/shell/setup"
INSTALL_CONFIG_SHELL="$ROOT_DIR/install/config/shell.sh"
INSTALL_FILES_SH="$ROOT_DIR/shell/sdata/subcmd-install/3.files.sh"
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

extract_bootstrap_function() {
  awk '
    /^resolve_bootstrap_repo_root\(\) \{/ { capture = 1 }
    capture { print }
    capture && /^}/ { exit }
  ' "$SETUP"
}

[[ -f $SETUP ]] || fail "missing shell/setup"
[[ -f $INSTALL_CONFIG_SHELL ]] || fail "missing install/config/shell.sh"
[[ -f $INSTALL_FILES_SH ]] || fail "missing shell/sdata/subcmd-install/3.files.sh"
[[ -f $SHELL_UPDATES_QML ]] || fail "missing ShellUpdates.qml"
[[ -f $FUNCTIONS_SH ]] || fail "missing functions.sh"
[[ -f $ROBUST_UPDATE_SH ]] || fail "missing robust-update.sh"

vendor_sync_block=$(awk '
  /rsync -a/ { capture = 1 }
  capture { print }
  capture && /\$SHELL_VENDOR\/\./ { exit }
' "$INSTALL_CONFIG_SHELL")

[[ $vendor_sync_block == *"--delete"* ]] || \
  fail "install/config/shell.sh should delete stale files from ~/.local/share/ryoku-shell during vendor sync"

[[ $vendor_sync_block == *"--delete-excluded"* ]] || \
  fail "install/config/shell.sh should remove stale dev-only files from ~/.local/share/ryoku-shell during vendor sync"

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

rg -q "matches_repo_source" "$SHELL_UPDATES_QML" || \
  fail "shell local-mod detection should ignore stale manifest mismatches when runtime files match repo source"

rg -q 'scripts/ryoku-shell' "$SHELL_UPDATES_QML" || \
  fail "shell updater repo detection should require Ryoku shell launcher shape"

! rg -q 'omarchy|illogical-impulse|quickshell/ii' "$SHELL_UPDATES_QML" || \
  fail "shell updater repo search should not fall back to old shell paths"

rg -q "repo_worktree_hash" "$SHELL_UPDATES_QML" || \
  fail "shell local-mod detection should compare checksum mismatches against the repo working tree"

rg -q 'repo_content_hash HEAD' "$SHELL_UPDATES_QML" || \
  fail "shell local-mod detection should compare checksum mismatches against local repo HEAD"

rg -q 'repo_content_hash \\"\$remote_ref\\"' "$SHELL_UPDATES_QML" || \
  fail "shell local-mod detection should compare checksum mismatches against fetched remote source"

rg -q 'write_version_info_json "\$\{II_TARGET\}/version\.json" "\$\(get_repo_version\)" "\$\(get_repo_commit\)" "setup-install"' "$INSTALL_FILES_SH" || \
  fail "runtime version.json should use shared metadata helpers"

! rg -q 'cat "\$\{REPO_ROOT\}/VERSION"|git -C "\$\{REPO_ROOT\}" rev-parse --short HEAD' "$INSTALL_FILES_SH" || \
  fail "runtime version.json should not bypass shared metadata helpers"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/repo/scripts" "$tmp_dir/bin" "$tmp_dir/home"
printf '%s\n' '#!/bin/bash' 'exit 0' > "$tmp_dir/repo/scripts/ryoku-shell"
chmod +x "$tmp_dir/repo/scripts/ryoku-shell"
ln -s "$tmp_dir/repo/scripts/ryoku-shell" "$tmp_dir/bin/ryoku-shell"

REPO_ROOT="$tmp_dir/repo"
export XDG_BIN_HOME="$tmp_dir/bin"
export HOME="$tmp_dir/home"
export PATH="$tmp_dir/bin:$PATH"
ensure_launcher_path_in_shells() { :; }

eval "$(extract_sync_launcher_function)"

if ! sync_launcher_from_repo >/dev/null 2>"$tmp_dir/launcher.err"; then
  fail "launcher sync should not fail when target is a symlink to the repo launcher"
fi

[[ ! -s $tmp_dir/launcher.err ]] || \
  fail "launcher sync should not emit cp same-file errors"

export STY_BLUE=""
export STY_RST=""
export INSTALLED_LISTFILE="$tmp_dir/installed-list"
x() { "$@"; }

eval "$(extract_cp_file_function)"

if ! cp_file "$tmp_dir/repo/scripts/ryoku-shell" "$tmp_dir/bin/ryoku-shell" >/dev/null 2>"$tmp_dir/cp-file.err"; then
  fail "shared file copy helper should not fail when target is a symlink to source"
fi

[[ ! -s $tmp_dir/cp-file.err ]] || \
  fail "shared file copy helper should not emit cp same-file errors"

export XDG_CONFIG_HOME="$tmp_dir/xdg-config"
export XDG_STATE_HOME="$tmp_dir/xdg-state"
runtime_target="$tmp_dir/.config/quickshell/ryoku-shell"
metadata_repo="$tmp_dir/metadata-repo"
vendored_shell="$tmp_dir/ryoku-shell"
mkdir -p \
  "$REPO_ROOT/sdata" \
  "$metadata_repo/shell" \
  "$vendored_shell" \
  "$runtime_target/docs/javascripts" \
  "$runtime_target/distro/arch/stale-runtime-git"

printf '9.9.9\n' > "$metadata_repo/VERSION"
touch "$metadata_repo/shell/setup" "$metadata_repo/shell/shell.qml"
touch "$vendored_shell/setup" "$vendored_shell/shell.qml"
git -C "$metadata_repo" init -q
git -C "$metadata_repo" config user.email "tests@example.invalid"
git -C "$metadata_repo" config user.name "Ryoku Tests"
git -C "$metadata_repo" add VERSION shell/setup shell/shell.qml
git -C "$metadata_repo" commit -qm "seed metadata repo"

eval "$(extract_bootstrap_function)"

# shellcheck disable=SC2053 # AGENTS.md keeps variables unquoted in [[ ]].
[[ $(resolve_bootstrap_repo_root "$vendored_shell") == $vendored_shell ]] || \
  fail "setup bootstrap should allow detached vendored shell payloads"

REPO_ROOT="$vendored_shell"
RYOKU_PATH="$metadata_repo"
export RYOKU_PATH
# shellcheck source=shell/sdata/lib/versioning.sh
source "$ROOT_DIR/shell/sdata/lib/versioning.sh"

[[ $(get_repo_version) == "9.9.9" ]] || \
  fail "setup should record the Ryoku repo version when running from detached shell payload"

[[ $(get_repo_commit) != "unknown" ]] || \
  fail "setup should record the Ryoku repo commit when running from detached shell payload"

[[ $(get_install_mode) == "repo-copy" ]] || \
  fail "detached shell payloads sourced from RYOKU_PATH should be treated as repo-copy installs"

[[ $(get_update_strategy) == "repo-setup" ]] || \
  fail "detached shell payloads sourced from RYOKU_PATH should keep repo-setup updates"

# shellcheck disable=SC2053 # AGENTS.md keeps variables unquoted in [[ ]].
[[ $(get_version_repo_path) == $metadata_repo ]] || \
  fail "version metadata should point ShellUpdates at the Ryoku repo root"

printf '%s\n' '# ryoku-manifest v2' 'shell.qml:' > "$runtime_target/.ryoku-manifest"
touch \
  "$runtime_target/shell.qml" \
  "$runtime_target/docs/javascripts/mathjax.js" \
  "$runtime_target/distro/arch/stale-runtime-git/.SRCINFO" \
  "$runtime_target/distro/arch/stale-runtime-git/PKGBUILD" \
  "$runtime_target/distro/arch/stale-runtime-git/stale-runtime-git.install" \
  "$runtime_target/distro/arch/stale-runtime-git/publish-aur.sh"

log_info() { :; }
# shellcheck source=shell/sdata/lib/robust-update.sh
# shellcheck disable=SC1091
source "$ROBUST_UPDATE_SH"

cleanup_orphans "$runtime_target" "$runtime_target/.ryoku-manifest"

[[ ! -e $runtime_target/docs/javascripts/mathjax.js ]] || \
  fail "orphan cleanup should remove tracked files outside current payload directories"

[[ ! -e $runtime_target/distro/arch/stale-runtime-git/publish-aur.sh ]] || \
  fail "orphan cleanup should remove stale full-repo runtime files"

[[ ! -e $runtime_target/distro/arch/stale-runtime-git/PKGBUILD ]] || \
  fail "orphan cleanup should remove stale package build files"

[[ ! -e $runtime_target/distro/arch/stale-runtime-git/.SRCINFO ]] || \
  fail "orphan cleanup should remove stale package metadata files"

[[ ! -e $runtime_target/distro/arch/stale-runtime-git/stale-runtime-git.install ]] || \
  fail "orphan cleanup should remove stale package install hook files"

echo "PASS: shell update runtime manifest stays authoritative"
