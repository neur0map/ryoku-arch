#!/bin/bash

# Arch-family adapter. Implements the distro contract for arch and its
# derivatives (cachyos, endeavouros, manjaro, garuda, ...). It installs the
# packages listed in the shared manifests (install/ryoku-*.packages); it never
# names a package itself.
#
# Contract (see TEMPLATE.sh):
#   ryoku_distro_system_update
#   ryoku_distro_prereqs
#   ryoku_distro_install_full

# rsi_arch_aur_helper -> echo yay or paru if present, empty otherwise.
rsi_arch_aur_helper() {
  if command -v yay >/dev/null 2>&1; then printf 'yay'
  elif command -v paru >/dev/null 2>&1; then printf 'paru'
  fi
}

rsi_arch_bootstrap_yay() {
  command -v yay >/dev/null 2>&1 && return 0
  command -v paru >/dev/null 2>&1 && return 0
  rsi_step "bootstrapping yay (no AUR helper found)"
  if rsi_dry; then
    rsi_dim "  would clone aur/yay-bin and makepkg -si"
    return 0
  fi
  local tmp
  tmp="$(mktemp -d)"
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  ( cd "$tmp/yay-bin" && makepkg -si --noconfirm )
  rm -rf "$tmp"
}

# Full system update, run as its own phase BEFORE anything Ryoku is pulled or
# installed. Installing new packages on a not-fully-updated Arch system is a
# partial upgrade: the new packages pull newer shared libraries while
# already-installed apps (the display manager and graphics stack included)
# still expect the old ones, which breaks them and can drop the machine to a
# TTY. Refresh archlinux-keyring first so the big upgrade's signatures validate
# on long-stale systems (the canonical fix for "invalid or corrupted package
# (PGP signature)"), then run the full upgrade.
ryoku_distro_system_update() {
  if rsi_dry; then
    rsi_dim "  would: sudo pacman -Sy --noconfirm archlinux-keyring"
    rsi_dim "  would: sudo pacman -Syu --noconfirm"
    return 0
  fi
  rsi_step "refreshing archlinux-keyring"
  sudo pacman -Sy --noconfirm archlinux-keyring \
    || rsi_warn "could not refresh archlinux-keyring; continuing (the upgrade may still work)"
  # Force-refresh the db (-Syy): on rolling mirrors the local db can list a
  # build the CDN already replaced (404 on install); a forced refresh realigns it.
  rsi_step "running a full system upgrade (pacman -Syyu)"
  sudo pacman -Syyu --noconfirm \
    || rsi_die "system update failed (pacman -Syu). Fix the pacman error above (often a stale keyring or a manual intervention) and re-run."
  rsi_ok "system is up to date"
}

ryoku_distro_prereqs() {
  rsi_step "installing build tools (base-devel, git)"
  if rsi_dry; then
    rsi_dim "  would: sudo pacman -S --needed --noconfirm base-devel git"
  else
    sudo pacman -S --needed --noconfirm base-devel git
  fi
  rsi_arch_bootstrap_yay
}

# Guarantee the real quickshell is installed. Ryoku's shell.qml uses Quickshell
# pragmas (e.g. DefaultEnv) that forks such as noctalia-qs (the CachyOS
# Niri+Noctalia base) do not implement. noctalia-qs `provides` AND `conflicts`
# quickshell and owns /usr/bin/qs, so the manifest's `quickshell` looks
# already-satisfied and is skipped, leaving the shell to crash on launch (black
# screen). Replace any conflicting provider with the real package.
rsi_arch_ensure_real_quickshell() {
  local owner=""
  owner="$(pacman -Qoq /usr/bin/qs 2>/dev/null || true)"
  # A real quickshell (quickshell / -git / -ryoku) already owns the binary.
  [[ $owner == *quickshell* ]] && return 0
  if rsi_dry; then
    [[ -n $owner ]] && rsi_dim "  would replace conflicting quickshell provider: $owner"
    rsi_dim "  would: sudo pacman -S --needed --noconfirm quickshell"
    return 0
  fi
  if [[ -n $owner ]]; then
    rsi_step "replacing conflicting quickshell provider ($owner) with the real quickshell"
    sudo pacman -Rdd --noconfirm "$owner" \
      || rsi_warn "could not remove $owner; the real quickshell may still conflict"
  fi
  rsi_step "installing the real quickshell (Ryoku's shell requires it)"
  if sudo pacman -S --needed --noconfirm quickshell; then
    rsi_record pkg quickshell
  else
    rsi_warn "could not install the real quickshell; the shell may not start"
  fi
}

