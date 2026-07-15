#!/usr/bin/env bash
# Fixture test for the ryowalls enhance verdict contract: every terminal path
# (done / sharp / error / unsupported) must exit with its documented code AND
# print one JSON verdict line on stdout carrying result, kind, and — for a
# skip — the pixels measured against the cap they met, and — for a failure —
# a why (gpu | read | ...), because the UI turns those into the "why nothing
# happened" note. Runs the real engine with a stub waifu2x (magick 200%
# resize), a stub hyprctl (2560-wide screen, so screen_cap = 2560) and an
# isolated HOME/XDG_STATE_HOME; also covers live-list badging clips with their
# real ffprobe'd resolution, the animated-image first-frame probe (a bare %h
# concatenates frame heights into nonsense like "12001200"), the all-GPUs-bad
# error path (regression: `local ok` unset used to trip set -u before the
# verdict), and the unreadable-clip path (regression: a failing ffprobe used
# to errexit the verb with no verdict at all).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
engine="$here/../ryoku/apps/ryowalls/bin/ryowalls"

for tool in jq magick identify; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP: $tool required" >&2
    exit 0
  fi
done
have_ffmpeg=1
{ command -v ffmpeg && command -v ffprobe; } >/dev/null 2>&1 || have_ffmpeg=0

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Isolate everything the engine persists (enhance state, gpu pref, wallpaper
# state, Pictures pools) so the test never touches the real account.
export HOME="$work/home"
export XDG_STATE_HOME="$work/state"
mkdir -p "$HOME" "$XDG_STATE_HOME"

# Shim dir: a hyprctl claiming one 2560x1440 monitor at scale 1 (screen_cap
# resolves to 2560) and a waifu2x that doubles with magick, dir or single
# file. Prepended to PATH — not a hard reset — so the stubs shadow any system
# waifu2x/hyprctl while every other tool resolves wherever the host keeps it.
shim="$work/shim"
mkdir -p "$shim"
cat >"$shim/hyprctl" <<'EOF'
#!/bin/sh
printf '[{"width":2560,"height":1440,"scale":1.0}]\n'
EOF
cat >"$shim/waifu2x-ncnn-vulkan" <<'EOF'
#!/usr/bin/env bash
in=""; out=""
while [ $# -gt 0 ]; do
  case "$1" in
  -i) in="$2"; shift 2 ;;
  -o) out="$2"; shift 2 ;;
  *) shift ;;
  esac
