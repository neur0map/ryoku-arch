#!/usr/bin/env bash
# shellcheck shell=bash
# build the AUR set in the target. base system has no AUR helper, so we
# bootstrap yay (clone from the AUR, fall back to the GitHub release binary
# when the AUR is unreachable), then install system/packages/aur.packages.
#
# makepkg refuses to run as root, so the build runs as the unpriv user via
# runuser, with a one-shot NOPASSWD sudo drop-in (removed at the end) so
# makepkg/yay can drive pacman without a TTY prompt. chroot is lent the live
# resolv.conf for DNS while building, then restored.
#
# best-effort: offline install or a failed build = warn + return 0, so the
# install still completes (user bootstraps later). runs after the bootloader
# step while /mnt is still mounted; emits no @@RYOKU_STEP.

ryoku_aur() {
  local u=$RYOKU_USERNAME
  local aur_file="$RYOKU_REPO/system/packages/aur.packages"

  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "DRYRUN: bootstrap yay and install the AUR set from $aur_file as $u"
    return 0
  fi
  if [[ -n ${RYOKU_SKIP_AUR:-} ]]; then
    log "AUR: RYOKU_SKIP_AUR set, skipping the AUR set (bootstrap it later)"
    return 0
  fi
  if [[ ${RYOKU_ONLINE:-1} != 1 ]]; then
    log "AUR: offline install, skipping (bootstrap yay with an AUR helper once online)"
    return 0
  fi
  [[ -f $aur_file ]] || { log "AUR: no $aur_file, skipping"; return 0; }

  local -a pkgs=()
  mapfile -t pkgs < <(grep -vE '^[[:space:]]*(#|$)' "$aur_file")
  (( ${#pkgs[@]} )) || { log "AUR: package set is empty, skipping"; return 0; }

  log "AUR: bootstrapping yay and building ${#pkgs[@]} package(s); this can take several minutes"

  # one-shot NOPASSWD sudo so makepkg/yay can call pacman without a prompt.
  printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$u" >/mnt/etc/sudoers.d/99-ryoku-aur-build
  chmod 0440 /mnt/etc/sudoers.d/99-ryoku-aur-build
  # security: always remove the passwordless-sudo drop-in from the TARGET, even
  # on an early return, so the installed system never ships with NOPASSWD sudo.
  trap 'rm -f /mnt/etc/sudoers.d/99-ryoku-aur-build 2>/dev/null' RETURN

  # chroot needs DNS to reach the AUR and GitHub. only set it when the
  # target has none yet, and undo exactly that after.
  local made_resolv=0
  if [[ ! -e /mnt/etc/resolv.conf ]] && cp -L /etc/resolv.conf /mnt/etc/resolv.conf 2>/dev/null; then
    made_resolv=1
  fi

  # 1. bootstrap yay as the user. HOME forced; runuser keeps root's env.
  if arch-chroot /mnt runuser -u "$u" -- env "HOME=/home/$u" "USER=$u" "LOGNAME=$u" bash -s <<'BOOTSTRAP'; then
set -e
command -v yay >/dev/null && exit 0
sudo pacman -S --needed --noconfirm base-devel git curl >/dev/null
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
ok=0
for attempt in 1 2 3; do
  rm -rf "$work/yay-bin"
  if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$work/yay-bin"; then ok=1; break; fi
  echo "git clone of yay-bin failed (attempt $attempt/3), retrying in 5s..."
  sleep 5
done
if (( ok == 1 )); then
  cd "$work/yay-bin"
  makepkg -si --noconfirm
else
  echo "AUR unreachable, falling back to the yay GitHub release binary..."
  cd "$work"
  url=$(curl -fsSL https://api.github.com/repos/Jguer/yay/releases/latest \
    | grep -oE '"browser_download_url": *"[^"]*x86_64\.tar\.gz"' | head -1 \
    | sed 's/.*: *"\(.*\)"/\1/')
  [[ -n $url ]] || { echo "could not determine the yay release URL" >&2; exit 1; }
  curl -fsSL "$url" -o yay.tar.gz
  tar xzf yay.tar.gz
  bin=$(find . -maxdepth 2 -type f -name yay | head -1)
  [[ -n $bin ]] || { echo "yay binary not found in the tarball" >&2; exit 1; }
  sudo install -m0755 "$bin" /usr/local/bin/yay
fi
command -v yay >/dev/null
BOOTSTRAP
    log "AUR: installing ${pkgs[*]}"
    arch-chroot /mnt runuser -u "$u" -- env "HOME=/home/$u" "USER=$u" "LOGNAME=$u" \
      yay -S --noconfirm --needed "${pkgs[@]}" \
      || log "AUR: warning, some packages did not build (continuing)"
  else
    log "AUR: warning, yay bootstrap failed; the AUR set was not installed"
  fi

  # restore the target's sudo + resolv.conf state.
  rm -f /mnt/etc/sudoers.d/99-ryoku-aur-build
  if (( made_resolv == 1 )); then
    rm -f /mnt/etc/resolv.conf
  fi
  return 0
}
