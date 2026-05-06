# Fix "100% volume but barely audible" symptoms.
#
# Two upstream causes, both hardware-agnostic:
#  1) Some codecs (notably Realtek ALC285/ALC287/ALC295) ship with hardware
#     mixer controls (Speaker, Headphone) muted or attenuated by default.
#     We force WirePlumber to manage volume in software and unmute the hw mixers.
#  2) WirePlumber 0.4.12+ defaults `device.routes.default-sink-volume` to 0.4
#     (40%) for new devices, so even with the slider at 100% the device starts
#     attenuated until the user manually drags it up.

mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
cp $RYOKU_PATH/default/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf ~/.config/wireplumber/wireplumber.conf.d/
rm -rf ~/.local/state/wireplumber/default-routes

# Initialize hardware mixer controls before WirePlumber routes through the soft mixer.
while read -r card; do
  for ctl in Master Speaker Headphone PCM; do
    amixer -c "$card" sget "$ctl" >/dev/null 2>&1 || continue
    amixer -c "$card" set "$ctl" 100% unmute >/dev/null 2>&1
  done
done < <(aplay -l 2>/dev/null | sed -n 's/^card \([0-9]\+\):.*/\1/p' | sort -u)

# Override WirePlumber's 40% default sink volume.
if command -v wpctl >/dev/null 2>&1 && pgrep -x wireplumber >/dev/null 2>&1; then
  wpctl settings --save device.routes.default-sink-volume 1.0 >/dev/null 2>&1 || true
fi
mkdir -p ~/.local/state/wireplumber
sm_settings=~/.local/state/wireplumber/sm-settings
if grep -q '^\[sm-settings\]' "$sm_settings" 2>/dev/null; then
  if grep -q '^device.routes.default-sink-volume=' "$sm_settings"; then
    sed -i 's/^device.routes.default-sink-volume=.*/device.routes.default-sink-volume=1.0/' "$sm_settings"
  else
    sed -i '/^\[sm-settings\]/a device.routes.default-sink-volume=1.0' "$sm_settings"
  fi
else
  printf '[sm-settings]\ndevice.routes.default-sink-volume=1.0\n' >> "$sm_settings"
fi
