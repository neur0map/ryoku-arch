echo "Switch back to mainline chromium now that it supports full live themeing"

if ryoku-pkg-present omarchy-chromium; then
  if ryoku-tui confirm "Ready to switch to mainstream chromium? (Will close Chromium + reset settings)"; then
    pkill -x chromium
    ryoku-pkg-drop omarchy-chromium
    ryoku-pkg-add chromium
    ryoku-theme-set-browser
  fi
fi
