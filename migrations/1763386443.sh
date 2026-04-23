echo "Uniquely identify terminal apps with custom app-ids using ryoku-launch-tui"

# Replace terminal -e calls with ryoku-launch-tui in bindings
sed -i 's/\$terminal -e \([^ ]*\)/ryoku-launch-tui \1/g' ~/.config/hypr/bindings.conf

# Update waybar to use ryoku-launch-or-focus with ryoku-launch-tui for TUI apps
sed -i 's|xdg-terminal-exec btop|ryoku-launch-or-focus-tui btop|' ~/.config/waybar/config.jsonc
sed -i 's|xdg-terminal-exec --app-id=com\.omarchy\.Wiremix -e wiremix|ryoku-launch-or-focus-tui wiremix|' ~/.config/waybar/config.jsonc
