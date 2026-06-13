# end-4 (illogical-impulse) quickshell: architecture, process model, matugen, live-apply

Base: `~/Work/dots-hyprland/dots/.config/quickshell/ii` (= `$qsConfig`, "ii"). SAME stack as ryoku (QML + quickshell). Everything below is directly transferable.

---

## 1. Launch / run model: ONE quickshell process

- Hyprland starts the shell **once** via a `hyprland.start` hook (not systemd, not per-widget):
  - `hl.exec_cmd("qs -c $qsConfig")`, `dots/.config/hypr/hyprland/execs.lua:6`, with `qsConfig="ii"` set at `dots/.config/hypr/hyprland/variables.lua:5`.
- Single root: `shell.qml:19` `ShellRoot { ... }`. All surfaces are children of this ONE process; there is no second shell process. `//@ pragma UseQApplication` (`shell.qml:1`) widgets+OSD in one binary.
- The Settings GUI is a **separate** quickshell instance launched on demand: `qs -p ~/.config/quickshell/$qsConfig/settings.qml` (`variables.lua:16`); `settings.qml:19` is an `ApplicationWindow`, NOT part of the bar process. It edits the same JSON file and the bar reacts via file-watch (see §3).
- IPC/CLI dispatch into the running process: `qs -c $qsConfig ipc call <target> <fn>` (`keybinds.lua:9`), e.g. cliphist updates `qs -c $qsConfig ipc call cliphistService update` (`execs.lua:20-21`). Hyprland global shortcuts route via `GlobalShortcut`/`hl.dsp.global("quickshell:...")` (`keybinds.lua:12-34`, handlers e.g. `GlobalStates.qml:41`, `shell.qml:70`).
- One process, many windows: `shell.qml:44-58` gates whole "panel families" behind `LazyLoader { active: Config.ready && Config.options.panelFamily === identifier }`; the active family (`IllogicalImpulseFamily.qml`) instantiates every surface through `PanelLoader` (`IllogicalImpulseFamily.qml:26-47`).

**Portable:** ryoku should keep a single `qs -c ryoku` exec-once + one `ShellRoot`, and run its settings GUI as a separate `qs -p` window that writes the same JSON. Lazy-load surfaces behind `Config.ready`.

---

## 2. Background processes: exec churn control

- **Long-lived subscribers**, not polling. Network uses one persistent `nmcli monitor` whose stdout triggers refreshes: `services/Network.qml:163-170` `Process { running: true; command: ["nmcli","monitor"]; stdout: SplitParser { onRead: root.update() } }`. Only on an event does it spawn short queries (`update()` at `Network.qml:156-161`).
- **Short CLI calls** use `Quickshell.Io` `Process` with `.exec([...])` and parse via `SplitParser` (line stream) or `StdioCollector` (whole output): `Network.qml:99-153`, `:252-257`. Env pinned `LANG=C/LC_ALL=C` for stable parsing (`Network.qml:105-108`).
- **Fire-and-forget** OS actions use `Quickshell.execDetached([...])` (no QML object kept), e.g. `Directories.qml:56-64` mkdir/cleanup, `MaterialThemeLoader.qml:78` wallpaper script.
- Startup work is centralized once in `shell.qml:25-33` `Component.onCompleted` (theme reapply, Hyprsunset, Cliphist.refresh, Wallpapers.load…) rather than scattered timers.
- **Reload UX** (`ReloadPopup.qml`): listens to the Quickshell global reload signals, `Connections { target: Quickshell; onReloadCompleted/onReloadFailed }` (`ReloadPopup.qml:13-29`), and shows a transient toast with a countdown bar (`:113-126`), pause-on-hover (`:125`). Popup body is in a `LazyLoader` so it costs nothing when idle (`:32`). Note `shell.qml:2` sets `QS_NO_RELOAD_POPUP=1`; quickshell hot-reloads QML in place on file save (dev loop), no manual restart.

