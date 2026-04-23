echo "Install swayOSD to show volume status"

if ryoku-cmd-missing swayosd-server; then
  ryoku-pkg-add swayosd
  setsid uwsm-app -- swayosd-server &>/dev/null &
fi