done
if [ -d "$in" ]; then
  mkdir -p "$out"
  for f in "$in"/*.png; do magick "$f" -resize 200% "$out/$(basename "$f")"; done
else
  magick "$in" -resize 200% "$out"
fi
EOF
chmod +x "$shim/hyprctl" "$shim/waifu2x-ncnn-vulkan"
export PATH="$shim:$PATH"

# a wedged-GPU shim: waifu2x "succeeds" but emits flat black frames, which the
# engine's sane_img must reject on every GPU index -> error verdict, why=gpu.
badgpu="$work/badgpu"
mkdir -p "$badgpu"
cp "$shim/hyprctl" "$badgpu/hyprctl"
cat >"$badgpu/waifu2x-ncnn-vulkan" <<'EOF'
#!/usr/bin/env bash
in=""; out=""
while [ $# -gt 0 ]; do
  case "$1" in
  -i) in="$2"; shift 2 ;;
  -o) out="$2"; shift 2 ;;
  *) shift ;;
  esac
done
if [ -d "$in" ]; then
  mkdir -p "$out"
  for f in "$in"/*.png; do magick -size 64x64 xc:black "$out/$(basename "$f")"; done
else
  magick -size 64x64 xc:black "$out"
fi
EOF
chmod +x "$badgpu/waifu2x-ncnn-vulkan"

# a PATH with no upscaler at all, for the unsupported verdict: only the tools
# the probed paths need, symlinked one by one, so a waifu2x installed
# system-wide (as on any machine that ships ryoku-desktop) can't leak in.
noshim="$work/noshim"
mkdir -p "$noshim"
for t in bash jq identify magick tr mkdir dirname cat head tail; do
  ln -s "$(command -v "$t")" "$noshim/$t"
done
[ "$have_ffmpeg" -eq 1 ] && ln -s "$(command -v ffmpeg)" "$noshim/ffmpeg"

fail=0
pass=0
ok()  { printf 'PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n  %s\n' "$1" "$2" >&2; fail=$((fail + 1)); }

run_enhance() { # path -> sets rc + verdict (last stdout line)
  rc=0
  local out
  out="$("$engine" enhance "$1" 2>/dev/null)" || rc=$?
  verdict="$(printf '%s\n' "$out" | tail -n1)"
}

# ---- image: already 4K tall -> sharp, exit 2, px/cap in the verdict ---------
magick -size 320x2200 gradient: "$work/tall.png"
run_enhance "$work/tall.png"
if [ "$rc" -eq 2 ] && jq -e '.result=="sharp" and .kind=="image" and .px==2200 and .cap==2160' >/dev/null 2>&1 <<<"$verdict"; then
  ok "image sharp verdict"
else
  bad "image sharp verdict" "rc=$rc verdict=$verdict"
fi
if jq -e '.phase=="sharp"' "$XDG_STATE_HOME/ryoku-ryowalls-enhance.json" >/dev/null 2>&1; then
  ok "image sharp state file"
else
  bad "image sharp state file" "$(cat "$XDG_STATE_HOME/ryoku-ryowalls-enhance.json" 2>/dev/null)"
fi

# ---- image: small -> upscaled in place, exit 0, done verdict -----------------
magick -size 320x180 gradient:red-blue "$work/small.png"
run_enhance "$work/small.png"
got="$(identify -format '%wx%h' "$work/small.png" 2>/dev/null)"
if [ "$rc" -eq 0 ] && [ "$got" = "640x360" ] && jq -e '.result=="done" and .kind=="image"' >/dev/null 2>&1 <<<"$verdict"; then
  ok "image done verdict + 2x output"
else
  bad "image done verdict + 2x output" "rc=$rc size=$got verdict=$verdict"
fi

# ---- image: animated, 1200px frames -> NOT sharp (first-frame probe) ---------
# a bare identify %h prints every frame's height concatenated ("12001200"),
# which used to misread a 1080p-class animation as past-4K and skip it.
# gradient frames, not solid xc: — sane_img rightly rejects zero-deviation
# output as flat garbage, and a solid frame is exactly that.
magick -size 100x1200 gradient:red-yellow gradient:blue-green "$work/anim.gif"
run_enhance "$work/anim.gif"
if [ "$rc" -eq 0 ] && jq -e '.result=="done" and .kind=="image"' >/dev/null 2>&1 <<<"$verdict"; then
  ok "animated image enhances (first-frame height probe)"
else
  bad "animated image enhances (first-frame height probe)" "rc=$rc verdict=$verdict"
fi

# ---- image: every GPU emits garbage -> error, exit 1, why=gpu ----------------
magick -size 320x180 gradient: "$work/small3.png"
PATH="$badgpu:$PATH" run_enhance "$work/small3.png"
if [ "$rc" -eq 1 ] && jq -e '.result=="error" and .kind=="image" and .why=="gpu"' >/dev/null 2>&1 <<<"$verdict"; then
  ok "image error verdict (black output rejected)"
else
  bad "image error verdict (black output rejected)" "rc=$rc verdict=$verdict"
fi

# ---- image: no upscaler on PATH -> unsupported, exit 3 -----------------------
magick -size 320x180 gradient: "$work/small2.png"
PATH="$noshim" run_enhance "$work/small2.png"
if [ "$rc" -eq 3 ] && jq -e '.result=="unsupported" and .kind=="image"' >/dev/null 2>&1 <<<"$verdict"; then
  ok "image unsupported verdict"
else
  bad "image unsupported verdict" "rc=$rc verdict=$verdict"
fi

if [ "$have_ffmpeg" -eq 1 ]; then
  # ---- video: at the screen cap -> sharp, exit 2, px/cap in the verdict -----
  ffmpeg -y -f lavfi -i "testsrc2=size=2560x160:rate=10:duration=0.5" -c:v libx264 -pix_fmt yuv420p "$work/wide.mkv" >/dev/null 2>&1
  run_enhance "$work/wide.mkv"
  if [ "$rc" -eq 2 ] && jq -e '.result=="sharp" and .kind=="video" and .px==2560 and .cap==2560' >/dev/null 2>&1 <<<"$verdict"; then
    ok "video sharp verdict"
  else
    bad "video sharp verdict" "rc=$rc verdict=$verdict"
  fi

  # ---- video: small -> sibling .mp4 at 2x, source untouched, done verdict ---
  ffmpeg -y -f lavfi -i "testsrc2=size=320x180:rate=10:duration=0.5" -c:v libx264 -pix_fmt yuv420p "$work/clip.mkv" >/dev/null 2>&1
  run_enhance "$work/clip.mkv"
  vres="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$work/clip.mp4" 2>/dev/null | head -1)"
  if [ "$rc" -eq 0 ] && [ "$vres" = "640x360" ] && [ -s "$work/clip.mkv" ] \
    && jq -e --arg out "$work/clip.mp4" '.result=="done" and .kind=="video" and .out==$out' >/dev/null 2>&1 <<<"$verdict"; then
    ok "video done verdict + sibling 2x mp4"
  else
    bad "video done verdict + sibling 2x mp4" "rc=$rc res=$vres verdict=$verdict"
  fi

  # ---- video: every GPU emits garbage -> error, exit 1, why=gpu --------------
  # regression: with all GPUs bad, `local ok` stayed unset and set -u killed
  # the engine at [ -n "$ok" ] before any verdict or error state was written.
  ffmpeg -y -f lavfi -i "testsrc2=size=320x180:rate=10:duration=0.5" -c:v libx264 -pix_fmt yuv420p "$work/clip2.mkv" >/dev/null 2>&1
  PATH="$badgpu:$PATH" run_enhance "$work/clip2.mkv"
  if [ "$rc" -eq 1 ] && jq -e '.result=="error" and .kind=="video" and .why=="gpu"' >/dev/null 2>&1 <<<"$verdict"; then
    ok "video error verdict (black frames rejected on every GPU)"
  else
    bad "video error verdict (black frames rejected on every GPU)" "rc=$rc verdict=$verdict"
  fi

  # ---- video: unreadable file -> error, exit 1, why=read ---------------------
  # regression: ffprobe failing on the width probe used to errexit the verb
  # with an empty stdout and the state file stuck at phase "probe".
  head -c 4096 /dev/urandom >"$work/garbage.mp4"
  run_enhance "$work/garbage.mp4"
  if [ "$rc" -eq 1 ] && jq -e '.result=="error" and .kind=="video" and .why=="read"' >/dev/null 2>&1 <<<"$verdict"; then
    ok "video error verdict (unreadable source)"
  else
    bad "video error verdict (unreadable source)" "rc=$rc verdict=$verdict"
  fi

  # ---- video: no upscaler on PATH -> unsupported, exit 3 ---------------------
  ffmpeg -y -f lavfi -i "testsrc2=size=320x180:rate=10:duration=0.2" -c:v libx264 -pix_fmt yuv420p "$work/clip3.mkv" >/dev/null 2>&1
  PATH="$noshim" run_enhance "$work/clip3.mkv"
  if [ "$rc" -eq 3 ] && jq -e '.result=="unsupported" and .kind=="video"' >/dev/null 2>&1 <<<"$verdict"; then
    ok "video unsupported verdict"
  else
    bad "video unsupported verdict" "rc=$rc verdict=$verdict"
  fi

  # ---- live-list: local clips badge their real resolution -------------------
  mkdir -p "$HOME/Pictures/livewalls"
  cp "$work/clip.mp4" "$HOME/Pictures/livewalls/clip.mp4"
  row="$("$engine" live-list 2>/dev/null | head -1)"
  if jq -e '.resolution=="640x360"' >/dev/null 2>&1 <<<"$row"; then
    ok "live-list real resolution"
  else
    bad "live-list real resolution" "row=$row"
  fi
else
  echo "SKIP: video cases need ffmpeg + ffprobe" >&2
fi

printf '%d passed, %d failed\n' "$pass" "$fail"
exit "$((fail > 0 ? 1 : 0))"
