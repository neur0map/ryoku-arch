---
name: ryoku
description: >
  REQUIRED for end-user customization of Linux desktop, window manager, or system config.
  Use when editing ~/.config/hypr/, ~/.config/waybar/, ~/.config/walker/,
  ~/.config/alacritty/, ~/.config/kitty/, ~/.config/ghostty/, ~/.config/mako/,
  or ~/.config/ryoku/. Triggers: Hyprland, window rules, animations, keybindings,
  monitors, gaps, borders, blur, opacity, waybar, walker, terminal config, themes,
  wallpaper, night light, idle, lock screen, screenshots, layer rules, workspace
  settings, display config, and user-facing ryoku commands. Excludes Ryoku
  source development in ~/.local/share/ryoku/ and ryoku-dev-* workflows.
---

# Ryoku Skill

Manage Ryoku Linux systems built around Hyprland, Waybar, Walker, themed terminals, and the Ryoku command set.

This skill is for end-user customization on installed systems.
It is not for contributing to Ryoku source code.

## When This Skill MUST Be Used

**ALWAYS invoke this skill for end-user requests involving ANY of these:**

- Editing ANY file in `~/.config/hypr/` (window rules, animations, keybindings, monitors, etc.)
- Editing ANY file in `~/.config/waybar/`, `~/.config/walker/`, `~/.config/mako/`
- Editing terminal configs (alacritty, kitty, ghostty)
- Editing ANY file in `~/.config/ryoku/`
- Window behavior, animations, opacity, blur, gaps, borders
- Layer rules, workspace settings, display/monitor configuration
- Themes, wallpapers, fonts, appearance changes
- User-facing `ryoku-*` commands (`ryoku-theme-*`, `ryoku-refresh-*`, `ryoku-restart-*`, etc.)
- Screenshots, screen recording, night light, idle behavior, lock screen

**If you're about to edit a config file in ~/.config/ on this system, STOP and use this skill first.**

**Do NOT use this skill for Ryoku development tasks** (editing files in `~/.local/share/ryoku/`, creating migrations, or running `ryoku-dev-*` workflows).

## Critical Safety Rules

**For end-user customization tasks, NEVER modify anything in `~/.local/share/ryoku/`** - but READING is safe and encouraged.

This directory contains Ryoku's source files managed by git. Any changes will be:
- Lost on next `ryoku-update`
- Cause conflicts with upstream
- Break the system's update mechanism

```
~/.local/share/ryoku/     # READ-ONLY - NEVER EDIT (reading is OK)
├── bin/                    # Source scripts (symlinked to PATH)
├── config/                 # Default config templates
├── themes/                 # Stock themes
├── default/                # System defaults
├── migrations/             # Update migrations
└── install/                # Installation scripts
```

**Reading `~/.local/share/ryoku/` is SAFE and useful** - do it freely to:
- Understand how Ryoku commands work: `cat $(which ryoku-theme-set)`
- See default configs before customizing: `cat ~/.local/share/ryoku/config/waybar/config.jsonc`
- Check stock theme files to copy for customization
- Reference default hyprland settings: `cat ~/.local/share/ryoku/default/hypr/*`

**Always use these safe locations instead:**
- `~/.config/` - User configuration (safe to edit)
- `~/.config/ryoku/themes/<custom-name>/` - Custom themes (must be real directories)
- `~/.config/ryoku/hooks/` - Custom automation hooks

If the request is to develop Ryoku itself, this skill is out of scope. Follow repository development instructions instead of this skill.

## System Architecture

Ryoku is built on:

| Component | Purpose | Config Location |
|-----------|---------|-----------------|
| **Arch Linux** | Base OS | `/etc/`, `~/.config/` |
| **Hyprland** | Wayland compositor/WM | `~/.config/hypr/` |
| **Waybar** | Status bar | `~/.config/waybar/` |
| **Walker** | App launcher | `~/.config/walker/` |
| **Alacritty/Kitty/Ghostty** | Terminals | `~/.config/<terminal>/` |
| **Mako** | Notifications | `~/.config/mako/` |
| **SwayOSD** | On-screen display | `~/.config/swayosd/` |

## Command Discovery

Ryoku provides a command surface centered on the `ryoku-<category>-<action>` pattern.

```bash
# List all ryoku commands
compgen -c | grep -E '^ryoku-' | sort -u

# Find commands by category
compgen -c | grep -E '^ryoku-theme'
compgen -c | grep -E '^ryoku-restart'

# Read a command's source to understand it
cat $(which ryoku-theme-set)
```

### Command Categories

