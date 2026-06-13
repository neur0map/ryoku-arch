# Noctalia: Process/Event Model, IPC, Config Live-Reload, System Integration

Repo: `~/Work/noctalia-shell`. A **single native C++ binary** with one `poll()` event loop. All paths below are `src/`-relative unless absolute.

---

## 1. Process / threading & event model

**Single binary, one `poll(2)` loop, one thread.** `MainLoop::run()` is a `while (!s_shutdownRequested)` loop (`app/main_loop.cpp:290`). Each iteration:
1. Drains deferred callbacks queued from the previous tick, `DeferredCall::takePending()` (`app/main_loop.cpp:297-313`). This is how worker threads marshal results back onto the main thread.
2. Prepares the Wayland read with `wl_display_prepare_read` / `wl_display_flush`, handling `EAGAIN` backpressure by also polling `POLLOUT` (`app/main_loop.cpp:316-356`).
3. **Builds the pollfd set fresh every iteration** from a sources provider, starting with the Wayland fd (`app/main_loop.cpp:362-364`). Fetching fresh "so config reloads can add/remove poll sources … without leaving stale pointers" (comment `:358-360`).
4. Computes a single `poll` timeout as the earliest source deadline (`app/main_loop.cpp:382-418`); forces `timeout=0` if surfaces have pending frame/render work (`:419-421`).
5. One `::poll(...)` (`app/main_loop.cpp:470`), then reads/dispatches Wayland (`:534-570`) and dispatches **only sources whose fd fired or whose timeout elapsed**, re-checking liveness before each dispatch because a reload can free a source mid-pass (`:572-615`).
6. Drains queued surface frame work + renders (`:617-637`).

**The poll_source pattern** (`app/poll_source.h`): an abstract `PollSource` with three hooks, `doAddPollFds()` (contribute fds), `pollTimeoutMs()` (advertise a timed wake, `-1` = none), and `dispatch(fds, startIdx)` (run after poll). Every subsystem that owns a kernel fd implements it, so the loop multiplexes everything uniformly. Concrete sources:
- Wayland: hard-wired as `pollFds[0]` (`app/main_loop.cpp:364`).
- IPC: `ipc/ipc_poll_source.h`, adds the listen fd, dispatches `IpcService::dispatch()` on `POLLIN`.
- Config: `config/config_poll_source.h:10-13`, adds inotify fd, calls `checkReload()` on `POLLIN`.
- D-Bus: `dbus/system_bus_poll_source.h:21-25` adds **two** fds (`pd.fd` + `pd.eventFd` from sd-bus `getEventLoopPollData`) and votes `pollTimeoutMs()` from sd-bus's own timeout (`:10-16`).
- PipeWire, brightness, timer, clipboard, key-repeat, calendar, http, each has a `*_poll_source.h` (see `pipewire/pipewire_poll_source.h`, `system/brightness_poll_source.h`, `app/timer_poll_source.h`, `net/http_client_poll_source.h`).

**Threads exist only for blocking work, not the event loop.** Luau widget scripts run on a 4-thread `ScriptWorkerPool` (`scripting/script_worker_pool.h:22`); results return via `DeferredCall` (`scripting/script_runtime.cpp:3`, drained at `main_loop.cpp:297`). `process::runAsync` also offloads child-process waits to a detached thread (`core/process.cpp:724-755`).

**How it avoids helper subprocesses:** system state is read through fds folded into the one loop, not by polling CLIs, sd-bus connection fd (`dbus/system_bus.cpp:34`), libpipewire loop fd, sysfs + inotify for brightness, inotify for config. `fork/exec` is reserved for genuinely external actions: launching apps, `ddcutil` (external-monitor DDC/CI), and `wpctl` default-sink persistence.

---

## 2. How it runs (launch + single instance)

**Single-instance guard = `flock`.** `SingleInstanceLock::tryAcquire()` opens `$XDG_RUNTIME_DIR/noctalia-$WAYLAND_DISPLAY.lock` and takes `flock(LOCK_EX|LOCK_NB)`; `EWOULDBLOCK` ⇒ another instance is live ⇒ refuse (`app/single_instance_lock.cpp:18-44`; path built `:56-66`). On any other error it degrades to running unguarded rather than refusing to start (`:23-27,36-39`). Closing the fd releases it; the lock file is intentionally never unlinked (`:46-54`). The lock is claimed before any Wayland init (`main.cpp:226-234`).

