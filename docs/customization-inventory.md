# Customizable Config Inventory

This is the repo-safe inventory of Ryoku's shipped text-based customization surfaces.
Paths are repo-relative or generic runtime/install targets only; there are no machine-specific absolute paths here.

## Scope

- Included: editable text/config/script files under `config/`, `default/`, and `themes/` that change shipped behavior, appearance, startup, or automation.
- Excluded on purpose: wallpapers/background images, preview images, logo art, font binaries, and `.gitkeep` placeholders. Those are assets, not dotfiles/config surfaces.
- Theme directories repeat a few identical file shapes across many themes. To keep this readable, repeated theme families are listed once with explicit theme coverage.

## `config/` User-Facing Shipped Configs

| Repo Path | Runtime / Install Target | What It Controls |
| --- | --- | --- |
| `config/Typora/themes/ia_typora.css` | `~/.config/Typora/themes/ia_typora.css` | Light Typora writing theme CSS. |
| `config/Typora/themes/ia_typora_night.css` | `~/.config/Typora/themes/ia_typora_night.css` | Dark Typora writing theme CSS. |
| `config/alacritty/alacritty.toml` | `~/.config/alacritty/alacritty.toml` | Base Alacritty behavior, fonts, padding, and themed color include. |
| `config/autostart/org.fcitx.Fcitx5.desktop` | `~/.config/autostart/org.fcitx.Fcitx5.desktop` | Desktop autostart entry for Fcitx5 input method. |
| `config/brave-flags.conf` | `~/.config/brave-flags.conf` | Extra Brave command-line flags. |
| `config/btop/btop.conf` | `~/.config/btop/btop.conf` | btop layout, meters, and behavior defaults. |
| `config/chromium-flags.conf` | `~/.config/chromium-flags.conf` | Extra Chromium command-line flags. |
| `config/chromium/Default/Preferences` | `~/.config/chromium/Default/Preferences` | Minimal Chromium profile defaults, mainly theme-related browser preferences. |
| `config/elephant/calc.toml` | `~/.config/elephant/calc.toml` | Elephant launcher calculator behavior. |
| `config/elephant/desktopapplications.toml` | `~/.config/elephant/desktopapplications.toml` | Elephant desktop app search behavior. |
| `config/elephant/symbols.toml` | `~/.config/elephant/symbols.toml` | Elephant symbol/emoji action behavior. |
| `config/environment.d/fcitx.conf` | `~/.config/environment.d/fcitx.conf` | Environment variables for Fcitx integration. |
| `config/fastfetch/config.jsonc` | `~/.config/fastfetch/config.jsonc` | Fastfetch output modules and formatting. |
| `config/fcitx5/conf/clipboard.conf` | `~/.config/fcitx5/conf/clipboard.conf` | Fcitx clipboard addon settings. |
| `config/fcitx5/conf/xcb.conf` | `~/.config/fcitx5/conf/xcb.conf` | Fcitx XCB frontend behavior. |
| `config/fontconfig/fonts.conf` | `~/.config/fontconfig/fonts.conf` | Font fallback and fontconfig overrides. |
| `config/ghostty/config` | `~/.config/ghostty/config` | Ghostty defaults, keybinds, padding, font, and themed color include. |
| `config/git/config` | `~/.config/git/config` | Default Git aliases and CLI behavior. |
| `config/hypr/autostart.conf` | `~/.config/hypr/autostart.conf` | User Hyprland autostart additions and overrides. |
| `config/hypr/bindings.conf` | `~/.config/hypr/bindings.conf` | User application and personal Hyprland keybinds. |
| `config/hypr/hypridle.conf` | `~/.config/hypr/hypridle.conf` | Idle timeouts for screensaver, lock, display sleep, and keyboard backlight. |
| `config/hypr/hyprland.conf` | `~/.config/hypr/hyprland.conf` | Top-level Hyprland config that composes defaults, theme overrides, user overrides, and toggle drop-ins. |
| `config/hypr/hyprlock.conf` | `~/.config/hypr/hyprlock.conf` | Lock screen layout, widgets, PAM auth, and theme include. |
| `config/hypr/hyprsunset.conf` | `~/.config/hypr/hyprsunset.conf` | Night-light profiles and color temperature schedule. |
| `config/hypr/input.conf` | `~/.config/hypr/input.conf` | Keyboard, touchpad, repeat rate, compose key, and gesture-related input overrides. |
| `config/hypr/looknfeel.conf` | `~/.config/hypr/looknfeel.conf` | User-side Hyprland gaps, borders, layout, animation, and decoration overrides. |
| `config/hypr/monitors.conf` | `~/.config/hypr/monitors.conf` | Monitor layout, scale, transform, and display-specific examples. |
| `config/hypr/xdph.conf` | `~/.config/hypr/xdph.conf` | Hyprland portal screen-share picker behavior. |
| `config/hyprland-preview-share-picker/config.yaml` | `~/.config/hyprland-preview-share-picker/config.yaml` | Preview share picker layout, sizing, CSS class names, and selection behavior. |
| `config/imv/config` | `~/.config/imv/config` | Image viewer keybinds for print, delete, and rotate actions. |
| `config/kitty/kitty.conf` | `~/.config/kitty/kitty.conf` | Kitty behavior, font, padding, and themed color include. |
| `config/lazygit/config.yml` | `~/.config/lazygit/config.yml` | Lazygit overrides; currently reserved for future custom settings. |
| `config/opencode/opencode.json` | `~/.config/opencode/opencode.json` | OpenCode UI theme mode and update behavior. |
| `config/quickshell/ryoku/config/Config.qml` | `~/.config/quickshell/ryoku/config/Config.qml` | Decorative frame sizing, rounding, exclusions, and live theme color binding for Quickshell. |
| `config/quickshell/ryoku/config/qmldir` | `~/.config/quickshell/ryoku/config/qmldir` | QML module manifest for the Quickshell config singleton. |
| `config/quickshell/ryoku/modules/frame/ExclusionZones.qml` | `~/.config/quickshell/ryoku/modules/frame/ExclusionZones.qml` | Placeholder Quickshell exclusion-zone module for frame layout coordination. |
| `config/quickshell/ryoku/modules/frame/Frame.qml` | `~/.config/quickshell/ryoku/modules/frame/Frame.qml` | Quickshell frame renderer for the desktop border/matboard effect. |
| `config/quickshell/ryoku/modules/frame/qmldir` | `~/.config/quickshell/ryoku/modules/frame/qmldir` | QML module manifest for frame components. |
| `config/quickshell/ryoku/qmldir` | `~/.config/quickshell/ryoku/qmldir` | Top-level QML module manifest for the Ryoku shell bundle. |
| `config/quickshell/ryoku/shell.qml` | `~/.config/quickshell/ryoku/shell.qml` | Quickshell entrypoint that instantiates the frame on each screen. |
| `config/ryoku/extensions/menu.sh` | `~/.config/ryoku/extensions/menu.sh` | User hook for overriding pieces of `ryoku-menu`. |
| `config/ryoku/hooks/battery-low.sample` | `~/.config/ryoku/hooks/battery-low` | Sample hook that runs when low-battery notifications fire. |
| `config/ryoku/hooks/font-set.sample` | `~/.config/ryoku/hooks/font-set` | Sample hook that runs after font changes. |
| `config/ryoku/hooks/post-update.sample` | `~/.config/ryoku/hooks/post-update` | Sample hook that runs after `ryoku-update`. |
| `config/ryoku/hooks/theme-set.sample` | `~/.config/ryoku/hooks/theme-set` | Sample hook that runs after theme changes. |
| `config/ryoku/themed/alacritty.toml.tpl.sample` | `~/.config/ryoku/themed/alacritty.toml.tpl` | Example user template showing how to override theme-rendered app configs. |
| `config/starship.toml` | `~/.config/starship.toml` | Prompt layout, symbols, and Git status styling. |
| `config/swayosd/config.toml` | `~/.config/swayosd/config.toml` | SwayOSD server behavior and stylesheet path. |
| `config/swayosd/style.css` | `~/.config/swayosd/style.css` | SwayOSD visual styling. |
| `config/systemd/user/ryoku-battery-monitor.service` | `~/.config/systemd/user/ryoku-battery-monitor.service` | User service definition for periodic battery checks. |
| `config/systemd/user/ryoku-battery-monitor.timer` | `~/.config/systemd/user/ryoku-battery-monitor.timer` | User timer cadence for battery checks. |
| `config/tmux/tmux.conf` | `~/.config/tmux/tmux.conf` | Tmux keybinds and session behavior. |
| `config/uwsm/default` | `~/.config/uwsm/default` | Desktop-session defaults such as terminal/editor and optional screenshot paths. |
| `config/uwsm/env` | `~/.config/uwsm/env` | UWSM session environment bootstrap and runtime exports. |
| `config/waybar/config.jsonc` | `~/.config/waybar/config.jsonc` | Waybar modules, order, click actions, icons, and bar geometry. |
| `config/waybar/style.css` | `~/.config/waybar/style.css` | Waybar styling and spacing. |
| `config/wiremix/wiremix.toml` | `~/.config/wiremix/wiremix.toml` | Wiremix audio mixer display symbols and overrides. |
| `config/xdg-terminals.list` | `~/.config/xdg-terminals.list` | Preferred terminal candidates for `xdg-terminal-exec`. |
| `config/xournalpp/settings.xml` | `~/.config/xournalpp/settings.xml` | Xournal++ UI, autosave, stylus, and document-view defaults. Review before ISO builds because app state files can retain last-used paths. |

