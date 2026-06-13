# Native-feel v2: Background process & service management

How noctalia / end-4 dots run long-lived work vs ryoku, and the next tier of
per-tick fork → event-driven conversions. Ranked by impact-per-risk.

## Reference baseline (how the two shells avoid per-tick forks)

- **noctalia** pushes nearly all background work into **C++ dbus / sysfs / dlopen
  services** that *subscribe* instead of poll:
  - UPower battery: pure dbus `PropertiesChanged` signals, zero polling
    (`noctalia-shell:src/dbus/upower/upower_service.cpp:113,195,343`).
  - System monitor: one background sampling thread reading `/sys` directly and
    pulling NVIDIA stats through **NVML via `dlopen("libnvidia-ml.so.1")`**, no
    `nvidia-smi` fork ever (`src/system/system_monitor_service.cpp:586-657,675`).
    CPU temp comes from `/sys/class/hwmon` files, not the `sensors` binary
    (`:467-471, readCpuHwmonTempSensor :478-534`, `readCpuTempCelsius :1205`).
    GPU usage falls back to `/sys/class/drm/.../gpu_busy_percent`
    (`readSysfsGpuUsage :282-329`).
  - Fine-grained **per-metric refcount**: `retainCpuTemp/releaseCpuTemp`,
    `retainGpuUsage`, `retainGpuVram`, `retainDiskPath(path)`
    (`:797-834`), a metric is only sampled while a visible widget holds it.
- **end-4 dots** is QML but leans on Quickshell event sources: nmcli/recorder
  status are checked **only on a state transition**, gated with
  `running: isRecording` (`dots:.../regionSelector/RegionSelection.qml:203-207`),
  not on a repeating timer. Note dots' own `ResourceUsage.qml:62-64` runs an
  **ungated** `running:true` CPU/mem timer, ryoku is already *ahead* here (it
  refCount-gates, see below), so don't regress that.

ryoku already does the right thing in several places: `NetworkUsage.qml` reads
`/proc/net/dev` via `FileView` gated on `refCount` (`:149-158`); `Network.qml`
uses `nmcli monitor` (`:291-295`) and `Nmcli.qml` `nmcli monitor` (`:1256-1260`);
`GameMode.qml` uses `gdbus monitor` (`:320-323`); battery is `Quickshell.Services.UPower`
(`shell/modules/BatteryMonitor.qml:13-47`), audio is `Quickshell.Services.Pipewire`
(`shell/services/Audio.qml:175-202`). The first research loop also moved the
**GENERIC** GPU path to a resolved-once `FileView` (`SystemUsage.qml:298-315`).
The findings below are what that first pass left on the table.

---

## 1. `sensors` is forked every resource tick: convert to a resolved-once hwmon FileView  ·  impact: HIGH · risk: LOW · no compositor

**Gap.** Every resource tick spawns the `sensors` binary just to read one CPU
temperature number, on *every* machine (NVIDIA, AMD, Intel alike). This is the
exact pattern the first loop already eliminated for the GENERIC GPU busy file,
but the CPU-temp fork was missed.

**Reference evidence.** noctalia never forks for temps, it walks
`/sys/class/hwmon/*/name` + `tempN_input`, scores the CPU sensor
(coretemp/k10temp/zenpower) and reads the file directly:
`noctalia-shell:src/system/system_monitor_service.cpp:478-534` (`readGpuHwmonTempSensor`
+ the CPU twin `readCpuHwmonTempSensor`), surfaced by `readCpuTempCelsius :1205-1208`.
Pure file reads, zero subprocesses.

**ryoku current state.** The fast timer kicks `sensors.running = true` every tick
(`shell/services/SystemUsage.qml:96`), and the `sensors` Process forks the binary
and regex-scrapes its stdout (`:317-333`). At `resourceUpdateInterval` = 1000ms
this is one fork/sec whenever any metrics surface is visible.

