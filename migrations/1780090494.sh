echo "Move the keyboard layout into a user-owned keyboard.conf so updates can't reset it"

# kb_layout used to live in the shipped hyprland.conf, so any default-restore (the
# update safety net, the reorganize prompt, a config reset) wiped a custom layout
# back to us. Extract the user's current layout into keyboard.conf, which Ryoku
# never overwrites, and source it from hyprland.conf.

hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
hypr_conf="$hypr_dir/hyprland.conf"
kbd_conf="$hypr_dir/keyboard.conf"

[[ -f $hypr_conf ]] || exit 0
[[ -f $kbd_conf ]] && exit 0

get_val() {
  local line
  line=$(grep -m1 -E "^[[:space:]]*$1[[:space:]]*=" "$hypr_conf" 2>/dev/null) || return 0
  printf '%s' "${line#*=}" | sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

layout=$(get_val kb_layout); layout=${layout:-us}
variant=$(get_val kb_variant)
options=$(get_val kb_options)

cat >"$kbd_conf" <<EOF
# Keyboard layout. User-owned: edits here survive Ryoku updates.
# Layouts: \`localectl list-x11-keymap-layouts\`; variants/options: man 5 hyprland.conf (input).

input {
    kb_layout = $layout
    kb_variant = $variant
    kb_options = $options
}
EOF
echo "  Wrote $kbd_conf (kb_layout=$layout)"

sed -i -E '/^[[:space:]]*kb_(layout|variant|options)[[:space:]]*=/d' "$hypr_conf"

if ! grep -qxF 'source = ~/.config/hypr/keyboard.conf' "$hypr_conf"; then
  printf '\nsource = ~/.config/hypr/keyboard.conf\n' >>"$hypr_conf"
fi

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