## `default/` Default Sources, Templates, and System Overrides

| Repo Path | Runtime / Install Target | What It Controls |
| --- | --- | --- |
| `default/alacritty/screensaver.toml` | `~/.config/alacritty/screensaver.toml` | Alacritty profile used by the Ryoku screensaver terminal window. |
| `default/bash/aliases` | `~/.local/share/ryoku/default/bash/aliases` | Default interactive Bash aliases and small shell helpers. |
| `default/bash/envs` | `~/.local/share/ryoku/default/bash/envs` | Default shell environment exports and runtime contract loading. |
| `default/bash/fns/compression` | `~/.local/share/ryoku/default/bash/fns/compression` | Bash helper functions for archive compression/extraction. |
| `default/bash/fns/drives` | `~/.local/share/ryoku/default/bash/fns/drives` | Bash helper functions for imaging and formatting removable drives. |
| `default/bash/fns/ssh-port-forwarding` | `~/.local/share/ryoku/default/bash/fns/ssh-port-forwarding` | Bash helpers for local SSH port forwards. |
| `default/bash/fns/tmux` | `~/.local/share/ryoku/default/bash/fns/tmux` | Bash helpers for tmux AI/dev layouts. |
| `default/bash/fns/transcoding` | `~/.local/share/ryoku/default/bash/fns/transcoding` | Bash helpers for video/image transcoding. |
| `default/bash/fns/worktrees` | `~/.local/share/ryoku/default/bash/fns/worktrees` | Bash helpers for git worktree creation/removal. |
| `default/bash/functions` | `~/.local/share/ryoku/default/bash/functions` | Loader that sources all Bash function bundles. |
| `default/bash/init` | `~/.local/share/ryoku/default/bash/init` | Interactive shell initialization for mise, starship, zoxide, try, and fzf. |
| `default/bash/inputrc` | `~/.local/share/ryoku/default/bash/inputrc` | Readline completion and history-search behavior. |
| `default/bash/rc` | `~/.local/share/ryoku/default/bash/rc` | Ordered loader for the default Bash stack. |
| `default/bash/shell` | `~/.local/share/ryoku/default/bash/shell` | Core Bash history, completion, and shell-option defaults. |
| `default/bashrc` | `~/.bashrc` | User-facing Bash entrypoint that pulls in Ryoku defaults and leaves room for personal additions. |
| `default/chromium/extensions/copy-url/background.js` | `Chromium extension bundle` | Background script for the bundled copy-url browser extension. |
| `default/chromium/extensions/copy-url/manifest.json` | `Chromium extension bundle` | Manifest for the bundled copy-url browser extension. |
| `default/ghostty/screensaver` | `~/.config/ghostty/screensaver` | Ghostty profile used by the Ryoku screensaver terminal window. |
| `default/gpg/dirmngr.conf` | `/etc/gnupg/dirmngr.conf` | System GnuPG keyserver and dirmngr defaults. |
| `default/hypr/apps.conf` | `~/.local/share/ryoku/default/hypr/apps.conf` | Aggregator that sources all app-specific Hyprland rules. |
| `default/hypr/apps/1password.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland rules for 1Password windows. |
| `default/hypr/apps/bitwarden.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland rules for Bitwarden app and extension windows. |
| `default/hypr/apps/browser.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland rules for browser tags, opacity, and screen-sharing bars. |
| `default/hypr/apps/davinci-resolve.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland focus behavior for DaVinci Resolve floating dialogs. |
| `default/hypr/apps/geforce.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland fullscreen/idle behavior for GeForce NOW. |
| `default/hypr/apps/hyprshot.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland layer rules for screenshot selection overlays. |
| `default/hypr/apps/localsend.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland float/size/center rules for LocalSend windows. |
| `default/hypr/apps/moonlight.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland fullscreen/idle behavior for Moonlight. |
| `default/hypr/apps/pip.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland picture-in-picture floating, pinning, size, and opacity rules. |
| `default/hypr/apps/qemu.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland opacity rules for QEMU windows. |
| `default/hypr/apps/retroarch.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland fullscreen/idle/opacity rules for RetroArch. |
| `default/hypr/apps/steam.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland float, size, and idle rules for Steam windows. |
| `default/hypr/apps/system.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Global Hyprland rules for floating utilities, media windows, screensaver, and no-idle tags. |
| `default/hypr/apps/telegram.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland focus-stealing fix for Telegram. |
| `default/hypr/apps/terminals.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland tag and opacity rules for terminal apps. |
| `default/hypr/apps/tofi.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland layer animation rule for tofi. |
| `default/hypr/apps/typora.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland floating print-dialog rule for Typora. |
| `default/hypr/apps/webcam-overlay.conf` | `~/.local/share/ryoku/default/hypr/apps/*.conf` | Hyprland float/pin/no-focus rules for webcam overlay windows. |
| `default/hypr/autostart.conf` | `~/.local/share/ryoku/default/hypr/autostart.conf` | Default Hyprland startup services and desktop daemons. |
| `default/hypr/bindings.conf` | `~/.local/share/ryoku/default/hypr/bindings.conf` | Deprecated all-in-one Hyprland bindings file kept for compatibility. |
| `default/hypr/bindings/clipboard.conf` | `~/.local/share/ryoku/default/hypr/bindings/clipboard.conf` | Clipboard-related Hyprland keybinds. |
| `default/hypr/bindings/media.conf` | `~/.local/share/ryoku/default/hypr/bindings/media.conf` | Media keys, brightness, touchpad, and player control Hyprland keybinds. |
| `default/hypr/bindings/tiling-v2.conf` | `~/.local/share/ryoku/default/hypr/bindings/tiling-v2.conf` | Current primary Hyprland tiling/navigation keybind set. |
| `default/hypr/bindings/tiling.conf` | `~/.local/share/ryoku/default/hypr/bindings/tiling.conf` | Deprecated legacy tiling keybind set kept for compatibility. |
| `default/hypr/bindings/utilities.conf` | `~/.local/share/ryoku/default/hypr/bindings/utilities.conf` | Menus, toggles, capture, notification, and control-panel Hyprland keybinds. |
| `default/hypr/envs.conf` | `~/.local/share/ryoku/default/hypr/envs.conf` | Hyprland-scoped environment variables for Wayland apps, cursor size, XCompose, and portal behavior. |
| `default/hypr/input.conf` | `~/.local/share/ryoku/default/hypr/input.conf` | Default Hyprland keyboard, touchpad, and DPMS wake input settings. |
| `default/hypr/looknfeel.conf` | `~/.local/share/ryoku/default/hypr/looknfeel.conf` | Default Hyprland gaps, borders, shadows, blur, animations, and layout behavior. |
| `default/hypr/plain-bindings.conf` | `~/.local/share/ryoku/default/hypr/plain-bindings.conf` | Plain-text keybinding reference used by help surfaces. |
| `default/hypr/toggles/flags.conf` | `~/.local/state/ryoku/toggles/hypr/flags.conf` | Permanent toggle-state anchor file for Hyprland toggle directory loading. |
| `default/hypr/toggles/internal-monitor-disable.conf` | `~/.local/state/ryoku/toggles/hypr/internal-monitor-disable.conf` | Toggle snippet that disables the internal laptop display. |
| `default/hypr/toggles/single-window-aspect-ratio.conf` | `~/.local/state/ryoku/toggles/hypr/single-window-aspect-ratio.conf` | Toggle snippet that limits overly wide single-window layouts. |
| `default/hypr/toggles/window-no-gaps.conf` | `~/.local/state/ryoku/toggles/hypr/window-no-gaps.conf` | Toggle snippet that removes gaps and borders. |
| `default/hypr/windows.conf` | `~/.local/share/ryoku/default/hypr/windows.conf` | Base Hyprland window rules and default-opacity tagging. |
| `default/limine/default.conf` | `/etc/default/limine` | Default Limine Snapper variables, boot order, snapshot count, and UKI behavior. |
| `default/limine/limine.conf` | `/boot/limine.conf` | Limine bootloader UI colors, branding, and default entry behavior. |
| `default/mako/core.ini` | `~/.local/share/ryoku/default/mako/core.ini` | Default Mako notification behavior, actions, geometry, and urgency rules. |
| `default/nautilus-python/extensions/localsend.py` | `Nautilus Python extension directory` | Adds a LocalSend action to Nautilus file selections. |
| `default/pacman/mirrorlist-edge` | `/etc/pacman.d/mirrorlist` | Pacman mirrorlist for the edge channel. |
| `default/pacman/mirrorlist-rc` | `/etc/pacman.d/mirrorlist` | Pacman mirrorlist for the release-candidate channel. |
| `default/pacman/mirrorlist-stable` | `/etc/pacman.d/mirrorlist` | Pacman mirrorlist for the stable channel. |
| `default/pacman/pacman-edge.conf` | `/etc/pacman.conf` | Pacman repository configuration for the edge channel. |
| `default/pacman/pacman-rc.conf` | `/etc/pacman.conf` | Pacman repository configuration for the release-candidate channel. |
| `default/pacman/pacman-stable.conf` | `/etc/pacman.conf` | Pacman repository configuration for the stable channel. |
| `default/plymouth/ryoku.plymouth` | `Plymouth theme bundle` | Plymouth theme metadata and plugin selection. |
| `default/plymouth/ryoku.script` | `Plymouth theme bundle` | Plymouth script logic for the boot splash. |
| `default/ryoku-skill/SKILL.md` | `~/.claude/skills/ryoku/SKILL.md` | Installed AI assistant skill describing safe end-user Ryoku customization workflows. |
| `default/systemd/faster-shutdown.conf` | `/etc/systemd/system.conf.d/10-faster-shutdown.conf` | Systemd manager override that shortens shutdown stop timeouts. |
| `default/systemd/system-sleep/force-igpu` | `/usr/lib/systemd/system-sleep/force-igpu` | Sleep hook for forcing integrated-GPU mode on supported hybrid systems. |
| `default/systemd/system-sleep/keyboard-backlight` | `/usr/lib/systemd/system-sleep/keyboard-backlight` | Sleep hook that disables keyboard backlight before hibernate on affected hardware. |
| `default/systemd/system-sleep/unmount-fuse` | `/usr/lib/systemd/system-sleep/unmount-fuse` | Sleep hook that unmounts GVFS FUSE mounts before suspend and restarts GVFS afterward. |
| `default/systemd/system/supergfxd.service.d/delay-start.conf` | `/etc/systemd/system/supergfxd.service.d/delay-start.conf` | Systemd drop-in that delays `supergfxd` startup. |
| `default/systemd/user@.service.d/faster-shutdown.conf` | `/etc/systemd/system/user@.service.d/faster-shutdown.conf` | User-manager systemd override for faster shutdown. |
| `default/themed/alacritty.toml.tpl` | `~/.config/ryoku/current/theme/alacritty.toml` | Theme-rendered Alacritty colors. |
| `default/themed/btop.theme.tpl` | `~/.config/ryoku/current/theme/btop.theme` | Theme-rendered btop palette. |
| `default/themed/chromium.theme.tpl` | `~/.config/ryoku/current/theme/chromium.theme` | Theme-rendered Chromium accent tuple. |
| `default/themed/ghostty.conf.tpl` | `~/.config/ryoku/current/theme/ghostty.conf` | Theme-rendered Ghostty colors. |
| `default/themed/hyprland-preview-share-picker.css.tpl` | `~/.config/ryoku/current/theme/hyprland-preview-share-picker.css` | Theme-rendered CSS for the share picker UI. |
| `default/themed/hyprland.conf.tpl` | `~/.config/ryoku/current/theme/hyprland.conf` | Theme-rendered Hyprland color variables and theme defaults. |
| `default/themed/hyprlock.conf.tpl` | `~/.config/ryoku/current/theme/hyprlock.conf` | Theme-rendered Hyprlock color variables. |
| `default/themed/keyboard.rgb.tpl` | `~/.config/ryoku/current/theme/keyboard.rgb` | Theme-rendered keyboard RGB value for supported hardware. |
| `default/themed/kitty.conf.tpl` | `~/.config/ryoku/current/theme/kitty.conf` | Theme-rendered Kitty colors. |
| `default/themed/mako.ini.tpl` | `~/.config/ryoku/current/theme/mako.ini` | Theme-rendered Mako colors and styling. |
| `default/themed/obsidian.css.tpl` | `~/.config/ryoku/current/theme/obsidian.css` | Theme-rendered Obsidian CSS snippet. |
| `default/themed/quickshell-colors.qml.tpl` | `~/.config/ryoku/current/theme/quickshell-colors.qml` | Theme-rendered Quickshell color singleton. |
| `default/themed/swayosd.css.tpl` | `~/.config/ryoku/current/theme/swayosd.css` | Theme-rendered SwayOSD stylesheet. |
| `default/themed/tofi.conf.tpl` | `~/.config/ryoku/current/theme/tofi.conf` | Theme-rendered tofi colors. |
| `default/themed/walker.css.tpl` | `~/.config/ryoku/current/theme/walker.css` | Theme-rendered walker launcher CSS. |
| `default/themed/waybar.css.tpl` | `~/.config/ryoku/current/theme/waybar.css` | Theme-rendered Waybar stylesheet. |
| `default/tofi/config` | `~/.local/share/ryoku/default/tofi/config` | Default tofi launcher geometry, font, and behavior. |
| `default/tofi/pickers/backgrounds.sh` | `~/.local/share/ryoku/default/tofi/pickers/backgrounds.sh` | tofi picker script for choosing wallpapers/backgrounds. |
| `default/tofi/pickers/themes.sh` | `~/.local/share/ryoku/default/tofi/pickers/themes.sh` | tofi picker script for choosing themes. |
| `default/udev/framework16-qmk-hid.rules` | `/etc/udev/rules.d/50-framework16-qmk-hid.rules` | udev access rule for Framework 16 QMK HID devices. |
| `default/voxtype/config.toml` | `~/.config/voxtype/config.toml` | Voxtype recording, whisper, hotkey, and output defaults. |
| `default/waybar/indicators/idle.sh` | `$RYOKU_PATH/default/waybar/indicators/idle.sh` | Waybar custom module script for idle-lock status. |
| `default/waybar/indicators/notification-silencing.sh` | `$RYOKU_PATH/default/waybar/indicators/notification-silencing.sh` | Waybar custom module script for notification-silencing status. |
| `default/waybar/indicators/screen-recording.sh` | `$RYOKU_PATH/default/waybar/indicators/screen-recording.sh` | Waybar custom module script for screen-recording status. |
| `default/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf` | `~/.config/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf` | WirePlumber rule forcing software volume control on ALSA devices. |
| `default/xcompose` | `~/.XCompose` | Custom compose-key definitions. |

## `themes/` Theme Payloads

| Repo Path / Pattern | Runtime / Install Target | What It Controls |
| --- | --- | --- |
| `themes/<theme>/colors.toml` | `~/.config/ryoku/current/theme/colors.toml` | Primary theme token set. Present in: `catppuccin`, `catppuccin-latte`, `ethereal`, `everforest`, `flexoki-light`, `gruvbox`, `hackerman`, `kanagawa`, `lumon`, `matte-black`, `miasma`, `nord`, `osaka-jade`, `retro-82`, `ristretto`, `rose-pine`, `tokyo-night`, `vantablack`, `white`. |
| `themes/<theme>/icons.theme` | `~/.config/ryoku/current/theme/icons.theme` | GNOME/icon theme selection for the current theme. Present in all 19 shipped themes. |
| `themes/<theme>/vscode.json` | `~/.config/ryoku/current/theme/vscode.json` | VS Code extension/theme mapping for the current theme. Present in all 19 shipped themes. |
| `themes/<theme>/btop.theme` | `~/.config/ryoku/current/theme/btop.theme` | Theme-specific btop palette override. Present in all 19 shipped themes. |
| `themes/<theme>/light.mode` | `~/.config/ryoku/current/theme/light.mode` | Marker used to switch desktop/browser/GTK surfaces into light mode. Present in: `catppuccin-latte`, `flexoki-light`, `rose-pine`, `white`. |
| `themes/flexoki-light/chromium.theme` | `~/.config/ryoku/current/theme/chromium.theme` | Theme-specific Chromium accent tuple for `flexoki-light`. |
| `themes/lumon/chromium.theme` | `~/.config/ryoku/current/theme/chromium.theme` | Theme-specific Chromium accent tuple for `lumon`. |
| `themes/retro-82/chromium.theme` | `~/.config/ryoku/current/theme/chromium.theme` | Theme-specific Chromium accent tuple for `retro-82`. |
| `themes/rose-pine/chromium.theme` | `~/.config/ryoku/current/theme/chromium.theme` | Theme-specific Chromium accent tuple for `rose-pine`. |
| `themes/kanagawa/hyprland.conf` | `~/.config/ryoku/current/theme/hyprland.conf` | Theme-specific Hyprland border/window override for `kanagawa`. |
| `themes/lumon/hyprland.conf` | `~/.config/ryoku/current/theme/hyprland.conf` | Theme-specific Hyprland border/window override for `lumon`. |
| `themes/retro-82/hyprland.conf` | `~/.config/ryoku/current/theme/hyprland.conf` | Theme-specific Hyprland border/window override for `retro-82`. |
| `themes/retro-82/waybar.css` | `~/.config/ryoku/current/theme/waybar.css` | Theme-specific Waybar CSS override for `retro-82`. |
| `themes/catppuccin/waybar.css` | `~/.config/ryoku/current/theme/waybar.css` | Theme-specific Waybar CSS override for `catppuccin`. |
| `themes/lumon/waybar.css` | `~/.config/ryoku/current/theme/waybar.css` | Theme-specific Waybar CSS override for `lumon`. |
| `themes/retro-82/swayosd.css` | `~/.config/ryoku/current/theme/swayosd.css` | Theme-specific SwayOSD CSS override for `retro-82`. |
| `themes/lumon/swayosd.css` | `~/.config/ryoku/current/theme/swayosd.css` | Theme-specific SwayOSD CSS override for `lumon`. |
| `themes/tokyo-night/keyboard.rgb` | `~/.config/ryoku/current/theme/keyboard.rgb` | Theme-specific keyboard RGB value for supported hardware in `tokyo-night`. |

## ISO / Release Notes

| Repo Path | Why It Deserves Extra Review Before Shipping |
| --- | --- |
| `config/xournalpp/settings.xml` | Application state files can retain last-opened and last-saved paths; scrub or reset if you do not want baked-in path history. |
| `config/chromium/Default/Preferences` | Browser preference seeds are safe to ship, but this class of file is stateful by nature, so review it whenever browser defaults change. |
