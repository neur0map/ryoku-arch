# Theming Presets

44 built-in color presets that bypass wallpaper-based color generation and apply predefined palettes.

## How presets work

Normally, iNiR extracts colors from your wallpaper using Material You. Presets skip that step and inject a complete Material 3 color palette directly. The palette propagates to external apps (GTK, terminals, Firefox, etc.) the same way wallpaper colors do.

Apply presets from Settings > Appearance > Theme, or via IPC:

```bash
inir theme setPreset gruvbox-dark
inir theme setPreset catppuccin-mocha
inir theme auto                        # back to wallpaper-based
```

When a preset is active, changing wallpapers changes the background image but doesn't regenerate colors.

## Preset catalog

### Signature

| Preset | Description |
|--------|-------------|
| **Angel** | Celestial twilight. Warm golden halos against deep cosmic void. The iNiR signature theme. |
| **Angel Light** | Ethereal dawn variant. Warm cream surfaces with golden accents. |

### Catppuccin

| Preset | Description |
|--------|-------------|
| **Catppuccin Mocha** | Dark. Warm purple-blue with pastel accents. |
| **Catppuccin Macchiato** | Medium-dark. Slightly warmer than Mocha. |
| **Catppuccin Frappe** | Medium. Muted blue-grey. |
| **Catppuccin Latte** | Light. Cream base with soft pastels. |

### Gruvbox

| Preset | Description |
|--------|-------------|
| **Gruvbox Dark** | The classic warm retro palette. Orange/yellow accents on dark brown. |
| **Gruvbox Material** | Gruvbox colors adapted to Material Design surfaces. |

### Japanese-inspired

| Preset | Description |
|--------|-------------|
| **Kanagawa** | The Great Wave. Deep blues with warm highlights. |
| **Kanagawa Dragon** | Darker Kanagawa variant with stronger contrasts. |
| **Tokyo Night** | Neon city. Cool blues with warm purple accents. |
| **Sakura** | Cherry blossom pink on dark surfaces. |
| **Samurai** | Deep crimson and black. Disciplined, sharp. |
| **Zen Garden** | Muted earth tones. Stone, moss, bamboo. |

### Classic

| Preset | Description |
|--------|-------------|
| **Nord** | Arctic. Cool blue-grey palette from the Nord project. |
| **Dracula** | Purple-centric dark theme. A classic. |
| **Solarized Dark** | Ethan Schoonover's carefully crafted palette. |
| **One Dark** | Atom editor's signature dark theme. |
| **Monokai** | The Sublime Text classic. Warm highlights on dark. |
| **Rose Pine** | Soft, muted pastels. Natural and calming. |
| **Rose Pine Moon** | Darker Rose Pine variant. |

### Modern

| Preset | Description |
|--------|-------------|
| **GitHub Dark** | GitHub's dark mode palette. Clean, neutral. |
| **Vercel** | Monochrome with blue accents. Minimal and modern. |
| **Material Ocean** | Deep ocean blue Material Design variant. |
| **Palenight** | Soft purple-blue. Calm and easy on the eyes. |
| **Everforest** | Green-focused. Natural, forest-inspired. |
| **Ayu Dark** | Warm grey with orange accents. |
| **Ayu Mirage** | Medium-dark Ayu variant. Softer contrasts. |
| **Ayu Light** | Light Ayu variant. |

### Special

| Preset | Description |
|--------|-------------|
| **Synthwave '84** | Retro neon. Hot pink and cyan on dark purple. |
| **Matrix** | Green terminal aesthetic on black. Exactly what you think. |
| **Moonlight** | Cool purple moonlit palette. |
| **Night Owl** | Sarah Drasner's dark theme. Rich blues. |
| **Vitesse** | Anthony Fu's theme. Muted, elegant. |
| **Poimandres** | Deep purple-blue with mint accents. |

## Preset features

Some presets include metadata that affects more than just colors:

- **Rounding scale**: multiplier for corner rounding (Zen Garden uses larger rounding for a softer feel)
- **Font style**: some presets override the default font (mono for Matrix, serif for certain Japanese themes)
- **Border width**: Angel uses thinner borders by default

## Variant system

Presets can be used as seeds for Material You scheme variants. Instead of using the preset colors directly, the engine generates a full Material 3 scheme from the preset's primary color:

- **Tonal Spot**: standard Material You mapping
- **Expressive**: more vibrant secondary/tertiary colors
- **Fidelity**: stays closer to the source color
- **Content**: muted, content-focused palette

## Custom presets

There's no UI for creating custom presets yet, but you can add them by editing `modules/common/ThemePresets.qml`. Each preset is a JavaScript object with the full Material 3 color token set.

The easiest way to create a custom preset is to copy an existing one and modify the colors. The token names follow the Material 3 specification.
