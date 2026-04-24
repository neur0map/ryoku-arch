echo "Rename hibernation conf and drop legacy SDDM theme"

MARKER="$HOME/.local/state/ryoku/independence-cutover.assets.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

# Hibernation conf: rename omarchy_resume.conf -> ryoku_resume.conf so
# Category 4 brand assets stop carrying the omarchy name. If hibernation
# is configured, rebuild initramfs so the new filename takes effect.
LEGACY_RESUME="/etc/mkinitcpio.conf.d/omarchy_resume.conf"
RYOKU_RESUME="/etc/mkinitcpio.conf.d/ryoku_resume.conf"

if [[ -f $LEGACY_RESUME && ! -f $RYOKU_RESUME ]]; then
  echo "  renaming $LEGACY_RESUME -> $RYOKU_RESUME"
  sudo mv "$LEGACY_RESUME" "$RYOKU_RESUME"
  if command -v limine-mkinitcpio >/dev/null 2>&1; then
    sudo limine-mkinitcpio
  else
    sudo mkinitcpio -P
  fi
fi

# Legacy SDDM theme directories: qylock is now the canonical theme
# bundle; the old omarchy and ryoku custom theme dirs are not used.
for legacy in /usr/share/sddm/themes/omarchy /usr/share/sddm/themes/ryoku; do
  if [[ -d $legacy ]]; then
    echo "  removing legacy SDDM theme: $legacy"
    sudo rm -rf "$legacy"
  fi
done

# Clear [Theme] Current= from sddm config so qylock can set its own on
# next install run.
if [[ -f /etc/sddm.conf.d/autologin.conf ]]; then
  if grep -qE '^Current=(omarchy|ryoku)$' /etc/sddm.conf.d/autologin.conf; then
    echo "  clearing legacy [Theme] Current= from /etc/sddm.conf.d/autologin.conf"
    sudo sed -i '/^\[Theme\]$/,/^$/ { /^Current=\(omarchy\|ryoku\)$/d; /^\[Theme\]$/d }' /etc/sddm.conf.d/autologin.conf
  fi
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"

echo "  legacy SDDM theme + resume conf cleanup complete"
echo "  run 'ryoku-install-qylock' to pick a new SDDM theme from the qylock bundle"
