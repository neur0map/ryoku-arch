# Noctalia: Settings UI, Propagation, Transparency & Theme

Scope: `~/Work/noctalia-shell/src`, settings UI, config propagation, the opacity/transparency control, and the Material-You theme system. Every claim cited `path:line`.

---

## 1. Settings UI architecture

**Same process, separate xdg-toplevel surface.** The settings UI is NOT a separate app. It is a class living in the shell binary that owns its own `ToplevelSurface` and scene graph, sharing the shell's `RenderContext`:

> `shell/settings/settings_window.h:46`, `// Standalone xdg-toplevel settings UI (same binary as the shell; shares RenderContext).`

It is initialized with pointers to the live `ConfigService`, `RenderContext`, etc. (`settings_window.h:51-54`) and is a member of `Application` alongside the bar/panels (`app/application.h` wires `m_settingsWindow`). It builds a `Node` tree (`m_sceneRoot`, `settings_window.h:170`) with its own `AnimationManager` (`:168`) and an `InputDispatcher` (`:184`). Because it holds a direct pointer to the same `ConfigService` the shell reads from, an edit mutates shared state both surfaces observe, no socket, no second process.

**How a control binds to a config field.** Each setting is a `SettingEntry` carrying a config **path** (`std::vector<std::string>`, e.g. `{"shell","panel","transparency_mode"}`) plus a control descriptor variant (`SliderSetting`, enum-select, bool, color…). Registration example:

> `shell/settings/settings_registry.cpp:916-918`
> ```
> tr("...transparency-mode.description"), {"shell","panel","transparency_mode"},
> asSegmented(enumSelect(kPanelTransparencyModes, cfg.shell.panel.transparencyMode)),
> "glass opacity alpha translucent cards blur"
> ```

`SettingsControlFactory` turns each descriptor into a scene-graph control and wires its callback to the path. The bar background-opacity slider: `settings_registry.cpp:2214-2215` → `SliderSetting{bar.backgroundOpacity, 0.0f, 1.0f, 0.01f, false}`.

**Per-widget settings (`widget_settings_registry`)** split a setting into two halves: the **schema** (`WidgetSettingField`: key/type/default/range/enumValues, the single source the config layer validates against) and a UI-only **presentation overlay** (`WidgetSettingSpec`: control kind, labels, visibility):

> `shell/settings/widget_settings_registry.h:95-113`, `struct WidgetSettingSpec { noctalia::config::schema::WidgetSettingField schema; WidgetControlKind control; … }`

`WidgetControlKind` (Bool/Int/Double/String/Select/ColorSpec…, `:50-63`) selects the rendered control; the schema key path is the config target. Scripted widgets get their specs from a Lua manifest (`:131-134`).

---

## 2. Propagation: how a setting reaches the live shell

**In-app edits are direct in-process, synchronous, NOT IPC, NOT file-watch.** A control's commit calls `SettingsWindow::setSettingOverride` (`settings_window_mutations.cpp:32`), which defers one tick then calls `m_config->setOverride(path,value)` (`:40`). `ConfigService::setOverride` → `setOverrides` (`config_overrides.cpp:1185-1238`) does, in order:

1. Merge the new value into the in-memory overrides table (`:1196-1211`).
2. `writeOverridesToFile()` → atomic TOML write for **persistence** (`:1228`, `config_overrides.cpp:1858-1869`, `writeTextFileAtomic`).
3. Set `m_ownOverridesWritePending = true` (`:1234`) so the inotify echo of our own write is ignored.
4. **`loadAll()` then `fireReloadCallbacks()` synchronously** (`:1236-1237`).

So the live update does NOT wait for the filesystem watcher; the file write is only for durability. `fireReloadCallbacks` (`config_service.cpp:509-514`) invokes every registered `ReloadSubscriber` (`config_service.h:199-203`). Subscribers consult `lastChange()` (a `ConfigChangeSet`, `config_service.h:48`) to skip unaffected work, e.g. the bar callback early-returns unless bars/widgets/shadow changed: `bar.cpp:878-887` → `if (cfg.bars==m_lastBars && …) return; reload();`.

**External edits (hand-edited TOML, CLI `noctalia config`) go through inotify.** A single inotify fd (`config_service.h:184`) watches the config dir + state dir. It is registered into the main `poll()` loop as a `PollSource`:

> `config/config_poll_source.h:10-20`, adds `m_config.watchFd()` with `POLLIN`; on `POLLIN` calls `m_config.checkReload()`.

`checkReload` (`config_service.cpp:749-832`) drains events, skips the self-write echo (`:802-805`), and on a real change runs `loadOverridesFromFile()`/`loadAll()` + `fireReloadCallbacks()` (`:814-831`). The CLI `config-reload` IPC handler just calls `forceReload()` (`config_service.cpp:1475-1478`).

