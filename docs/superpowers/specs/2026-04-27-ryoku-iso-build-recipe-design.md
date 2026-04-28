# Ryoku ISO Build Recipe (Working Offline Path)

> Captures the working build / install / boot recipe for the Ryoku ISO as
> of 2026-04-27. Intended for: future contributors who want to add
> customizations without breaking the offline install path, and for the
> next time the install regresses.

## What is verified

| Stage | Verified | Notes |
|---|---|---|
| Build container builds the ISO | yes | `iso/bin/ryoku-iso-make --local-source --no-boot-offer` exits 0 on a clean cache and on a warm cache |
| Live ISO boots in QEMU/UEFI VM | yes | `iso/bin/ryoku-iso-boot iso/release/ryoku-*-main.iso` opens GTK + reaches the configurator UI |
| `archinstall` pacstraps base from the offline mirror | yes | No internet needed to reach the configurator finish line |
| Chroot install runs `install/*` to completion | yes | Exits with `/mnt/var/tmp/ryoku-install-completed`, VM auto-reboots |
| First-boot reaches branded boot + SDDM + Hyprland | yes | Confirmed 2026-04-28: Limine boot menu (color caveat below) -> Plymouth decrypt prompt -> pixel-rainyroom SDDM -> Hyprland session with a working terminal |
| Online install (`RYOKU_ONLINE_INSTALL=1` in chroot env) | NOT smoke-tested | The live ISO currently runs the chroot in offline mode; online path is intentional fallback only |

## Local prerequisites

- Docker daemon running. The ISO is built inside `archlinux/archlinux:latest`.
- `qemu-full` and `edk2-ovmf` on the host. `ryoku-iso-boot` will install them with `ryoku-pkg-add` if missing.
- ~6 GB free in `$HOME/.cache/ryoku` for the warm-cache path. Cold rebuilds need extra room for the package downloads.
- Wayland or X11 session. `ryoku-iso-boot` opens a `-display gtk,gl=on` window.

## Working build recipe

```bash
cd /home/omi/prowl/ryoku-arch

# Optional cold-cache reset
sudo rm -rf "$HOME/.cache/ryoku"
rm -f /tmp/ryoku-iso-boot.qcow2 /tmp/OVMF_VARS.4m.fd iso/release/*.iso

# Build (warm cache: ~5-10 min, cold cache: ~30 min)
./iso/bin/ryoku-iso-make --local-source --no-boot-offer

# Boot for GUI testing
./iso/bin/ryoku-iso-boot iso/release/ryoku-*-main.iso
```

Port 2222 on the host is hostfwd'd to the VM's port 22, so `ssh -p 2222 root@localhost` works once `sshd` starts inside the live env. If a previous QEMU is still running, the new boot will refuse to bind 2222 and exit; kill the stale `qemu-system-x86_64` first.

## Install flow (live ISO -> installed disk)

1. SYSLINUX (BIOS) / GRUB (UEFI) loads kernel + initramfs from the live ISO.
2. archiso live env boots, mounts squashfs root.
3. `/root/.automated_script.sh` runs on tty1:
   1. `use_ryoku_helpers` exports `RYOKU_PATH` / `RYOKU_INSTALL`.
   2. `run_configurator` collects user info into `user_configuration.json` + `user_credentials.json`.
   3. `install_arch` calls `archinstall --silent` against the configurator JSON, mounts `/var/cache/ryoku/mirror/offline` into `/mnt`, copies `/root/ryoku` into `/mnt/home/<user>/.local/share/`, writes static `/mnt/etc/resolv.conf` (1.1.1.1 + 8.8.8.8).
   4. `install_ryoku` runs `arch-chroot /mnt /bin/bash <user>'s install.sh` with `env -i RYOKU_CHROOT_INSTALL=1`.
4. The chroot `install.sh` runs `preflight/all.sh` then `packaging/all.sh` then `config/all.sh` then `login/all.sh` then `post-install/all.sh`.
   - In offline mode (`RYOKU_ONLINE_INSTALL` unset, the default in the live ISO env), `preflight/pacman.sh`, `preflight/yay-bootstrap.sh`, `packaging/aur-core.sh`, `packaging/tofi.sh`, etc. exit early.
   - `packaging/base.sh` installs everything in `install/ryoku-base.packages` from the offline mirror's `[offline]` repo.
   - `login/limine-snapper.sh` hard-fails if `limine`, `limine-snapper-sync`, `limine-mkinitcpio-hook`, or `limine-update` is missing; runs `mkinitcpio -P` + `limine-update`; asserts `/boot/EFI/Linux/ryoku_linux.efi` and a `^/+Ryoku` entry in `/boot/limine.conf`.
   - `login/sddm.sh` refuses to enable SDDM unless the bundled pixel-rainyroom theme + the hyprland-uwsm session file exist.
   - `post-install/pacman.sh` swaps `/etc/pacman.conf` to the upstream-only config, dropping the temporary `[offline]` entry from the user's installed system.
   - `post-install/finished.sh` writes `/mnt/var/tmp/ryoku-install-completed` and triggers a reboot.

