#!/bin/bash
set -euo pipefail

# Generate cava config for internal widget usage.
# Usage: generate_config.sh <output_file> [framerate] [sensitivity] [bars] [stereo]

OUTPUT_FILE="${1:-/tmp/cava_config.txt}"
FRAMERATE="${2:-60}"
SENSITIVITY="${3:-100}"
BARS="${4:-50}"
STEREO="${5:-false}"

get_audio_method() {
  if command -v pactl >/dev/null 2>&1 && pactl info 2>/dev/null | grep -qi "PipeWire"; then
    echo "pipewire"
  else
    echo "pulse"
  fi
}

get_default_monitor() {
  local default_sink
  default_sink="$(pactl get-default-sink 2>/dev/null || true)"
  if [[ -n $default_sink ]]; then
    echo "${default_sink}.monitor"
    return
  fi
  echo "auto"
}

METHOD="$(get_audio_method)"
MONITOR="$(get_default_monitor)"
CHANNELS="mono"
[[ $STEREO == "true" ]] && CHANNELS="stereo"

cat > "$OUTPUT_FILE" <<EOF
[general]
framerate = ${FRAMERATE}
sensitivity = ${SENSITIVITY}
autosens = 1
bars = ${BARS}

[input]
method = ${METHOD}
source = ${MONITOR}

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
channels = ${CHANNELS}
mono_option = average

[smoothing]
noise_reduction = 20
EOF

echo "$OUTPUT_FILE"
