echo "Use absolute Ryoku helper paths for web app launchers"

app_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
[[ -d $app_dir ]] || exit 0

ryoku_path_escaped="${RYOKU_PATH//&/\\&}"
ryoku_shell_launcher="${XDG_BIN_HOME:-$HOME/.local/bin}/ryoku-shell"
ryoku_shell_launcher_escaped="${ryoku_shell_launcher//&/\\&}"

while IFS= read -r -d '' desktop_file; do
  sed -i -E \
    -e "s|^Exec=ryoku-launch-webapp[[:space:]]+|Exec=\"$ryoku_path_escaped/bin/ryoku-launch-webapp\" |" \
    -e "s|^Exec=omarchy-launch-webapp[[:space:]]+|Exec=\"$ryoku_path_escaped/bin/ryoku-launch-webapp\" |" \
    -e "s|^Exec=ryoku-webapp-handler-([^[:space:]]+)[[:space:]]+|Exec=\"$ryoku_path_escaped/bin/ryoku-webapp-handler-\\1\" |" \
    -e "s|^Exec=omarchy-webapp-handler-([^[:space:]]+)[[:space:]]+|Exec=\"$ryoku_path_escaped/bin/ryoku-webapp-handler-\\1\" |" \
    -e "s|^Exec=ryoku-windows-vm([[:space:]]*)|Exec=\"$ryoku_path_escaped/bin/ryoku-windows-vm\"\\1|" \
    -e "s|^Exec=ryoku-shell([[:space:]]*)|Exec=\"$ryoku_shell_launcher_escaped\"\\1|" \
    "$desktop_file"
done < <(find "$app_dir" -maxdepth 1 -name "*.desktop" -print0 2>/dev/null)
