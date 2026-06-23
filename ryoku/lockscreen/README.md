# lockscreen/

The login screen and the in-session lock. Both render the same qylock skin
(clockwork/orbital by default): a plain Qt6 QML greeter that needs no Ryoku
desktop shell, so it works on a clean Hyprland session.

## What's here

- `qylock/` The vendored qylock bundle (clockwork theme + Quickshell
  lockscreen), trimmed to just what Ryoku ships. Copied verbatim from upstream;
  see `qylock/README.ryoku.md` for the source commit and license.
- `install-qylock` Installs the greeter and the in-session lock on the target
  machine: the default skin to `/usr/share/sddm/themes/ryoku` (the fixed greeter
  name the Hub later overwrites), the SDDM selection to
  `/etc/sddm.conf.d/99-ryoku.conf`, and the Quickshell lockscreen into the user's home.
- `sddm/setup` The install-time SDDM wiring: enable the service, default to the
  graphical target, drop `pam_gnome_keyring` from the SDDM PAM stack, and make
  sure a Hyprland wayland session exists.
- `README.md`, `CHANGELOG.md` This file and the change log.

## Two pieces, one theme

The greeter you see at boot is SDDM rendering the selected skin (clockwork/orbital
by default). After you log in, locking the session (Hyprland binds Super+Alt+L,
hypridle locks on idle) runs `qylock/quickshell-lockscreen/lock.sh`, which launches
Quickshell with the same skin. The greeter reads `/etc/sddm.conf.d/99-ryoku.conf`;
the in-session lock reads `~/.config/qylock/theme`.

The skin is chosen in Ryoku Settings (**Lockscreen**), which browses the full qylock
catalogue live from upstream with looping previews. Selecting a skin rewrites
`~/.config/qylock/theme` (the in-session lock) and reinstalls it as the SDDM greeter
under `/usr/share/sddm/themes/ryoku`. The greeter half lives on a system path, so the
Hub escalates it with pkexec (`ryoku-hub lock apply-greeter`); skins not yet present
download into `~/.local/share/qylock/themes` first. Only the theme changes; the
login/auth flow is untouched.

## Installing by hand

```
sudo ryoku/lockscreen/sddm/setup        # service + session wiring
ryoku/lockscreen/install-qylock         # greeter theme + in-session lock
```

Both take `--dry-run` (or `RYOKU_DRYRUN=1`) to print the plan without changing
anything. The install backend runs them for you on a normal install.

## Packages it needs

The greeter and lock are Qt6 QML and depend on these (install them from the
package set, not from these scripts):

```
qt6-declarative qt6-5compat qt6-svg qt6-multimedia qt6-multimedia-ffmpeg quickshell
```
