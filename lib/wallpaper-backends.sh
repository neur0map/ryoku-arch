#!/bin/bash
# Shared live-wallpaper backend lifecycle helpers, sourced by ryoku-wallpaper-apply.

ryoku_wp_type() {
  local p="${1,,}"
  case "$p" in
    *.mp4|*.mkv|*.mov|*.webm|*.avi) printf 'video\n' ;;
    *.gif)                          printf 'animated\n' ;;
    *.jpg|*.jpeg|*.png|*.webp|*.bmp|*.tif|*.tiff) printf 'image\n' ;;
    *)                              printf 'image\n' ;;
  esac
}

ryoku_wp_write_type() {
  local type="$1" dir="$RYOKU_STATE_PATH/wallpaper" tmp
  mkdir -p "$dir"
  tmp="$(mktemp "$dir/.type.XXXXXX")"
  printf '%s\n' "$type" >"$tmp"
  mv "$tmp" "$dir/type.txt"
}

ryoku_wp_stop_live_backends() {
  if pgrep -x mpvpaper >/dev/null 2>&1; then
    pkill -x mpvpaper 2>/dev/null || true
    # mpvpaper with --auto-pause can ignore SIGTERM; wait briefly then SIGKILL
    # any survivors so a new instance never stacks on top of an old one.
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      pgrep -x mpvpaper >/dev/null 2>&1 || break
      sleep 0.1
    done
    pgrep -x mpvpaper >/dev/null 2>&1 && pkill -KILL -x mpvpaper 2>/dev/null
    for _ in 1 2 3 4 5; do
      pgrep -x mpvpaper >/dev/null 2>&1 || break
      sleep 0.1
    done
  fi
  awww kill 2>/dev/null || true
}

ryoku_wp_make_poster() {
  local src="$1" out="$2"
  mkdir -p "$(dirname "$out")"; rm -f "$out"
  case "$(ryoku_wp_type "$src")" in
    video)
      command -v ffmpegthumbnailer >/dev/null 2>&1 &&
        ffmpegthumbnailer -i "$src" -o "$out" -s 1280 -q 9 >/dev/null 2>&1 || true ;;
    animated)
      command -v convert >/dev/null 2>&1 &&
        convert "${src}[0]" "$out" >/dev/null 2>&1 || true ;;
  esac
  [[ -f $out ]]
}
