# Ryoku themes

Each theme is a folder: `themes/<name>/`. The folder name is the theme id
(lowercase, hyphens). The Settings → Color Scheme picker shows every installed
theme, and the download list shows repo themes you don't have yet.

## Structure

```
themes/<name>/
  colors.toml      # REQUIRED: the palette (see below)
  preview.png      # optional: tile/preview image
  kitty.conf       # optional: terminal theme
  alacritty.toml   # optional
  btop.theme       # optional
  vscode.json      # optional
  icons.theme      # optional
  backgrounds/     # optional: bundled wallpapers
```

## colors.toml (required keys)

```toml
accent     = "#RRGGBB"   # primary accent
background = "#RRGGBB"    # surface / window background
foreground = "#RRGGBB"    # main text
color0 = "#RRGGBB"  …  color15 = "#RRGGBB"   # 16-color terminal palette
```

The shell maps these to a full Material-3 scheme via `ryoku-theme-to-scheme`
(accent→primary, color6→secondary, color5→tertiary, background→surfaces, etc.).

## Adding a theme to the repo

1. Add `themes/<name>/colors.toml` (+ optional assets above).
2. Regenerate the catalog: `bin/ryoku-theme-index themes -o themes/index.json`.
3. Commit + push. Users then see it in the Settings download list and can
   install it (fetched into `~/.config/ryoku/themes/<name>/`).

Users can also add personal themes by dropping a folder into
`~/.config/ryoku/themes/<name>/`. It appears in the picker immediately.