| Prefix | Purpose | Example |
|--------|---------|---------|
| `ryoku-refresh-*` | Reset config to defaults (backs up first) | `ryoku-refresh-waybar` |
| `ryoku-restart-*` | Restart a service/app | `ryoku-restart-waybar` |
| `ryoku-toggle-*` | Toggle feature on/off | `ryoku-toggle-nightlight` |
| `ryoku-theme-*` | Theme management | `ryoku-theme-set <name>` |
| `ryoku-install-*` | Install optional software | `ryoku-install-docker-dbs` |
| `ryoku-launch-*` | Launch apps | `ryoku-launch-browser` |
| `ryoku-cmd-*` | System commands | `ryoku-cmd-screenshot` |
| `ryoku-pkg-*` | Package management | `ryoku-pkg-install <pkg>` |
| `ryoku-setup-*` | Initial setup tasks | `ryoku-setup-fingerprint` |
| `ryoku-update-*` | System updates | `ryoku-update` |

## Configuration Locations

### Hyprland (Window Manager)

```
~/.config/hypr/
├── hyprland.conf      # Main config (sources others)
├── bindings.conf      # Keybindings
├── monitors.conf      # Display configuration
├── input.conf         # Keyboard/mouse settings
├── looknfeel.conf     # Appearance (gaps, borders, animations)
├── envs.conf          # Environment variables
├── autostart.conf     # Startup applications
├── hypridle.conf      # Idle behavior (screen off, lock, suspend)
├── hyprlock.conf      # Lock screen appearance
└── hyprsunset.conf    # Night light / blue light filter
```

**Key behaviors:**
- Hyprland auto-reloads on config save (no restart needed for most changes)
- Use `hyprctl reload` to force reload
- Use `ryoku-refresh-hyprland` to reset to defaults

### Waybar (Status Bar)

```
~/.config/waybar/
├── config.jsonc       # Bar layout and modules (JSONC format)
└── style.css          # Styling
```

**Waybar does NOT auto-reload.** You MUST run `ryoku-restart-waybar` after any config changes.

**Commands:** `ryoku-restart-waybar`, `ryoku-refresh-waybar`, `ryoku-toggle-waybar`

### Terminals

```
~/.config/alacritty/alacritty.toml
~/.config/kitty/kitty.conf
~/.config/ghostty/config
```

**Command:** `ryoku-restart-terminal`

### Other Configs

| App | Location |
|-----|----------|
| btop | `~/.config/btop/btop.conf` |
| fastfetch | `~/.config/fastfetch/config.jsonc` |
| lazygit | `~/.config/lazygit/config.yml` |
| starship | `~/.config/starship.toml` |
| git | `~/.config/git/config` |
| walker | `~/.config/walker/config.toml` |

## Safe Customization Patterns

### Pattern 1: Edit User Config Directly

For simple changes, edit files in `~/.config/`:

```bash
# 1. Read current config
cat ~/.config/hypr/bindings.conf

# 2. Backup before changes
cp ~/.config/hypr/bindings.conf ~/.config/hypr/bindings.conf.bak.$(date +%s)

# 3. Make changes with Edit tool

# 4. Apply changes
# - Hyprland: auto-reloads on save (no restart needed)
# - Waybar: MUST restart with ryoku-restart-waybar
# - Walker: MUST restart with ryoku-restart-walker
# - Terminals: MUST restart with ryoku-restart-terminal
```

### Pattern 2: Make a new theme

1. Create a directory under ~/.config/ryoku/themes.
2. See how an existing theme is done via ~/.local/share/ryoku/themes/catppuccin.
3. Download a matching background (or several) from the internet and put them in ~/.config/ryoku/themes/[name-of-new-theme]
4. When done with the theme, run ryoku-theme-set "Name of new theme"

### Pattern 3: Use Hooks for Automation

Create scripts in `~/.config/ryoku/hooks/` to run automatically on events:

```bash
# Available hooks (see samples in ~/.config/ryoku/hooks/):
~/.config/ryoku/hooks/
├── theme-set        # Runs after theme change (receives theme name as $1)
├── font-set         # Runs after font change
└── post-update      # Runs after ryoku-update
```

Example hook (`~/.config/ryoku/hooks/theme-set`):
```bash
#!/bin/bash
THEME_NAME=$1
echo "Theme changed to: $THEME_NAME"
# Add custom actions here
```

### Pattern 4: Reset to Defaults -- ALWAYS SEEK USER CONFIRMATION BEFORE RUNNING

When customizations go wrong:

```bash
# Reset specific config (creates backup automatically)
ryoku-refresh-waybar
ryoku-refresh-hyprland

# The refresh command:
# 1. Backs up current config with timestamp
# 2. Copies default from ~/.local/share/ryoku/config/
# 3. Restarts the component
```

## Common Tasks

### Themes

```bash
ryoku-theme-list              # Show available themes
ryoku-theme-current           # Show current theme
ryoku-theme-set <name>        # Apply theme (use "Tokyo Night" not "tokyo-night")
ryoku-theme-bg-next           # Cycle wallpaper
ryoku-theme-install <url>     # Install from git repo
```

