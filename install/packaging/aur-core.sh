#!/bin/bash
# Install the AUR packages every Ryoku machine ships with. The list lives
# in install/ryoku-aur.packages (sectioned, source-of-truth) so the same
# file feeds both this installer and the offline-mirror builder
# (iso/builder/build-iso.sh).
#
# Strategy:
#   1. Try sudo pacman -S first. The chroot install's pacman.conf
#      registers the [offline] mirror that build-iso.sh populated with
#      every AUR PackageBase from install/ryoku-aur.packages, so
#      pacman -S resolves them locally with zero network.
#   2. Fall back to yay (ryoku-pkg-aur-add) for online installs that
#      bypass the offline mirror, or for packages the offline mirror
#      didn't manage to bake in (e.g. a transient AUR outage during ISO
#      build that left some PackageBase missing).
#
# Failures during the fallback path do not abort the install; they're
# recorded to /var/log/ryoku-aur-failed so the user can re-run via
# 'ryoku-update-system-pkgs' once AUR is reachable.

mapfile -t aur_packages < <(
  grep -v '^#' "$RYOKU_INSTALL/ryoku-aur.packages" | grep -v '^$' | awk 'NF { print }'
)

if (( ${#aur_packages[@]} == 0 )); then
  echo "install/ryoku-aur.packages is empty; nothing to do."
  exit 0
fi

# Step 1: bulk pacman -S (offline mirror covers the list when present).
if sudo pacman -S --noconfirm --needed "${aur_packages[@]}" 2>/dev/null; then
  exit 0
fi

# Step 2: per-package pacman attempt, then yay fallback. Track failures.
echo "Bulk pacman install missed some AUR packages; retrying per-package with yay fallback..."

failed_pkgs=()
for pkg in "${aur_packages[@]}"; do
  if pacman -Q "$pkg" &>/dev/null; then
    continue
  fi

  if sudo pacman -S --noconfirm --needed "$pkg" 2>/dev/null; then
    continue
  fi

  installed=0
  if command -v yay >/dev/null 2>&1 && ryoku-pkg-aur-accessible 2>/dev/null; then
    for attempt in 1 2 3; do
      if ryoku-pkg-aur-add "$pkg"; then
        installed=1
        break
      fi
      echo "AUR install of $pkg failed (attempt $attempt/3), retrying in 5s..."
      sleep 5
    done
  fi

  (( installed == 0 )) && failed_pkgs+=("$pkg")
done

if (( ${#failed_pkgs[@]} > 0 )); then
  printf '%s\n' "${failed_pkgs[@]}" | sudo tee /var/log/ryoku-aur-failed >/dev/null
  echo
  echo "WARNING: the following AUR packages could not be installed and were skipped:"
  printf '  %s\n' "${failed_pkgs[@]}"
  echo
  echo "They should already be in the offline mirror; if not, run"
  echo "'ryoku-update-system-pkgs' once the network is up."
fi

exit 0
