#!/usr/bin/env bash
# Generate cava config with correct audio monitor source
# Usage: generate_config.sh [output_file]
#
# Supports both PipeWire and PulseAudio systems.
# Uses the default sink monitor (final audio output).

OUTPUT_FILE="${1:-/tmp/cava_config.txt}"

# Detect audio backend (pipewire or pulseaudio)
get_audio_method() {
    if pactl info 2>/dev/null | grep -qi "PipeWire"; then
        echo "pipewire"
    else
        echo "pulse"
    fi
}

# Get the default sink's monitor source
get_default_monitor() {
    local default_sink
    default_sink=$(pactl get-default-sink 2>/dev/null)
    if [[ -n "$default_sink" ]]; then
        echo "${default_sink}.monitor"
        return
    fi
    # Fallback: auto-detect
    echo "auto"
}

METHOD=$(get_audio_method)
MONITOR=$(get_default_monitor)

cat > "$OUTPUT_FILE" << EOF
[general]
framerate = 60
autosens = 1
bars = 50

[input]
method = ${METHOD}
source = ${MONITOR}

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
channels = mono
mono_option = average

[smoothing]
noise_reduction = 20
EOF

echo "$OUTPUT_FILE"