# Install the full Ryoku app + dependency set from the shared manifests, skipping
# any `# @os-only` region (packages the OS install owns: bootloader, display
# manager, kernel hooks). The AUR helper resolves both official-repo and AUR
# packages, and --needed leaves anything already installed untouched (so it
# coexists with the user's existing apps). Failures are non-fatal and reported.
ryoku_distro_install_full() {
  local want=() p
  while IFS= read -r p; do want+=("$p"); done < <(
    rsi_read_manifest "$RSI_BASE_PACKAGES" "$RSI_AUR_PACKAGES"
  )
  if [[ ${#want[@]} -eq 0 ]]; then
    rsi_die "no package manifests found at $RSI_BASE_PACKAGES / $RSI_AUR_PACKAGES"
  fi

  # Resolve the quickshell provider conflict before the package loop, since a
  # conflicting provider makes `quickshell` look already-present below.
  rsi_arch_ensure_real_quickshell

  local pkgs=() missing=()
  for p in "${want[@]}"; do
    pkgs+=("$p")
    rsi_arch_pkg_present "$p" || missing+=("$p")
  done

  rsi_say "  $(( ${#pkgs[@]} - ${#missing[@]} )) already present (kept), ${#missing[@]} to install, $(( ${#want[@]} - ${#pkgs[@]} )) system packages skipped"
  if (( ${#missing[@]} == 0 )); then
    rsi_ok "all Ryoku packages already present"
    return 0
  fi

  # Split repo vs AUR so an AUR build failure or a bad AUR name can never block
  # the reliable repo apps (terminal, file manager, quickshell, Qt6, ...).
  local repo_pkgs=() aur_pkgs=()
  for p in "${missing[@]}"; do
    if pacman -Si "$p" &>/dev/null; then repo_pkgs+=("$p"); else aur_pkgs+=("$p"); fi
  done

  if (( ${#repo_pkgs[@]} > 0 )); then
    rsi_step "installing ${#repo_pkgs[@]} packages from the official repos"
    if rsi_dry; then
      rsi_dim "  would: sudo pacman -S --needed --noconfirm <${#repo_pkgs[@]} packages>"
    elif ! sudo pacman -S --needed --noconfirm "${repo_pkgs[@]}"; then
      rsi_warn "bulk repo install hit a snag; retrying one-by-one so a single conflict cannot block the rest"
      for p in "${repo_pkgs[@]}"; do
        sudo pacman -S --needed --noconfirm "$p" || rsi_warn "skipped (conflict or error): $p"
      done
    fi
    for p in "${repo_pkgs[@]}"; do rsi_record pkg "$p"; done
  fi

  if (( ${#aur_pkgs[@]} > 0 )); then
    local helper
    helper="$(rsi_arch_aur_helper)"
    [[ -n $helper ]] || helper="yay"
    rsi_step "installing ${#aur_pkgs[@]} AUR packages via $helper (failures are skipped, not fatal)"
    for p in "${aur_pkgs[@]}"; do
      if rsi_dry; then
        rsi_dim "  would: $helper -S --needed --noconfirm $p"
      elif "$helper" -S --needed --noconfirm "$p"; then
        rsi_record pkg "$p"
      else
        rsi_warn "AUR package failed (build error or not found), skipped: $p"
      fi
    done
  fi
}

# rsi_arch_pkg_present NAME -> 0 if installed.
rsi_arch_pkg_present() { pacman -Qq "$1" >/dev/null 2>&1; }