**Launch model: compositor `exec`, not a systemd unit.** `find` for `*.service`/`*.desktop`/`*.desktop.in` across the repo returns **no files found**, there is no bundled unit. `main()` supports an optional `--daemon`/`-d` flag that `fork()`s, `setsid()`s, and **re-`execvp`s the same argv** so the daemon starts "from a normal process image rather than a raw post-fork child" (`main.cpp:173-224`, dispatch `:305-326`); the parent waits on a pipe for a startup result code (`:313-325`). Without the flag it runs in the foreground via `runShell()` (`main.cpp:226-244`), i.e. the compositor's `exec-once`/autostart launches it directly. `argv[1]` also dispatches sub-commands `theme` / `msg` / `config` as one-shot CLIs that exit without starting the shell (`main.cpp:278-285`).

---

## 3. IPC (Unix socket + `noctalia msg` CLI)

**Server (`ipc/ipc_service.cpp`).** `start()` creates an `AF_UNIX, SOCK_STREAM|SOCK_NONBLOCK|SOCK_CLOEXEC` socket, unlinks any stale file, binds, and `listen(fd, 128)` at `$XDG_RUNTIME_DIR/noctalia-$WAYLAND_DISPLAY.sock` (`:40-72`, path `:196-206`). The listen fd is polled by `IpcPollSource`; `dispatch()` `accept4`s in a loop and handles each connection synchronously (`:86-94`). `handleConnection` sets a 100ms `SO_RCVTIMEO` so a slow client can't stall the loop, reads one line ≤512 bytes up to `\n`, runs it, writes the reply, closes (`:115-156`). `execute()` splits the first space into `command`+`args` (`:97-113`); `executeParsed` looks the verb up in a handler vector (`:187-194`); `--help`/`-h` prints generated usage (`:158-185`).

**Handler registration.** `registerHandler(command, fn, usage, description)` appends to `m_handlers`, replacing any existing entry so a verb can be re-registered after reload (`:75-84`). Handlers are registered all over the codebase via `registerIpc(IpcService&)` methods.

**Client (`ipc/ipc_client.cpp` + `ipc/cli.cpp`).** `noctalia msg <command> [args...]` joins argv into one space-separated line (`cli.cpp:10-21`) and `IpcClient::send` connects to the same socket path, writes `line + "\n"`, reads the reply to EOF, prints it, and exits non-zero if it starts with `error:` (`ipc_client.cpp:28-89`). If `connect` fails it prints `error: noctalia is not running` (`:52-56`). 2s send/recv timeouts (`:38-41`).

**Notable verbs** (from `registerHandler` call sites):
- Lifecycle/config: `status`, `config-reload` (→ `forceReload`, `config/config_service.cpp:1473-1478`), `session <lock|suspend|logout|reboot|shutdown>` (`shell/session/session_ipc.cpp:62`).
- Panels/bar: `panel-toggle|open|close`, `settings-open|close|toggle` (`shell/panel/panel_manager.cpp:1976-2078`), `bar-show|hide|toggle`, `bar-auto-hide-set`, `scripted-widget` (`shell/bar/bar.cpp:2965-2988`), `dock-show|hide|toggle|reload`, `window-switcher`.
- Audio (PipeWire): `volume-set|up|down|mute`, `mic-volume-*`, `mic-mute` (`pipewire/pipewire_service.cpp:1680-1831`); `media <…>` (`dbus/mpris/mpris_service.cpp:690`).
- System: `brightness-osd` + `dpms-on|off` (`app/application.cpp:1768-1814`), `wifi-enable|disable|toggle|status` (`dbus/network/inetwork_service.cpp:36-75`), `bluetooth-*` (`dbus/bluetooth/bluetooth_service.cpp:488-527`), `power-set|cycle` (`dbus/power/power_profiles_service.cpp:197-228`), `caffeine-enable|disable|toggle` (`idle/idle_inhibitor.cpp:159-196`).
- Notifications/clipboard/capture: `notification-dnd-set|toggle|status`, `notification-clear-active|history`, `clipboard-clear` (`app/application.cpp:1683-1767`), `screenshot-region|fullscreen` (`capture/screenshot_service.cpp:568-587`).
- Wallpaper/widgets: `wallpaper-random|get|set` (`shell/wallpaper/wallpaper.cpp:427-469`), `desktop-widgets-edit|exit|toggle-edit`, `lockscreen-widgets-*`, `greeter-sync`.