**Fix.** Mirror the shipped `gpuBusyResolve → gpuBusy` pattern exactly:
1. Add a one-time resolver Process (or a `Component.onCompleted` scan via a
   `FileView` over `/sys/class/hwmon`) that finds the right `tempN_input` path
   (match `name` ∈ {coretemp, k10temp, zenpower}; AMD Tdie/Tctl label) and stores
   `root.cpuTempPath`.
2. Replace the per-tick `sensors.running = true` with `cpuTempFile.reload()` on a
   resolved `FileView { path: root.cpuTempPath }`, parsing the millidegree int.
3. Keep the `sensors` fork only as a cold fallback when no hwmon path resolves.

**Wired key.** No new key, stays on the existing
`GlobalConfig.dashboard.resourceUpdateInterval` (`dashboardconfig.hpp:34`, default
1000) tick that already drives the surface. This is a pure fork→FileView
conversion; the key it honours is unchanged.

**Risk.** Low. hwmon layout is stable; the `sensors` fallback preserves coverage
on exotic platforms. Same shape as code already in the file.

---

## 2. NVIDIA GPU stats fork `nvidia-smi` every tick: use one long-lived `nvidia-smi -lms` stream (or NVML)  ·  impact: HIGH (NVIDIA boxes) · risk: MED · no compositor

**Gap.** On NVIDIA systems the per-tick GPU sample forks `nvidia-smi` every
`resourceUpdateInterval`. `nvidia-smi` has a heavy (~100-300ms) cold start and
spins the GPU out of low-power states, the most expensive recurring fork in the
shell, and it fires on this very workstation (RTX 4060). The GENERIC path was
already fixed to a `FileView`; the NVIDIA path was not.

**Reference evidence.** noctalia reads NVIDIA temp/usage/VRAM through NVML loaded
once with `dlopen("libnvidia-ml.so.1", ...)` and cached function pointers -
`noctalia-shell:src/system/system_monitor_service.cpp:586-657` (the
`NvidiaNvmlReader` struct: `readGpuUsagePercent :615`, `readGpuTempSensor :589`)
and `:675-687` (one-time `dlopen` + `dlsym`). Sampling the GPU is then an
in-process library call per tick, zero forks.

**ryoku current state.** `shell/services/SystemUsage.qml:93-94` sets
`gpuUsage.running = true` each tick, and the Process command for NVIDIA is
`["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"]`
(`:274-294`), a full fork every tick.

**Fix (QML-side, lowest risk).** Replace the per-tick fork with **one persistent
process** in `nvidia-smi` loop mode, parsed line-by-line, the same idiom ryoku
already trusts for `nmcli monitor`:
```
Process {
  id: gpuMon
  running: root.refCount > 0 && root.gpuType === "NVIDIA"
  command: ["nvidia-smi",
            "--query-gpu=utilization.gpu,temperature.gpu",
            "--format=csv,noheader,nounits",
            "-lms", String(GlobalConfig.dashboard.resourceUpdateInterval)]
  stdout: SplitParser { onRead: line => { /* parse usage,temp */ } }
}
```
One process for the whole session instead of one fork per second.
**Fix (best, higher effort).** Add an NVML reader to the `Ryoku.Config`/internal
C++ plugin exposing `gpuUsage`/`gpuTemp` properties, matching noctalia. Removes
the dependency on the `nvidia-smi` CLI entirely.

**Wired key.** Reuses `GlobalConfig.dashboard.resourceUpdateInterval`
(`dashboardconfig.hpp:34`), fed straight into `-lms` so the live key still
controls cadence (changing it restarts the monitor). No dead setting.

**Risk.** Med. `-lms` is supported on all current drivers; the process must be
torn down/restarted when `refCount` hits 0 or the interval key changes (bind
`running` + key into the command as above so a config edit re-execs it).

---

## 3. Custom "command" widgets fork `sh -c` every tick, ungated by visibility, with no minimum interval  ·  impact: MED-HIGH · risk: LOW-MED · no compositor