## Errors that look scary but are fine (chroot install only)

These messages appear during the chroot install and do NOT abort it. They appear because `limine-mkinitcpio-hook` and `limine-snapper-sync` ship pacman hooks that detect they are running inside a chroot and refuse to write to the live system's boot config:

- `detected chroot env, skipping`
- `kernel cmdline is not available`
- `warning: this does not update limine, use limine-mkinitcpio`
- `Failed to register keybind: $XDG_RUNTIME_DIR not set` (or similar)

`install.sh` later runs `mkinitcpio -P` + `limine-update` explicitly against the installed kernel, so the boot config DOES end up correct on the installed disk. Keybinds register on first boot.

## Fixes that have to stay applied

These commits make the offline path work. Reverting any of them re-breaks the install.

| Commit | What it fixes |
|---|---|
| `74426a3 install: require branded boot and graphical parity` | `login/limine-snapper.sh` and `login/sddm.sh` hard-fail instead of silently degrading. Preserves the `.disabled` mkinitcpio-hook restoration block; without it, kernel updates would not trigger initramfs rebuilds on the installed system. |
| `fcc38283 iso: embed offline boot overlay and clean install inputs` | `iso/builder/ryoku-boot-overlay.packages` + `iso/builder/build-boot-overlay.sh` build limine-mkinitcpio-hook + limine-snapper-sync from AUR at ISO-build time. `install/ryoku-base.packages` adds them so `packaging/base.sh` pacstraps them. `iso/configs/airootfs/root/configurator` drops the bogus `mirror.github.com/neur0map/ryoku-arch` mirror. |
| `5a554eee install: re-attach offline overlay during chroot pacman swap` | When the chroot runs in online mode (`RYOKU_ONLINE_INSTALL=1`), `preflight/pacman.sh` would otherwise drop `[offline]` after copying the upstream pacman.conf, and `packaging/base.sh` would no longer find the AUR-built boot packages. The fix appends `[offline]` to the swapped config. `post-install/pacman.sh` re-copies the clean config at install end so this never leaks. |
| `ad82fa7c iso: build-boot-overlay forces overwrite + chowns build root` | `mktemp -d` produces a 0700 root-owned dir; the unprivileged `builder` user inside the build container couldn't enter it for `git clone` and `makepkg`. The chown fixes that. `makepkg --force` is required for warm-cache rebuilds (otherwise `A package has already been built. (use -f to overwrite)`). |
| `fea59bfb iso: rebuild offline.db on every run so CSIZE matches actual file` | `repo-add --new` skips packages already in the db, so an overlay package rebuilt with a different byte size between two runs (limine-mkinitcpio-hook and limine-snapper-sync are non-deterministic across `makepkg` invocations) carries the old `%CSIZE%`. pacman in the chroot then rejects the file as size-mismatched and aborts with `failed retrieving file 'limine-snapper-sync...'`. The fix removes `offline.db.tar.gz` + siblings before `repo-add` and drops the `--new` flag. |
| `d9abf47e install: drop broken resolv.conf symlink during chroot install` | `arch-chroot` bind-mounts `/etc/resolv.conf` from the live ISO. `ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf` then errors with `are the same file` because both paths resolve to the same inode through the bind-mount. The verification check then required `/etc/resolv.conf` to be a symlink, which fails because the bind-mount surface is exposed as a regular file. The static `/etc/resolv.conf` (1.1.1.1 + 8.8.8.8) `.automated_script.sh` writes onto `/mnt` is what ends up on the installed disk and is enough for first-boot DNS. |
| `3932a787 boot: limine branding hex for limine 12 compatibility` | Limine 12 changed `interface_branding_color` from an ANSI 0-7 index resolved via `term_palette` to a literal RRGGBB hex value. The shipped value `2` therefore stopped resolving to Ryoku orange on new installs (the offline overlay ships limine 12.0.2). Set `interface_branding_color` and `interface_help_color` to `F25623` directly. |
| `03442325 iso: keep .git in --local-source dev builds for ryoku-update` | `iso/builder/sync-local-source.sh` was tarring the dev tree with `--exclude='./.git'`, so the installed system's `~/.local/share/ryoku` was a tar-extracted dir (not a git repo) and `ryoku-update` aborted with `fatal: not a git repository`. Production ISOs (built via `git clone`) already preserve `.git` through `cp -r`; dev `--local-source` builds need the explicit pass-through to match. With `.git` shipped, `git pull` from the public origin works without any GitHub auth (omarchy's update mechanism relies on the same property). |
| `11fc74ae hypr: ship Adwaita cursor theme so first-login cursor is on-brand` | `default/hypr/envs.conf` set `XCURSOR_SIZE`/`HYPRCURSOR_SIZE` but never selected an actual theme, so first-login users landed at the X11 fallback "X" cursor. Add `adwaita-cursors` to `install/ryoku-base.packages` and set `XCURSOR_THEME=Adwaita` + `HYPRCURSOR_THEME=Adwaita` explicitly. omarchy gets the same effect implicitly via gsettings; making it explicit here means Ryoku does not depend on a side-effect to land on a real cursor. |
| `fb6e5b03 update: bootstrap yay first run + skip AUR cleanly with no aur pkgs` | First-time `ryoku-update` on a freshly installed offline-ISO system was printing "AUR is unavailable (so skipping updates)" because `pacman -Qem >/dev/null` exits 0 even with empty output (so the AUR block always entered) and `yay` was never bootstrapped (offline install gates `preflight/yay-bootstrap.sh` on `RYOKU_ONLINE_INSTALL`). Use `[[ -n $(pacman -Qem) ]]` to gate on actual installed AUR packages, and bootstrap yay at the top of `ryoku-update-aur-pkgs` once the network is up so subsequent AUR work can proceed without manual intervention. |

