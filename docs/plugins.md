# Writing a Ryoku shell plugin

A plugin is a small widget you write that the **user** drops into the Ryoku
desktop. You write the *content and the logic*. **Ryoku owns everything about how
it looks, moves, sizes, and where it lives.** That split is the whole point: a
plugin always looks and behaves like a native part of the shell, because the
shell - not you - draws the surface around it.

If you only read one thing, read **"Who does what"** below.

---

## Who does what

| You (the contributor) write... | Ryoku (the shell) handles for you... |
|---|---|
| The **logic**: fetch data, hold state, run commands (`service/Main.qml`). | **Where the widget lives** (frame popout, desktop widget) and letting the user choose and move it. |
| **One view** of your widget (`content/Widget.qml`) - the labels, buttons, grid, etc. | The **card / popout surface** behind your view: background, rounded corners, shadow, hairline. |
| A small **manifest** describing your plugin and its defaults. | **Dragging, resizing, the right-click menu, hover-to-open** - all the interaction. |
| A **settings schema** in your manifest (`metadata.settings`). | **Sizing**: the popout grows to fit your content; the desktop tile scales as the user resizes it. |
| Optionally, **shipped scripts/binaries** (`bin/`). | **Theming, motion, the brand look** (the "deck dialect"), so you match the shell automatically. |

**The golden rule:** never set your own position, never draw your own window
chrome, never assume your size. You declare *how big your content naturally
wants to be*; Ryoku does the rest. Break this rule and your plugin will look
bolted-on instead of native.

---

## Files you ship

```
<your-plugin-id>/
  manifest.json        what your plugin is + its suggested defaults   (required)
  service/Main.qml     persistent logic and state, no UI               (required)
  content/Widget.qml   ONE view of your widget                          (required)
  bin/                 scripts or binaries your plugin runs            (optional)
  README.md            what it is + a preview.gif                      (recommended)
```

- **Installed** to `~/.local/share/ryoku/plugins/<id>/`.
- **For local dev**, point `RYOKU_PLUGINS_DIR` at a folder of plugins (colon-
  separated for several) and the dev shell discovers them live.

---

## The two hosts a user can choose

When a user enables your plugin they pick **one** of these in Ryoku Settings →
Plugins. Your *same* `content/Widget.qml` is used for both - Ryoku just renders
it differently.

### 1. Desktop widget - a tile on the wallpaper

It sits on the wallpaper next to the clock and weather, and behaves **exactly
like them**, because Ryoku gives it the identical machinery:

- **Left-drag** to move it anywhere (snaps to a grid).
- **Right-click** it for its menu (Lock to freeze it, Hide to turn it off).
- **Drag the bottom-right corner** to resize (scales 50%–250%, live).
- It's drawn on a **card** (rounded, translucent, soft shadow) matching the
  clock/weather.

**You do nothing to get any of that.** You just write the content; Ryoku wraps it
in the draggable, resizable, right-clickable card. The only thing you owe it: a
content root that reports its natural size (see "Sizing" below), so the card can
size itself around you.

### 2. Frame popout - grows out of the screen edge

It melts out of the frame border on hover (like the volume mixer and power
menu), fused into the same blob. The user picks which **edge** (top / right /
bottom / left) and which **end** of that edge (the centre of each edge is
reserved for the shell's own island/mixer/power, so you can't dock there).

- Ryoku handles the **hover trigger, the open/close animation, and the fuse into
  the frame**.
- The popout **grows to fit your content** - it's exactly as tall as your view
  needs, with even padding. You never set the popout's width or height.

`ryoku-shell plugin <id>` toggles your frame popout open (bind it to a key).

> Island, topbar-glyph, and window hosts are planned but not built yet. Declare
> only `framePopout` and `desktopWidget` in your manifest today.

---

## Writing `content/Widget.qml`

This is your view. Ryoku sets a few properties on its root **for you to read** -
**never assign them**:

