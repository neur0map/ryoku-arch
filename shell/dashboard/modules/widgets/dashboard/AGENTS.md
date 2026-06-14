# DASHBOARD KNOWLEDGE BASE

## OVERVIEW
Ryoku dashboard. Tabbed interface with LRU-based lazy-loading for widgets, system metrics, and clipboard. Opened via the Notch overlay.

## STRUCTURE
- **Root**: `Dashboard.qml` orchestrates LRU logic, tab layout, and open/close animations; `DashboardView.qml` is the view wrapper.
- **Sub-tabs** (each a directory):
  - `widgets/`: `WidgetsTab` - main grid: `FullPlayer`, `WeatherWidget`, `QuickControls`, `ControlButton`, `calendar/`.
  - `metrics/`: `MetricsTab` - real-time CPU/RAM/GPU/disk monitoring.
  - `clipboard/`: `ClipboardTab` - searchable clipboard history with categories (largest file).

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Tab loading** | `Dashboard.qml` | `TabLoader` + `shouldTabBeLoaded(index)` LRU logic |
| **Widgets grid** | `widgets/WidgetsTab.qml` | Player, weather, quick controls |
| **System metrics** | `metrics/MetricsTab.qml` | CPU/RAM/GPU/disk monitoring |
| **Clipboard** | `clipboard/ClipboardTab.qml` | Largest file. Category filtering |

## CONVENTIONS
- **LRU management**: Use `shouldTabBeLoaded(index)` for conditional `Loader.active`. Tabs evicted when exceeding cache limit.
- **Keyboard flow**: Components implement `focusSearchInput()` so root can forward focus on open.
- **UI primitives**: ALWAYS use `StyledRect` variants (`"pane"`, `"internalbg"`, `"focus"`) for containers.
- **Service bindings**: Connect directly to service singletons (`Audio`, `MprisController`). No prop-drilling.
- **Large files**: Most tabs exceed 900 lines. Edit with care; use targeted line ranges.

## ANTI-PATTERNS
- Creating tab content without LRU integration via `TabLoader`.
- Prop-drilling service state through parent components instead of importing singletons directly.
- Using `Rectangle` instead of `StyledRect` for any container.
