echo "Apply Ryoku shell branding and default theme"

if [[ -x $RYOKU_PATH/install/config/ryoku-shell-branding.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
fi

if [[ -d $RYOKU_PATH/themes/ryoku ]] && ryoku-cmd-present ryoku-theme-set; then
  ryoku-theme-set "ryoku"
fi
