echo "Expose Ryoku video edit-ready helper in the user launcher path"

bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
source_path="$RYOKU_PATH/bin/ryoku-cmd-video-edit-ready"
target_path="$bin_dir/ryoku-cmd-video-edit-ready"

mkdir -p "$bin_dir"

if [[ -x $source_path ]]; then
  ln -sf "$source_path" "$target_path"
  echo "Linked $target_path"
fi
