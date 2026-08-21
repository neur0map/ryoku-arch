#!/usr/bin/env bash
# fingerprint-unlock: install / uninstall Ryoku fingerprint unlock overrides
#
# Usage:
#   ./install.sh              install (backs up existing files)
#   ./install.sh --uninstall  restore from backups
#   ./install.sh --dry-run    show what would happen
#
# Requires: fprintd, fprintd-list (the user must have at least one finger
# enrolled for the lock to offer sensor unlock).

set -euo pipefail

DRY=0
UNINSTALL=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY=1 ;;
        --uninstall) UNINSTALL=1 ;;
        --help|-h)  echo "Usage: $0 [--dry-run] [--uninstall]"; exit 0 ;;
    esac
done

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCKSCREEN_DIR="$HOME/.local/share/quickshell-lockscreen"
THEME_DIR="$HOME/.local/share/qylock/themes/clockwork/orbital"
HUB_DIR="$HOME/.config/quickshell/hub/pages"
BACKUP_DIR="$HOME/.ryoku-fingerprint-backups"

# Files to install (source -> dest)
declare -A FILES=(
    ["$SCRIPT_DIR/shim/SddmShim.qml"]="$LOCKSCREEN_DIR/shim/SddmShim.qml"
    ["$SCRIPT_DIR/lock_shell.qml"]="$LOCKSCREEN_DIR/lock_shell.qml"
    ["$SCRIPT_DIR/assets/pam/ryoku-lock"]="$LOCKSCREEN_DIR/assets/pam/ryoku-lock"
    ["$SCRIPT_DIR/themes/clockwork/orbital/Main.qml"]="$THEME_DIR/Main.qml"
    ["$SCRIPT_DIR/pages/LockscreenPage.qml"]="$HUB_DIR/LockscreenPage.qml"
)

backup_file() {
    local dest="$1"
    if [ -f "$dest" ]; then
        local rel="${dest#$HOME/}"
        local bak="$BACKUP_DIR/$rel"
        mkdir -p "$(dirname "$bak")"
        if [ "$DRY" -eq 1 ]; then
            echo "  backup: $dest -> $bak"
        else
            cp "$dest" "$bak"
            echo "  backed up: $dest"
        fi
    fi
}

install_file() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [ "$DRY" -eq 1 ]; then
        echo "  install: $src -> $dest"
    else
        cp "$src" "$dest"
        echo "  installed: $dest"
    fi
}

restore_file() {
    local dest="$1"
    local rel="${dest#$HOME/}"
    local bak="$BACKUP_DIR/$rel"
    if [ -f "$bak" ]; then
        if [ "$DRY" -eq 1 ]; then
            echo "  restore: $bak -> $dest"
        else
            cp "$bak" "$dest"
            echo "  restored: $dest"
        fi
    elif [ "$DRY" -eq 1 ]; then
        echo "  skip (no backup): $dest"
    fi
}

echo "=== Ryoku Fingerprint Unlock ==="
echo ""

if [ "$UNINSTALL" -eq 1 ]; then
    echo "Restoring from backups in $BACKUP_DIR ..."
    for dest in "${FILES[@]}"; do
        restore_file "$dest"
    done
    echo ""
    echo "Done. Restart the shell: systemctl --user restart ryoku-shell"
    echo "Backups kept in: $BACKUP_DIR"
    exit 0
fi

# Preflight: check fprintd
if ! command -v fprintd-list &>/dev/null; then
    echo "WARNING: fprintd-list not found. Install fprintd for fingerprint support."
fi

# Check enrolled fingers
FINGER_COUNT=0
if command -v fprintd-list &>/dev/null; then
    FP_OUTPUT=$(fprintd-list "$(whoami)" 2>/dev/null || true)
    FINGER_COUNT=$(echo "$FP_OUTPUT" | grep -c "^ - #" || true)
fi

if [ "$FINGER_COUNT" -eq 0 ]; then
    echo "WARNING: No fingers enrolled. Run 'fprintd-enroll' first."
    echo ""
fi

echo "Backing up existing files to $BACKUP_DIR ..."
for dest in "${FILES[@]}"; do
    backup_file "$dest"
done

echo ""
echo "Installing fingerprint unlock overrides ..."
for src in "${!FILES[@]}"; do
    install_file "$src" "${FILES[$src]}"
done

echo ""
echo "=== Installed ==="
echo ""
echo "Files changed:"
for dest in "${FILES[@]}"; do
    echo "  $dest"
done
echo ""
echo "Backups: $BACKUP_DIR"
echo "  Restore with: $0 --uninstall"
echo ""
echo "Restart the shell: systemctl --user restart ryoku-shell"
echo "Test with: loginctl lock-session"
