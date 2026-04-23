echo "Create Ryoku state and config namespaces with legacy bridges"

mkdir -p "$HOME/.local/state/ryoku" "$HOME/.config/ryoku"

if [[ -d $HOME/.local/state/omarchy && ! -L $HOME/.local/state/omarchy ]]; then
  cp -an "$HOME/.local/state/omarchy/." "$HOME/.local/state/ryoku/"
  rm -rf "$HOME/.local/state/omarchy"
  ln -snf "$HOME/.local/state/ryoku" "$HOME/.local/state/omarchy"
fi

if [[ -d $HOME/.config/omarchy && ! -L $HOME/.config/omarchy ]]; then
  cp -an "$HOME/.config/omarchy/." "$HOME/.config/ryoku/"
fi