**Gap.** A user command widget runs an arbitrary `sh -c` on a `repeat:true`
`running:true` timer at a user-supplied `${ms}`. There is (a) **no visibility
gate**, it forks even when the bar/surface holding it is hidden, unlike every
other ryoku poller which checks `refCount`/`running:`; and (b) **no floor** on
the interval, so a mis-typed `ms: 50` forks ~20×/sec forever. This is the
SystemUsage-fork problem generalised to user content.

**Reference evidence.** noctalia's scripted widgets are managed by the C++
`scripted_widget_manager`/`screen_recorder.lua` model with explicit lifecycle and
`runAsync` (`noctalia-shell:scripts/screen_recorder.lua:124-129,368`), and metrics
honour the per-metric `retain*/release*` refcount so nothing samples while hidden
(`src/system/system_monitor_service.cpp:805-811`). dots gates its polled checks
on a live boolean (`running: isRecording`,
`dots:.../regionSelector/RegionSelection.qml:203`).

**ryoku current state.** Generated command-widget QML:
`shell/services/CustomWidgets.qml:133-147`, `Process { command:["sh","-c",${cmd}] }`
driven by `Timer { interval:${ms}; running:true; repeat:true; triggeredOnStart:true }`.
`running:true` is hard-wired, ignoring whether the widget is on screen.

**Fix.**
1. Gate the generated `Timer.running` on the widget's own
   `visible && Window.visibility !== Window.Hidden` (the delegate already has a
   `visible` binding it can forward), so hidden custom widgets stop forking, same
   discipline as `SystemUsage`/`NetworkUsage` `refCount` gating.
2. Clamp the effective interval to a configurable floor:
   `interval: Math.max(${ms}, GlobalConfig.services.customWidgetMinIntervalMs)`.

**Wired key (new).** `CONFIG_GLOBAL_PROPERTY(int, customWidgetMinIntervalMs, 1000)`
in `shell/plugin/src/Ryoku/Config/serviceconfig.hpp` (alongside the other service
knobs; mirrors the existing `bluetoothRssiPollIntervalMs` precedent in
`networkconfig.hpp:18`). The visibility gate needs no key. Reachable as
`GlobalConfig.services.customWidgetMinIntervalMs`, consumed by the generated
`interval:` binding in `CustomWidgets.qml:_genCommand`.

**Risk.** Low-med. The floor changes behaviour only for users who set
sub-second intervals (intended); the visibility gate must re-fire
`triggeredOnStart` on re-show so the value isn't stale.

---

## 4. Recorder polls `pidof` every 2s while recording: gate tighter / wire the cadence  ·  impact: MED · risk: LOW · no compositor

**Gap.** While a recording is believed active, ryoku forks a `pidof`-based shell
probe every 2000ms to reconcile state. The recorder is launched detached
(`Quickshell.execDetached(["ryoku-cmd-screenrecord", ...])`,
`shell/services/Recorder.qml:30`), so the process handle is lost and the only way
back to truth is polling.

**Reference evidence.** dots checks recorder liveness **only on a transition**,
not on a repeat timer: `running: isRecording` + `command:["pidof","wf-recorder"]`
+ `onExited` (`dots:.../regionSelector/RegionSelection.qml:203-207`). noctalia
tracks the recorder it spawned via its own managed process/state in
`screen_recorder.lua` (`:358-372`) rather than re-discovering it by name.

**ryoku current state.** `shell/services/Recorder.qml:92-97` -
`Timer { interval:2000; repeat:true; running:props.running; onTriggered: statusProc.running=true }`,
where `statusProc` forks `sh -c "pidof gpu-screen-recorder ... || pidof wf-recorder ..."`
(`:63-67`).

**Fix (cheap, lower risk).** Keep the reconcile but (a) make the cadence a key so
it isn't a magic 2000, and (b) widen it (recordings rarely die silently within
2s; 5s is plenty). **Fix (better).** Launch the recorder as a managed `Process`
(not `execDetached`) and drive state off `onExited` + `onRunningChanged`, deleting
the poll entirely, the recorder is a single child the shell owns for the session.