---

## 4. Config: TOML + atomic writes + live in-process reload

**Schema/format.** Config is TOML parsed with toml++ (`toml::parse_file`, `config/state_store.cpp:60`; the main config is loaded by `ConfigService::loadAll()`). `StateStore` keeps a `toml::table` of per-owner / per-key entries with typed getters/setters (`config/state_store.cpp:74-180`) and validated identifiers (`:13-24`).

**Atomic writes (`config/atomic_file.cpp`).** `writeTextFileAtomic` writes to `<path>.tmp` then `std::filesystem::rename` over the target (`:64-82`), a crash never leaves a half-written config. It is **symlink-aware**: `resolveAtomicWriteTarget` canonicalizes through a symlink so the real file is replaced, not the link (`:17-47`). `StateStore::write()` serializes the table and calls it (`config/state_store.cpp:182-188`).

**Change detection, two inotify watchers.**
- Generic `core/file_watcher.cpp`: one inotify instance; `watch(file, cb)` adds a watch on the **parent directory** (`IN_MODIFY|IN_CLOSE_WRITE|IN_CREATE|IN_MOVED_TO`, ref-counted per dir, `:27-53`) and `dispatch()` reads events, matches by filename, and fires callbacks with a **100ms debounce** per watch (`:71-107`). Used by widgets/services that watch arbitrary files.
- `ConfigService` has its **own** inotify for the config itself: `setupWatch()` watches the config dir, the settings/overrides dir, and any symlink-target dirs (`config/config_service.cpp:933-1012`).

**Live reload trace, file change → UI update, NO restart:**
1. inotify fd fires → `ConfigPollSource::dispatch` → `ConfigService::checkReload()` (`config/config_poll_source.h:10-13`).
2. `checkReload()` drains inotify events bucketed per watch descriptor, **skips the echo of its own write** (`m_ownOverridesWritePending`, `:802-805`), reloads overrides if needed, then if anything changed calls `loadAll()` and `fireReloadCallbacks()` (`config/config_service.cpp:749-832`).
3. `loadAll()` rebuilds the in-memory `Config` and sets section-level dirty flags in `m_lastChange` (e.g. `bars`, `widgets`, `theme`, `brightness`, `audio`…; flag list enumerated `:524-547`).
4. `fireReloadCallbacks()` invokes every subscriber registered via `addReloadCallback(cb, label)` (`:469-471`, fire `:509-561`).
5. Subscribers do **targeted, in-process rebuilds**, gated on `lastChange()` flags. Key example, the bar: its callback returns early unless `cfg.bars`/`cfg.widgets`/`cfg.shell.shadow` actually differ from cached copies (`shell/bar/bar.cpp:878-887`); `reload()` rebuilds the `WidgetFactory` and re-syncs instances live, only recreating layer-shell surfaces if widget **order** changed (`:901-928`). Theme (`app/application.cpp:513`), gamma/nightlight (`:656-658`), brightness (`:915`), audio (`:978`), hooks (`:640`), i18n language (`:489-491`), wallpaper (`shell/wallpaper/wallpaper.cpp:261`), dock, backdrop, calendar/weather/location all subscribe the same way.

So a settings edit → atomic file write → inotify wake → diff → only the affected service re-applies, in the same process, same frame budget. `config-reload` IPC verb just calls `forceReload()` (= `loadAll()` + `fireReloadCallbacks()`, `:492-507`) to force it without a file change.

---

## 5. System integration: direct D-Bus / syscalls / Wayland, not CLI scraping

