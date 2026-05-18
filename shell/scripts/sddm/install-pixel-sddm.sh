#!/bin/bash
# Install ii-pixel SDDM theme for Ryoku
# Pixel aesthetic with Material You dynamic colors matching the Quickshell lockscreen.
# Requires: sddm, qt6-declarative, qt6-5compat

set -euo pipefail

THEME_NAME="ii-pixel"
THEME_SRC="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/dots/sddm/pixel"
THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
SYNC_SCRIPT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/scripts/sddm/sync-pixel-sddm.py"
SDDM_CONF="/etc/sddm.conf.d/theme.conf"
LEGACY_SDDM_CONFS=(
  "/etc/sddm.conf.d/inir-theme.conf"
  "/etc/sddm.conf.d/ryoku-shell-theme.conf"
)
AUTO_APPLY_MODE="${RYOKU_SHELL_SDDM_AUTO_APPLY:-preserve}" # preserve|ask|yes|no

log_info() { echo -e "\033[0;36m[sddm] $*\033[0m"; }
log_ok()   { echo -e "\033[0;32m[sddm] ✓ $*\033[0m"; }
log_warn() { echo -e "\033[0;33m[sddm] ⚠ $*\033[0m"; }
log_err()  { echo -e "\033[0;31m[sddm] ✗ $*\033[0m"; }

# Intelligent privilege escalation: sudo for terminal, pkexec for graphical/IPC mode
elevate() {
  # If we have a TTY, use interactive sudo
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    sudo "$@"
    return $?
  fi
  
  # Try non-interactive sudo first (works if NOPASSWD is configured or credentials cached)
  if sudo -n true 2>/dev/null; then
    sudo "$@"
    return $?
  fi
  
  # Try pkexec for graphical environments with polkit
  if command -v pkexec &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    pkexec "$@"
    return $?
  fi
  
  # Last resort: try sudo anyway (may fail without TTY)
  sudo "$@"
}

