# Ryoku Architecture, Process Model, IPC, Config & Organization

Read-only investigation of `~/Work/ryoku-arch`. Every claim cited `path:line`.
Stack: QML/quickshell shell (`shell/`) + C++ quickshell plugin (`shell/plugin/src/Ryoku/`) + a large `ryoku-*` bash command layer + bash migrations.

---

## 1. How the shell runs (startup chain)

- **systemd user unit**: `config/systemd/user/ryoku-shell.service:1-25`. `Type=simple`, `ExecStart=%h/.local/bin/ryoku-shell run --session` (`:13`), `Restart=on-failure`/`RestartSec=1` (`:17-18`), `KillMode=process`/`SIGTERM` (`:15-16`), `SuccessExitStatus=143` (`:14`), `ExecStopPost=…ryoku-shell-cleanup-orphans --quiet` (`:21`). **No `[Install]` section, Hyprland starts it via the session config exec-once** (`:24`). Env baked in: `QT_SCALE_FACTOR=1`, a `PATH` including `~/.local/share/ryoku/bin`, `QT_LOGGING_RULES`, `QS_DISABLE_CRASH_HANDLER=1` (`:9-12`).
- **Launcher**: `shell/scripts/ryoku-shell` (installed to `~/.local/bin/ryoku-shell`). `run|start` → `exec qs -p "$runtime_dir" "$@"` (`:134-140`); runtime dir defaults to `$XDG_CONFIG_HOME/quickshell/ryoku-shell` (`:6`). It exports `QML_IMPORT_PATH`/`QML2_IMPORT_PATH` to `~/.local/lib/qt6/qml` (`:8,19-20`), `QT_QPA_PLATFORM=wayland;xcb` (`:21`), prepends `$RYOKU_PATH/bin` to PATH (`:22-27`), and unsets `QS_CONFIG_NAME/PATH/MANIFEST` (`:28`).
- **QML entrypoint**: `shell/shell.qml`. Pragmas set the render loop and font/reload behaviour: `QSG_RENDER_LOOP=threaded`, `QS_DROP_EXPENSIVE_FONTS=1`, `QS_NO_RELOAD_POPUP=1` (`:2-5`). `ShellRoot { settings.watchFiles: true }` (`:18-19`) enables quickshell hot-reload of QML. Singletons eager-instantiated at root: `Background`, `Drawers`, `AreaPicker`, `Overlay`, `ConfigToasts`, `Shortcuts`, `BatteryMonitor`, `LockBridge`, `IdleMonitors`, `WallpaperRotation`, `ClipboardMaintenance`, `WeatherUnitSync`, `PluginMenu` (`:26-40`). Note the deliberate eager-load hack for `IdleInhibitor` and `GameMode` so their `IpcHandler`/watchers live from start (`:20-24`).

## 2. Process model (long-lived services vs shell-outs; per-tick jank)

Architecture is **QML singletons under `shell/services/` that wrap `Quickshell.Io.Process`**. Two patterns:

- **Long-lived monitor processes (good)**, one process, event-driven, no per-tick spawn:
  - `Network.qml:291-294` `nmcli m` (`running:true`, SplitParser) + `Nmcli.qml:1256-1261` `nmcli monitor`.
  - `GameMode.qml:320-323` `gdbus monitor --session …GameMode` (D-Bus watcher).
  - `Recorder.qml:63-68` one-shot status probe via `pidof`.
- **Per-tick subprocess spawns (jank risk)**:
  - **`SystemUsage.qml:81-93`**, a `Timer` (`interval: GlobalConfig.dashboard.resourceUpdateInterval`, `running: refCount>0`) that on **every tick** spawns `lsblk -J -b …` (`:139-144`), plus `gpuUsage`, `sensors` Processes (`:89-91`). CPU/mem use cheap `FileView` `/proc/stat`,`/proc/meminfo` reloads (`:107-137`), but the 3 process spawns per tick while resource widgets are visible are a concrete, repeating fork/exec cost.
  - **`CustomWidgets.qml:133-146`**, user desktop widgets get a `Timer{ onTriggered: proc.running=true }` per interval, i.e. **arbitrary `sh -c` spawned every N ms per widget**.
  - `LockThemes.qml`, `Notes.qml:119`, `CustomWidgets.qml:330` build JSON by spawning `sh -c` shell pipelines (`printf '['…cat…`) instead of using `FilesystemModel`/`FileView`.
- **Shells out to `ryoku-*`/systemctl** from services: `IdleInhibitor.qml:45-75` (`ryoku-cmd-caffeine`), `GameMode.qml:307-310` (`systemctl is-active`), `RyokuAbout.qml` (`ryoku-doctor`/update), `RyokuExtras.qml:196-198` (`ryoku-extras-install`). Settings UI shells out heavily via `Quickshell.execDetached` (see §3/§5).

