echo "Use explicit timezone selector when right-clicking on clock"

sed -i 's/ryoku-cmd-tzupdate/ryoku-launch-floating-terminal-with-presentation ryoku-tz-select/g' ~/.config/waybar/config.jsonc
