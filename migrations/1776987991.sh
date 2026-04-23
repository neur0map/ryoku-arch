echo "Replace omarchy-nvim/LazyVim with Helix"

MARKER="$HOME/.local/state/ryoku/independence-cutover.nvim.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

ryoku-snapshot create || true

# Install helix first so the system always has a working editor
ryoku-pkg-add helix

# Back up user's nvim config if it exists and is not empty, then remove.
if [[ -d $HOME/.config/nvim ]]; then
  if [[ -n $(ls -A "$HOME/.config/nvim" 2>/dev/null) ]]; then
    backup="$HOME/.config/nvim.ryoku.bak.$(date +%s)"
    mv "$HOME/.config/nvim" "$backup"
    echo "  backed up ~/.config/nvim -> $backup"
  else
    rmdir "$HOME/.config/nvim" 2>/dev/null || true
  fi
fi

# Remove nvim-state directories if they exist
for d in "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
  [[ -d $d ]] && rm -rf "$d" && echo "  removed $d"
done

# Remove omarchy-nvim (LazyVim bundle) and neovim itself
sudo pacman -Rdd --noconfirm omarchy-nvim 2>/dev/null || true
sudo pacman -Rdd --noconfirm neovim 2>/dev/null || true

# Orphan sweep (will likely pick up anything only pulled in for nvim/LazyVim)
orphans=$(pacman -Qdtq 2>/dev/null || true)
if [[ -n $orphans ]]; then
  echo "  removing orphans:"
  echo "$orphans" | sed 's/^/    /'
  sudo pacman -Rns --noconfirm $orphans
fi

# Flip EDITOR on existing user config
if [[ -f $HOME/.config/uwsm/default ]]; then
  sed -i 's|^export EDITOR=nvim|export EDITOR=hx|' "$HOME/.config/uwsm/default"
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"

echo "  nvim cutover complete"
