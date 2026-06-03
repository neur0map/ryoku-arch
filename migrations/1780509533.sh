echo "Fix missing app icons: create qt6ct.conf and repair the icon theme to Papirus"

# Qt apps (e.g. the Vicinae launcher) had no ~/.config/qt6ct/qt6ct.conf, so they
# resolved no icon theme and showed blank app logos; GNOME's icon-theme could
# also be left pointing at the unshipped Yaru. Re-run the canonical icon-theme
# setter - it now also creates qt6ct.conf with icon_theme=Papirus - then restart
# Vicinae so it picks up the new icon theme without a relogin.
ryoku-refresh-icon-theme >/dev/null 2>&1 || true
systemctl --user restart vicinae.service >/dev/null 2>&1 || true
