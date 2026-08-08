# nautilus

The file manager. Nautilus keeps its settings in dconf (GSettings) and reads the
standard home folders directly, so there is no settings file to ship. What we do
ship is one extension: the Ryoku stash actions on the right-click menu (below).

## Stash actions

`ryoku-stash-menu.py` is a `nautilus-python` extension that reuses the
preserved stash's install and compression helpers without opening the sidebar:

- **Install with Ryoku** on an AppImage, tarball, Arch/`.deb`/`.rpm` package, or
  Flatpak bundle runs `stash-install.sh`. It passes `RYOKU_STASH_KEEP=1`, since a
  file you right-clicked is yours to keep, not a redundant stash copy to clear.
- **Compress with Ryoku** on a video or image runs `stash-compress.sh`, writing
  the shrunk copy beside the original.

`ryoku-desktop` installs it to `/usr/share/nautilus-python/extensions/`, loaded
for every user, so `nautilus-python` is the only dependency. Nautilus loads
extensions at startup, so a fresh install picks it up on the next `nautilus`
launch (`nautilus -q` to restart a running one).

## Home folders

The folders you see in the sidebar (Documents, Downloads, Pictures, Videos,
Music, Desktop) come from `xdg-user-dirs`. On first graphical login,
`xdg-user-dirs-update` creates them and writes `~/.config/user-dirs.dirs`.
Nautilus picks them up natively, so install `xdg-user-dirs` and make sure the
update runs once and nothing else is needed here.

## Optional defaults

If you want to set Nautilus preferences during install, apply them per user with
`gsettings` (the user session must be reachable, so run this as the logged-in
user, not via the chroot):

```sh
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
gsettings set org.gnome.nautilus.preferences show-hidden-files false
gsettings set org.gtk.Settings.FileChooser sort-directories-first true
```

These are conveniences, not requirements: a fresh Nautilus works without them.
