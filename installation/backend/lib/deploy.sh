#!/usr/bin/env bash
# shellcheck shell=bash
# install the Ryoku desktop from the signed [ryoku] pacman repo, then materialize
# the per-user config. desktop = packages now (ryoku-keyring, ryoku-shell,
# ryoku-hub, ryoku-blobs, ryoku, ryoku-desktop): binaries, hardware helper
# scripts, the Ryoku.Blobs QML plugin, the GPU udev rule, every ~/.config
# dotfile, all pacman. `ryoku materialize` then lays the dotfiles out from
# /usr/share/ryoku/config.
#
# a few user-data bits no package owns yet are still seeded from the repo
# payload here: brand assets + wallpapers (shell reads them from $HOME),
# ~/.npmrc prefix, the nvim default-editor registration, qylock + the SDDM
# theme. runs in the "configure" stage after chroot.sh, through the dry-run
# wrappers, and tolerates offline / partial installs (the desktop set then
# turns up on the first `ryoku update`).

ryoku_deploy() {
  local u=$RYOKU_USERNAME
  local h="/mnt/home/$u"
  log "deploying the Ryoku desktop for user $u"

  ryoku_deploy_repo              # [ryoku] stanza + mirrorlist + keyring trust (local)
  ryoku_deploy_packages          # pacman -S the desktop set (needs net)
  ryoku_deploy_materialize "$u"  # `ryoku materialize` as the user
  ryoku_deploy_seed "$h"         # unpackaged: brand, wallpapers, ~/.npmrc
  ryoku_deploy_chown "$u"        # own root-seeded files before the user steps
  ryoku_deploy_qylock            # qylock writes user files as the now-owning user
}

# deploy_file: one config file, mode 644, parents made.
deploy_file() {
  local src=$1 dst=$2
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    printf 'DRYRUN: install -Dm644 %s %s\n' "$src" "$dst"
    return 0
  fi
  [[ -f $src ]] || { log "skip: $src not present"; return 0; }
  install -Dm644 "$src" "$dst"
}

# repo prep: add [ryoku] to /mnt/etc/pacman.conf, drop the live ISO's
# known-good mirrorlist into the target (the default mirrorlist ships every
# server commented out, so the chroot's `pacman -Sy` would otherwise have
# zero servers for core/extra), and import the release signing key so
# SigLevel=Required passes. all local, runs even offline; the repo stays
# configured for the next `ryoku update`.
ryoku_deploy_repo() {
  ryoku_repo_pacman_conf
  ryoku_repo_mirrorlist
  ryoku_repo_keyring
}

# pacman_conf: append [ryoku] once. release bucket lives under /stable/, so
# Server carries the prefix; single-quoted heredoc keeps $arch literal.
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
Server = https://repo.ryoku.dev/stable/$arch
EOF
}

# mirrorlist: copy the live one over so the chroot's pacman -Sy can refresh
# core/extra. live one is what the ISO pacstrapped with, so known-good.
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

# keyring: import the Ryoku release signing key into the target so pacman
# trusts [ryoku] before any signed pkg is fetched. key material ships in
# release/packages/ryoku-keyring. seed the three files, run pacman-key
# --populate (imports + locally signs into the trustdb), then drop the seeds
# so the ryoku-keyring package can install them without a file conflict.
# trustdb sticks.
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

# packages: pacman -S the desktop set from [ryoku] inside the chroot. lends
# the live resolv.conf for DNS (target has none yet), same trick as aur.sh;
# restored after. needs net, so offline = skip. online, a failed install is
# fatal: no desktop without it and no ryoku CLI left to recover, so we stop
# loudly instead of booting a half-configured box.
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

  # lend the chroot DNS only when the target has none yet, then undo exactly that.
  local made_resolv=0
  if [[ ! -e /mnt/etc/resolv.conf ]] && cp -L /etc/resolv.conf /mnt/etc/resolv.conf 2>/dev/null; then
    made_resolv=1
  fi

  log "installing the Ryoku desktop set: ${pkgs[*]}"
  local rc=0
  if arch-chroot /mnt pacman -Sy; then
    arch-chroot /mnt pacman -S --noconfirm --needed "${pkgs[@]}" || rc=$?
  else
    rc=1
  fi

  if (( made_resolv == 1 )); then
    rm -f /mnt/etc/resolv.conf
  fi

  if (( rc != 0 )); then
    log "ERROR: could not install the Ryoku desktop set from [ryoku]"
    log "       (https://repo.ryoku.dev/stable). The desktop needs it and there is no"
    log "       ryoku CLI to recover with; check the network and re-run the installer."
    return 1
  fi
  return 0
}

# materialize: lay the base config (/usr/share/ryoku/config, owned by
# ryoku-desktop) into ~/.config by running `ryoku materialize` as the user.
# HOME/USER/LOGNAME forced because runuser keeps root's env (same dance as
# aur.sh). skipped when the `ryoku` CLI is absent (offline / partial pkgs).
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

# seed the user-data nothing else owns: brand assets + wallpapers (shell
# reads them from $HOME), ~/.npmrc prefix. from the repo payload; missing
# sources are fine.
ryoku_deploy_seed() {
  local h=$1
  log "seeding brand assets, wallpapers, and ~/.npmrc into $h"
  deploy_dir "$RYOKU_REPO/ryoku/assets/brand" "$h/.local/share/ryoku/assets/brand"
  # ship a wallpaper set so a fresh install has something to pick from;
  # ryoku-shell picks one at random on first start.
  deploy_dir "$RYOKU_REPO/ryoku/assets/wallpapers" "$h/Pictures/Wallpapers"
  deploy_file "$RYOKU_REPO/ryoku/apps/npm/npmrc" "$h/.npmrc"
}

# qylock: install the lockscreen bundle + the SDDM clockwork theme. not yet
# packaged, so the bundle ships in the payload and its two installers run
# in the chroot.
ryoku_deploy_qylock() {
  log "deploying qylock bundle + SDDM clockwork theme"
  deploy_dir "$RYOKU_REPO/ryoku/lockscreen/qylock" /mnt/usr/share/ryoku/qylock

  # stage the two installers in the chroot, run, drop.
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