**Latency / restart.** In-app edits: the new value is parsed and all surfaces re-rendered within the same frame/event-loop turn after the deferred call, effectively instant, no restart. External edits: one `poll()` wakeup after the kernel delivers the inotify event, sub-frame. **No setting in this path requires a restart**; the reload rebuilds `Config` and re-runs subscriber callbacks that re-apply styles and request redraws.

> **Answer to "is everything IPC?": No.** IPC exists only for CLI/scripts. The settings GUI mutates the same in-process `ConfigService` and triggers a synchronous reload→re-render. The TOML file is the persistence + external-edit channel, not the live-update channel.

---

## 3. Transparency / opacity: control → config → pixels

Two independent controls:

**(a) Per-surface `background_opacity` sliders** (bar, dock, OSD, notifications). Slider commit is on **drag-end**, not per-frame:

> `settings_control_factory.cpp:362`, `slider->setOnDragEnd([commit, sliderPtr]() { commit(sliderPtr->value()); });`
> `:334-337`, during drag only the numeric text field updates (`onValueChanged`), no config write.

`commit` (`:342-360`) builds a `ConfigOverrideValue` and calls `setOverride({"bar","background_opacity"}, v)` (or a batched `setOverrides` for linked fields). That runs the §2 synchronous pipeline → `fireReloadCallbacks()` → bar reload callback (`bar.cpp:878`).

**Consumer (slider → pixels).** The bar background fill is rebuilt from `backgroundOpacity` and the live `Surface` color role:

> `bar.cpp:1872-1876`, `style.fill = colorForRole(ColorRole::Surface, instance.barConfig.backgroundOpacity); … instance.bg->setStyle(style);`
> `bar.cpp:2129-2133` and `:540` (`bgOpacity = clamp(barConfig.backgroundOpacity,0,1)`) feed the rounded-rect background + shadow alpha (`surface/shadow.cpp:27` multiplies shadow alpha by `backgroundOpacity`).

Attached panels **inherit** the host bar's opacity and update live: `panel_manager.cpp:1673-1677` re-applies `barConfig.backgroundOpacity` when it drifts ≥0.001 (`panel.h:62-66` documents the inherit contract). Dock: `dock_instance.cpp:259-261` `panel->setFill(colorSpecFromRole(Surface, cfg.backgroundOpacity))`. OSD: `osd_overlay.cpp:544-547`.

**(b) `shell.panel.transparency_mode`**, a segmented enum `Solid/Soft/Glass` (`config_types.h:666-676`). It maps to derived card/detached opacities by pure functions:

> `config_types.cpp:130-141` `panelCardOpacityForTransparencyMode` → Solid `1.0`; Soft `clamp(op+0.08, .82–.92)`; Glass `clamp(op+0.10, .62–.75)`.
> `config_types.cpp:143-153` `detachedPanelBackgroundOpacityForTransparencyMode` → Solid `1.0`; Soft `0.80`; Glass `0.55`.

`panel_manager.cpp:155-164` reads `config().shell.panel.transparencyMode` and resolves attached/detached opacity through those functions, applied via `setPanelCardOpacity` (`:1677`).

**Why it visibly "does something" instantly.** On commit the synchronous reload re-runs the bar/panel/dock callbacks in the same turn; they recompute `fill = colorForRole(Surface, opacity)` and call `setStyle`/`setFill`, which dirties the scene node and schedules a redraw, the surface re-rasterizes with the new alpha that frame. There is no debounce, no external round-trip, no restart between the slider release and the pixel change.

---

## 4. Theme / Material-You: generation & propagation

**Palette model.** A resolved theme is a `Palette` of 16 Material color roles (`ui/palette.h:70-87`, roles enumerated `:11-28`). A `GeneratedPalette` is the token-keyed superset (`dark`/`light` maps of packed ARGB, `theme/palette.h:12-17`).

**Sources** (`theme_service.cpp:457-504`, `ThemeService::resolveAndSet`):
- **Builtin**: 10 hand-authored palettes as constexpr data incl. terminal ANSI colors, `builtin_palettes.cpp:12-68` (e.g. "Ayu"). Resolved via `resolveBuiltin` → `expandBuiltinPalette` (`theme_service.cpp:59-71`).
- **Wallpaper (Material-You)**: `resolveWallpaperGenerated` (`:401-455`) decodes+resizes the wallpaper to a 112×112 buffer (`loadAndResize`, `:430`) and runs `generate(rgb, scheme)` (`palette_generator.cpp:5-14` → `generateMaterial` for M3 schemes / `generateCustom`, M3 logic in `m3_schemes.cpp`). Result is memoized on (path, mtime, scheme) so an unchanged wallpaper skips the ~100 ms decode (`theme_service.h:68-73`, `theme_service.cpp:420-426,448-453`).
- **Custom**/ **Community** palettes parsed from JSON / downloaded+cached (`:462-501`).

