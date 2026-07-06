#!/usr/bin/env bash
# add (on) or drop (off) the Ryoku shell keybinds on the live session so the
# real bindings can be exercised. overrides yours until `hyprctl reload`.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
bin="$here/ipc/ryoku-shell"

binds=(
	"SUPER,Space,exec,$bin launcher"
	"SUPER,V,exec,$bin clipboard"
	"SUPER,L,exec,$bin lock"
	"SUPER,B,exec,$bin wallpaper"
	"SUPER,C,exec,flock -n -o /tmp/ryoku-wallpaper.lock qs -p $here/quickshell/wallpaper"
)

case "${1:-on}" in
on)
	for b in "${binds[@]}"; do hyprctl keyword bind "$b" >/dev/null; done
	echo "keybinds added. restore yours with: hyprctl reload"
	;;
off)
	for b in "${binds[@]}"; do hyprctl keyword unbind "${b%%,exec,*}" >/dev/null; done
	echo "keybinds removed"
	;;
*)
	echo "usage: dev-binds.sh [on|off]" >&2
	exit 1
	;;
esac
