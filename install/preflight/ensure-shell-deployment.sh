#!/bin/bash

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
#   (5) the compositor starts the Ryoku shell from the user's Hyprland config,
#       so a fresh boot must have the launcher, service file, and runtime tree
#       in user-owned paths before the graphical session starts.
#
# This script paves over all five. It is run from
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

# (4) Restore +x on all .sh under the shell tree AND the install tree.
# The install copy step (cp/rsync without --preserve=mode in some paths)
# drops the bit, and bin/ryoku-update-perform invokes
# install/config/shell.sh by direct exec (not `bash <path>`), so missing
# +x on install/*.sh manifests as a "Permission denied" mid-update.
find "$shell_src" -type f -name '*.sh' -exec chmod +x {} +
chmod +x "$shell_src/scripts/ryoku-shell" 2>/dev/null || true
if [[ -d $ryoku_path/install ]]; then
    find "$ryoku_path/install" -type f -name '*.sh' -exec chmod +x {} +
fi
if [[ -d $ryoku_path/bin ]]; then
    find "$ryoku_path/bin" -type f -exec chmod +x {} +
fi

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
printf '%s\n' "$ryoku_path" >"$quickshell_dir/.ryoku-source-path"

# (5) User-service wants-links. Several install/ scripts call
# `systemctl --user enable --now <unit>` directly:
#
#   install/config/ryoku-hypridle.sh:41        hypridle.service
#   install/config/ryoku-resume-listener.sh:20 ryoku-resume-listener.service
#   install/first-run/battery-monitor.sh:5     ryoku-battery-monitor.timer
#
# Those calls silently no-op in chroot context (no user dbus / systemd
# user instance). Re-create each [Install] WantedBy=... wants-link
# directly here from the user's $HOME so the wiring is correct on first
# boot regardless of where the original install/ script ran. Idempotent:
# ln -sfn replaces stale links.
ensure_user_wants_link() {
    local target_unit="$1"  # filename of the unit to enable
    local wanted_by="$2"    # WantedBy target (e.g. graphical-session.target)
    local source_path="$3"  # absolute path the symlink should point to
    [[ -e $source_path ]] || return 0
    local wants_dir="$xdg_config_home/systemd/user/${wanted_by}.wants"
    mkdir -p "$wants_dir"
    ln -sfn "$source_path" "$wants_dir/$target_unit"
}

# graphical-session consumers.
ensure_user_wants_link ryoku-resume-listener.service graphical-session.target \
    "$xdg_config_home/systemd/user/ryoku-resume-listener.service"
ensure_user_wants_link hypridle.service graphical-session.target \
    /usr/lib/systemd/user/hypridle.service

# timers.target consumer (only wired if the host has a battery; the
# original first-run/battery-monitor.sh gated on ryoku-battery-present,
# but the safety net is harmless for desktops since the timer simply
# won't trigger anything battery-relevant).
ensure_user_wants_link ryoku-battery-monitor.timer timers.target \
    "$xdg_config_home/systemd/user/ryoku-battery-monitor.timer"

# daemon-reload only works if a user systemd is reachable. In a chroot
# install context it is not, silently ignore. On a real post-install
# run as the user it will pick up the new links.
systemctl --user daemon-reload >/dev/null 2>&1 || true

echo "ensure-shell-deployment: ok"
