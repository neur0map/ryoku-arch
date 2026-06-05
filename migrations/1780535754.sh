echo "Relocate the dashboard desktop-config store from ~/.config/ambxst to ~/.config/ryoku/dashboard"

# The active-desktop component (bar, notch, dashboard widgets -- formerly the
# vendored "ambxst" shell) used to persist its JSON config under
# ~/.config/ambxst/config, with its keybinds in ~/.config/ambxst/binds.json. The
# de-vendor rename repoints that store at ~/.config/ryoku/dashboard. Fresh
# installs already write there; bring an existing user's store in line so their
# desktop config survives the rename. Idempotent and best-effort: only move when
# the legacy source exists and the new target does not, and never fail the
# migration on a missing dir.

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
old_dir="$cfg/ambxst"
new_root="$cfg/ryoku"
new_dir="$new_root/dashboard"

# Nothing to migrate without the legacy store.
[[ -d $old_dir ]] || exit 0

# The new store lives under ~/.config/ryoku; make sure that root exists first.
mkdir -p "$new_root" || true

# Config store: ~/.config/ambxst/config -> ~/.config/ryoku/dashboard.
if [[ -d $old_dir/config && ! -e $new_dir ]]; then
  mv "$old_dir/config" "$new_dir" || true
fi

# Keybinds: ~/.config/ambxst/binds.json -> ~/.config/ryoku/dashboard/binds.json.
if [[ -f $old_dir/binds.json && ! -e $new_dir/binds.json ]]; then
  mkdir -p "$new_dir" || true
  mv "$old_dir/binds.json" "$new_dir/binds.json" || true
fi

# Drop the legacy dir once it is empty (rmdir refuses a non-empty dir, so any
# unexpected leftovers are preserved untouched).
rmdir "$old_dir" 2>/dev/null || true