## Customization safety rails

When adding things, mirror these patterns or expect a regression in the offline install path.

1. **New base packages.** Add to `install/ryoku-base.packages`. They will be pulled from the offline mirror IF they're in upstream Arch. AUR-only base packages MUST also be added to `iso/builder/ryoku-boot-overlay.packages` so the build container makepkgs them and dumps them into the offline mirror.
2. **New AUR-only packages that are not boot-critical.** Add to `install/packaging/aur-core.sh` (or a sibling under `install/packaging/`). They install at first-boot via `ryoku-update`, not at install time, so the offline ISO doesn't need them in the overlay.
3. **New `install/login/*` or `install/post-install/*` scripts.** Don't do anything that requires network unconditionally. Gate online-only work behind `[[ -n ${RYOKU_ONLINE_INSTALL:-} ]]` so the offline install keeps working.
4. **Editing `login/limine-snapper.sh` or `login/sddm.sh`.** Keep the hard-check guard at the top and the post-`limine-update` verifications. They are the only thing keeping a silently broken boot from shipping.
5. **Editing `iso/builder/build-iso.sh`.** Never reintroduce `repo-add --new`. Always rebuild `offline.db` from the current set of `.pkg.tar.zst` files.
6. **Editing `install/config/hardware/network.sh`.** Don't try to manipulate `/etc/resolv.conf` inside the chroot. The bind-mount makes it a no-op at best and a hard error at worst.

## Adding new dotfiles / configs / commands

The `--local-source` build mounts the working tree into the build container as `/ryoku`, then `iso/builder/sync-local-source.sh` tars it (with `.git`, excluding only `iso/release`) into the airootfs at `/root/ryoku`. `iso/configs/airootfs/root/.automated_script.sh` then `cp -r /root/ryoku /mnt/home/<user>/.local/share/ryoku` during install. So **anything you put in the working tree, committed or not, ends up at `~/.local/share/ryoku/<same-relative-path>` on the installed system.** No special "ship this file" registration step is required.

That tells you where to put things:

