# Ryoku Branding

The visual + verbal identity of the Ryoku Arch project.

## Name

**Ryoku** comes from the Japanese kanji **力** (read *chikara* or *ryoku*), meaning "power / strength". The project's tagline appears in both Japanese and English:

> **力と美のために** : *For the sake of power and beauty.*

Use "Ryoku" in prose. Use the "Ryoku Arch" full name on first mention in user-facing copy where context might be ambiguous (release pages, install instructions, the README header).

**Do not call it a distro.** Ryoku is an opinionated Arch Linux environment / configuration on top of Arch Linux, not its own distribution. Stick to "Ryoku Arch", "the Ryoku environment", "the Ryoku setup".

## Website

`https://ryoku.dev` is reserved for the public site. Suggested layout once the site is up:

| Subdomain | Purpose |
|---|---|
| `ryoku.dev` | Marketing / landing page, install instructions |
| `iso.ryoku.dev` | Custom domain in front of the Cloudflare R2 bucket that hosts the ISO |
| `docs.ryoku.dev` | (optional) hosted version of `docs/` if it grows past README-readable |

Until the site is published, use the GitHub repo URL (`https://github.com/neur0map/ryoku-arch`) as the canonical pointer.

## Brand colors (Greek Noir palette)

The palette is named **Greek Noir** in the codebase. It is the Ryoku-branded reference palette. Hex values:

| Role | Hex | Notes |
|---|---|---|
| **Accent / brand orange** | `#F25623` | Primary brand color. Used for the kanji mark, `RYOKU` wordmark, Limine branding, MIT-license badge, status badges, terminal accent. |
| Bright orange | `#F56E0F` | Secondary accent, brighter version of the brand. Used in `term_palette_bright` slot 5 and as the bright variant in some themes. |
| Background dark | `#171717` | Default dark surface. SVG logo background, terminal background, Plymouth window background, Limine `term_background`. |
| Foreground / subdued | `#aeab94` | Muted beige used for body text in dark contexts and the tagline. |
| Foreground bright | `#CCD0CF` | Standard terminal text. |
| Background bright | `#333333` | Lifted dark surface, subtle hover states. |
| Muted gray accent | `#4D4D4D` | Yellow slot replacement, dividers. |
| Muted green-gray | `#88A57D` | Blue slot replacement, callout/info. |
| Cyan replacement | `#8A8A8A` | Standard cyan slot, neutralized. |
| Light gray | `#bcbfbc` | White slot in normal palette. |
| Faded foreground | `#757d75` | White slot in bright palette, subtle hint text. |
| SDDM neutral foreground | `#f0ede8` | Pending rebrand value for the iNiR `ii-pixel` greeter. |

### Limine boot menu palette (literal config)

This is what `default/limine/limine.conf` ships:

```
term_background:      171717
backdrop:             171717
term_palette:         171717;aeab94;F25623;4D4D4D;88A57D;F56E0F;8A8A8A;bcbfbc
term_palette_bright:  333333;aeab94;F25623;4D4D4D;88A57D;F56E0F;8A8A8A;757d75
term_foreground:        CCD0CF
term_foreground_bright: CCD0CF
term_background_bright: 333333

interface_branding:       Ryoku Bootloader
interface_branding_color: F25623
interface_help_color:     F25623
```

Limine 11 expects ANSI-index `0..7` for branding color (resolved through `term_palette`); Limine 12+ expects RRGGBB hex directly. The shipped value `F25623` is the hex form so it lands on-brand on Limine 12. See `docs/iso-build-recipe.md` for the migration note.

### Plymouth window

`default/plymouth/ryoku.script` sets the decrypt-prompt window to a flat dark surface:

```
Window.SetBackgroundTopColor(0.0902, 0.0902, 0.0902);    # ≈ #171717
Window.SetBackgroundBottomColor(0.0902, 0.0902, 0.0902); # ≈ #171717
```

## Logos

### Source files (canonical)

All logo sources live at the **repo root** so they are visible from the README without subfolder navigation:

| File | Purpose | Format | Notes |
|---|---|---|---|
| `logo.svg` | Square logo with rounded background | SVG | 512x512, `#171717` rounded-square background, `#F25623` kanji `力` centered. Use on light surfaces and in places that want the full mark with its own backdrop (favicon, app icon). |
| `logo-mark.svg` | Transparent-background kanji mark | SVG | 512x512, transparent background, `#F25623` kanji `力` centered. Use in the README header, on dark theme cards, anywhere that already provides its own background. |
| `logo.txt` | ASCII wordmark | UTF-8 box-drawing | The `RYOKU` wordmark used by `boot.sh`, the configurator, and `ryoku-cmd-first-run`. Reuse this verbatim; do not regenerate. |
| `icon.png` | Rasterized square logo | PNG (512x512) | Same composition as `logo.svg`, exported. Used as a fallback where SVG is not supported. |
| `logo-mark.png` | Rasterized transparent mark | PNG (512x512) | Same composition as `logo-mark.svg`, exported. Used in the README header. |