**Propagation to ALL shell surfaces, smooth cross-fade.** `setPalette` writes the global `extern Palette palette` (`ui/palette.h:108,122`) and fires `paletteChanged()` (`:129-131`); controls subscribe in their ctor and re-apply palette-derived colors. A config/wallpaper change calls `onConfigReload`/`onWallpaperChange` → `resolveAndSet(animate=true)` → `startTransition` (`theme_service.cpp:547-584`): it animates `0→1` over `kTransitionDurationMs` with `EaseOutCubic`, each tick `setPalette(lerpPalette(from,target,t))` + `m_changeCallback()` (`:565-578`). `lerpPalette` interpolates every role in sRGB (`ui/palette.h:133-135`). The change callback is wired in `application.cpp:672-673` to `requestAllSurfacesRedraw()` (+ lockscreen/tray theme refresh), so every surface redraws on each fade tick. Theme is hooked to config reload at `application.cpp:513` (`addReloadCallback([]{ onConfigReload(); }, "theme")`).

**Propagation to EXTERNAL apps, templates.** A separate `resolvedCallback` (`application.cpp:494-511`) runs on each resolved palette: it calls `m_templateApplyService.apply(generated, mode)` and fires `HookKind::ColorsChanged`. `TemplateApplyService` runs on a **background worker thread** (`template_apply_service.cpp:128,268-282`) so external theming never blocks the shell render. `apply` (`:143-159`) skips work when palette/templates/wallpaper/scheme are unchanged (`sameInputs`, `:177-183`), then `applyRequest` (`:213-266`) feeds the palette into `TemplateEngine` and processes builtin (`assets/templates/builtin.toml`), community, and user templates. The engine renders color tokens into each app's config file and runs `apply.sh` pre/post hooks. Bundled templates cover gtk, foot, ghostty, alacritty, kitty, hyprland, wezterm, btop, cava, emacs, helix, starship, sway, … (`assets/templates/*/`). IPC `templates-apply` re-runs the last palette (`:185-198`).

End-to-end: **wallpaper/palette change → resolveAndSet → cross-fade shell + (worker thread) render template files + run hooks → external apps recolored**.

---

## 5. End-to-end "slider → pixels" (transparency)

1. User drags the bar opacity slider; only the numeric label tracks live (`settings_control_factory.cpp:334-337`).
2. On release, `setOnDragEnd` → `commit(value)` (`:362`) → `setOverride({"bar","background_opacity"}, v)` (`:359`).
3. `SettingsWindow::setSettingOverride` defers one tick → `m_config->setOverride(...)` (`settings_window_mutations.cpp:36-41`).
4. `ConfigService::setOverrides`: merge → atomic TOML write (persist) → `m_ownOverridesWritePending=true` → **`loadAll()` + `fireReloadCallbacks()`** synchronously (`config_overrides.cpp:1226-1238`).
5. Bar reload subscriber sees `bars` changed, runs `reload()` (`bar.cpp:881-884`).
6. `instance.bg->setStyle({fill = colorForRole(Surface, backgroundOpacity)})` (`bar.cpp:1872-1876`) dirties the scene node; attached panels inherit (`panel_manager.cpp:1673-1677`).
7. Dirty node schedules a redraw; the surface re-rasterizes that frame with the new alpha. No restart, no IPC, no file-watch round-trip in the in-app path.

---

## Portable to ryoku (propagation pattern)

The decisive lesson is **decouple persistence from live update**:

- ryoku's `GlobalConfig` (C++ singleton → `~/.config/ryoku/shell.json`) should, on a settings write, **(a)** persist the JSON AND **(b)** synchronously update the in-process config object and emit a change signal in the SAME turn, never rely on the file-watcher to feed the live shell. Noctalia explicitly writes the file, sets an "own-write pending" flag to ignore the watcher echo (`config_overrides.cpp:1234`, `config_service.cpp:802-805`), then re-renders directly. This is exactly the fix for "settings don't feel like they do much": QML bindings on a singleton property will update instantly if the setter mutates the property (not just the file).
- Keep file-watch ONLY as the channel for **external** edits, with self-write suppression to avoid double reloads / flicker.
- Use a **change-set** (`ConfigChangeSet`/`lastChange()`) so each consumer skips unaffected work instead of full rebuilds (`config_service.cpp:524-543`, `bar.cpp:881`).
- For opacity specifically: bind the surface fill to `colorForRole(Surface, opacity)` and re-apply on the change signal; commit on slider release (not per-frame) to avoid thrashing, but make the commit path synchronous so release → visible alpha is one frame.
- Theme transparency as **named modes** (Solid/Soft/Glass) via pure mapping functions (`config_types.cpp:130-153`) gives discrete, legible presets instead of a raw alpha that "does nothing perceptible".
- Theme changes should **cross-fade** (`lerpPalette` over a fixed duration with easing, `theme_service.cpp:565-578`) rather than snap, this is a large part of the "native/smooth" feel.
- Run external-app theming (matugen/templates) on a **worker thread** keyed on unchanged-input skip (`template_apply_service.cpp:128,151`) so it never stutters the shell.
