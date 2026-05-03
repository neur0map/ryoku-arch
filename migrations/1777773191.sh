echo "Refresh live Limine boot branding and Ryoku UKI"

if [[ -x $RYOKU_PATH/bin/ryoku-refresh-limine ]]; then
  "$RYOKU_PATH/bin/ryoku-refresh-limine"
fi