get_current_sddm_theme() {
  local current="" value="" f

  shopt -s nullglob
  for f in /etc/sddm.conf.d/*.conf; do
    value=$(awk -F= '
      /^[[:space:]]*Current[[:space:]]*=/ {
        gsub(/[[:space:]]/, "", $2)
        current = $2
      }
      END { print current }
    ' "$f" 2>/dev/null || true)
    if [[ -n $value ]]; then
      current="$value"
    fi
  done
  shopt -u nullglob

  # Main sddm.conf can override drop-ins on some SDDM builds.
  if [[ -f /etc/sddm.conf ]]; then
    value=$(awk -F= '
      /^[[:space:]]*Current[[:space:]]*=/ {
        gsub(/[[:space:]]/, "", $2)
        current = $2
      }
      END { print current }
    ' /etc/sddm.conf 2>/dev/null || true)
    if [[ -n $value ]]; then
      current="$value"
    fi
  fi

  echo "$current"
}

cleanup_legacy_current_dropins() {
  local conf
  for conf in "${LEGACY_SDDM_CONFS[@]}"; do
    if [[ -f $conf ]]; then
      log_info "Removing stale SDDM theme drop-in: ${conf}"
      elevate rm -f "$conf"
    fi
  done
}

neutralize_conflicting_input_method() {
  local conf conf_name

  shopt -s nullglob
  for conf in /etc/sddm.conf.d/*.conf; do
    [[ -f $conf ]] || continue
    [[ $conf == "$SDDM_CONF" ]] && continue
    if grep -qiE '^[[:space:]]*InputMethod[[:space:]]*=[[:space:]]*qtvirtualkeyboard[[:space:]]*$' "$conf" 2>/dev/null; then
      conf_name="$(basename "$conf")"
      log_warn "Removing conflicting SDDM InputMethod from ${conf_name}"
      elevate sed -i '/^[[:space:]]*InputMethod[[:space:]]*=[[:space:]]*qtvirtualkeyboard[[:space:]]*$/Id' "$conf"
    fi
  done
  shopt -u nullglob

  if [[ -f /etc/sddm.conf ]] \
    && grep -qiE '^[[:space:]]*InputMethod[[:space:]]*=[[:space:]]*qtvirtualkeyboard[[:space:]]*$' /etc/sddm.conf 2>/dev/null; then
    log_warn "Removing conflicting SDDM InputMethod from /etc/sddm.conf"
    elevate sed -i '/^[[:space:]]*InputMethod[[:space:]]*=[[:space:]]*qtvirtualkeyboard[[:space:]]*$/Id' /etc/sddm.conf
  fi
}

write_pixel_sddm_conf() {
  elevate mkdir -p /etc/sddm.conf.d
  # Use X11 as display server - Wayland (kwin_wayland) crashes in some environments (VMs, etc.).
  # Keep Qt's built-in virtual keyboard disabled because the pixel theme ships its own.
  elevate tee "${SDDM_CONF}" > /dev/null << SDDM_EOF
[General]
DisplayServer=x11
InputMethod=

[Theme]
Current=${THEME_NAME}
SDDM_EOF
}

should_apply_theme() {
    local current_theme
    current_theme="$(get_current_sddm_theme)"

    if [[ $AUTO_APPLY_MODE == "yes" ]]; then
        return 0
    fi
    if [[ $AUTO_APPLY_MODE == "no" ]]; then
        log_info "Skipping SDDM Current theme switch by policy (RYOKU_SHELL_SDDM_AUTO_APPLY=no)"
        return 1
    fi
    if [[ $AUTO_APPLY_MODE == "preserve" ]]; then
        # Apply ii-pixel only on truly-fresh installs: no Current= found
        # anywhere under /etc/sddm.conf.d/ or /etc/sddm.conf. If any
        # conf carries a non-empty theme name, preserve it. Qylock and
        # any other user-chosen theme survive even if /etc/sddm.conf.d/
        # theme.conf gets temporarily clobbered or corrupted, because
        # get_current_sddm_theme reads from every conf.d file before
        # falling through.
        #
        # If the current theme is already ii-pixel, skip the rewrite
        # (idempotent). The theme files themselves are still synced by
        # the steps above; only the SDDM Current= line is left alone.
        if [[ -n $current_theme ]]; then
            if [[ $current_theme != "$THEME_NAME" ]]; then
                cleanup_legacy_current_dropins
                log_info "Preserving current SDDM theme: ${current_theme}"
            else
                log_info "SDDM already on ${THEME_NAME}, skipping conf rewrite"
            fi
            return 1
        fi
        # current_theme is empty: no Current= line in any conf. Truly
        # fresh install. Apply ii-pixel as the bundled default.
        return 0
    fi

    if [[ -z $current_theme || $current_theme == "$THEME_NAME" ]]; then
        return 0
    fi

    echo ""
    log_warn "Detected current SDDM theme: ${current_theme}"
    read -r -p "[sddm] Apply ${THEME_NAME} as SDDM Current theme? [y/N] " reply
    case "$reply" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *)
            log_info "Keeping current SDDM theme: ${current_theme}"
            return 1
            ;;
    esac
}

# Check SDDM is installed
if ! command -v sddm &>/dev/null; then
    log_warn "SDDM not installed. Skipping theme setup."
    log_info "Install with: sudo pacman -S sddm qt6-declarative qt6-5compat"
    exit 0
fi

if [[ ! -d "$THEME_SRC" ]]; then
    log_err "Theme source not found: $THEME_SRC"
    exit 1
fi

# Install theme files
# If user already owns the theme dir (from a previous install), skip sudo entirely.
# This allows IPC-triggered updates (ryoku-shell shell update) to refresh the theme
# without needing a terminal for sudo prompts.

# Checksum comparison: skip copy if source and target are identical.
# Only compare QML/JS/conf files (not assets like background.png which are user-generated).
theme_needs_update=true
if [[ -d "${THEME_DIR}" ]]; then
    src_hash=$(find "${THEME_SRC}" -maxdepth 1 -type f \( -name '*.qml' -o -name '*.js' -o -name '*.conf' -o -name 'metadata.desktop' \) -exec sha256sum {} + 2>/dev/null | sort | sha256sum | cut -d' ' -f1)
    tgt_hash=$(find "${THEME_DIR}" -maxdepth 1 -type f \( -name '*.qml' -o -name '*.js' -o -name '*.conf' -o -name 'metadata.desktop' \) -exec sha256sum {} + 2>/dev/null | sort | sha256sum | cut -d' ' -f1)
    if [[ -n "$src_hash" && "$src_hash" == "$tgt_hash" ]]; then
        theme_needs_update=false
    fi
fi

if $theme_needs_update; then
    log_info "Installing ${THEME_NAME} to ${THEME_DIR}..."
    if [[ -d "${THEME_DIR}" ]] && [[ -O "${THEME_DIR}" ]]; then
        # User already owns the directory — no sudo needed
        mkdir -p "${THEME_DIR}/assets"
        cp -rf "${THEME_SRC}/." "${THEME_DIR}/"
        log_ok "Theme files updated (no sudo needed — user owns dir)"
    else
        # First install or owned by root — requires elevation (sudo or pkexec)
        elevate mkdir -p "${THEME_DIR}/assets"
        elevate cp -rf "${THEME_SRC}/." "${THEME_DIR}/"
        log_ok "Theme files installed"

        # Transfer ownership to the current user so the sync script can update colors
        # and wallpaper on every wallpaper change without triggering sudo/polkit prompts.
        elevate chown -R "${USER}:${USER}" "${THEME_DIR}"
        log_ok "Theme directory owned by ${USER} — sync requires no sudo"
    fi
else
    log_ok "Theme files already up to date — skipping copy"
fi

# Create a placeholder background (symlinked to wallpaper later by sync script)
if [[ ! -f "${THEME_DIR}/assets/background.png" ]]; then
    log_info "No background.png yet — creating placeholder..."
    # Copy default wallpaper from Ryoku assets as initial background
    repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    default_wall="${repo_root}/assets/images/default_wallpaper.png"
    if [[ -f "$default_wall" ]]; then
        cp "$default_wall" "${THEME_DIR}/assets/background.png"
        log_ok "Default wallpaper set as background"
    else
        # Create a minimal 1x1 black PNG as placeholder
        python3 -c "
import struct, zlib
def make_png():
    sig = b'\x89PNG\r\n\x1a\n'
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
    idat = chunk(b'IDAT', zlib.compress(b'\x00\x14\x1b\x20'))
    iend = chunk(b'IEND', b'')
    return sig + ihdr + idat + iend
import sys; sys.stdout.buffer.write(make_png())
" > "${THEME_DIR}/assets/background.png"
        log_warn "Placeholder background created — run sync-pixel-sddm.py to set wallpaper"
    fi
fi

# Configure SDDM to use this theme (intelligent: optional if user has another theme)
pixel_theme_active=false
if should_apply_theme; then
    log_info "Configuring SDDM to use ${THEME_NAME}..."
    cleanup_legacy_current_dropins
    
    # Remove any existing Current= line from /etc/sddm.conf to avoid conflicts
    # The drop-in /etc/sddm.conf.d/ only works if the main file doesn't override it
    if [[ -f /etc/sddm.conf ]] && grep -qE '^[[:space:]]*Current[[:space:]]*=' /etc/sddm.conf 2>/dev/null; then
        log_info "Removing conflicting theme setting from /etc/sddm.conf..."
        elevate sed -i '/^[[:space:]]*Current[[:space:]]*=/d' /etc/sddm.conf
    fi
    
    write_pixel_sddm_conf
    log_ok "SDDM configured (${SDDM_CONF}) with X11 display server"
    pixel_theme_active=true
else
    current_theme="$(get_current_sddm_theme)"
    if [[ $current_theme == "$THEME_NAME" ]]; then
        log_info "Updating SDDM settings for ${THEME_NAME}..."
        cleanup_legacy_current_dropins
        write_pixel_sddm_conf
        log_ok "SDDM settings updated (${SDDM_CONF})"
        pixel_theme_active=true
    else
        log_info "Installed ${THEME_NAME}, but did not change SDDM Current theme"
    fi
fi

if [[ $pixel_theme_active == "true" ]]; then
    neutralize_conflicting_input_method
fi

# Run initial color sync now that files are in place
log_info "Running initial color sync..."
if python3 "$SYNC_SCRIPT" 2>/dev/null; then
    log_ok "Colors synced from Material You palette"
else
    log_warn "Color sync skipped (run after first wallpaper generation)"
fi

# Install sync script to ~/.local/bin for wallpaper change hook
SYNC_DST="${HOME}/.local/bin/sync-pixel-sddm.py"
mkdir -p "$(dirname "$SYNC_DST")"
cp "$SYNC_SCRIPT" "$SYNC_DST"
chmod +x "$SYNC_DST"
log_ok "Sync script installed to ${SYNC_DST}"

# NOTE: We no longer mutate the user theming config here.
# Color sync runs from the unified Python theming pipeline. Keep installer idempotent.

# Cleanup stale sudo-based hook variants from very old setups if present
MATUGEN_CONFIG="${XDG_CONFIG_HOME:-${HOME}/.config}/matugen/config.toml"
if [[ -f "$MATUGEN_CONFIG" ]]; then
    if grep -qE "post_hook\s*=\s*'.*sudo.*sync-pixel-sddm\.py" "$MATUGEN_CONFIG" 2>/dev/null; then
        log_warn "Detected legacy sudo SDDM theming hook in user config"
        log_warn "Please remove old ii-pixel-sddm hook block from: $MATUGEN_CONFIG"
    fi
fi

# Enable SDDM service (only on first install — on updates the service is already enabled,
# and running sudo without a terminal would fail in IPC mode)
if command -v systemctl &>/dev/null && [[ -d /run/systemd/system ]]; then
    if ! systemctl is-enabled sddm.service &>/dev/null 2>&1; then
        # Handle conflicting display-manager.service symlink (e.g., plasmalogin, gdm, etc.)
        if [[ -L /etc/systemd/system/display-manager.service ]]; then
            current_dm=$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null | xargs basename 2>/dev/null || echo "unknown")
            if [[ "$current_dm" != "sddm.service" ]]; then
                log_info "Removing conflicting display-manager.service -> ${current_dm}"
                elevate rm -f /etc/systemd/system/display-manager.service 2>/dev/null || true
            fi
        fi
        
        # Disable known conflicting display managers
        for dm in gdm lightdm lxdm greetd plasmalogin; do
            if systemctl is-enabled "${dm}.service" &>/dev/null 2>&1; then
                log_info "Disabling conflicting display manager: ${dm}"
                elevate systemctl disable "${dm}.service" 2>/dev/null || true
            fi
        done
        
        elevate systemctl enable sddm.service 2>/dev/null && log_ok "SDDM service enabled"
    fi
fi

log_ok "${THEME_NAME} installed and configured"
log_info "Test with: sddm-greeter-qt6 --test-mode --theme ${THEME_DIR}"
log_info "Colors auto-sync on wallpaper change via the Ryoku theming pipeline"
log_info "Manual re-sync: python3 ~/.local/bin/sync-pixel-sddm.py"
