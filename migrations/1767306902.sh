echo "Migrate to new theme setup"

# Move user-added backgrounds from Ryoku theme folders to user config
RYOKU_DIR="$HOME/.local/share/omarchy"
USER_BACKGROUNDS_DIR="$HOME/.config/ryoku/backgrounds"

if [[ -d $RYOKU_DIR/themes ]]; then
  cd "$RYOKU_DIR"

  # Get list of git-tracked background files (relative to omarchy dir)
  mapfile -t TRACKED_BACKGROUNDS < <(git ls-files --cached 'themes/*/backgrounds/*' 2>/dev/null)

  # Find all background files and check if they're untracked (user-added)
  for theme_dir in themes/*/; do
    theme_name=$(basename "$theme_dir")
    backgrounds_dir="themes/$theme_name/backgrounds"

    [[ -d $backgrounds_dir ]] || continue

    for bg_file in "$backgrounds_dir"/*; do
      [[ -f $bg_file ]] || continue

      # Check if this file is tracked by git
      is_tracked=false
      for tracked in "${TRACKED_BACKGROUNDS[@]}"; do
        if [[ $tracked == $bg_file ]]; then
          is_tracked=true
          break
        fi
      done

      if [[ $is_tracked == "false" ]]; then
        # This is a user-added background, move it to user config
        user_theme_bg_dir="$USER_BACKGROUNDS_DIR/$theme_name"
        mkdir -p "$user_theme_bg_dir"
        mv "$bg_file" "$user_theme_bg_dir/"
        echo "Moved user background: $bg_file -> $user_theme_bg_dir/"
      fi
    done
  done
fi

THEMES_DIR="$HOME/.config/ryoku/themes"
CURRENT_THEME_LINK="$HOME/.config/ryoku/current/theme"

# Get current theme name before removing anything
CURRENT_THEME_NAME=""
if [[ -L $CURRENT_THEME_LINK ]]; then
  CURRENT_THEME_NAME=$(basename "$(readlink "$CURRENT_THEME_LINK")")
elif [[ -d $CURRENT_THEME_LINK ]]; then
  CURRENT_THEME_NAME=$(basename "$CURRENT_THEME_LINK")
elif [[ -f $HOME/.config/ryoku/current/theme.name ]]; then
  CURRENT_THEME_NAME=$(cat "$HOME/.config/ryoku/current/theme.name")
fi

# Remove all symlinks from ~/.config/ryoku/themes
find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type l -delete

# Re-apply the current theme with the new system
if [[ -n $CURRENT_THEME_NAME ]]; then
  ryoku-theme-set "$CURRENT_THEME_NAME"
else
  # Backup to ensure a theme is set if we can't deduce the name
  ryoku-theme-set "Tokyo Night"
fi
