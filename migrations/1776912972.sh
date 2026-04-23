echo "Create Ryoku state and config namespaces with legacy bridges"

mkdir -p "$HOME/.local/state/ryoku" "$HOME/.config/ryoku"

if [[ -d $HOME/.local/state/ryoku && ! -L $HOME/.local/state/ryoku ]]; then
  cp -an "$HOME/.local/state/ryoku/." "$HOME/.local/state/ryoku/"
  rm -rf "$HOME/.local/state/ryoku"
  ln -snf "$HOME/.local/state/ryoku" "$HOME/.local/state/ryoku"
fi

if [[ -d $HOME/.config/ryoku && ! -L $HOME/.config/ryoku ]]; then
  cp -an "$HOME/.config/ryoku/." "$HOME/.config/ryoku/"
fi
