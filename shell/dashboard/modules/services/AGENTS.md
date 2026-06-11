# SERVICES KNOWLEDGE BASE

## OVERVIEW
Backend singletons bridging Wayland protocols and CLI tools (upower, wpctl, brightnessctl, etc.) to the QML UI layer, following a "Reactive Singleton" pattern: internal state derived from async system calls, exposed as QML properties.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Audio/Volume** | `Audio.qml` | PipeWire via `wpctl`. Sink/source management |
| **Battery** | `Battery.qml` | UPower integration. Percentage, charging state |
| **Power profiles** | `PowerProfile.qml` | power-profiles-daemon profile control |
| **Brightness** | `Brightness.qml` | Per-monitor brightness via `brightnessctl` |
| **Clipboard** | `ClipboardService.qml` | Persistent clipboard via SQLite (`clipboard_init.sql`) + helper scripts |
| **Media** | `MprisController.qml` | MPRIS D-Bus player control |
| **Notifications** | `Notifications.qml` | D-Bus notification server with persistence |
| **Weather** | `WeatherService.qml` | Forecast, sunrise/sunset, day/night detection |
| **Compositor** | `AxctlService.qml` | Abstraction over compositor IPC (focus, dispatch) |
| **Visibility** | `Visibilities.qml` | Per-screen UI visibility/layering orchestration |
| **State** | `StateService.qml` | JSON persistence for session state |
| **Suspend** | `SuspendManager.qml` | Sleep/resume coordination |
| **Game mode** | `GameModeService.qml` | Read-only mirror of the shell game-mode state file |
| **Lock screen** | `LockscreenService.qml` | IPC bridge for lock state |

## CONVENTIONS
- **Singleton pattern**: `pragma Singleton` + `Singleton { id: root }` root component.
- **System access**: Prefer `Quickshell.Io.Process` with `SplitParser` for line-by-line stdout handling.
- **Naming**: Properties in camelCase (`wifiEnabled`, `isCharging`). Methods: `update()` for polling, `toggleX()` for booleans.
- **Persistence**: `FileView` for direct JSON manipulation. Reference `Config` for global settings; keep service-specific state local.
- **Async safety**: `Qt.callLater()` when modifying lists/models inside process handlers.
- **Self-init**: Services handle own lifecycle via `Component.onCompleted: update()`.
- **Error handling**: Always provide safe fallback values (`available: device !== null`).

## ANTI-PATTERNS
- Polling without a timer guard (use `Timer` with configurable intervals).
- Modifying list models synchronously inside `Process.onStdout` handlers.
