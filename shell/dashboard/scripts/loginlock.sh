#!/usr/bin/env bash

LOCKFILE="/tmp/ryoku_loginlock.lock"
if [ -e "$LOCKFILE" ]; then
	PID=$(cat "$LOCKFILE")
	if kill -0 "$PID" 2>/dev/null; then
		exit 0
	fi
fi
echo $$ >"$LOCKFILE"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/dashboard/system.json"

get_lock_cmd() {
	if [ -f "$CONFIG_FILE" ]; then
		jq -r '.idle.general.lock_cmd // "loginctl lock-session"' "$CONFIG_FILE"
	else
		echo "loginctl lock-session"
	fi
}

dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Session',member='Lock'" |
	while read -r line; do
		if echo "$line" | grep -q "member=Lock"; then
			COMMAND=$(get_lock_cmd)
			if [ -n "$COMMAND" ]; then
				eval "$COMMAND" &
			fi
		fi
	done
