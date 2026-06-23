#!/bin/bash
# Cobalt-backed media fetcher and local remuxer for the Ryoku shell file stash.
# Downloads through a cobalt API instance (https://github.com/imputnet/cobalt)
# when one is reachable, and falls back to yt-dlp otherwise so a fresh install
# still works. Remux is always a local, lossless ffmpeg container copy, which is
# exactly what cobalt's own remux does on-device (no re-encode).
#
# Point it at your instance with COBALT_API_URL (default http://localhost:9000);
# run one per https://github.com/imputnet/cobalt/blob/main/docs/run-an-instance.md
#
# Streams tab-separated, line-buffered status the stash queue parses:
#   START <name> | PROGRESS <0-100> | SAVED <filename> | ERROR <message>
# Usage: stash-cobalt.sh download <url> [auto|audio|mute] | remux <file>
set -u

STASH="${STASH_DIR:-$HOME/Downloads/Stash}"
COBALT="${COBALT_API_URL:-http://localhost:9000}"
mkdir -p "$STASH"

emit() { printf '%s\t%s\n' "$1" "${2:-}"; }

# A free path in the stash for the wanted name: "name.ext", then "name (1).ext".
dest_for() {
  local base; base=$(basename "$1"); [ -n "$base" ] || base="download"
  [ -e "$STASH/$base" ] || { printf '%s' "$STASH/$base"; return; }
  local stem ext i=1; stem="${base%.*}"; ext="${base##*.}"
  [ "$stem" = "$base" ] && ext=""
  while :; do
    local cand="$STASH/$stem ($i)${ext:+.$ext}"
    [ -e "$cand" ] || { printf '%s' "$cand"; return; }
    i=$((i + 1))
  done
}

cobalt_up() { curl -fsS --max-time 2 -H "Accept: application/json" "$COBALT/" >/dev/null 2>&1; }

# Fetch one direct URL to DEST. curl's default meter is parsed for a coarse percent.
fetch() {
  local url="$1" dest="$2" rc
  curl -fL --max-time 1800 -A "Mozilla/5.0 (X11; Linux x86_64)" -o "$dest" "$url" 2>&1 \
    | stdbuf -oL tr '\r' '\n' \
    | stdbuf -oL grep -oE '[0-9]{1,3}\.[0-9]' \
    | while read -r p; do emit PROGRESS "${p%.*}"; done
  rc=${PIPESTATUS[0]}
  return "$rc"
}