1. **Battery/power via UPower over D-Bus (sdbus-c++).** `SystemBus` wraps `sdbus::createSystemBusConnection()` (`dbus/system_bus.cpp:32`) and exposes `getEventLoopPollData()` so its fd joins the main poll loop (`:34`, consumed by `SystemBusPollSource`). `UpowerService` talks to `org.freedesktop.UPower` / `.Device` and subscribes to `PropertiesChanged`, calling `refresh()` on signal, no `upower`/`acpi` CLI (`dbus/upower/upower_service.cpp:19-23,115-122,197-204,345-352`). Bluetooth, network, power-profiles, MPRIS, tray are sibling sd-bus services.
2. **Audio via libpipewire directly.** `pw_context_new` → `pw_context_connect` → `pw_core_get_registry`, binding `pw_node`/`pw_device`/`pw_metadata` proxies and listening for param changes (`pipewire/pipewire_service.cpp:505-528,668-817`). Volume is set by building a SPA POD with `spa_pod_builder_*` and calling `pw_node_set_param(SPA_PARAM_Props)` (`:1445-1455`, mute `:1536-1547`), not `pactl`/`wpctl` for the actual level. `wpctl` is used **only** to persist device default-sink/mute through WirePlumber policy (`:1428,1493,1591`).
3. **Internal brightness via sysfs + inotify.** Backlights enumerated from `/sys/class/backlight` (`system/brightness_service.cpp:818-865`); current value read with an `ifstream` on `…/brightness` (`readSysfsInt`/`readBacklightBrightness` `:141-158`); an inotify watch on the brightness file detects external changes (`:907-908`). External monitors fall back to the `ddcutil` subprocess via a forked async worker (`:449-470`), the documented exception, because DDC/CI needs the i2c tool.
4. **Time / Wayland-native bits.** Time from a syscall-backed `TimeService` + `TimePollSource` (`time/`). DPMS output power goes through the compositor platform (`m_compositorPlatform.setOutputPower`, `app/application.cpp:1771,1782`). Screenshots use the `wlr-screencopy` Wayland protocol (`capture/screencopy_*`). Weather/location use the in-process `net/http_client` on the poll loop, not `curl`.

---

## Portable to ryoku (QML/quickshell)

ryoku is a QML shell on Quickshell with Qt's own event loop, it cannot adopt the single-`poll` C++ architecture, but the **behaviors** that make Noctalia feel native are reproducible:

- **Stop shelling out for live state.** Where ryoku scrapes `nmcli`/`bluetoothctl`/`brightnessctl`/`pactl`/`wpctl`/`upower` (each a fork+exec+parse with latency and no push updates), use the data sources Quickshell already exposes (Pipewire, UPower/D-Bus, MPRIS, network) so values are event-driven and instant. Noctalia subscribes to `PropertiesChanged` and PipeWire param events; a CLI poll loop is both slower and laggier.
- **Never restart to apply settings.** Noctalia's win is: atomic temp+rename write → inotify → debounced reload → **section-diffed, targeted in-process re-apply** (only the bar/theme/brightness service that changed re-runs). The QML analogue is a single watched config (Quickshell `FileView`/`FileSystemWatcher`) feeding observable properties so bindings update reactively; never `quickshell kill`/relaunch. The user's "transparency slider does nothing" symptom is exactly what a missing reactive binding (or a restart-only path) looks like, wire the slider to a live-bound property, not a value only read at startup.
- **Atomic + symlink-aware writes** (`atomic_file.cpp`) prevent the half-written-config corruption that forces manual restarts; worth mirroring in ryoku's `plugin/` JSON persistence (write `.tmp` then rename).
- **One socket, many verbs.** Noctalia's `noctalia msg <verb>` over a single `$XDG_RUNTIME_DIR/noctalia-$DISPLAY.sock` is a clean model for ryoku's IPC surface: a flat verb table, one-line request/response, `"not running"` on connect failure, easy for keybinds and scripts to drive without restarting the shell.
- **Debounce file-watch reloads** (Noctalia uses 100ms) so an editor's multi-write save fires one reload, avoiding flicker.
