echo "Route text files through Ryoku's Neovim launcher"

if [[ -x $RYOKU_PATH/bin/ryoku-refresh-applications ]]; then
  "$RYOKU_PATH/bin/ryoku-refresh-applications" || true
fi

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
