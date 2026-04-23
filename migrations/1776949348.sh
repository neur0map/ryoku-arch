echo "Create Ryoku repo path bridge"

if [[ -d $HOME/.local/share/omarchy && ! -e $HOME/.local/share/ryoku ]]; then
  ln -snf "$HOME/.local/share/omarchy" "$HOME/.local/share/ryoku"
fi
