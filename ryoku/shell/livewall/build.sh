#!/usr/bin/env bash
# Build ryoku-livewall, the lightweight video-wallpaper daemon.
#
# It software-decodes a (pre-downscaled) clip on the CPU and paints frames into
# wl_shm buffers on a wlr-layer-shell background surface, letting wp_viewport
# upscale a small render buffer to the whole output. Because it never creates an
# EGL/GL context, no GPU userspace driver (Mesa gallium+LLVM, or the NVIDIA
# GL/CUDA stack) is ever mapped into the process, so its RSS stays in the ~40 MB
# awww class on any GPU vendor -- unlike mpv/mpvpaper (a GL pipeline, 300-700 MB
# and an unbounded per-loop leak). The shell transcodes clips to <=720p30 first
# so the CPU decode is cheap (~8% of one core) and the decoded-frame pool small.
#
# Build-time only: wayland-scanner, a C toolchain, and the ffmpeg + wayland
# client dev libraries. The installed target runs against the ffmpeg/wayland
# runtime libraries the shell already depends on.
#
#   build.sh [output-path]   default: ./ryoku-livewall
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="${1:-$here/ryoku-livewall}"
proto="$(pkg-config --variable=pkgdatadir wayland-protocols)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

gen() { # xml basename
  wayland-scanner private-code  "$1" "$tmp/$2-protocol.c"
  wayland-scanner client-header "$1" "$tmp/$2-client-protocol.h"
}
gen "$here/wlr-layer-shell.xml"                     wlr-layer-shell
gen "$proto/stable/viewporter/viewporter.xml"        viewporter
gen "$proto/stable/xdg-shell/xdg-shell.xml"          xdg-shell

# shellcheck disable=SC2046  # intentional: split pkg-config's flags into argv
cc -O2 -Wall -I"$tmp" -o "$out" "$here/livewall.c" \
  "$tmp"/wlr-layer-shell-protocol.c "$tmp"/viewporter-protocol.c "$tmp"/xdg-shell-protocol.c \
  $(pkg-config --cflags --libs wayland-client libavformat libavcodec libavutil libswscale) -lm
