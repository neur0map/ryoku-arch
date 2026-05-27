#!/usr/bin/env bash

if [ -z "$1" ]; then
	echo "Use: $0 /path/to/wallpaper [shader_path] [monitor_target]"
	exit 1
fi

WALLPAPER="$1"
SHADER="$2"
MONITOR="${3:-ALL}"

# When a specific monitor is targeted, we don't kill all mpvpaper instances,
# just the one for that monitor if possible. However mpvpaper doesn't
# natively support killing by monitor easily via pkill.
# For now, we'll kill by checking the command line args if MONITOR != ALL.
# We must avoid killing this script itself, so we filter by the exact executable name.
if [ "$MONITOR" = "ALL" ]; then
    pkill -x "mpvpaper" 2>/dev/null
else
    pgrep -x mpvpaper | while read -r pid; do
        if ps -p "$pid" -o args= | grep -q "$MONITOR"; then
            kill "$pid" 2>/dev/null
        fi
    done
fi
SOCKET="/tmp/ambxst_mpv_socket_${MONITOR}"

MPV_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 video-scale-x=1.0 video-scale-y=1.0 load-scripts=no input-ipc-server=$SOCKET"

# Si el shader no está vacío y el archivo existe, agregarlo a MPV_OPTS
if [ -n "$SHADER" ] && [ -f "$SHADER" ]; then
	MPV_OPTS="$MPV_OPTS glsl-shaders=$SHADER"
fi

nohup mpvpaper -o "$MPV_OPTS" "$MONITOR" "$WALLPAPER" >/tmp/mpvpaper.log 2>&1 &
