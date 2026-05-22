# Vroomies Upstream

Source: https://github.com/maxchennn/vroomies
Imported commit: 3315be8709eb3471cf24c9cb3d85695536dae33b
License: MIT

This directory vendors the Vroomies Quickshell dotfiles as the visual base for the Ryoku rebirth Hyprland shell. The upstream setup scripts are intentionally not imported or executed because they install packages, replace user config directories, and change shell preferences.

Ryoku-specific adaptation in this copy:
- Runtime paths resolve through `RYOKU_VROOMIES_SHELL_DIR` and default to `~/.config/quickshell/ryoku-vroomies-shell`.
- Hyprland launches and keybinds are owned by Ryoku, not by the upstream Vroomies Hyprland config.
- The missing upstream Settings loader is disabled until Ryoku rebuilds that surface.