Net: the **steady-state shell is mostly long-lived services**, but `SystemUsage` (whenever a resource widget is shown) and any user `CustomWidgets`/`Notes` polling are the repeating subprocess sources most likely to cause micro-stutter.

## 3. IPC

- **Surface**: `shell/ipc-surface.txt:1-85` (auto-generated, "Do not hand-edit", `:1-2`). 24 targets, e.g. `overlay`, `mpris`, `lock`/`lockscreen`, `clipboard`, `gaming`, `brightness`, `idleInhibitor`, `toaster`, `controlCenter`, `notifs`, `picker`, `wallpaper`, `suspend`, `plugins`, `hypr`, `widgets`, `drawers`, `audio`.
- **Producers**: each is an `IpcHandler{}` inside the owning service singleton, e.g. `Audio.qml:216`, `Brightness.qml:111`, `GameMode.qml:406`, `Hypr.qml:323`, `IdleInhibitor.qml:91`, `Notifs.qml:136`, `Players.qml:117`.
- **Transport**: quickshell's own socket IPC. Invoked as `qs -p "$runtime_dir" ipc call <target> <fn> [args]`, see `shell/scripts/ryoku-shell:60-63` (`ipc_call`), with convenience verbs mapping to it: `launcher→drawers toggle launcher` (`:157-159`), `settings→controlCenter toggle` (`:169-171`), `lock→lock lock` (`:76`), etc.
- **Callers**:
  - **External / keybinds / commands**: Hyprland keybinds and `ryoku-*` scripts call `ryoku-shell ipc …` / `ryoku-shell <verb>`. Translations document the public form `qs -c ryoku-shell ipc call cb …` for custom bar buttons (`shell/settingsgui/Assets/Translations/en.json:131`).
  - **settingsgui / dashboard / controlcenter → shell**: these surfaces do **not** primarily use the IPC socket. They mutate config (`GlobalConfig.*` / `Settings.data.*`) and **shell out with `Quickshell.execDetached`** for actions and `systemctl` (dozens of sites, `shell/settingsgui/Modules/**`). Notable: `Bar/common/DesignSubTab.qml:27` and `ControlCenter/ControlCenterTab.qml:83` run `systemctl --user restart ryoku-shell.service`. So cross-surface "talk to the shell" is a mix of (a) Qt property bindings on shared singletons and (b) detached process launches, **not** a single IPC channel.

## 4. Config: `Ryoku.Config` / `GlobalConfig` (C++ plugin)

- **Singleton & file**: `config.cpp:37-59`, `GlobalConfig` extends `RootConfig`, owns ~19 typed sub-config objects (appearance, general, background, bar, border, dashboard, gaming, gameMode, controlCenter, launcher, notifs, osd, session, winfo, lock, utilities, sidebar, services, paths) and calls `setupFileBackend(configDir()+"shell.json")` (`:58`) → **`~/.config/ryoku/shell.json`**. Per-monitor overlays via `MonitorConfigManager` (`config.cpp:117-119`).
- **Property macro = live binding**: `configobject.hpp:24-41` `CONFIG_PROPERTY` generates `Q_PROPERTY … NOTIFY xChanged`; the setter change-detects (`updateMember`, `:111-121`), then emits `xChanged()` **and** `notifyPropertyChanged`. So any QML binding to `GlobalConfig.bar.foo` updates **live** the instant the property changes, no restart for binding-driven values.
- **Persistence (auto-save, debounced)**: `rootconfig.cpp:125-129` connects every sub-object's `propertiesChanged` → `saveToFile()`; `saveToFile` (`:180-186`) starts a **500 ms single-shot save timer** (`:73-74`) that writes `QJsonDocument(toJsonObject())` indented (`:86-88`). `recentlySaved`+2 s cooldown (`:96-100,184-185`) suppresses the self-triggered reload.
- **External edits apply live**: `QFileSystemWatcher` on the file+dir (`:64,110-111,142-170`); on change (and not recently self-saved) a **50 ms debounce → `reload()`** (`:102-105,172-178`). `reloadFromFile` retries JSON parse up to 3× at 50 ms (`:206-217`) so a half-written hand edit doesn't blank config. **Unknown keys are preserved** across save (`configobject.hpp:139-140`; `collectUnknownKeys` `rootconfig.cpp:31-58`), matching the AGENTS contract that hand edits are honoured (`AGENTS.md:114-118`).
- **Net**: the file backend is bidirectional and live, most settings apply with **no restart**.

