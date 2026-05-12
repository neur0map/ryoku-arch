echo "Expose Ryoku update recovery commands in the user launcher path"

bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
mkdir -p "$bin_dir"

for command in ryoku-update ryoku-doctor; do
  source_path="$RYOKU_PATH/bin/$command"
  target_path="$bin_dir/$command"

  [[ -x $source_path ]] || continue
  ln -sf "$source_path" "$target_path"
  echo "Linked $target_path"
done