| Property Ryoku sets | What it means | What you do with it |
|---|---|---|
| `pluginApi` | handle to your service + settings + folder | read `pluginApi.mainInstance` for your live `service/Main.qml` |
| `density` | `"glyph"`, `"compact"`, or `"full"` | lay out smaller/larger for the space you're given |
| `widthBudget` | the width you have to lay out within | size your content to this width, not to the screen |
| `active` | true while your widget is open/visible | start/stop work (e.g. don't poll when hidden) |
| `screen` | the monitor this copy is on | usually ignore it |

### Sizing - the one thing you MUST get right

**Declare your content's natural size; never hardcode geometry.** Ryoku reads
your root's `implicitWidth` / `implicitHeight` to size the card or grow the
popout. If you don't report a size, your widget collapses to nothing.

```qml
import QtQuick
import Ryoku.PluginKit          // the deck kit: Theme, Motion, Card, etc.

Item {
    id: root

    // Ryoku sets these; you only read them.
    property var pluginApi
    property string density: "full"
    property real widthBudget: 0
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null

    // Pick ONE content width from the budget, and lay everything out from it.
    readonly property real contentW: widthBudget > 0 ? widthBudget : 360

    // Report your natural size so the host can size its surface around you.
    implicitWidth: contentW
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: root.contentW          // bind children to contentW, NOT parent.width
        spacing: 12
        // ... your eyebrow, search, list, grid ...
    }
}
```

Rules that keep it native:
- **Bind children to your own `contentW`**, never to `parent.width` through
  nested layouts (that leaves width-derived heights at zero and your widget
  collapses).
- **Reflow with `Column` / `Row` / `Grid` / `Flow`** so you adapt to the width
  Ryoku gives you. Don't position with absolute `x`/`y`.
- **Three densities**: `glyph` = an icon (+ optional badge); `compact` = a small
  summary; `full` = the rich panel. Lay out for whichever `density` you're handed.

---

## Styling - use the kit, match the shell

Your runtime content imports the **deck kit** so it looks like the rest of the
shell automatically:

```qml
import Ryoku.PluginKit            // Theme, Motion, GlyphIcon, MicroLabel,
                                  // SearchField, Card, CornerTicks, WaveMeter
```

Use `Theme` colors and `Motion` curves - mono eyebrows, hairline dividers, the
brand accent, the project's morph timing. **Don't hardcode colors**; read them
from `Theme`. The brand orange is the one fixed accent - use it sparingly.

Your **settings are not QML** - you declare them as a `metadata.settings` schema
in the manifest (below) and Ryoku renders native controls for them, both in
Ryoku Settings and in the desktop widget's right-click menu.

---

## `service/Main.qml` - your logic

A non-visual `QtObject`/`Item` that holds state and does the work (HTTP, running
your `bin/` scripts, parsing results). Ryoku keeps one instance alive and hands
it to your content as `pluginApi.mainInstance`.
Declare user options as a `metadata.settings` schema in your manifest (below).
Ryoku renders the controls, seeds your defaults on install, and persists changes
to `plugins.json`; read the live values from `pluginApi.pluginSettings`.

---

## `manifest.json`

```json
{
  "id": "your-plugin",
  "name": "Your Plugin",
  "version": "1.0.0",
  "author": "You <you@example.com>",
  "description": "One sentence describing it.",
  "license": "MIT",
  "official": false,
  "entryPoints": {
    "main": "service/Main.qml",
    "content": "content/Widget.qml"
  },
  "files": ["content/Helper.qml", "assets/example.jpg"],
  "capabilities": { "densities": ["compact", "full"] },
  "hosts": ["framePopout", "desktopWidget"],
  "defaults": {
    "host": "framePopout",
    "framePopout": { "edge": "top", "align": "end" },
    "key": "p",
    "icon": "image",
    "label": "Your Plugin"
  },
  "commands": ["bin/your-tool"],
  "dependencies": { "commands": ["curl", "jq"] },
  "metadata": {
    "settings": [
      { "key": "imagePath", "type": "image",  "label": "Image", "group": "Photo", "default": "" },
      { "key": "style", "type": "choice", "label": "Style", "group": "Photo", "default": "rounded",
        "options": [ { "value": "rounded", "label": "Rounded" }, { "value": "polaroid", "label": "Polaroid" } ] },
      { "key": "shadowEnabled", "type": "toggle", "label": "Drop shadow", "group": "Shadow", "default": true },
      { "key": "shadowBlur", "type": "slider", "label": "Blur", "group": "Shadow", "default": 0.5, "min": 0, "max": 1, "step": 0.01 }
    ]
  }
}
```

- `hosts` - declare **only the hosts you actually support and have tested**
  (today: `framePopout`, `desktopWidget`). Don't list hosts that don't work.
- `defaults` - *suggestions*. The user's choices in Settings always win. For
  `framePopout`, prefer `align: "start"` or `"end"` (never `"center"` - that's
  reserved).
- `official` - leave `false`. Only first-party Ryoku plugins set `true`.
- `files` - any extra files the plugin ships beyond its entry points and
  `commands` (helper QML a view imports, images, data). Install fetches the entry
  points, `commands`, `README.md`, and everything listed here; a file you forget
  to list is simply missing on install, so the plugin can fail to render.

---

## Install, enable, place

- **Install**: drop your folder in `~/.local/share/ryoku/plugins/<id>/`, or ship
  it through an `ryoku-extras` bundle (`ryoku-extras-install` fetches the source).
- **Enable & place**: Ryoku Settings → Plugins. The user toggles it on, picks a
  host, and (for a frame popout) the edge. Placement saves to
  `~/.config/ryoku/plugins.json`; the shell watches that file and retunes live -
  no restart.
- **Desktop widgets** are then moved/resized/hidden directly on the wallpaper
  (drag, corner-resize, right-click) - not from Settings.

---

## Gotcha: images in grid/list delegates

An `Image` inside an inline QML `component` used as a delegate **loads but never
paints** in Quickshell (a scene-graph quirk). Put image/thumbnail delegates
inline - a plain `Rectangle { Image {} }` - or in their own `.qml` file, **not**
inside an inline `component { ... }`. See `wallhaven`'s grid for the working
pattern.

---

For the full design and rationale, see
`docs/superpowers/specs/2026-06-24-shell-plugin-widgets-design.md`.
