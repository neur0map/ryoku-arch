#!/usr/bin/env bash
# shellcheck shell=bash
# Deploy the Ryoku desktop payload into the freshly installed system: hardware
# helper scripts, the udev GPU rule, and the user's dotfiles (Hyprland, kitty,
# fastfetch, fish, starship), then the qylock lockscreen bundle and the SDDM
# clockwork theme. Runs in the "configure" stage after chroot.sh, under the
# same @@RYOKU_STEP. Everything goes through the dry-run wrappers and tolerates a
# missing source (so a partial repo still deploys what it has).

ryoku_deploy() {
  local u=$RYOKU_USERNAME
  local h="/mnt/home/$u"
  log "deploying desktop payload for user $u"

  ryoku_deploy_bin
  ryoku_deploy_configs "$h"
  ryoku_deploy_shell "$h"
  ryoku_deploy_editor "$h"
  ryoku_deploy_chown "$u"
  ryoku_deploy_qylock
}

# install_bin installs an executable into /mnt/usr/local/bin (mode 755).
install_bin() {
  local src=$1 dst="/mnt/usr/local/bin/$2"
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    printf 'DRYRUN: install -Dm755 %s %s\n' "$src" "$dst"
    return 0
  fi
  [[ -f $src ]] || { log "skip: $src not present"; return 0; }
  install -Dm755 "$src" "$dst"
}

# deploy_file copies a single config file (mode 644), creating parent dirs.
deploy_file() {
  local src=$1 dst=$2
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    printf 'DRYRUN: install -Dm644 %s %s\n' "$src" "$dst"
    return 0
  fi
  [[ -f $src ]] || { log "skip: $src not present"; return 0; }
  install -Dm644 "$src" "$dst"
}

