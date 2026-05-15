# Install Sound Open Firmware for the audio DSP on non-XPS Intel Panther Lake.
# XPS Panther Lake stays on linux-ptl, which hard-depends on sof-firmware.

if ryoku-hw-intel-ptl && ! ryoku-hw-match "XPS"; then
  ryoku-pkg-add sof-firmware
fi