# yt-dlp fallback honouring the download mode; prints its own clean percent.
ytdlp() {
  local url="$1" mode="$2" out err dest status
  out=$(mktemp); err=$(mktemp); trap 'rm -f "$out" "$err"' RETURN
  local fmt=(--merge-output-format mp4)
  case "$mode" in
    audio) fmt=(-x --audio-format mp3) ;;
    mute)  fmt=(-f "bv*" --merge-output-format mp4) ;;
  esac
  ( yt-dlp --no-playlist --no-mtime --no-warnings --restrict-filenames --newline \
      "${fmt[@]}" -P "$STASH" -o "%(title).80s.%(ext)s" "$url" >"$out" 2>"$err" ) &
  local pid=$!
  ( tail -f --pid=$pid "$out" 2>/dev/null | stdbuf -oL grep -oE '\[download\] +[0-9]{1,3}\.[0-9]%' \
      | while read -r line; do line=${line##* }; emit PROGRESS "${line%%.*}"; done ) &
  wait $pid; status=$?
  if [ "$status" -ne 0 ]; then tail -n2 "$err" >&2; return "$status"; fi
  dest=$(sed -n 's/.*Merging formats into "\(.*\)".*/\1/p' "$out" | tail -n1)
  [ -n "$dest" ] || dest=$(sed -n 's/^\[download\] Destination: //p' "$out" | tail -n1)
  [ -n "$dest" ] || dest=$(sed -n 's/^\[ExtractAudio\] Destination: //p' "$out" | tail -n1)
  [ -n "$dest" ] || dest=$(find "$STASH" -maxdepth 1 -type f -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -n1 | cut -f2-)
  case "$dest" in /*) ;; *) dest="$STASH/$dest" ;; esac
  emit SAVED "$(basename "$dest")"
}

# cobalt POST + tunnel/redirect/picker; returns non-zero to trigger the fallback.
cobalt_get() {
  local url="$1" mode="$2" body resp st durl fn dest
  body=$(printf '{"url":%s,"downloadMode":"%s","filenameStyle":"basic"}' "$(printf '%s' "$url" | jq -Rs .)" "$mode")
  resp=$(curl -fsS --max-time 60 -X POST "$COBALT/" \
    -H "Accept: application/json" -H "Content-Type: application/json" -d "$body" 2>/dev/null) || return 1
  st=$(printf '%s' "$resp" | jq -r '.status // "error"')
  case "$st" in
    tunnel | redirect)
      durl=$(printf '%s' "$resp" | jq -r '.url')
      fn=$(printf '%s' "$resp" | jq -r '.filename // "download"')
      [ -n "$durl" ] && [ "$durl" != "null" ] || return 1
      emit START "$fn"; dest=$(dest_for "$fn")
      fetch "$durl" "$dest" || return 1
      emit SAVED "$(basename "$dest")"
      ;;
    picker)
      local n=0 i u t
      n=$(printf '%s' "$resp" | jq -r '.picker | length')
      [ "$n" -gt 0 ] || return 1
      for i in $(seq 0 $((n - 1))); do
        u=$(printf '%s' "$resp" | jq -r ".picker[$i].url")
        t=$(printf '%s' "$resp" | jq -r ".picker[$i].type // \"media\"")
        [ -n "$u" ] && [ "$u" != "null" ] || continue
        emit START "item $((i + 1)) of $n"
        dest=$(dest_for "cobalt-$t-$((i + 1)).${u##*.}")
        fetch "$u" "$dest" && emit SAVED "$(basename "$dest")"
      done
      ;;
    *) return 1 ;;
  esac
}

cmd="${1:-}"
case "$cmd" in
download)
  url="${2:-}"; mode="${3:-auto}"
  [ -n "$url" ] || { emit ERROR "no link"; exit 2; }
  case "$mode" in auto | audio | mute) ;; *) mode="auto" ;; esac
  emit START "fetching link"
  if cobalt_up && cobalt_get "$url" "$mode"; then
    notify-send "Stash" "Downloaded via cobalt" -i emblem-ok-symbolic 2>/dev/null || true
    exit 0
  fi
  # No cobalt instance, or it declined (auth/unsupported): fall back to yt-dlp.
  if ytdlp "$url" "$mode"; then
    notify-send "Stash" "Downloaded" -i emblem-ok-symbolic 2>/dev/null || true
    exit 0
  fi
  emit ERROR "download failed"
  notify-send "Stash" "Download failed" -i dialog-error 2>/dev/null || true
  exit 1
  ;;
remux)
  src="${2:-}"
  [ -f "$src" ] || { emit ERROR "file not found"; exit 2; }
  base=$(basename "$src"); stem="${base%.*}"; ext="${base##*.}"
  [ "$stem" = "$base" ] && ext="mp4"
  dest=$(dest_for "$stem.remux.$ext")
  emit START "$base"
  # Lossless container rebuild: copy every stream, fix the container and its
  # timestamps. No re-encode, so it is near-instant, just like cobalt's remux.
  if ffmpeg -nostdin -hide_banner -loglevel error -i "$src" -map 0 -c copy \
      -movflags +faststart "$dest" </dev/null; then
    emit SAVED "$(basename "$dest")"
    notify-send "Stash" "Remuxed $(basename "$dest")" -i emblem-ok-symbolic 2>/dev/null || true
    exit 0
  fi
  rm -f "$dest"
  emit ERROR "remux failed"
  notify-send "Stash" "Remux failed" -i dialog-error 2>/dev/null || true
  exit 1
  ;;
*)
  echo "usage: stash-cobalt.sh download <url> [auto|audio|mute] | remux <file>" >&2
  exit 2
  ;;
esac
