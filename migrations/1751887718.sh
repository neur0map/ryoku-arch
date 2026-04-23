echo "Install Impala as new wifi selection TUI"

if ryoku-cmd-missing impala; then
  ryoku-pkg-add impala
  ryoku-refresh-waybar
fi
