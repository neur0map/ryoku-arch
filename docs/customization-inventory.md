# Customizable Config Inventory

This is the repo-safe inventory of Ryoku's shipped text-based customization
surfaces. Paths are repo-relative or generic runtime/install targets only;
there are no machine-specific absolute paths here.

## Scope

- Included: editable text/config/script files under `config/`, `default/`,
  and `themes/` that change shipped behavior, appearance, startup, or
  automation.
- Excluded on purpose: wallpapers/background images, preview images, logo art,
  font binaries, and `.gitkeep` placeholders. Those are assets, not dotfiles.
- Historical migrations can still mention retired components because they must
  converge older installs. They are not the active desktop contract.

## Current Desktop Stack

| Repo Path | Runtime / Install Target | What It Controls |
| --- | --- | --- |
| `config/niri/config.kdl` | `~/.config/niri/config.kdl` | Top-level Niri config that includes the split config fragments. |
| `config/niri/config.d/10-input-and-cursor.kdl` | `~/.config/niri/config.d/10-input-and-cursor.kdl` | Keyboard layout, touchpad, mouse, tablet, and cursor defaults. |
| `config/niri/config.d/20-layout-and-overview.kdl` | `~/.config/niri/config.d/20-layout-and-overview.kdl` | Niri layout, gaps, focus behavior, overview, and preset widths/heights. |
| `config/niri/config.d/30-window-rules.kdl` | `~/.config/niri/config.d/30-window-rules.kdl` | App/window matching, floating rules, opacity, and screenshot behavior. |
| `config/niri/config.d/40-environment.kdl` | `~/.config/niri/config.d/40-environment.kdl` | Session environment for Wayland, portals, Qt, GPU hints, and shell state. |
| `config/niri/config.d/50-startup.kdl` | `~/.config/niri/config.d/50-startup.kdl` | Niri startup commands. The shell itself is managed by a user systemd service. |
| `config/niri/config.d/60-animations.kdl` | `~/.config/niri/config.d/60-animations.kdl` | Niri animation timing and transition behavior. |
| `config/niri/config.d/70-binds.kdl` | `~/.config/niri/config.d/70-binds.kdl` | Source of truth for shipped Niri and shell keybindings. |
| `config/niri/config.d/80-layer-rules.kdl` | `~/.config/niri/config.d/80-layer-rules.kdl` | Layer-shell rules for overlays, background layers, and panels. |
| `config/niri/config.d/90-user-extra.kdl` | `~/.config/niri/config.d/90-user-extra.kdl` | Safe user override slot for local Niri additions. |
| `config/fuzzel/fuzzel.ini` | `~/.config/fuzzel/fuzzel.ini` | Fuzzel launcher defaults retained as a lightweight fallback. |
| `config/fuzzel/fuzzel_theme.ini` | `~/.config/fuzzel/fuzzel_theme.ini` | Fuzzel color/theme include. |
| `config/xdg-desktop-portal/niri-portals.conf` | `~/.config/xdg-desktop-portal/niri-portals.conf` | Portal backend preference for the Niri session. |

## Terminals, Shell, And CLI

| Repo Path | Runtime / Install Target | What It Controls |
| --- | --- | --- |
| `config/alacritty/alacritty.toml` | `~/.config/alacritty/alacritty.toml` | Base Alacritty behavior, fonts, padding, and themed color include. |
| `config/alacritty/colors.toml` | `~/.config/alacritty/colors.toml` | Current Alacritty color payload copied from the live Niri setup. |
| `config/foot/foot.ini` | `~/.config/foot/foot.ini` | Foot terminal defaults. |
| `config/ghostty/config` | `~/.config/ghostty/config` | Ghostty defaults, keybinds, padding, font, and themed color include. |
| `config/kitty/kitty.conf` | `~/.config/kitty/kitty.conf` | Kitty behavior, font, padding, and themed color include. |
| `config/starship.toml` | `~/.config/starship.toml` | Prompt layout, symbols, and Git status styling. |
| `config/starship/ii-palette.toml` | `~/.config/starship/ii-palette.toml` | Current prompt palette copied from the live Niri setup. |
| `config/tmux/tmux.conf` | `~/.config/tmux/tmux.conf` | Tmux keybinds and session behavior. |
| `config/git/config` | `~/.config/git/config` | Default Git aliases and CLI behavior. |
| `config/xdg-terminals.list` | `~/.config/xdg-terminals.list` | Preferred terminal candidates for `xdg-terminal-exec`. |
| `default/bashrc` | `~/.bashrc` | User-facing Bash entrypoint that loads Ryoku defaults. |
| `default/bash/*` | `~/.local/share/ryoku/default/bash/*` | Bash aliases, functions, history, completion, and shell environment defaults. |
| `default/alacritty/screensaver.toml` | `~/.config/alacritty/screensaver.toml` | Alacritty profile used by the Ryoku screensaver terminal window. |
| `default/ghostty/screensaver` | `~/.config/ghostty/screensaver` | Ghostty profile used by the Ryoku screensaver terminal window. |

## Applications And Desktop Defaults