**Wired key (new).** `CONFIG_GLOBAL_PROPERTY(int, recorderReconcileIntervalMs, 5000)`
in `serviceconfig.hpp`, consumed by `Recorder.qml:93` `interval:`. If the managed-
Process route is taken instead, this becomes a fork→event conversion needing no key.

**Risk.** Low. Cadence change is cosmetic; the managed-Process route needs care so
an externally started recorder (CLI/keybind outside the shell) is still detected -
keep one slow reconcile (≥5s) as a safety net.

---

## 5. RyokuExtras install poll redundantly re-reads a FileView it already watches  ·  impact: LOW · risk: LOW · no compositor

**Gap.** During an extras install the 4s `pollTimer` calls `reportView.reload()`
even though `reportView` is a `FileView` with `watchChanges:true; onFileChanged:reload()`
- the reload is already event-driven; the timer-driven reload is dead work. (The
`detectProc` fork in the same tick is the only thing that must stay.)

**ryoku current state.** `shell/services/RyokuExtras.qml:253-259` (watched FileView)
vs `:262-269` (timer also reloads it). Note this timer is install-scoped
(`start()`/`stop()`), not always-on, so impact is low.

**Fix.** Drop `reportView.reload()` from the timer body; let `onFileChanged` drive
report parsing. Keep `detectProc.running = true` (genuine status fork) and the
15-min safety cap.

**Wired key.** None, pure dead-work removal inside an already-gated timer.

**Risk.** Low. `watchChanges` already covers the reload path.

---

## 6. Weather refresh interval is a hardcoded 1h literal with no live key  ·  impact: LOW · risk: LOW · no compositor

**Gap.** Not a fork hotspot, but a *dead-config* gap of the kind this audit must
flag: the weather refresh cadence is hardcoded and the timer runs `running:true`
unconditionally (even with no weather surface visible), with no `GlobalConfig`
key to tune it.

**Reference evidence.** noctalia's `weather_service` is a config-driven C++
service (`noctalia-shell:src/system/weather_service.{h,cpp}`) with its refresh
cadence and location bound to settings rather than a literal.

**ryoku current state.** `shell/services/Weather.qml:221-225` -
`Timer { interval: 3600000 /* 1 hour */; running:true; repeat:true }`. `weatherLocation`
and `useFahrenheit` are already live keys (`serviceconfig.hpp:16,18`) but the
interval is not, and the fetch isn't gated on any weather widget being shown.

**Fix.** Bind `interval` to a new key and gate `running` on a weather-surface
refCount (dashboard weather card / background weather widget), so a hidden weather
widget doesn't fetch.

**Wired key (new).** `CONFIG_GLOBAL_PROPERTY(int, weatherRefreshIntervalMs, 3600000)`
in `serviceconfig.hpp` (next to `weatherLocation`), consumed by
`Weather.qml:221` `interval:`. Reachable as
`GlobalConfig.services.weatherRefreshIntervalMs`.

**Risk.** Low. Pure parameterisation; keep a sane minimum (e.g. ≥ 600000) to avoid
API hammering.

---

## Cross-cutting note (aspirational, for a later pass)

ryoku's resource timers gate on a **single coarse `refCount`** for the whole
`SystemUsage` singleton (`SystemUsage.qml:82-83,100-101`). noctalia refcounts
**per metric** (`retainCpuTemp`, `retainGpuUsage`, `retainGpuVram`, `retainDiskPath`,
`system_monitor_service.cpp:797-834`): if only the CPU graph is visible, it does
*not* sample GPU temp/usage. After findings #1–#2 land, the remaining waste is
that an open metrics surface showing only CPU still triggers the (now cheaper)
GPU reads. A future split of `refCount` into `cpuRefCount` / `gpuRefCount` /
`diskRefCount` would close that, no new persisted key needed, just internal
counters wired to each widget's `Component.onCompleted`/`onDestruction`.