- **App configs (Hyprland, alacritty, mako, hypr, waybar, fuzzel, tofi, etc.)** : drop them under `default/<app>/`. The `install/config/<app>.sh` script (or a new one you author) is responsible for symlinking the files into `~/.config/<app>/` at install time. Look at `install/config/theme.sh` and the existing siblings for the pattern.
- **A new dotfile that has no install/config step yet** : add the file under `default/<app>/`, then add a small `install/config/<app>.sh` that does the symlink/copy. Source it from `install/config/all.sh`.
- **A new bin script (`ryoku-foo`, helpers, launchers)** : drop it in `bin/` and `chmod +x`. `default/hypr/envs.conf` already prepends `$HOME/.local/share/ryoku/bin` to the user's `PATH`, so it is callable from Hyprland bindings, terminal, anywhere.
- **A new package the system needs** : see "Customization safety rails" above. Pure-Arch goes in `install/ryoku-base.packages`; AUR-only that has to be available at first boot goes in `iso/builder/ryoku-boot-overlay.packages` AND `install/ryoku-base.packages`; AUR-only that can wait until first-boot online updates goes in `install/packaging/aur-core.sh`.
- **A new theme** : add the dir under `themes/<theme-name>/`, mirroring the existing themes. `omarchy-theme-set` (or its Ryoku equivalent) reads from `themes/`.
- **A change that should run once per user on first login** : `install/first-run/<step>.sh`, plus a `bash "$RYOKU_PATH/install/first-run/<step>.sh"` line in `bin/ryoku-cmd-first-run`. The first-run marker file gates these so they only fire once.
- **A change that has to run as part of a system update** : add a migration script under `migrations/<unix-timestamp>.sh` and it will run on the next `ryoku-update`.

### One-shot dev cycle for a new customization

```bash
# 1. Make the change in the working tree (edit, add, commit if you want).
$EDITOR default/alacritty/alacritty.toml      # for example

# 2. Sanity-check that the file the install will copy is what you expect.
git status                                    # untracked is fine, will be in the ISO
ls -la default/alacritty/alacritty.toml

# 3. Rebuild + boot. The --local-source flag mounts the working tree; the
#    new file rides in via sync-local-source.sh. Cache is warm so this is
#    ~5-10 min total.
rm -f iso/release/*.iso /tmp/ryoku-iso-boot.qcow2 /tmp/OVMF_VARS.4m.fd
./iso/bin/ryoku-iso-make --local-source --no-boot-offer
./iso/bin/ryoku-iso-boot iso/release/ryoku-*-main.iso

# 4. Drive the install in QEMU, log in, verify the customization landed:
#    cat ~/.config/alacritty/alacritty.toml   # inside the VM
#    or whatever check is appropriate.
```

Two recurring traps to avoid:

- **The dev tree's HEAD ships, not just the working tree.** Because we no longer strip `.git` (commit `03442325`), the `.git` directory of the dev tree goes onto the installed system. `git pull` from origin works without auth, but if your local commits are not pushed and origin is ahead/diverged, the user's first `ryoku-update` will try to merge and may conflict. Push your commits to origin before treating the ISO as "shippable", or accept that the ISO is a private build.
- **Adding a config file under `default/<app>/` is not enough on its own.** Without an `install/config/<app>.sh` step that symlinks or copies it into `~/.config/<app>/`, the file just sits in `~/.local/share/ryoku/default/<app>/` and the app never reads it.

## Verification after adding customizations

After any non-trivial change, re-run the recipe. Warm cache makes this ~5-10 min:

```bash
rm -f iso/release/*.iso /tmp/ryoku-iso-boot.qcow2 /tmp/OVMF_VARS.4m.fd
./iso/bin/ryoku-iso-make --local-source --no-boot-offer
./iso/bin/ryoku-iso-boot iso/release/ryoku-*-main.iso
```

Watch for:

- Build container exits 0. Look for `[mkarchiso] INFO: Done!` near the end of the build log, then `Writing to 'stdio:/out/...iso' completed successfully`.
- VM reaches the configurator UI without a kernel panic.
- Configurator + archinstall + chroot install reach `installation completed` without aborting at a `Failed script:` line.
- Reboot lands at the pixel-rainyroom SDDM greeter (Ryoku branded).
- Logging in reaches the Hyprland session.

If any of the above breaks, the failure menu in the live ISO offers `View full log`. Screenshot the `Failed script:` line + the error block above it; that points at the regressing script.

## Known follow-ups (not blocking the recipe)

- Online-install path (`RYOKU_ONLINE_INSTALL=1`) has not been smoke-tested end-to-end in the same way the offline path has. The fix in `5a554eee` is in place but unproven against a real online install.
- Direct EFI UKI normal-boot path (Task 3 of `2026-04-26-ryoku-iso-parity-implementation.md`) is still pending. Limine is currently the normal path, which is fine, but the parity plan also wants a direct UKI option.
- `limine-mkinitcpio-hook` and `limine-snapper-sync` pacman-hook noise during chroot install ("detected chroot env, skipping") is harmless but could be suppressed by reordering `mkinitcpio -P` + `limine-update` so the user-facing install transcript stays clean.
- (resolved 2026-04-28 by `11fc74ae`) Cursor X-fallback issue is fixed by shipping adwaita-cursors and setting XCURSOR_THEME/HYPRCURSOR_THEME in envs.conf.
