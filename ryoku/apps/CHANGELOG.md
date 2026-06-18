# Changelog: ryoku/apps/

## Unreleased

### Added
- `kitty/` terminal config (`kitty.conf`) plus a default `current-theme.conf` in
  the Ryoku dark palette.
- `fastfetch/` branded readout (`config.jsonc`) and the `ryoku-fastfetch` launcher
  (kitty graphics with a chafa fallback).
- `fish/` shell config with the greeting suppressed and starship, zoxide, fzf,
  and eza wired up.
- `starship/` prompt (directory, git branch, command duration) on a fixed
  Ryoku palette.
- `nautilus/` notes on xdg-user-dirs home folders and optional GSettings defaults.
- `nvim/` LazyVim-based Neovim config with the custom Ryoku startup dashboard
  logo (snacks.nvim header), tokyonight default, plus `ryoku-nvim.desktop` that
  registers it for text files.
- `yazi/` file manager config; its editor opener is Neovim (blocking).
- `mimeapps.list` makes Neovim the default application for text and code files.

### Changed
- `fish/`: put `~/.local/bin` on `PATH` for every shell (not only interactive),
  so user-installed tools and the `ryoku-fastfetch` wrapper resolve.
- `fastfetch/`: align the readout to the upstream Ryoku config (host/cpu/gpu
  layout, no `title`); the `力` brand logo uses a wider left pad to clear the edge.
- `fastfetch/`: color the keys and percentages with fixed brand truecolor
  instead of palette slots, so the readout stays legible under any wallust theme
  (themed `red`/`green` could fall to near-background contrast and vanish).
- `fish/`: ship a fixed, legible syntax-highlight color scheme set
  unconditionally in `config.fish`. fish applied a palette-tied default theme
  before `config.fish` that rendered typed input in a near-background color
  (invisible as you type); pinning command, param, error, comment, and
  autosuggestion colors keeps the command line readable under any wallust theme.
- `fish/`: hook `cd` into zoxide (`zoxide init fish --cmd cd`), so plain `cd`
  learns and jumps to frecent directories (`cdi` for an interactive pick).
- `yazi/`: show hidden files by default (`[mgr] show_hidden = true`), so dotfile
  trees like `~/.config` are visible.
