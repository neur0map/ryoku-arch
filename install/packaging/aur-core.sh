#!/bin/bash
# Install the AUR-only packages that used to come from the [omarchy]
# pacman repo. After Path A dropped the repo, these are pulled from
# AUR instead so the install flow still converges without touching
# DHH-hosted infrastructure.
#
# Packages intentionally excluded:
#   asdcontrol                     Apple display brightness (only useful
#                                  with Apple USB-C displays; kept on
#                                  live systems but not reinstalled).
#   hyprland-preview-share-picker  Screen-share visual picker; we accepted
#                                  the feature loss when the omarchy repo
#                                  left.
#   tobi-try                       Unknown provenance; dropped.

if ! ryoku-pkg-aur-accessible; then
  echo "AUR unavailable, skipping AUR-core install"
  exit 0
fi

aur_packages=(
  1password-beta
  1password-cli
  claude-code
  limine-mkinitcpio-hook
  limine-snapper-sync
  localsend
  pinta
  python-terminaltexteffects
  spotify
  ttf-ia-writer
  typora
  tzupdate
  ufw-docker
  xdg-terminal-exec
  yaru-icon-theme
)

# AUR can be flaky during installs (RPC timeouts, TLS handshake failures,
# package-build network errors). Try the whole batch first; on failure,
# retry per-package up to 3 times each. Packages that ultimately fail are
# reported as a warning and recorded in /var/log/ryoku-aur-failed so the
# user can `ryoku-update-system-pkgs` later, but we do not abort the
# install over a flaky AUR.

if ryoku-pkg-aur-add "${aur_packages[@]}"; then
  exit 0
fi

echo "Batch AUR install hit a snag, retrying packages individually..."

failed_pkgs=()
for pkg in "${aur_packages[@]}"; do
  installed=0
  for attempt in 1 2 3; do
    if ryoku-pkg-aur-add "$pkg"; then
      installed=1
      break
    fi
    echo "AUR install of $pkg failed (attempt $attempt/3), retrying..."
    sleep 5
  done
  if (( installed == 0 )); then
    failed_pkgs+=("$pkg")
  fi
done

if (( ${#failed_pkgs[@]} > 0 )); then
  printf '%s\n' "${failed_pkgs[@]}" | sudo tee /var/log/ryoku-aur-failed >/dev/null
  echo
  echo "WARNING: the following AUR packages could not be installed and were skipped:"
  printf '  %s\n' "${failed_pkgs[@]}"
  echo
  echo "Run 'yay -S ${failed_pkgs[*]}' after reboot to retry, or wait for"
  echo "AUR to come back and run 'ryoku-update-system-pkgs'."
fi

exit 0