**Portable:** prefer one persistent subscriber process per service (`nmcli monitor`, `pactl subscribe`, etc.) that gates cheap refresh queries; use `execDetached` for stateless actions; keep a single `Component.onCompleted` init block; copy `ReloadPopup` verbatim for "did my change apply?" feedback.

---

## 3. Config singleton: JSON-backed, live via FileView + JsonAdapter

The whole live-apply story is two quickshell primitives: **`FileView` (watchChanges) + `JsonAdapter`**.

- `modules/common/Config.qml:8` `Singleton`, exposed as `Config.options` (`:11` `property alias options: configOptionsJsonAdapter`) and a `Config.ready` gate (`:12`, set true `onLoaded` `:71`).
- Backing file: `Config.qml:10` `filePath: Directories.shellConfigPath` → `~/.config/illogical-impulse/config.json` (`Directories.qml:33-35`).
- The schema IS the adapter: one giant nested `JsonAdapter { ... }` of typed `JsonObject`/`property` defaults (`Config.qml:78-631`, e.g. transparency block `:119-124`, bar block `:226-285`). Defaults live in code; missing keys are auto-written.
- **Two-way live binding** (`Config.qml:64-76`):
```
FileView {
    id: configFileView
    path: root.filePath
    watchChanges: true
    onFileChanged: fileReloadTimer.restart()      // external edit -> reload
    onAdapterUpdated: fileWriteTimer.restart()     // UI changed a prop -> write
    onLoaded: root.ready = true
    onLoadFailed: e => { if (e==FileViewError.FileNotFound) writeAdapter() }
}
```
  - Debounced through `readWriteDelay` timers (`Config.qml:13,46-62`) to coalesce bursts and avoid read/write feedback loops; settings app drops the delay to 0 (`settings.qml:76`).
