#!/bin/bash

# Shared environment for the Ryoku Shell installer. Sourced by every other
# lib and by the install/uninstall entrypoints. Defines paths and run state;
# performs no actions.

# Repo root is the parent of shell-install/.
RSI_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RSI_REPO="$(cd -- "$RSI_DIR/.." && pwd)"
export RSI_DIR RSI_REPO

# Canonical deploy targets. RYOKU_PATH must match lib/runtime-env.sh so the
# deployed ryoku-* commands resolve their payload.
export RSI_RYOKU_PATH="${RSI_RYOKU_PATH:-$HOME/.local/share/ryoku}"
export RSI_SHELL_PATH="${RSI_SHELL_PATH:-$HOME/.local/share/ryoku-shell}"

# Update channel to deploy and track (maps 1:1 to a git branch in
# lib/ryoku-update-core.sh: main or unstable-dev). Empty = follow the branch you
# bootstrapped, else main. ryoku-update pulls this channel on later updates.
export RSI_CHANNEL="${RSI_CHANNEL:-}"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
export RSI_CONFIG_HOME="$CONFIG_HOME"
export RSI_BIN_HOME="$BIN_HOME"
export RSI_QUICKSHELL_DIR="$CONFIG_HOME/quickshell/ryoku-shell"

# Per-run state, manifest and backups.
export RSI_STATE_DIR="$STATE_HOME/ryoku-shell"
export RSI_MANIFEST="$RSI_STATE_DIR/manifest.tsv"
export RSI_BACKUP_ROOT="$RSI_STATE_DIR/backups"

# The Ryoku wayland session entry. The only path the installer writes with
# sudo; a distinct name so it sits beside the user's existing sessions.
export RSI_SESSION_FILE="/usr/share/wayland-sessions/ryoku.desktop"

# Run flags, overridable from the entrypoints.
export RSI_DRY_RUN="${RSI_DRY_RUN:-0}"
export RSI_ASSUME_YES="${RSI_ASSUME_YES:-0}"

# Driver boot config: 0 = install driver packages only (never rewrite this
# machine's boot path); 1 = full ISO parity (mkinitcpio/modprobe/bootloader).
# Default off for a user-scope install; --with-boot-config sets it to 1.
export RYOKU_BOOT_CONFIG="${RYOKU_BOOT_CONFIG:-0}"

# Ryoku package manifests (the source of truth shared with the OS installer).
export RSI_BASE_PACKAGES="$RSI_REPO/install/ryoku-base.packages"
export RSI_AUR_PACKAGES="$RSI_REPO/install/ryoku-aur.packages"

# os-release path, overridable for testing the distro-detection gate.
export RSI_OS_RELEASE="${RSI_OS_RELEASE:-/etc/os-release}"
