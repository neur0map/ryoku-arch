#!/usr/bin/env bash
# shellcheck shell=bash
# Install the Ryoku desktop into the freshly installed system from the signed
# [ryoku] pacman repository, then materialize the per-user config. The desktop now
# ships as packages (ryoku-keyring, ryoku-shell, ryoku-hub, ryoku-blobs, ryoku,
# ryoku-desktop): the binaries, the hardware helper scripts, the Ryoku.Blobs QML
# plugin, the GPU udev rule, and every ~/.config dotfile come from pacman, and
# `ryoku materialize` lays the dotfiles down from /usr/share/ryoku/config. A few
# user-data bits no package owns yet are still seeded from the repo payload here:
# the brand assets and wallpaper collection (the shell reads them from $HOME) and
# the ~/.npmrc prefix; the neovim default-editor registration and the qylock
# lockscreen + SDDM theme are likewise still installed here. Runs in the "configure"
# stage after chroot.sh, routes through the dry-run wrappers, and tolerates an
# offline or partial install (the desktop set then arrives on the first
# `ryoku update`).

ryoku_deploy() {
  local u=$RYOKU_USERNAME
  local h="/mnt/home/$u"
  log "deploying the Ryoku desktop for user $u"

  ryoku_deploy_repo            # [ryoku] stanza + mirrorlist + keyring trust (local)
  ryoku_deploy_packages        # pacman -S the Ryoku desktop set (needs network)
  ryoku_deploy_materialize "$u"  # ryoku materialize as the user
  ryoku_deploy_seed "$h"       # unpackaged user-data: brand, wallpapers, ~/.npmrc
  ryoku_deploy_editor "$h"     # neovim default-editor registration (unpackaged)
  ryoku_deploy_qylock          # qylock lockscreen + SDDM theme (unpackaged)
  ryoku_deploy_chown "$u"      # own the root-seeded files under /home
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

# ryoku_deploy_repo prepares the target to install signed Ryoku packages: it adds
# the [ryoku] repository to /mnt/etc/pacman.conf, copies the live ISO's known-good
# mirrorlist into the target (the pacman-mirrorlist default ships every server
# commented out, so the chroot's `pacman -Sy` would otherwise have no servers for
# core/extra), and imports the Ryoku release signing key into the target keyring so
# SigLevel=Required verifies. All of this is local, so it runs even on an offline
# install, leaving the repo configured for a later `ryoku update`.
ryoku_deploy_repo() {
  ryoku_repo_pacman_conf
  ryoku_repo_mirrorlist
  ryoku_repo_keyring
}

# ryoku_repo_pacman_conf appends the [ryoku] stanza to /mnt/etc/pacman.conf once.
# The single-quoted heredoc keeps $arch literal so pacman expands it per host.
ryoku_repo_pacman_conf() {
  local conf=/mnt/etc/pacman.conf
  if [[ -z ${RYOKU_DRYRUN:-} ]] && grep -q '^\[ryoku\]' "$conf" 2>/dev/null; then
    log "[ryoku] repository already present in $conf"
    return 0
  fi
  log "adding the [ryoku] repository to $conf"
  append_file "$conf" <<'EOF'

[ryoku]
SigLevel = Required
Server = https://repo.ryoku.dev/$arch
EOF
}

# ryoku_repo_mirrorlist copies the live mirrorlist into the target so the chroot's
# `pacman -Sy` can refresh core/extra alongside [ryoku]. The live list is the one
# the ISO pacstrapped with, so it is known-good.
ryoku_repo_mirrorlist() {
  local src=/etc/pacman.d/mirrorlist dst=/mnt/etc/pacman.d/mirrorlist
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    printf 'DRYRUN: cp %s %s\n' "$src" "$dst"
    return 0
  fi
  [[ -s $src ]] || { log "skip: no live mirrorlist at $src"; return 0; }
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}

# ryoku_repo_keyring imports the Ryoku release signing key into the target keyring
# so pacman trusts [ryoku] before any signed package is fetched. The key material
# ships in the repo payload (release/packages/ryoku-keyring). We seed the three
# keyring files, run `pacman-key --populate ryoku` (which imports and locally signs
# the key into the target trustdb), then remove the seeds so the ryoku-keyring
# package can install them without a file conflict; the trustdb persists.
ryoku_repo_keyring() {
  local kdir="$RYOKU_REPO/release/packages/ryoku-keyring"
  local kd=/mnt/usr/share/pacman/keyrings
  if [[ -z ${RYOKU_DRYRUN:-} && ! -f "$kdir/ryoku.gpg" ]]; then
    log "warning: $kdir/ryoku.gpg missing; cannot trust [ryoku] (Ryoku packages will be skipped)"
    return 0
  fi
  log "importing the Ryoku release key into the target keyring"
  run install -Dm644 "$kdir/ryoku.gpg"     "$kd/ryoku.gpg"
  run install -Dm644 "$kdir/ryoku-trusted" "$kd/ryoku-trusted"
  run install -Dm644 "$kdir/ryoku-revoked" "$kd/ryoku-revoked"
  run arch-chroot /mnt pacman-key --populate ryoku \
    || log "warning: pacman-key --populate ryoku failed (continuing)"
  run rm -f "$kd/ryoku.gpg" "$kd/ryoku-trusted" "$kd/ryoku-revoked"
}

# ryoku_deploy_packages installs the Ryoku desktop set from [ryoku] in the chroot.
# The chroot is lent the live resolv.conf for DNS (the target has none yet), exactly
# like the AUR step; that state is restored afterwards. Needs network, so it is
# skipped on an offline install. Best-effort: a failure is logged and the install
# continues (a later `ryoku update` recovers the set).
ryoku_deploy_packages() {
  local -a pkgs=(ryoku-keyring ryoku-shell ryoku-hub ryoku-blobs ryoku ryoku-desktop)

  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "DRYRUN: arch-chroot /mnt pacman -Sy"
    log "DRYRUN: arch-chroot /mnt pacman -S --noconfirm --needed ${pkgs[*]}"
    return 0
  fi
  if [[ ${RYOKU_ONLINE:-1} != 1 ]]; then
    log "packages: offline install, skipping the Ryoku desktop set (run 'ryoku update' once online)"
    return 0
  fi

  # Lend the chroot DNS only when the target has none yet, and undo exactly that.
  local made_resolv=0
  if [[ ! -e /mnt/etc/resolv.conf ]] && cp -L /etc/resolv.conf /mnt/etc/resolv.conf 2>/dev/null; then
    made_resolv=1
  fi

  log "installing the Ryoku desktop set: ${pkgs[*]}"
  if arch-chroot /mnt pacman -Sy; then
    arch-chroot /mnt pacman -S --noconfirm --needed "${pkgs[@]}" \
      || log "packages: warning, some Ryoku packages did not install (continuing)"
  else
    log "packages: warning, could not refresh the databases; skipping the Ryoku set"
  fi

  if (( made_resolv == 1 )); then
    rm -f /mnt/etc/resolv.conf
  fi
  return 0
}

# ryoku_deploy_materialize lays the Ryoku base config (/usr/share/ryoku/config,
# shipped by ryoku-desktop) into the user's ~/.config by running `ryoku materialize`
# as the target user. HOME/USER/LOGNAME are forced because runuser keeps root's env,
# the same pattern aur.sh uses. Skipped when the `ryoku` CLI is not installed (an
# offline or partial package install).
ryoku_deploy_materialize() {
  local u=$1
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "DRYRUN: arch-chroot /mnt runuser -u $u -- env HOME=/home/$u ryoku materialize"
    return 0
  fi
  if [[ ! -x /mnt/usr/bin/ryoku ]]; then
    log "materialize: skipped (ryoku CLI not installed)"
    return 0
  fi
  log "materializing the Ryoku config into /home/$u/.config"
  arch-chroot /mnt runuser -u "$u" -- env "HOME=/home/$u" "USER=$u" "LOGNAME=$u" \
    ryoku materialize \
    || log "materialize: warning, ryoku materialize failed (continuing)"
}

# ryoku_deploy_seed lays down the user-data no package owns yet and that
# `ryoku materialize` (which is ~/.config-only) does not cover: the brand assets and
# wallpaper collection the shell reads from $HOME, and the ~/.npmrc prefix. Seeded
# from the repo payload; tolerates missing sources.
ryoku_deploy_seed() {
  local h=$1
  log "seeding brand assets, wallpapers, and ~/.npmrc into $h"
  deploy_dir "$RYOKU_REPO/ryoku/assets/brand" "$h/.local/share/ryoku/assets/brand"
  # The shipped wallpaper collection seeds ~/Pictures/Wallpapers so a fresh install
  # has a set to pick from; ryoku-shell sets a random one on first start.
  deploy_dir "$RYOKU_REPO/ryoku/assets/wallpapers" "$h/Pictures/Wallpapers"
  deploy_file "$RYOKU_REPO/ryoku/apps/npm/npmrc" "$h/.npmrc"
}

# ryoku_deploy_editor makes neovim the default text editor: the .desktop entry plus
# the mimeapps defaults that route text files to it. Not packaged (ryoku-desktop
# ships the nvim config under /usr/share/ryoku/config, but not this registration).
ryoku_deploy_editor() {
  local h=$1
  log "registering neovim as the default text editor"
  deploy_file "$RYOKU_REPO/ryoku/apps/nvim/ryoku-nvim.desktop" "$h/.local/share/applications/ryoku-nvim.desktop"
  deploy_file "$RYOKU_REPO/ryoku/apps/mimeapps.list" "$h/.config/mimeapps.list"
}

# ryoku_deploy_qylock installs the qylock lockscreen bundle and the SDDM clockwork
# theme. Not yet packaged, so the bundle ships in the payload and its two installers
# run in the chroot.
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