- **Read path a widget uses**, plain property bindings, no glue. A surface reads `Config.options.bar.vertical` (`IllogicalImpulseFamily.qml:45`); `Appearance.qml:34` reads `Config.options.appearance.transparency.*`. When the JSON changes, FileView mutates the adapter properties → all bindings re-evaluate → UI updates instantly.
- **Write path**, settings widgets assign directly: `QuickConfig.qml:224` `Config.options.appearance.transparency.enable = checked`, `:239-240` bar position. That mutation fires `onAdapterUpdated` → debounced `writeAdapter()` → file → (the bar process's own FileView watch) → re-read → re-bind. So the standalone settings process and the bar process stay in sync purely through the file.
- A nested string-path setter exists for generic settings widgets: `Config.qml:16-44` `setNestedValue("a.b.c", v)` with JSON type coercion.
- Same pattern reused for ephemeral state: `Persistent.qml` (`states.json`, `Persistent.states.*`) is an identical FileView+JsonAdapter+debounce-timer singleton (`Persistent.qml:41-162`) for window positions, tab indices, pomodoro, etc.

**Portable (highest value):** ryoku already has a C++ `Ryoku.Config`/`GlobalConfig` persisted to `shell.json`. The end-4 lesson is the **live-apply loop**: back the config with `FileView{ watchChanges:true }` + `JsonAdapter` (or make the C++ singleton emit property-changed on file change) so every widget binds `Config.options.x` directly and updates with zero imperative refresh code. If a slider "doesn't feel like it does much," it is almost always because the consuming widget reads a snapshot instead of a live binding to the singleton, copy this exact FileView/JsonAdapter/debounce-timer trio.

---

## 4. Color pipeline: wallpaper → matugen → JSON → Appearance singleton → whole desktop

Flow when wallpaper/mode/accent changes (entry: `scripts/colors/switchwall.sh`, invoked by UI or `MaterialThemeLoader.toggleLightDark` `MaterialThemeLoader.qml:78`):

1. **Pick source & scheme** (`switchwall.sh:319-471 main`): resolves image vs accent color, auto-detects M3 scheme type from the image via `scheme_for_image.py` (`:338-343,424-445`), writes `background.wallpaperPath` back into config.json with jq (`:144-148`).
2. **Run matugen** (`switchwall.sh:306`) `matugen "${matugen_args[@]}"`. matugen renders ALL templates from `~/.config/matugen/config.toml`:
   - `[templates.m3colors]` → `~/.local/state/quickshell/user/generated/colors.json` (`matugen/config.toml:4-6`), the file the QML shell reads.
   - `[templates.hyprland]`/`hyprlock`, `[templates.fuzzel]`, `[templates.gtk3]`→`~/.config/gtk-3.0/gtk.css`, `[templates.gtk4]`, `[templates.kde_colors]`→`color.txt`, `[templates.wallpaper]` (`config.toml:8-35`). One matugen run themes hypr, GTK3/4, fuzzel, kde, terminal in lockstep.
3. **Extra terminal/scss** (`switchwall.sh:308-311`): a python generator writes `material_colors.scss`, then `applycolor.sh` live-pushes terminal colors: copies `kitty-theme.conf`/`sequences.txt`, sed-substitutes colors, then `kill -SIGUSR1 $(pidof kitty)` to live-reload kitty (`applycolor.sh:30-79`) and cats escape sequences to every `/dev/pts/*` (`:67-73`). Gated by `appearance.wallpaperTheming.enableTerminal` (`applycolor.sh:82-91`).
4. **Qt/KDE apps** (`switchwall.sh:53-60 post_process` → `handle_kde_material_you_colors` `:15-34`): runs `kde-material-you-colors-wrapper.sh`, which reads `color.txt` and calls `kde-material-you-colors -d/-l --color <hex> -sv <n>` (`kde-material-you-colors-wrapper.sh:5,46-47`) → writes `kdeglobals` + Kvantum so native Qt/KDE apps recolor. Gated by `enableQtApps` (`switchwall.sh:17-22`). GTK light/dark + adw-gtk3 theme set via gsettings in `pre_process` (`switchwall.sh:40-46`).
5. **Live-apply into the running shell**, `services/MaterialThemeLoader.qml`:
   - Watches the generated JSON: `FileView{ path: Directories.generatedMaterialThemePath; watchChanges:true; onFileChanged: { reload(); delayedFileRead.start() } }` (`MaterialThemeLoader.qml:61-74`); `generatedMaterialThemePath = .../generated/colors.json` (`Directories.qml:40`).
   - `applyColors()` parses JSON, snake_case→`m3<Camel>` keys, and assigns onto the color singleton: `Appearance.m3colors[m3Key] = json[key]` (`MaterialThemeLoader.qml:22-31`); derives dark mode from background lightness (`:33`).
   - A small `arbitraryRaceConditionDelay` timer (default 100ms) avoids reading a half-written file (`MaterialThemeLoader.qml:51-59`). Must `reapplyTheme()` at startup because singletons are lazy (`shell.qml:26`, comment `MaterialThemeLoader.qml:10-13`).
6. **Consumption**, `modules/common/Appearance.qml` is the single color/typography/animation singleton. `m3colors` holds raw M3 tokens (`Appearance.qml:37-109`); `colors` derives semantic layered tokens (`colLayer0..4`, hover/active, primary/secondary…) via `ColorUtils.mix/solveOverlayColor/transparentize` (`:111-199`). Widgets bind `Appearance.colors.colOnLayer0` etc. (e.g. `settings.qml:125`). Because step 5 mutates `m3colors`, all derived bindings recompute → whole shell recolors instantly with no reload.

**Transparency** is folded into the same singleton: `Appearance.qml:34-35` reads `Config.options.appearance.transparency.*`; auto mode computes alpha from wallpaper vibrancy via a `ColorQuantizer` of the wallpaper (`:19-32`). Every layer color is `transparentize(..., backgroundTransparency)` / `solveOverlayColor(..., 1-contentTransparency)` (`:114-179`), so toggling the slider re-derives every surface live.

**Portable:** adopt matugen + a `config.toml` that fans out to colors.json (shell), gtk.css, kde/kvantum, terminal, hypr in ONE run; have a `MaterialThemeLoader`-style singleton `FileView`-watch the generated JSON and assign into a `Colours` singleton; build all UI colors as *derived bindings* off that singleton so wallpaper/transparency changes propagate with zero imperative repaint. Use `kde-material-you-colors` for native Qt theming and `SIGUSR1`/pts escape sequences for live terminal recolor.

---

## Directly portable to ryoku (same stack: copy these)

| Pattern | end-4 location | Why ryoku needs it |
|---|---|---|
| **Live config loop**: `FileView{watchChanges:true}` + `JsonAdapter` + debounced read/write timers, exposed as `Config.options.*` + `Config.ready` | `Config.qml:10-76` | Makes EVERY setting live with zero glue; fixes "sliders don't do anything" (consumers must bind to the singleton, not snapshot it). |
| **Standalone settings as separate `qs -p` process** writing the same JSON | `settings.qml`, `variables.lua:16`, write at `QuickConfig.qml:224` | Decouples settings UI from bar; both sync through the file watch. |
| **Single color/type/anim singleton** with raw `m3colors` + derived semantic `colors` (layered tokens, hover/active) | `Appearance.qml:37-199` | One source of truth; transparency + theme changes recompute everything via bindings. |
| **`MaterialThemeLoader`**: watch generated `colors.json`, parse, assign into singleton, race-delay timer, `reapplyTheme()` at startup | `MaterialThemeLoader.qml` (whole) | The mechanism that live-applies wallpaper colors without restart. |
| **matugen `config.toml` fan-out** (shell JSON + gtk3/4 + kde + fuzzel + hypr + terminal) in one run | `matugen/config.toml:4-35` | Native GTK/Qt/terminal theming, not just the shell. |
| **Native Qt theming** via `kde-material-you-colors` writing kdeglobals/Kvantum | `kde-material-you-colors-wrapper.sh:46-47` | Makes Qt/KDE apps feel native with the shell. |
| **Live terminal recolor**: template + sed + `SIGUSR1`/pts escape sequences | `applycolor.sh:30-79` | Instant terminal theme without relaunch. |
| **Persistent ephemeral state** singleton (identical FileView+JsonAdapter) for window/tab positions | `Persistent.qml` (whole) | Clean separation of user prefs vs runtime state. |
| **`ReloadPopup`** toast on Quickshell reload signals | `ReloadPopup.qml:13-29` | Visible confirmation that changes applied. |
| **Long-lived subscriber Processes** (`nmcli monitor`) gating cheap refresh queries; `execDetached` for fire-and-forget | `Network.qml:163-170`; `Directories.qml:56-64` | Reduces subprocess churn / jank. |
| **Hyprland `layer_rule` blur/animation per `quickshell:<ns>` namespace** | `hypr/.../rules.lua:132-151` | Native-feeling blur + per-surface enter/exit animations come from the compositor, not QML. |
| **LazyLoader-gated panel families/surfaces** behind `Config.ready` | `shell.qml:44-58`, `IllogicalImpulseFamily.qml:26-47` | Cheap startup, swappable layouts. |
| **Animation curve library** (M3 expressive/emphasized beziers + durations) on the singleton | `Appearance.qml:251-268` | Reusable, consistent "smooth" motion tokens. |

### Note on "native blur/animation"
end-4 does NOT render blur in QML. It tags every surface with a `WlrLayershell.namespace: "quickshell:<x>"` and lets Hyprland apply blur + slide/fade/popin per namespace: `rules.lua:132-151` (`blur`, `blur_popups`, `animation = "slide"/"fade"/"popin 120%"`, `ignore_alpha`). This is the cheapest path to a native feel and ryoku can adopt it by matching namespaces to hypr layer rules.
