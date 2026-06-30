# apps/

The applications Ryoku ships and their settings, one folder per app. Each folder
maps to a place under `~/.config` (except the small helper script noted below).

## What's here

- `kitty/` The terminal. JetBrains Mono Nerd Font, a beam cursor, and fish as the
  shell. `kitty.conf` includes `current-theme.conf`, which carries the Ryoku dark
  palette (background `#171717`, foreground `#CCD0CF`, accent `#F25623`).
- `fastfetch/` The branded system readout. `config.jsonc` draws the 力 logo and a
  short list of facts (host, OS, kernel, WM, CPU, GPU, memory, disk, terminal,
  uptime). `ryoku-fastfetch` is a launcher that uses kitty's graphics protocol in
  kitty and falls back to chafa elsewhere.
- `fish/` The shell. The greeting is turned off so the login terminal stays
  clean, then it runs `ryoku-fastfetch` and wires up starship, zoxide, fzf, and a
  few eza listing aliases (each guarded so a missing tool is harmless).
- `starship/` The prompt: current directory, git branch, and command duration on
  a fixed Ryoku palette.
- `nvim/` The editor (LazyVim seed) plus `ryoku-nvim.desktop`, which registers
  neovim as the default text handler.
- `yazi/` The terminal file manager (`yazi.toml`).
- `npm/` (`npmrc`) and `pip/` (`pip.conf`) keep each package manager writing under
  the home, so neither needs root.
- `nautilus/` The graphical file manager. No config to ship; see its README for
  how the home folders and optional defaults work.
- `mimeapps.list` The default-application map (text files route to neovim).

## GUI apps (Quickshell)

These are full applications, not `~/.config` seeds: each `<name>/quickshell/`
ships as `qs -c <name>`, its `bin/` helpers and any Go helper land on `PATH`, and
its `<name>.desktop` plus `quickshell/logo.svg` register it in the launcher.

- `ryowalls/` Wallpaper browser: search wallhaven, preview the rice, set it.
  Engine: the `ryowalls` script. Summon with Super+Shift+W.
- `ryovm/` Virtual-machine manager built on quickemu/quickget: a Library of your
  machines and a Catalog of ~700 downloadable systems (Windows, macOS, Linux, the
  BSDs, Android x86). Builds in app with a live progress bar (the `ryovm-fetch` Go
  helper, under `fetch/`) or from any local ISO; per-VM cores/memory, snapshots,
  and Window / SPICE / Headless display. Engine: the `ryovm` script. Summon with
  Super+Shift+V. The GPU-passthrough gaming VM (a single, dedicated VM that owns
  the discrete GPU) is configured and launched from Ryoku Settings > GPU, not from
  here.

## Install paths

| Folder          | Destination                               |
| --------------- | ----------------------------------------- |
| `kitty/`        | `~/.config/kitty/`                        |
| `fastfetch/`    | `~/.config/fastfetch/` (config + wrapper) |
| `fish/`         | `~/.config/fish/config.fish`              |
| `starship/`     | `~/.config/starship.toml`                 |
| `nvim/`         | `~/.config/nvim/`                         |
| `yazi/`         | `~/.config/yazi/`                         |
| `npm/`          | `~/.npmrc`                                 |
| `pip/`          | `~/.config/pip/pip.conf`                  |
| `mimeapps.list` | `~/.config/mimeapps.list`                 |

The `ryoku-fastfetch` wrapper must also land on `PATH` (for example
`~/.local/bin/ryoku-fastfetch`) so fish can call it on terminal start. It expects
the brand logo at `~/.local/share/ryoku/assets/brand/logo-mark.png`.
