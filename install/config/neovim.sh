#!/bin/bash

set -euo pipefail

offline_cache="${RYOKU_NVIM_OFFLINE_CACHE:-/var/cache/ryoku/nvim}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"

[[ -d $offline_cache ]] || exit 0

mkdir -p "$data_home"
cp -an "$offline_cache/." "$data_home/" 2>/dev/null || true