# deploy_glob copies the files matching a glob from a source dir into a dest dir.
deploy_glob() {
  local srcdir=$1 pat=$2 dst=$3
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    printf 'DRYRUN: mkdir -p %s && cp %s/%s %s/\n' "$dst" "$srcdir" "$pat" "$dst"
    return 0
  fi
  [[ -d $srcdir ]] || { log "skip: $srcdir not present"; return 0; }
  local files=()
  shopt -s nullglob
  # shellcheck disable=SC2206  # $pat is a glob meant to expand into the array
  files=("$srcdir"/$pat)
  shopt -u nullglob
  (( ${#files[@]} )) || { log "skip: no $pat in $srcdir"; return 0; }
  mkdir -p "$dst"
  cp "${files[@]}" "$dst"/
}

ryoku_deploy_bin() {
  log "installing helper scripts to /usr/local/bin and the GPU udev rule"
  install_bin "$RYOKU_REPO/system/hardware/gpu/ryoku-gpu" ryoku-gpu
  install_bin "$RYOKU_REPO/system/hardware/gpu/ryoku-gpu-detect" ryoku-gpu-detect
  install_bin "$RYOKU_REPO/system/hardware/display/ryoku-monitor" ryoku-monitor
  install_bin "$RYOKU_REPO/system/hardware/power/ryoku-hw-laptop" ryoku-hw-laptop
  install_bin "$RYOKU_REPO/system/hardware/power/ryoku-idle" ryoku-idle
  install_bin "$RYOKU_REPO/system/hardware/leds/ryoku-leds" ryoku-leds
  install_bin "$RYOKU_REPO/ryoku/apps/fastfetch/ryoku-fastfetch" ryoku-fastfetch
  install_bin "$RYOKU_REPO/ryoku/shell/ipc/ryoku-shell" ryoku-shell
  install_bin "$RYOKU_REPO/ryoku/shell/ryoku" ryoku
  deploy_file "$RYOKU_REPO/system/hardware/gpu/90-ryoku-gpu.rules" \
    /mnt/etc/udev/rules.d/90-ryoku-gpu.rules
}

ryoku_deploy_configs() {
  local h=$1
  log "deploying brand assets, wallpapers, and dotfiles into $h"
  deploy_dir "$RYOKU_REPO/ryoku/assets/brand" "$h/.local/share/ryoku/assets/brand"
  # The shipped wallpaper collection seeds ~/Pictures/Wallpapers so a fresh
  # install has a set to pick from; ryoku-shell sets a random one on first start.
  deploy_dir "$RYOKU_REPO/ryoku/assets/wallpapers" "$h/Pictures/Wallpapers"

  # The shipped desktop is the Ryoku Hyprland config: a self-contained set with
  # hardware-managed gpu/keyboard/monitors plus an autostart that launches
  # ryoku-shell.
  deploy_dir "$RYOKU_REPO/ryoku/hyprland" "$h/.config/hypr"
  deploy_dir "$RYOKU_REPO/ryoku/apps/kitty" "$h/.config/kitty"
  deploy_file "$RYOKU_REPO/ryoku/apps/fastfetch/config.jsonc" "$h/.config/fastfetch/config.jsonc"
  deploy_file "$RYOKU_REPO/ryoku/apps/fish/config.fish" "$h/.config/fish/config.fish"
  deploy_file "$RYOKU_REPO/ryoku/apps/starship/starship.toml" "$h/.config/starship.toml"
  deploy_dir "$RYOKU_REPO/ryoku/apps/nvim" "$h/.config/nvim"
  deploy_dir "$RYOKU_REPO/ryoku/apps/yazi" "$h/.config/yazi"
  deploy_file "$RYOKU_REPO/ryoku/apps/npm/npmrc" "$h/.npmrc"
  deploy_file "$RYOKU_REPO/ryoku/apps/pip/pip.conf" "$h/.config/pip/pip.conf"
}

# ryoku_deploy_shell installs the Ryoku shell components: the quickshell UI, the
# wallust palette config, the qt/kde theme, and the user session target.
ryoku_deploy_shell() {
  local h=$1
  log "deploying the Ryoku shell components into $h"
  deploy_dir "$RYOKU_REPO/ryoku/shell/quickshell" "$h/.config/quickshell"
  deploy_dir "$RYOKU_REPO/ryoku/shell/wallust" "$h/.config/wallust"
  deploy_file "$RYOKU_REPO/ryoku/shell/kde/kdeglobals" "$h/.config/kdeglobals"
  deploy_dir "$RYOKU_REPO/ryoku/shell/systemd/user" "$h/.config/systemd/user"
  # The Ryoku.Blobs QML plugin (the frame's blob renderer), prebuilt into the
  # payload by iso/build.sh, onto the user's Qt QML import path. ryoku-shell
  # points QML2_IMPORT_PATH here for the quickshell processes it supervises.
  deploy_dir "$RYOKU_REPO/ryoku/shell/plugin/dist/Ryoku" "$h/.local/lib/qt6/qml/Ryoku"
}

# ryoku_deploy_editor makes neovim the default text editor: the .desktop entry
# plus the mimeapps defaults that route text files to it.
ryoku_deploy_editor() {
  local h=$1
  log "registering neovim as the default text editor"
  deploy_file "$RYOKU_REPO/ryoku/apps/nvim/ryoku-nvim.desktop" "$h/.local/share/applications/ryoku-nvim.desktop"
  deploy_file "$RYOKU_REPO/ryoku/apps/mimeapps.list" "$h/.config/mimeapps.list"
}

ryoku_deploy_qylock() {
  log "deploying qylock bundle + SDDM clockwork theme"
  deploy_dir "$RYOKU_REPO/ryoku/lockscreen/qylock" /mnt/usr/share/ryoku/qylock

  # Stage the two installers in the chroot, run them in the target, then remove.
  run cp "$RYOKU_REPO/ryoku/lockscreen/sddm/setup" /mnt/root/ryoku-sddm-setup
  run cp "$RYOKU_REPO/ryoku/lockscreen/install-qylock" /mnt/root/ryoku-install-qylock
  run chmod 755 /mnt/root/ryoku-sddm-setup /mnt/root/ryoku-install-qylock
  local env="RYOKU_QYLOCK_BUNDLE=/usr/share/ryoku/qylock SUDO_USER=$RYOKU_USERNAME RYOKU_DRYRUN=${RYOKU_DRYRUN:-}"
  # shellcheck disable=SC2086  # env assignments are intentionally word-split
  run arch-chroot /mnt env $env /root/ryoku-sddm-setup
  # shellcheck disable=SC2086
  run arch-chroot /mnt env $env /root/ryoku-install-qylock
  run rm -f /mnt/root/ryoku-sddm-setup /mnt/root/ryoku-install-qylock
}

ryoku_deploy_chown() {
  local u=$1
  log "fixing ownership of /home/$u"
  run arch-chroot /mnt chown -R "$u:$u" "/home/$u"
}
