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
  rsi_step "running a full system upgrade (pacman -Syu)"
  sudo pacman -Syu --noconfirm \
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

# rsi_arch_libcava_present -> 0 if libcava.pc is visible to pkg-config.
rsi_arch_libcava_present() {
  if command -v pkgconf >/dev/null 2>&1 && pkgconf --exists libcava 2>/dev/null; then
    return 0
  fi
  if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists libcava 2>/dev/null; then
    return 0
  fi
  [[ -f /usr/lib/pkgconfig/libcava.pc ]]
}

# Build and install cava-ryoku from the in-tree PKGBUILD so the shell plugin
# can link libcava. Stock `cava` (official repo) is binary-only; it does not
# ship libcava.so or libcava.pc, so CMake's pkg_check_modules(Cava libcava)
# fails and the audio visualiser is silently disabled.
ryoku_distro_install_local_pkgs() {
  rsi_step "checking for libcava (required by the shell audio visualizer plugin)"

  if rsi_arch_libcava_present; then
    rsi_ok "libcava already available"
    return 0
  fi

  local pkgbuild_dir="$RSI_REPO/distro/arch/cava-ryoku"
  if [[ ! -f "$pkgbuild_dir/PKGBUILD" ]]; then
    rsi_warn "cava-ryoku PKGBUILD not found at $pkgbuild_dir; audio visualizer will be disabled"
    return 0
  fi

  rsi_step "building cava-ryoku from $pkgbuild_dir (replaces stock cava, adds libcava)"

  if rsi_dry; then
    rsi_dim "  would: pacman -Rdd cava (if installed, conflicts with cava-ryoku)"
    rsi_dim "  would: cd $pkgbuild_dir && makepkg --syncdeps --install --noconfirm --needed --clean"
    return 0
  fi

  # cava-ryoku declares conflicts=(cava); pre-remove the stock package so
  # pacman -U does not abort on the conflict.
  if rsi_arch_pkg_present cava; then
    rsi_step "removing stock cava (conflicts with cava-ryoku)"
    sudo pacman -Rdd --noconfirm cava || {
      rsi_warn "could not remove stock cava; cava-ryoku install may fail"
    }
  fi

  (cd "$pkgbuild_dir" && makepkg --syncdeps --install --noconfirm --needed --clean) || {
    rsi_warn "cava-ryoku build failed; audio visualizer will be disabled (check output above)"
    return 0
  }

  if rsi_arch_libcava_present; then
    rsi_ok "libcava available"
  else
    rsi_warn "cava-ryoku installed but libcava.pc not found; plugin build may still fail"
  fi
}

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
