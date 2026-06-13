echo "Switch the default browser from Helium to Chromium for existing installs"

# Helium runs under XWayland to dodge a Chromium-on-Wayland rendering bug, but XWayland
# clients cannot capture native Wayland windows, so screen sharing (Discord/Meet/OBS)
# shows a black screen. Chromium on Wayland drives the PipeWire screencast portal and
# shares correctly. Offer to install Chromium and switch installs that still default to
# Helium; a browser the user deliberately chose is left untouched. New installs get
# Chromium from install/ryoku-base.packages + install/config/mimetypes.sh.

ryoku-default-app-migrate browser chromium
