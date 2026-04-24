echo "Add Tmux as an option with themed styling"

ryoku-pkg-add tmux

if [[ ! -f ~/.config/tmux/tmux.conf ]]; then
  mkdir -p ~/.config/tmux
  cp $RYOKU_PATH/config/tmux/tmux.conf ~/.config/tmux/tmux.conf
  ryoku-theme-refresh
fi