### Live-apply vs restart (the user's core complaint)

- **Restart mechanism**: settings code calls `Quickshell.execDetached(["systemctl","--user","restart","ryoku-shell.service"])`.
- **Requires a full shell restart**:
  - **Bar *design* switch**, `Bar/common/DesignSubTab.qml:19-47`: sets `pendingDesignRestart`, writes `GlobalConfig.bar.design`, and on `GlobalConfig.onSaved` restarts the service. Rationale documented in `services/BarDesign.qml:67-73`: `currentId` is **frozen at startup** (`Component.onCompleted: currentId = currentId`, `:72-73`) so the bar can't hot-swap with stale geometry; the fresh process re-reads it.
  - **Manual restart buttons**, `ControlCenter/ControlCenterTab.qml:82-83` ("Restart"), `modules/background/Background.qml:457` (desktop right-click menu).
- **Applies live (no restart)**, everything bound through `GlobalConfig`/tokens, e.g. transparency, rounding/spacing/padding scales, anim durations, resource update interval, colours. Transparency path: `appearanceconfig.hpp:223-234` (`enabled` default **false**, `base` 0.85, `layers` 0.4) → `services/Colours.qml:145-151` (`Transparency` reads `Tokens.transparency`, debounced `onChanged`) → `Colours.layer()` `:46-51` + Hyprland live `layerrule` blur/`ignore_alpha` (`:99-105`).
  - **Why "transparency slider feels like it does nothing"** (evidence): (a) the master `transparency.enabled` **defaults to false** (`appearanceconfig.hpp:227`) and `Colours.layer()` early-returns the opaque colour when disabled (`Colours.qml:47-48`), moving `base`/`layers` does nothing until the toggle is on; (b) consumption is **uneven**, drawers (`drawers/ContentWindow.qml:161`) and control-center (`controlcenter/Wrapper.qml:64-68`) honour it, but the **bar** (`modules/bar/BarWrapper.qml`,`Bar.qml`) has **no `transparency`/`opacity` reference** (searched: none), so the most-visible surface ignores the slider.

## 5. Organization / pain points (evidence-backed)

### Repo top-level (shell + non-shell mixed at root)
Root mixes the shell with whole-distro system tooling: `shell/`, `bin/` (240 `ryoku-*` commands), `migrations/` (402 `.sh`), `lib/`, `default/`, `config/`, `install/`, `iso/`, `shell-install/`, `distro/`, `themes/`, `wallpapers/` (~33 large image files), `videowalls/` (`.mp4`), `tui/` (Go), `vendor/qylock/`, `legacy/controlcenter/`, `tests/` (180+ `.sh`), `docs/`. Counts: **`bin/` = 240 `ryoku-*` of 241 entries; `migrations/` = 402** spanning `1751134560` (Jun 2025) → `1781355954` (Jun 2026). Per `AGENTS.md:70-81` everything under `shell/` except `vendor/qylock/` is Ryoku-owned and reorganizable.

### Three parallel UI/config surfaces (the central problem)
Documented as intentional-but-being-consolidated in `AGENTS.md:83-105`. The shell loads **all three at once** (`shell.qml:15` imports `qs.dashboard.modules.globals`; `shell.qml:74-77` still `LazyLoader`s `dashboard/modules/tools/MirrorWindow.qml`):

| Surface | Path | Config store | Status |
|---|---|---|---|
| **settings-gui** (canonical UI) | `shell/settingsgui/Modules/Panels/Settings/Tabs/` | `Settings.data.*` JsonAdapter → `~/.config/ryoku/settings-gui/settings.json` (`settingsgui/Commons/Settings.qml:24,30-34`, `settingsVersion: 59` `:28`) | **active** |
| **dashboard** (legacy) | `shell/dashboard/` + `shell/modules/dashboard/` | per-file FileViews → `~/.config/ryoku/dashboard/{theme,bar,workspaces,overview,notch,compositor,performance}.json` (`dashboard/config/Config.qml:74-724`) | **being retired** (`AGENTS.md:96-97`) |
| **control center** | `shell/modules/controlcenter/` + `settingsgui/Modules/Panels/ControlCenter/` | `GlobalConfig.*` | active |
| **typed config (canonical store)** | `shell/plugin/src/Ryoku/Config/` | `~/.config/ryoku/shell.json` | canonical (`AGENTS.md:85-92`) |

