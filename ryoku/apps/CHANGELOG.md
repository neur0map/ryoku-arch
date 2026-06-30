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
- `npm/` ships `~/.npmrc` (global prefix `~/.local`) and `pip/` ships
  `~/.config/pip/pip.conf` (`break-system-packages`), so `npm i -g` and
  `pip install --user` work without root.
- `ryovm/` a virtual-machine manager (`qs -c ryovm`, Super+Shift+V), built on
  quickemu/quickget. A **Library** of your machines and a **Catalog** of ~90
  operating systems (~770 release/edition combos: Windows, macOS, every major
  Linux, the BSDs, Android x86). Brand logos are prefetched in parallel and
  cached to `~/.cache/ryoku/ryovm-icons` (a negative cache skips the ~56 OSes
  with no upstream art, which fall back to a coloured monogram); systems that
  have a real logo sort into a **Popular** section above the rest. Builds a VM in
  app with a live progress bar and Cancel (a `ryovm-fetch` Go helper does the
  parallel download; cancelling wipes the half-image), or from any local ISO via
  **Load ISO**. Per-VM cores/memory, snapshots, and three display modes: a
  **Window**, a **SPICE** console, or **Headless** (terminal-only, SSH in). The
  running view shows the mode's cursor-release shortcut and a stop-to-free note.
  The `ryovm` engine is the data plane; the GPU-passthrough gaming VM in Ryoku
  Settings > GPU is a separate, single-VM path.

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
- `fish/`: route `go install` (`GOBIN`) and `cargo install` (`CARGO_INSTALL_ROOT`)
  to `~/.local/bin` and activate `mise`, so every language tool installs onto
  `PATH` and works from day one.
