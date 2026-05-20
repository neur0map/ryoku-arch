echo "Move Ryoku SDDM theme drop-in to a high-priority path"

new_conf="/etc/sddm.conf.d/99-ryoku-shell-theme.conf"
legacy_conf="/etc/sddm.conf.d/ryoku-shell-theme.conf"
upstream_legacy_conf="/etc/sddm.conf.d/i""nir-theme.conf"
generic_conf="/etc/sddm.conf.d/theme.conf"

if ! command -v sddm >/dev/null 2>&1; then
  exit 0
fi

sudo mkdir -p /etc/sddm.conf.d

if [[ ! -f $new_conf ]]; then
  for old_conf in "$legacy_conf" "$upstream_legacy_conf"; do
    if [[ -f $old_conf ]]; then
      sudo cp "$old_conf" "$new_conf"
      break
    fi
  done
fi

if [[ ! -f $new_conf && -f $generic_conf ]] \
  && grep -qE '^[[:space:]]*Current[[:space:]]*=[[:space:]]*ii-pixel[[:space:]]*$' "$generic_conf"; then
  sudo tee "$new_conf" >/dev/null <<'EOF'
[General]
DisplayServer=x11
InputMethod=

[Theme]
Current=ii-pixel
EOF
fi

for old_conf in "$legacy_conf" "$upstream_legacy_conf"; do
  if [[ -f $old_conf ]]; then
    sudo rm -f "$old_conf"
  fi
done
