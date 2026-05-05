# Config System

How configuration works in iNiR, from the user's perspective and from the code side.

## For users

Everything is configurable through the graphical Settings UI. Open it with `Super+,` or `inir settings`. You should never need to edit the config file by hand.

If you do want to edit it directly, it lives at:

```
~/.config/illogical-impulse/config.json
```

(The directory name is a legacy artifact from when iNiR was called illogical-impulse. `~/.config/inir` is symlinked to it.)

Changes you make in the file are picked up automatically within 50ms. No restart needed.

## For contributors

### The sync rule

Adding a new config key requires updating four things together in one commit:

1. **`modules/common/Config.qml`** - declare the schema property with its type and default
2. **`defaults/config.json`** - add the matching key for fresh installs
3. **Consumer code** - the QML that reads or writes the key
4. **Settings UI** - if the key is user-facing (most are)

Skip any of these and something breaks silently. The most common mistake is skipping Config.qml, which means `Config.options?.your?.key` resolves to `undefined` even though the key exists in defaults.

### Reading config

Always null-safe, always with a fallback:

```qml
// Standard pattern
readonly property bool enabled: Config.options?.bar?.autoHide?.enable ?? false
readonly property int interval: Config.options?.weather?.interval ?? 15

// Also fine (optional chaining is harmless even when the path exists)
readonly property string city: Config.options?.weather?.city ?? ""
```

Config properties are available after `Config.ready` becomes true. Everything that depends on config should gate on this.

### Writing config

There is exactly one way to write config that actually persists:

```qml
// This works
Config.setNestedValue("bar.autoHide.enable", true)

// This does NOT work (silently fails to persist)
Config.options.bar.autoHide.enable = true
```

The direct assignment updates the in-memory QML property but never writes to disk. This is the number one source of config bugs. If you see `Config.options.x.y = z` anywhere, it's a bug.

### Schema

`Config.qml` is a 1385+ line singleton that defines every config section as typed QML properties. Example:

```qml
readonly property QtObject bar: QtObject {
    readonly property bool vertical: root._config?.bar?.vertical ?? false
    readonly property QtObject autoHide: QtObject {
        readonly property bool enable: root._config?.bar?.autoHide?.enable ?? false
        readonly property int showDelay: root._config?.bar?.autoHide?.showDelay ?? 300
    }
}
```

The schema serves three purposes:

1. **Type safety**: properties are typed (`bool`, `int`, `string`, `list`), not `var`
2. **Default values**: the `?? fallback` provides a runtime default even if the key is missing
3. **Documentation**: the schema IS the config reference

### Defaults

`defaults/config.json` provides the starting config for fresh installs. It currently has 1100+ lines covering 51 top-level sections.

The defaults file and Config.qml can have different fallback values by design. The defaults file is what gets written to disk on first install. The schema fallbacks are what the code uses if a key is missing at runtime.

### Hot-reload

Config uses Quickshell's `FileView` with `watchChanges: true`. External edits (from a text editor, a script, whatever) are detected and applied within 50ms. Both reads and writes are debounced at 50ms.

### The configChanged signal

After `setNestedValue` writes to disk, `Config.configChanged()` fires. Components that need to react to config changes (beyond just re-reading a property) can connect to this signal.

## Config sections

The 51 top-level sections, roughly grouped:

**Shell structure**: `panelFamily`, `enabledPanels`, `bar`, `dock`, `sidebar`

**Appearance**: `appearance` (colors, rounding, style, animations), `background` (wallpaper, blur, widgets)

**Services**: `weather`, `ai`, `calendar`, `search`, `updates`

**System**: `battery`, `performance`, `lock`, `session`, `idle`

**Features**: `notifications`, `clipboard`, `screenRecord`, `nightLight`, `gameMode`

**Waffle-specific**: `waffles` (the entire waffle family config namespace)

The full schema is `modules/common/Config.qml`. The full defaults are `defaults/config.json`.

## Settings UI

Users interact with config exclusively through Settings:

- **Material ii**: `Super+,` opens an overlay settings panel (lives in `modules/settings/`)
- **Waffle**: `Super+,` opens a standalone settings window (lives in `modules/waffle/settings/`)

Both families have their own settings implementations but write to the same config.json. When a config key affects both families, both settings UIs need updating.

## Migrations

When a config key is renamed, restructured, or its semantics change in a way that affects existing users, a migration handles the transition. Migrations live in `sdata/migrations/` as numbered bash scripts.

Most config additions don't need migrations. A new key with a default just appears in the schema and existing users get the default value. Migrations are only for breaking changes to existing keys.