| Repo Path | Runtime / Install Target | What It Controls |
| --- | --- | --- |
| `config/Kvantum/kvantum.kvconfig` | `~/.config/Kvantum/kvantum.kvconfig` | Qt/Kvantum theme selection. |
| `config/gtk-3.0/settings.ini` | `~/.config/gtk-3.0/settings.ini` | GTK3 theme, icon, cursor, and font settings. |
| `config/gtk-3.0/gtk.css` | `~/.config/gtk-3.0/gtk.css` | GTK3 color and widget CSS. |
| `config/gtk-4.0/settings.ini` | `~/.config/gtk-4.0/settings.ini` | GTK4 theme, icon, cursor, and font settings. |
| `config/gtk-4.0/gtk.css` | `~/.config/gtk-4.0/gtk.css` | GTK4 color and widget CSS. |
| `config/btop/btop.conf` | `~/.config/btop/btop.conf` | btop layout, meters, and behavior defaults. |
| `config/btop/themes/ii-auto.theme` | `~/.config/btop/themes/ii-auto.theme` | Current btop palette copied from the live Niri setup. |
| `config/fastfetch/config.jsonc` | `~/.config/fastfetch/config.jsonc` | Fastfetch output modules and formatting. |
| `config/lazygit/config.yml` | `~/.config/lazygit/config.yml` | Lazygit defaults. |
| `config/imv/config` | `~/.config/imv/config` | Image viewer keybinds for print, delete, and rotate actions. |
| `config/wiremix/wiremix.toml` | `~/.config/wiremix/wiremix.toml` | Wiremix audio mixer display symbols and overrides. |
| `config/xournalpp/settings.xml` | `~/.config/xournalpp/settings.xml` | Xournal++ UI, autosave, stylus, and document-view defaults. Review before ISO builds because app state files can retain last-used paths. |
| `config/Typora/themes/ia_typora.css` | `~/.config/Typora/themes/ia_typora.css` | Light Typora writing theme CSS. |
| `config/Typora/themes/ia_typora_night.css` | `~/.config/Typora/themes/ia_typora_night.css` | Dark Typora writing theme CSS. |
| `config/autostart/org.fcitx.Fcitx5.desktop` | `~/.config/autostart/org.fcitx.Fcitx5.desktop` | Desktop autostart entry for Fcitx5 input method. |
| `config/environment.d/fcitx.conf` | `~/.config/environment.d/fcitx.conf` | Environment variables for Fcitx integration. |
| `config/fcitx5/conf/clipboard.conf` | `~/.config/fcitx5/conf/clipboard.conf` | Fcitx clipboard addon settings. |
| `config/fcitx5/conf/xcb.conf` | `~/.config/fcitx5/conf/xcb.conf` | Fcitx XCB frontend behavior. |
| `config/fontconfig/fonts.conf` | `~/.config/fontconfig/fonts.conf` | Font fallback and fontconfig overrides. |
| `config/brave-flags.conf` | `~/.config/brave-flags.conf` | Extra Brave command-line flags. |
| `config/chromium-flags.conf` | `~/.config/chromium-flags.conf` | Extra Chromium command-line flags. |
| `config/chromium/Default/Preferences` | `~/.config/chromium/Default/Preferences` | Minimal Chromium profile defaults, mainly theme-related browser preferences. |

## Ryoku Hooks And User Extension Points

| Repo Path | Runtime / Install Target | What It Controls |
| --- | --- | --- |
| `config/ryoku/extensions/menu.sh` | `~/.config/ryoku/extensions/menu.sh` | User hook for overriding pieces of `ryoku-menu`. |
| `config/ryoku/hooks/battery-low.sample` | `~/.config/ryoku/hooks/battery-low` | Sample hook that runs when low-battery notifications fire. |
| `config/ryoku/hooks/font-set.sample` | `~/.config/ryoku/hooks/font-set` | Sample hook that runs after font changes. |
| `config/ryoku/hooks/post-update.sample` | `~/.config/ryoku/hooks/post-update` | Sample hook that runs after `ryoku-update`. |
| `config/ryoku/hooks/theme-set.sample` | `~/.config/ryoku/hooks/theme-set` | Sample hook that runs after theme changes. |
| `config/ryoku/themed/alacritty.toml.tpl.sample` | `~/.config/ryoku/themed/alacritty.toml.tpl` | Example user template showing how to override theme-rendered app configs. |

## System Defaults And Install-Time Config

