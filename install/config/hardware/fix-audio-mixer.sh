# Fix "100% volume but barely audible" audio (hardware-agnostic).
#
# Cause: forcing WirePlumber to mix volume in software (the ALSA soft-mixer
# override) decouples the volume slider from the codec's
# hardware "Master" control. PipeWire then never raises the hardware mixer, so
# on any device whose hardware Master ships attenuated the output is ~20dB down
# even with the slider at 100% - on laptop speakers, headphones, and
# external/USB devices alike. Letting WirePlumber manage the hardware mixer
# natively (its default) couples the slider back to the hardware on every
# machine, so we never install the soft-mixer override and remove any copy a
# previous version left behind.
#
# Second, hardware-agnostic cause: WirePlumber 0.4.12+ defaults
# device.routes.default-sink-volume to 0.4 (40%) for new devices, so a fresh
# device starts attenuated until dragged up. We override it to 1.0.

soft_mixer_conf=~/.config/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf
soft_mixer_removed=0

# Drop any previously-forced software-mixer override so WirePlumber manages the
# hardware mixer natively again, and re-derive routes so the stale soft-mixer
# node is dropped.
if [[ -f $soft_mixer_conf ]]; then
  rm -f "$soft_mixer_conf"
  rm -rf ~/.local/state/wireplumber/default-routes
  soft_mixer_removed=1
fi

# Override WirePlumber's 40% default sink volume.
mkdir -p ~/.local/state/wireplumber
sm_settings=~/.local/state/wireplumber/sm-settings
if grep -q '^\[sm-settings\]' "$sm_settings" 2>/dev/null; then
  if grep -q '^device.routes.default-sink-volume=' "$sm_settings"; then
    sed -i 's/^device.routes.default-sink-volume=.*/device.routes.default-sink-volume=1.0/' "$sm_settings"
  else
    sed -i '/^\[sm-settings\]/a device.routes.default-sink-volume=1.0' "$sm_settings"
  fi
else
  printf '[sm-settings]\ndevice.routes.default-sink-volume=1.0\n' >>"$sm_settings"
fi
if command -v wpctl >/dev/null 2>&1 && pgrep -x wireplumber >/dev/null 2>&1; then
  wpctl settings --save device.routes.default-sink-volume 1.0 >/dev/null 2>&1 || true
fi

# Re-derive routes through the hardware mixer when we just removed the override
# on a live session; otherwise WirePlumber keeps the stale soft-mixer node (and
# the attenuated hardware Master) until the next login.
if (( soft_mixer_removed )) && pgrep -x wireplumber >/dev/null 2>&1; then
  systemctl --user restart wireplumber >/dev/null 2>&1 || true
fi

# Unmute the hardware output switches some codecs ship muted (a separate
# "silent speakers" symptom). WirePlumber owns the levels; the helper only
# flips the mute switches, it never forces a level.
"$RYOKU_PATH/bin/ryoku-audio-restore-mixers" || true