The kanji `力` is rendered at weight 900 in **Noto Sans CJK JP** at the size that fills the canvas with comfortable margin. That font is part of `noto-fonts-cjk`, which Ryoku already pulls in via `install/ryoku-base.packages`, so the SVG renders consistently on any Ryoku install.

### Asset locations on the installed system

| Path | Purpose |
|---|---|
| `~/.local/share/ryoku/logo-mark.png` | Repo asset, available for any Ryoku-aware app |
| `~/.local/share/ryoku/logo.txt` | ASCII wordmark, used by `ryoku-cmd-first-run` and `install/post-install/finished.sh` |
| `/usr/share/sddm/themes/ii-pixel/` | iNiR SDDM greeter; Ryoku visual rebrand is pending |
| `/usr/share/plymouth/themes/ryoku/logo.png` | Plymouth boot-splash branding |

### How to regenerate the SVG mark

The square SVG is intentionally minimal so you can hand-edit it. Replace the `text` element to change the glyph; keep the `fill` and `font-family` consistent with the table above.

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <rect width="512" height="512" rx="48" ry="48" fill="#171717"/>
  <text x="256" y="360"
        font-family="Noto Sans CJK JP, sans-serif"
        font-weight="900"
        font-size="360"
        fill="#F25623"
        text-anchor="middle"
        dominant-baseline="middle">力</text>
</svg>
```

To rasterize after editing the SVG (Inkscape is the project's reference tool because it ships with most distros and renders Noto CJK correctly):

```bash
inkscape -w 512 -h 512 logo.svg --export-filename=icon.png
inkscape -w 512 -h 512 logo-mark.svg --export-filename=logo-mark.png
```

Or with `rsvg-convert` (smaller dependency, no GUI):

```bash
rsvg-convert -w 512 -h 512 logo.svg -o icon.png
rsvg-convert -w 512 -h 512 logo-mark.svg -o logo-mark.png
```

After regenerating, commit the source SVG + the PNG so README rendering on GitHub continues to work without server-side SVG quirks.

### How to regenerate the ASCII wordmark

`logo.txt` was hand-built in box-drawing characters. If the wordmark needs to change (e.g. version branding), build it from a figlet-style font that uses Unicode box-drawing, then hand-tune for kerning. **Do not** auto-generate it as ANSI escape sequences; the file is meant to be raw UTF-8 so any terminal can render it.

```bash
# Reference: the current characters used by logo.txt
# ╔ ╗ ╚ ╝ ║ ═ ╠ ╣ ╦ ╩ ╬ █
```

The kanji-block art used by `boot.sh` is also hand-drawn block-text (`█` and friends) and lives inline in that script as a heredoc. Edit there, not in `logo.txt`.

## Application areas (where the brand shows up)

| Surface | Source of brand | What renders |
|---|---|---|
| GitHub README | `logo-mark.png`, MIT badge color `F25623` | Kanji mark + status badges in brand orange |
| Install bootstrap (`boot.sh`) | Inline kanji block-art + `RYOKU` wordmark | Orange ANSI art, beige tagline |
| Live ISO configurator | `bin/ryoku-cmd-first-run` ANSI palette setup | Brand-orange terminal accents during install |
| Limine boot menu | `default/limine/limine.conf` | Orange branding text "Ryoku Bootloader", Greek Noir terminal palette |
| Plymouth decrypt | `default/plymouth/ryoku.script` + `default/plymouth/*.png` | Dark window, branded progress bar + lock icon |
| SDDM greeter | iNiR `ii-pixel` theme | Upstream iNiR login theme until the Ryoku rebrand pass |
| Niri/iNiR session | `themes/<theme>/` per active theme | Greek Noir is the brand-accurate one; other themes are user-selectable but not "the brand" |
| First-boot welcome notification | `install/first-run/welcome.sh` | Branded notification copy |

## What "on-brand" means

A surface is on-brand if:

1. **The accent color the eye lands on first is `#F25623`.** Status indicators, branded headings, the kanji mark, the boot-menu title.
2. **Dark backgrounds default to `#171717`** with `#333333` as the lifted "card" tone. No pure black.
3. **Body text on dark is `#CCD0CF` (bright) or `#aeab94` (subdued).** Subdued is for taglines and annotations. Pure white is reserved for emphasis on light surfaces.
4. **The kanji `力` is the primary mark, not the wordmark.** The wordmark exists for places that already have spatial/typographic context (TTY install, ASCII banners). When in doubt, use the kanji square.
5. **No emoji-as-logo.** The mark is the kanji, the kanji is the mark.

User-selectable themes (Catppuccin, Tokyo Night, Gruvbox, Rose Pine, etc.) are first-class but they are user expression, not the brand. The brand is Greek Noir + the kanji mark.

## Don't-do list

- Don't recolor the kanji mark. The orange is the brand.
- Don't substitute a different kanji or character. `力` is the brand mark.
- Don't ship the wordmark without the kanji where space allows for both.
- Don't introduce a third accent color. If you need a second accent, use the bright orange `#F56E0F` from the existing palette.
- Don't add gradients to the kanji. Flat fill only.
- Don't use the brand orange for error states; the palette includes `#aeab94` for muted callouts and the standard ANSI red is acceptable for errors.
