# lockscreen/

The login screen and the in-session lock. Both are the qylock "clockwork"
theme, variant "orbital": a plain Qt6 QML greeter. It needs no Ryoku desktop
shell, so it works on a clean Hyprland session.

## What's here

- `qylock/` The vendored qylock bundle (clockwork theme + Quickshell
  lockscreen), trimmed to just what Ryoku ships. Copied verbatim from upstream;
  see `qylock/README.ryoku.md` for the source commit and license.
- `install-qylock` Installs the greeter and the in-session lock on the target
  machine: the orbital theme to `/usr/share/sddm/themes/orbital`, the SDDM
  selection to `/etc/sddm.conf.d/99-ryoku.conf`, and the Quickshell lockscreen
  into the user's home.
- `sddm/setup` The install-time SDDM wiring: enable the service, default to the
  graphical target, drop `pam_gnome_keyring` from the SDDM PAM stack, and make
  sure a Hyprland wayland session exists.
- `README.md`, `CHANGELOG.md` This file and the change log.

## Two pieces, one theme

The greeter you see at boot is SDDM rendering the orbital theme. After you log
in, locking the session (Hyprland binds Super+Alt+L, hypridle locks on idle)
runs `qylock/quickshell-lockscreen/lock.sh`, which launches Quickshell with the
same theme. The greeter reads `/etc/sddm.conf.d/99-ryoku.conf`; the in-session
lock reads `~/.config/qylock/theme` (set to `clockwork/orbital`).

The in-session lock skin is chosen in Ryoku Settings (**Lockscreen**), which browses
the full qylock catalogue live from upstream with looping previews. Selecting an
installed skin rewrites `~/.config/qylock/theme`; selecting one that isn't installed
downloads it into `~/.local/share/qylock/themes` first, then activates it. It only
swaps the skin; the greeter and the login flow are untouched.

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
