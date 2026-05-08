# Ensure the Ryoku shell tree, launcher, and bin/* helpers are reachable
# from PATH, executable, and deployed to ~/.config/quickshell/ryoku-shell/.
#
# Idempotent. Safe to re-run.
#
# Background: discovered during the 2026-05-08 ISO smoke test that fresh
# installs landed at tty1 with no graphical session. Root causes:
#
#   (1) install/config/shell.sh runs `./setup install` which is supposed
#       to sync_launcher_from_repo() into $XDG_BIN_HOME, but on the live
#       chroot install path the sync did not produce $HOME/.local/bin/
#       ryoku-shell, so the systemd user unit's ExecStart could not find
#       its target (status 203/EXEC).
#   (2) install/login/sddm.sh calls `ryoku-refresh-sddm`, which lives at
#       $HOME/.local/share/ryoku/bin/ryoku-refresh-sddm but is never on
#       any system PATH. The chroot install swallowed the
#       command-not-found and silently moved on, leaving sddm.service
#       disabled and the ii-pixel theme missing.
#   (3) The shell QML tree was never copied to
#       ~/.config/quickshell/ryoku-shell/ where quickshell looks for
#       shell.qml, so the launcher could not find its config-path helper.
#   (4) Many .sh scripts under shell/scripts/ lost their +x bit during
#       the install copy step.
#
# This script paves over all four. It is run from
# install/post-install/all.sh so it executes after every other install
# stage (and reapplies any earlier-stage stomps). Future install
# refactors should fix the upstream causes; until then this is the
# safety net that keeps fresh ISOs bootable.

set -euo pipefail

ryoku_path="${RYOKU_PATH:-$HOME/.local/share/ryoku}"
shell_src="$ryoku_path/shell"
xdg_bin_home="${XDG_BIN_HOME:-$HOME/.local/bin}"
xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
quickshell_dir="$xdg_config_home/quickshell/ryoku-shell"

if [[ ! -d $shell_src ]]; then
    echo "ensure-shell-deployment: $shell_src not found, skipping" >&2
    exit 0
fi

# (4) Restore +x on all .sh under the shell tree. The install copy step
# (cp/rsync without --preserve=mode in some paths) drops the bit.
find "$shell_src" -type f -name '*.sh' -exec chmod +x {} +
chmod +x "$shell_src/scripts/ryoku-shell" 2>/dev/null || true

# (1) User-bin launcher. The systemd unit ExecStart is
# $HOME/.local/bin/ryoku-shell. Make sure it exists and points at the
# real launcher.
mkdir -p "$xdg_bin_home"
ln -sf "$shell_src/scripts/ryoku-shell" "$xdg_bin_home/ryoku-shell"

# (2) System-wide PATH for ryoku-* helpers so install/login/sddm.sh and
# anything else can call ryoku-refresh-sddm, ryoku-shell, etc. without
# absolute paths. Use a profile.d entry so every interactive shell picks
# it up too.
if [[ -d $ryoku_path/bin ]]; then
    sudo install -d /usr/local/bin
    for f in "$ryoku_path"/bin/*; do
        [[ -f $f && -x $f ]] || continue
        sudo ln -sfn "$f" "/usr/local/bin/$(basename "$f")"
    done
    # And the launcher itself: replace any stale symlink with a thin
    # wrapper so BASH_SOURCE[0] inside the launcher resolves to its real
    # location (a direct symlink would make the script's helper search
    # fail because dirname of the symlink is /usr/local/bin).
    sudo rm -f /usr/local/bin/ryoku-shell
    sudo tee /usr/local/bin/ryoku-shell >/dev/null <<EOF
#!/bin/bash
exec "$shell_src/scripts/ryoku-shell" "\$@"
EOF
    sudo chmod +x /usr/local/bin/ryoku-shell

    # And the runtime-env helper that bin/* scripts source via
    # \$(dirname \$BASH_SOURCE)/.. /lib/runtime-env.sh - when invoked via
    # the /usr/local/bin/ symlink, the relative ../lib path resolves to
    # /usr/local/lib, so a symlink there makes the source line work.
    sudo install -d /usr/local/lib
    sudo ln -sfn "$ryoku_path/lib/runtime-env.sh" /usr/local/lib/runtime-env.sh
fi

# (3) Deploy shell tree to ~/.config/quickshell/ryoku-shell so quickshell
# can locate shell.qml and the launcher's helper search finds
# scripts/lib/config-path.sh on the user_config_dir candidate.
mkdir -p "$xdg_config_home/quickshell"
if [[ ! -d $quickshell_dir ]]; then
    cp -a "$shell_src/." "$quickshell_dir/"
else
    # Refresh in place so re-runs pick up shell tree updates.
    rsync -a --delete "$shell_src/" "$quickshell_dir/"
fi

echo "ensure-shell-deployment: ok"