**Three distinct, coexisting config stores**: `shell.json` (typed C++), `settings-gui/settings.json` (1000-line noctalia-style JsonAdapter with its own migration framework, `Settings.qml:183-1001`), and `dashboard/*.json` (7 separate FileView adapters). `AGENTS.md:88-92` explicitly forbids adding keys to the latter two but they remain live. A single settings panel can read/write **both** `Settings.data.*` and `GlobalConfig.*` (e.g. `ColorScheme/ColorsSubTab.qml:228,531-532` uses both `GlobalConfig` and `execDetached`), so "which store owns this value" is ambiguous per-field.

### Concrete duplication / dead paths
- **Duplicate component names across surfaces**: `CustomButton.qml` exists in `settingsgui/.../Bar/Widgets/` and `settingsgui/.../ControlCenter/Widgets/` (both shell-out via `execDetached`); `ActiveWindow.qml`/`Audio` logic duplicated between `bar/components/` and `bar/popouts/`.
- **`legacy/controlcenter/`** at repo root, an out-of-tree old surface kept around.
- **Settings actions bypass IPC**: ~55 files under `settingsgui/Modules/**` call `Quickshell.execDetached` directly (launching apps, `wl-copy`, `ryoku-theme-set`, `systemctl`) rather than going through the typed `ryoku-shell ipc` surface, contradicting the "narrow IPC/command adapter" flow in `AGENTS.md:126-140`.
- **Settings ⇒ restart for bar design** (`DesignSubTab.qml:19-47`) is a UX cliff vs the live-apply majority, feels inconsistent to the user.
- **System logic location**: correctly mostly outside QML, in `bin/ryoku-*`, `lib/*.sh`, `migrations/*.sh`, `default/`, `install/`. But QML services still embed `sh -c` JSON-builder pipelines (`Notes.qml:119`, `CustomWidgets.qml:330`, `LockThemes.qml:116-160`) that could be C++ models.

## C++ plugin module map (`shell/plugin/src/Ryoku/`)
QML+C++ hybrid; each subdir is a QML import module (own `CMakeLists.txt`):
- **`Ryoku` (root)**: `appdb` (desktop-app DB), `cutils`, `imageanalyser`, `qalculator`, `requests` (HTTP), `toaster` (notif toasts).
- **`Ryoku.Config`**: typed config tree, `config.{cpp,hpp}` (`GlobalConfig`), `rootconfig` (file backend/watch/save), `configobject` (property macros, unknown-key round-trip), `monitorconfigmanager` (per-screen overlays), `tokens`/`tokensattached` (rounding/spacing/padding/font/anim design tokens), `userpaths`, and ~19 per-domain config objects (`barconfig`, `appearanceconfig`, `notifsconfig`, `gamemodeconfig`, …). **Owns config + design tokens.**
- **`Ryoku.Internal`**: `hyprextras`/`hyprdevices` (Hyprland Lua/devices bridge), `logindmanager`, `arcgauge`, `sparklineitem`, `visualiserbars`, `circularbuffer`, `circularindicatormanager`, custom QQuickItem renderers + system bridges.
- **`Ryoku.Services`**: audio DSP, `audiocollector`, `audioprovider`, `beattracker`, `cavaprovider` (visualiser), `service`/`serviceref`.
- **`Ryoku.Blobs`**: GPU "blob"/rounded-corner shapes, `blobgroup`, `blobshape`, `blobrect`, `blobinvertedrect`, `blobmaterial` (custom QSGMaterial; the bar frame/seamless shape).
- **`Ryoku.Images`**: `imagecacher`, `cachingimageprovider`, `iutils` (image caching/provider).
- **`Ryoku.Models`**: `filesystemmodel`.
- **`Ryoku.Components`**: `lazylistview` (perf list).

---

## Portable-to-ryoku takeaways (current-state implications)
1. **Live-vs-restart is real and uneven**: only bar *design* truly needs restart (frozen `currentId`, `BarDesign.qml:67-73`); almost everything else is live via `CONFIG_PROPERTY` NOTIFY bindings. Messaging/UX should reflect this, and the design-switch restart could be made hot.
2. **Transparency slider gap**: bar ignores `appearance.transparency`; master `enabled` defaults false. Wiring the bar to `Colours.layer()`/tokens and surfacing the enable toggle would make the slider "do something".
3. **Subprocess jank**: `SystemUsage` spawns 3 processes/tick when resource widgets show; `CustomWidgets`/`Notes` poll via `sh -c`. Candidates for C++ `Ryoku.Internal`/`Models` providers (noctalia-style native collectors).
4. **Config-store fragmentation**: collapse `settings-gui/settings.json` + `dashboard/*.json` into the typed `shell.json` so one store = one source of truth and live binding everywhere.
5. **IPC underused by settings**: route settings actions through the typed `ryoku-shell ipc` surface instead of ad-hoc `execDetached`.
