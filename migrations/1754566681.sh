echo "Make new Osaka Jade theme available as new default"

if [[ ! -L ~/.config/ryoku/themes/osaka-jade ]]; then
  rm -rf ~/.config/ryoku/themes/osaka-jade
  git -C ~/.local/share/omarchy checkout -f themes/osaka-jade
  ln -nfs ~/.local/share/omarchy/themes/osaka-jade ~/.config/ryoku/themes/osaka-jade
fi
