echo "Add emergency entry for Walker"
CONFIG_FILE="$HOME/.config/walker/config.toml"

if [[ -f $CONFIG_FILE ]] && ! grep -q 'command = "ryoku-restart-walker"' "$CONFIG_FILE"; then
    cat >> "$CONFIG_FILE" << 'EOF'

[[emergencies]]
text = "Restart Walker"
command = "ryoku-restart-walker"
EOF
fi
