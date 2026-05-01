echo "Install Gradia image editor for screenshot editing"

if ryoku-pkg-present gradia; then
  exit 0
fi

if ryoku-cmd-missing yay && ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
  echo "  bootstrapping yay for Gradia install"
  RYOKU_ONLINE_INSTALL=1 bash "$RYOKU_PATH/install/preflight/yay-bootstrap.sh" || true
fi

if ! ryoku-pkg-aur-accessible; then
  echo "  AUR unavailable; aborting. Rerun ryoku-update when network is healthy." >&2
  exit 1
fi

ryoku-pkg-aur-add gradia
