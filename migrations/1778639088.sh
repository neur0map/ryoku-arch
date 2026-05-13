echo "Remove obsolete edit-ready video helper launcher"

bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
launcher="$bin_dir/ryoku-cmd-video-edit-ready"
target="$RYOKU_PATH/bin/ryoku-cmd-video-edit-ready"

if [[ -L $launcher && $(readlink "$launcher") == $target ]]; then
  rm -f "$launcher"
  echo "Removed $launcher"
fi
