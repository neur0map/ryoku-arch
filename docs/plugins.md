# Shell plugins

A plugin is a third-party shell widget the **user** places where they like, while
the **shell** owns how it looks and moves. You ship a service and one adaptive
view; the user picks a host (a frame popout, a desktop widget, ...) in Ryoku
Settings. The shell renders your content in its own material and motion, so a
plugin always reads as part of the desktop, never a panel bolted on.

See `docs/superpowers/specs/2026-06-24-shell-plugin-widgets-design.md` for the
full design and rationale. This is the working reference.

## Layout

```
plugins/<id>/
  manifest.json        capabilities + proposed defaults
  service/Main.qml     persistent, non-visual logic/state (the "main")
  content/Widget.qml   ONE adaptive view, rendered at a host-chosen density
  settings/Page.qml    options page, in the hub dialect (optional)
  bin/                 shipped executables (optional)
```

Installed under `~/.local/share/ryoku/plugins/<id>/`. In a checkout, point
`RYOKU_PLUGINS_DIR` at a dir of plugins for the dev loop.

## The contract

`content/Widget.qml` is one view that renders at three densities; the host sets
which:

- `glyph`   icon (+ badge): topbar glyph, collapsed island.
- `compact` a summary card: island, narrow popout, small desktop tile.
- `full`    the rich panel: frame popout, window, large desktop tile.

The host sets these on your content root; read them, never assign:

| Property | Meaning |
|---|---|
| `pluginApi` | handle to your service, settings, and dir |
| `screen` | the screen this instance is on |
| `density` | `"glyph"` \| `"compact"` \| `"full"` |
| `active` | true while the host is open/visible |
| `widthBudget` | the width to lay out within |

Never assume your size or position. Declare intrinsic `implicitWidth`/
`implicitHeight` per density and reflow with Layouts inside `widthBudget`. The
host owns geometry, motion, the input region, and the trigger.

`pluginApi`: `mainInstance` (your live service), `pluginSettings` (seeded from
`manifest.metadata.defaultSettings`), `saveSettings()`, `pluginDir`.

## Styling: two dialects

- **Runtime content** uses the deck kit, shipped as the `Ryoku.PluginKit` QML
  module (`import Ryoku.PluginKit`): `Theme`, `Motion`, `GlyphIcon`,
  `MicroLabel`, `SearchField`, `Card`, `CornerTicks`, `WaveMeter`,
  `PluginSurface`. Match the control deck: mono eyebrows, hairline dividers,
  vermilion accents, the project morph curve.
- **The settings page** uses the hub dialect (it loads inside Ryoku Settings):
  the hub `Theme` and section/row idioms.

## manifest.json

```json
{
  "id": "wallhaven",
  "name": "Wallhaven",
  "version": "2.0.0",
  "author": "You <you@example.com>",
  "description": "One sentence.",
  "license": "MIT",
  "official": false,
  "entryPoints": { "main": "service/Main.qml", "content": "content/Widget.qml", "settings": "settings/Page.qml" },
  "capabilities": { "densities": ["glyph", "compact", "full"] },
  "hosts": ["framePopout", "desktopWidget"],
  "defaults": { "host": "framePopout", "framePopout": { "edge": "right", "align": "center" }, "key": "w", "icon": "image" },
  "commands": ["bin/your-tool"],
  "dependencies": { "commands": ["curl", "jq"] },
  "metadata": { "defaultSettings": { "apiKey": "" } }
}
```

`defaults.*` are proposals; the user's choices in Settings always win.

## Hosts

| User intent | Host | Layer |
|---|---|---|
| hover to open on the frame | `framePopout` | pill blob field (fuses the frame) |
| a widget on the wallpaper | `desktopWidget` | `WlrLayer.Bottom`, draggable |
| a small island | `island` | island blob group (fast-follow) |
| a topbar icon | `topbarGlyph` | the bar (fast-follow) |
| a keybind window | `window` | centered surface (fast-follow) |

Frame-fusing hosts (`framePopout`, `island`) render in the pill process because
the blob field is per-process; independent layers (`desktopWidget`, `window`)
live in the `plugins` config.

## Install, enable, place

- Catalogue install: `ryoku-extras` bundles may list `plugin` items;
  `ryoku-extras-install` fetches the source into the data dir.
- Enable and place: Ryoku Settings -> Plugins. Placement persists to
  `~/.config/ryoku/plugins.json`; the runtime watches it and retunes live.
- Keybind / leader: `ryoku-shell plugin <id>` toggles a frame popout.

## Gotcha: images in delegates

An `Image` inside an inline QML `component` used as a list/grid delegate does not
composite its texture in Quickshell (it loads `Ready` but paints nothing). Put
thumbnail/image delegates inline (a plain `Rectangle { Image {} }` delegate) or
in a separate `.qml` file, not an inline `component`. See `wallhaven`'s grid.
