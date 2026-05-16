echo "Repair Ryoku Neovim editor launcher"

set_env_line() {
  local file="$1" key="$2" value="$3"
  mkdir -p "$(dirname "$file")"
  touch "$file"

  if grep -q "^export $key=" "$file"; then
    sed -i "s|^export $key=.*|export $key=$value|" "$file"
  else
    printf 'export %s=%s\n' "$key" "$value" >>"$file"
  fi
}

for launcher in \
  "$RYOKU_PATH/bin/xdg-terminal-exec" \
  "$RYOKU_PATH/bin/ryoku-terminal-exec" \
  "$RYOKU_PATH/bin/ryoku-launch-tui" \
  "$RYOKU_PATH/bin/ryoku-launch-editor"
do
  [[ -f $launcher ]] && chmod +x "$launcher"
done

if [[ -x $RYOKU_PATH/bin/ryoku-refresh-applications ]]; then
  "$RYOKU_PATH/bin/ryoku-refresh-applications" || true
fi

set_env_line "$HOME/.config/uwsm/default" RYOKU_EDITOR nvim
set_env_line "$HOME/.config/uwsm/default" EDITOR nvim
set_env_line "$HOME/.config/uwsm/default" VISUAL nvim
set_env_line "$HOME/.config/uwsm/default" SUDO_EDITOR nvim

ryoku-cmd-missing xdg-mime && exit 0

for mime in \
  text/plain \
  text/english \
  text/x-makefile \
  text/x-c++hdr \
  text/x-c++src \
  text/x-chdr \
  text/x-csrc \
  text/x-java \
  text/x-moc \
  text/x-pascal \
  text/x-tcl \
  text/x-tex \
  application/x-shellscript \
  text/x-c \
  text/x-c++ \
  application/xml \
  text/xml
do
  xdg-mime default ryoku-editor.desktop "$mime" 2>/dev/null || true
done