### Keybindings

Edit `~/.config/hypr/bindings.conf`. Format:
```
bind = SUPER, Return, exec, xdg-terminal-exec
bind = SUPER, Q, killactive
bind = SUPER SHIFT, E, exit
```

View current bindings: `ryoku-menu-keybindings --print`

**IMPORTANT: When re-binding an existing key:**

1. First check existing bindings: `ryoku-menu-keybindings --print`
2. If the key is already bound, you MUST add an `unbind` directive BEFORE your new `bind`
3. Inform the user what the key was previously bound to

Example - rebinding SUPER+F (which is bound to fullscreen by default):
```
# Unbind existing SUPER+F (was: fullscreen)
unbind = SUPER, F
# New binding for file manager
bind = SUPER, F, exec, nautilus
```

Always tell the user: "Note: SUPER+F was previously bound to fullscreen. I've added an unbind directive to override it."

### Display/Monitors

Edit `~/.config/hypr/monitors.conf`. Format:
```
monitor = eDP-1, 1920x1080@60, 0x0, 1
monitor = HDMI-A-1, 2560x1440@144, 1920x0, 1
```

List monitors: `hyprctl monitors`

### Window Rules

**CRITICAL: Hyprland window rules syntax changes frequently between versions.**

Before writing ANY window rules, you MUST fetch the current documentation from the official Hyprland wiki:
- https://github.com/hyprwm/hyprland-wiki/blob/main/content/Configuring/Window-Rules.md

DO NOT rely on cached or memorized window rule syntax. The format has changed multiple times and using outdated syntax will cause errors or unexpected behavior.

Window rules go in `~/.config/hypr/hyprland.conf` or a sourced file. Always verify the current syntax from the wiki first.

### Fonts

```bash
ryoku-font-list               # Available fonts
ryoku-font-current            # Current font
ryoku-font-set <name>         # Change font
```

### System

```bash
ryoku-update                  # Full system update
ryoku-version                 # Show Ryoku version
ryoku-debug --no-sudo --print # Debug info (ALWAYS use these flags)
ryoku-lock-screen             # Lock screen
ryoku-system-shutdown         # Shutdown
ryoku-system-reboot           # Reboot
```

**IMPORTANT:** Always run `ryoku-debug` with `--no-sudo --print` flags to avoid interactive sudo prompts that will hang the terminal.

## Troubleshooting

```bash
# Get debug information (ALWAYS use these flags to avoid interactive prompts)
ryoku-debug --no-sudo --print

# Upload logs for support
ryoku-upload-log

# Reset specific config to defaults
ryoku-refresh-<app>

# Refresh specific config file
# config-file path is relative to ~/.config/
# eg. ryoku-refresh-config hypr/hyprlock.conf will refresh ~/.config/hypr/hyprlock.conf
ryoku-refresh-config <config-file>

# Full reinstall of configs (nuclear option)
ryoku-reinstall
```

## Decision Framework

When user requests system changes:

1. **Is it a stock ryoku command?** Use it directly
2. **Is it a config edit?** Edit in `~/.config/`, never `~/.local/share/ryoku/`
3. **Is it a theme customization?** Create a NEW custom theme directory
4. **Is it automation?** Use hooks in `~/.config/ryoku/hooks/`
5. **Is it a package install?** Use `ryoku-pkg-add` (or `ryoku-pkg-aur-add` for AUR-only packages)
6. **Unsure if command exists?** Search with `compgen -c | grep ryoku`

## Out of Scope

This skill intentionally does not cover Ryoku source development. Do not use this skill for:
- Editing files in `~/.local/share/ryoku/` (`bin/`, `config/`, `default/`, `themes/`, `migrations/`, etc.)
- Creating or editing migrations
- Running `ryoku-dev-*` commands

## Example Requests

- "Change my theme to catppuccin" -> `ryoku-theme-set catppuccin`
- "Add a keybinding for Super+E to open file manager" -> Check existing bindings first, add `unbind` if needed, then add `bind` in `~/.config/hypr/bindings.conf`
- "Configure my external monitor" -> Edit `~/.config/hypr/monitors.conf`
- "Make the window gaps smaller" -> Edit `~/.config/hypr/looknfeel.conf`
- "Set up night light to turn on at sunset" -> `ryoku-toggle-nightlight` or edit `~/.config/hypr/hyprsunset.conf`
- "Customize the catppuccin theme colors" -> Create `~/.config/ryoku/themes/catppuccin-custom/` by copying from stock, then edit
- "Run a script every time I change themes" -> Create `~/.config/ryoku/hooks/theme-set`
- "Reset waybar to defaults" -> `ryoku-refresh-waybar`