| Repo Path | Runtime / Install Target | What It Controls |
| --- | --- | --- |
| `config/systemd/user/ryoku-battery-monitor.service` | `~/.config/systemd/user/ryoku-battery-monitor.service` | User service definition for periodic battery checks. |
| `config/systemd/user/ryoku-battery-monitor.timer` | `~/.config/systemd/user/ryoku-battery-monitor.timer` | User timer cadence for battery checks. |
| `default/gpg/dirmngr.conf` | `/etc/gnupg/dirmngr.conf` | System GnuPG keyserver and dirmngr defaults. |
| `default/limine/default.conf` | `/etc/default/limine` | Default Limine Snapper variables, boot order, snapshot count, and UKI behavior. |
| `default/limine/limine.conf` | `/boot/limine.conf` | Limine bootloader UI colors, branding, and default entry behavior. |
| `default/pacman/mirrorlist-*` | `/etc/pacman.d/mirrorlist` | Pacman mirrorlist snapshots for channel scaffolding. |
| `default/pacman/pacman-*.conf` | `/etc/pacman.conf` | Pacman repository configuration templates. |
| `default/plymouth/*` | `/usr/share/plymouth/themes/ryoku/` | Plymouth boot splash theme. |
| `default/systemd/faster-shutdown.conf` | `/etc/systemd/system.conf.d/10-faster-shutdown.conf` | Systemd manager override that shortens shutdown stop timeouts. |
| `default/systemd/system-sleep/*` | `/usr/lib/systemd/system-sleep/` | Sleep hooks for hybrid GPU, keyboard backlight, and FUSE cleanup. |
| `default/systemd/system/supergfxd.service.d/delay-start.conf` | `/etc/systemd/system/supergfxd.service.d/delay-start.conf` | Systemd drop-in that delays `supergfxd` startup. |
| `default/systemd/user@.service.d/faster-shutdown.conf` | `/etc/systemd/system/user@.service.d/faster-shutdown.conf` | User-manager systemd override for faster shutdown. |
| `default/udev/framework16-qmk-hid.rules` | `/etc/udev/rules.d/50-framework16-qmk-hid.rules` | udev access rule for Framework 16 QMK HID devices. |
| `default/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf` | `~/.config/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf` | WirePlumber rule forcing software volume control on ALSA devices. |
| `default/xcompose` | `~/.XCompose` | Custom compose-key definitions. |

## Theme Pipeline

| Repo Path / Pattern | Runtime / Install Target | What It Controls |
| --- | --- | --- |
| `themes/<theme>/colors.toml` | `~/.config/ryoku/current/theme/colors.toml` | Primary theme token set. |
| `themes/<theme>/icons.theme` | `~/.config/ryoku/current/theme/icons.theme` | GNOME/icon theme selection for the current theme. |
| `themes/<theme>/btop.theme` | `~/.config/ryoku/current/theme/btop.theme` | Theme-specific btop palette override. |
| `themes/<theme>/vscode.json` | `~/.config/ryoku/current/theme/vscode.json` | VS Code extension/theme mapping for the current theme. Some extension IDs retain upstream names and are documented in `docs/omarchy-heritage.md`. |
| `themes/<theme>/light.mode` | `~/.config/ryoku/current/theme/light.mode` | Marker used to switch desktop/browser/GTK surfaces into light mode. |
| `themes/<theme>/chromium.theme` | `~/.config/ryoku/current/theme/chromium.theme` | Optional theme-specific Chromium accent tuple. |
| `default/themed/alacritty.toml.tpl` | `~/.config/ryoku/current/theme/alacritty.toml` | Theme-rendered Alacritty colors. |
| `default/themed/btop.theme.tpl` | `~/.config/ryoku/current/theme/btop.theme` | Theme-rendered btop palette. |
| `default/themed/chromium.theme.tpl` | `~/.config/ryoku/current/theme/chromium.theme` | Theme-rendered Chromium accent tuple. |
| `default/themed/ghostty.conf.tpl` | `~/.config/ryoku/current/theme/ghostty.conf` | Theme-rendered Ghostty colors. |
| `default/themed/keyboard.rgb.tpl` | `~/.config/ryoku/current/theme/keyboard.rgb` | Theme-rendered keyboard RGB value for supported hardware. |
| `default/themed/kitty.conf.tpl` | `~/.config/ryoku/current/theme/kitty.conf` | Theme-rendered Kitty colors. |
| `default/themed/obsidian.css.tpl` | `~/.config/ryoku/current/theme/obsidian.css` | Theme-rendered Obsidian CSS snippet. |
| `config/matugen/*` | `~/.config/matugen/` | Material color generation templates for terminals, GTK, Firefox, Steam, KDE, and wallpaper-derived colors. |

## Legacy And Compatibility Notes

The current Niri path does not use the old Hyprland, Waybar, Mako, SwayOSD,
Tofi, Walker, Elephant, Brain Shell, or Noctalia runtime configs. If those
names appear in this repository, they should be one of:

- Historical migrations that converge older installs.
- Cleanup-only paths that remove old files from user systems.
- External theme/package identifiers that cannot be renamed safely.
- Historical plan/spec docs under `docs/superpowers/`.

Active public documentation for those leftovers lives in
`docs/omarchy-heritage.md` and `docs/rebrand-inventory.md`.

## ISO / Release Notes

| Repo Path | Why It Deserves Extra Review Before Shipping |
| --- | --- |
| `config/xournalpp/settings.xml` | Application state files can retain last-opened and last-saved paths; scrub or reset if you do not want baked-in path history. |
| `config/chromium/Default/Preferences` | Browser preference seeds are safe to ship, but this class of file is stateful by nature, so review it whenever browser defaults change. |
