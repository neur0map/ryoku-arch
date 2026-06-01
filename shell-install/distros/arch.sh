#!/bin/bash

# Arch-family adapter. Implements the distro contract for arch and its
# derivatives (cachyos, endeavouros, manjaro, garuda, ...). Maps logical
# dependency names to real pacman/AUR packages and installs them.
#
# Contract (see TEMPLATE.sh):
#   ryoku_distro_prereqs
#   ryoku_distro_map <logical>          -> "repo|aur  pkg [pkg...]"
#   ryoku_distro_install <logical...>

# logical -> "class real [real...]". class is repo or aur.
declare -gA RSI_ARCH_PKG=(
  [compositor]="repo hyprland hypridle hyprlock hyprpicker"
  [quickshell]="repo quickshell"
  [portal]="repo xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xwayland-satellite"
  [build]="repo cmake ninja python git pkgconf"
  [qt]="repo qt6-base qt6-declarative qt6-wayland qt6-svg qt6-imageformats qt6-5compat qt6-multimedia qt6-quicktimeline qt6-positioning qt6-sensors qt6-tools"
  [theme]="repo qt6ct kvantum adwaita-icon-theme papirus-icon-theme hicolor-icon-theme"
  [fonts]="repo ttf-cascadia-code-nerd ttf-material-symbols-variable noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-dejavu"
  [audio]="repo pipewire pipewire-pulse pipewire-alsa wireplumber cava playerctl aubio"
  [color]="repo matugen wlsunset"
  [tools]="repo jq rsync curl bc fish brightnessctl imagemagick"
  [cursors]="aur bibata-cursor-theme-bin"
  [wallpaper]="aur skwd-daemon-bin skwd-wall"
)

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

# System-level packages that the OS install owns; never install these on an
# existing machine (bootloader hooks, snapshots, display manager, boot splash,
# kernel-module retention hook).
RSI_ARCH_DENY="plymouth sddm kernel-modules-hook limine-mkinitcpio-hook limine-snapper-sync"

ryoku_distro_prereqs() {
  rsi_step "ensuring base build tools"
  if rsi_dry; then
    rsi_dim "  would: sudo pacman -S --needed --noconfirm base-devel git"
  else
    sudo pacman -S --needed --noconfirm base-devel git
  fi
  rsi_arch_bootstrap_yay
}

# Install the full Ryoku app + dependency set from the shared manifests, minus
# the system-level denylist. The AUR helper resolves both official-repo and AUR
# packages, and --needed leaves anything already installed untouched (so it
# coexists with the user's existing apps). Failures are non-fatal and reported.
ryoku_distro_install_full() {
  local want=() p
  while IFS= read -r p; do want+=("$p"); done < <(
    sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
      "$RSI_BASE_PACKAGES" "$RSI_AUR_PACKAGES" 2>/dev/null | grep -v '^$'
  )
  if [[ ${#want[@]} -eq 0 ]]; then
    rsi_warn "no package manifests found; installing the minimal set instead"
    local deps=()
    mapfile -t deps < <(rsi_read_deps)
    ryoku_distro_install "${deps[@]}"
    return
  fi

  local pkgs=() missing=()
  for p in "${want[@]}"; do
    case " $RSI_ARCH_DENY " in *" $p "*) continue ;; esac
    pkgs+=("$p")
    rsi_arch_pkg_present "$p" || missing+=("$p")
  done

  rsi_say "  $(( ${#pkgs[@]} - ${#missing[@]} )) already present (kept), ${#missing[@]} to install, $(( ${#want[@]} - ${#pkgs[@]} )) system packages skipped"
  if (( ${#missing[@]} == 0 )); then
    rsi_ok "all Ryoku packages already present"
    return 0
  fi

  local helper
  helper="$(rsi_arch_aur_helper)"
  [[ -n $helper ]] || helper="yay"
  rsi_step "installing ${#missing[@]} Ryoku packages via $helper"
  if rsi_dry; then
    rsi_dim "  would: $helper -S --needed --noconfirm <${#missing[@]} packages>"
  else
    "$helper" -S --needed --noconfirm "${missing[@]}" \
      || rsi_warn "some packages did not install (a conflict, an AUR build error, or no network). The desktop may be missing pieces; re-run or install them by hand."
  fi
  for p in "${missing[@]}"; do rsi_record pkg "$p"; done
}

# rsi_arch_pkg_present NAME -> 0 if installed.
rsi_arch_pkg_present() { pacman -Qq "$1" >/dev/null 2>&1; }

ryoku_distro_map() {
  printf '%s' "${RSI_ARCH_PKG[$1]:-}"
}

# ryoku_distro_install LOGICAL... -> resolve, split repo/aur, install missing.
ryoku_distro_install() {
  local logical class entry repo=() aur=() name
  for logical in "$@"; do
    entry="${RSI_ARCH_PKG[$logical]:-}"
    [[ -n $entry ]] || { rsi_warn "no Arch mapping for '$logical', skipping"; continue; }
    class="${entry%% *}"
    for name in ${entry#* }; do
      if [[ $class == aur ]]; then aur+=("$name"); else repo+=("$name"); fi
    done
  done

  local missing=()
  for name in "${repo[@]}"; do
    rsi_arch_pkg_present "$name" || missing+=("$name")
  done
  if ((${#missing[@]})); then
    rsi_step "repo packages: ${missing[*]}"
    if rsi_dry; then
      rsi_dim "  would: sudo pacman -S --needed --noconfirm ${missing[*]}"
    else
      sudo pacman -S --needed --noconfirm "${missing[@]}"
    fi
    for name in "${missing[@]}"; do rsi_record pkg "$name"; done
  fi

  local aur_missing=()
  for name in "${aur[@]}"; do
    rsi_arch_pkg_present "$name" || aur_missing+=("$name")
  done
  if ((${#aur_missing[@]})); then
    local helper
    helper="$(rsi_arch_aur_helper)"
    [[ -n $helper ]] || helper="yay"
    rsi_step "AUR packages: ${aur_missing[*]}"
    if rsi_dry; then
      rsi_dim "  would: $helper -S --needed --noconfirm ${aur_missing[*]}"
    else
      "$helper" -S --needed --noconfirm "${aur_missing[@]}"
    fi
    for name in "${aur_missing[@]}"; do rsi_record pkg "$name"; done
  fi
}
