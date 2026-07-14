#!/usr/bin/env bash

# Current directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set library paths
export QML2_IMPORT_PATH="$DIR/imports:$QML2_IMPORT_PATH"
export QML_XHR_ALLOW_FILE_READ=1

# Get session type: the env when set, else this session's logind record.
# XDG_SESSION_ID pins the right session; scraping `loginctl | grep user`
# picked the first of several (re-login, nested session) and could misread.
if [ -z "${XDG_SESSION_TYPE:-}" ]; then
    sid="${XDG_SESSION_ID:-$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$(id -un)" '$3 == u {print $1; exit}')}"
    XDG_SESSION_TYPE="$(loginctl show-session "$sid" -p Type --value 2>/dev/null || true)"
    [ -n "$XDG_SESSION_TYPE" ] || XDG_SESSION_TYPE=wayland
fi
export XDG_SESSION_TYPE

# User theme preference
# Get user theme
CONFIG_FILE="$HOME/.config/qylock/theme"
if [ -n "$1" ]; then
    export QS_THEME="$1"
elif [ -f "$CONFIG_FILE" ]; then
    QS_THEME=$(cat "$CONFIG_FILE")
    export QS_THEME
else
    export QS_THEME="clockwork/orbital"
fi

# Set theme path
if [ -d "$DIR/../themes" ] && [ ! -d "$DIR/themes_link" ]; then
    export QS_THEME_PATH="$DIR/../themes/$QS_THEME"
else
    export QS_THEME_PATH="$DIR/themes_link/$QS_THEME"
fi

# A theme that vanished (an uninstalled skin still named by the config, a
# broken themes_link) must never lock into a black screen with no unlock UI:
# fall back to the stock theme before launching.
if [ ! -f "$QS_THEME_PATH/Main.qml" ]; then
    echo "qylock: theme '$QS_THEME' not found at $QS_THEME_PATH; falling back to clockwork/orbital" >&2
    for fb in "$DIR/themes_link/clockwork/orbital" "$DIR/../themes/clockwork/orbital"; do
        if [ -f "$fb/Main.qml" ]; then
            export QS_THEME="clockwork/orbital"
            export QS_THEME_PATH="$fb"
            break
        fi
    done
fi

echo "Locking with Quickshell using theme: $QS_THEME"
echo "Theme path: $QS_THEME_PATH"

# Kill active lockers
killall -9 hyprlock swaylock wlogout 2>/dev/null || true

# Execute lock screen. Whatever way it ends (unlock or crash), drop the
# "compositor confirmed the lock" marker lock_shell.qml wrote: a stale marker
# would let a later `ryoku-shell lock` read a starting locker as already
# covering the screen.
quickshell -p "$DIR/lock_shell.qml"
rc=$?
rm -f "${XDG_RUNTIME_DIR:-/tmp}/qylock.locked"
exit "$rc"
