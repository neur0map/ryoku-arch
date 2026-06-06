echo "Stop forcing software audio mixing so the volume slider drives the hardware mixer"

# Forcing WirePlumber software mixing decoupled the slider from the codec's
# hardware "Master", leaving output ~20dB down ("100% volume, barely audible")
# on laptop speakers, headphones, and external/USB devices alike. The updated
# fix-audio-mixer.sh removes that override, restores WirePlumber's native
# hardware-mixer management (restarting WirePlumber on a live session), and
# unmutes the output switches.
# shellcheck disable=SC1091
source "$RYOKU_PATH/install/config/hardware/fix-audio-mixer.sh"
