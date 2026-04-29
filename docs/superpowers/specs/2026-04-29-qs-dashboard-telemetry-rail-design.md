# QS Dashboard Telemetry Rail Redesign

**Status:** Draft for implementation
**Date:** 2026-04-29
**Scope:** Redesign the Quickshell dashboard opened from the middle pill so it becomes a single slim unified view. Remove the tab-strip model, keep the personal/home surfaces the user explicitly wants (`Profile`, `Calendar`, `Clock`, `Player`), and replace the old boxed system-stats style with a more modern telemetry rail that mixes graphs, bars, and compact live summaries.

---

## 1. Goal

When the user opens the dashboard, they should immediately see one coherent home surface instead of switching between tabs or reading a grid of repeated stat widgets.

The target view contains:

- `Profile`
- `Calendar`
- `Clock`
- `Player`
- a new right-side `Telemetry Rail` with only the most important balanced system trackers

The system area must not look like five repeated cards or speedometers. It should feel more like a modern control surface: lighter, slimmer, more animated, and more visually varied.

## 2. User-approved design constraints

The design is constrained by the user decisions made during brainstorming:

- Keep a **single dashboard view** when the middle pill opens.
- Remove the **dashboard tab bar** so the popup feels slimmer.
- Keep the **personal/home content** visible in the same view.
- Use the **balanced system set**:
  - CPU
  - RAM
  - temperatures
  - network
  - one compact GPU/disk summary
- Keep **Profile**, **Calendar**, **Clock**, and **Player** in the final view.
- Replace the previous system style with a **mixed telemetry language**:
  - not five repeated cards
  - not a wall of circular gauges
  - use graphs, bars, and compact summaries where each metric reads best

## 3. Information architecture

### 3.1 Single-view dashboard

`Dashboard.qml` should stop behaving like a page-switching container.

Instead of:

- tab switcher at the top
- multiple pages (`home`, `stats`, etc.)
- page-dependent popup widths

the dashboard should become:

- one fixed content surface
- one body layout
- no page model
- no visible tab UI

The center-pill popup remains a dashboard, but conceptually it becomes a single home/control surface rather than a mini workspace.

### 3.2 Content zones

The unified layout should keep the current three-zone reading order:

- **Left column:** `Profile` above `Calendar`
- **Center column:** `Clock` above `Player`
- **Right rail:** new custom `Telemetry Rail`

This preserves a familiar home layout while moving the redesign effort into the system surface rather than redoing every existing card.

### 3.3 Dashboard footprint

Because the tab strip is removed, the popup should read slimmer than the current dashboard.

The implementation should:

- remove the space currently reserved by the tab switcher
- keep the popup width at the current dashboard width on the first implementation pass
- keep enough width for `PlayerCard` to remain comfortable and not collapse its controls

The slimmer feel for this spec comes from removing the tab strip and replacing the repeated stats widgets with a cleaner single-view composition, not from aggressively shrinking the popup width.

## 4. Telemetry Rail design

### 4.1 Core concept

The telemetry rail is a **single custom surface**, not a stack of generic `StatCard`s.

It should have:

- one continuous background treatment
- internal sections with different visual languages
- restrained motion
- clear hierarchy

The rail should feel purpose-built for live machine telemetry, not like old widgets dropped into a column.

### 4.2 Visual hierarchy

The rail should prioritize metrics in this order:

1. CPU
2. RAM
3. temperatures
4. network
5. compact GPU/disk summary

CPU and RAM should visually anchor the rail. Temp and network should be legible but lighter. GPU/disk should sit near the bottom as compact “when relevant” summaries rather than headline elements.

### 4.3 Mixed visualization language

The rail should deliberately mix presentation styles so repeated sections do not all look the same.

#### CPU

CPU should be the hero metric.

Recommended treatment:

- animated sparkline or filled line graph
- large live percent text
- smaller live frequency text beneath or beside it

Why: CPU usage benefits from showing recent change over time, not just a single number.

#### RAM

RAM should use a dense capacity visualization instead of a graph.

Recommended treatment:

- thick horizontal fill bar
- strong used/total text
- clear percentage

Why: memory is easier to read as occupancy than as a waveform.

#### Temperatures

Temperature should read as heat rather than utilization.

Recommended treatment:

- thermal gradient lane or heat strip
- CPU temperature always shown
- GPU temperature shown when meaningful

Why: a heat strip communicates “safe / warm / hot” better than another percent graph.

#### Network

Network should show directionality.

Recommended treatment:

- split up/down mini-bars or mirrored micro-graph
- small but live numeric rates for upload/download

Why: network is less about total capacity and more about whether traffic is moving and in which direction.

#### GPU and disk summary

GPU and disk should be compact bottom summaries.

Recommended treatment:

- GPU collapses or de-emphasizes when inactive
- disk shown as a quiet occupancy strip with a concise label/value

Why: they matter, but they should not compete with CPU/RAM/temp/network in the default home view.

### 4.4 Motion rules

Motion should be present but controlled.

Allowed motion:

- graphs repaint continuously from sampled history
- bars ease between values
- subtle glow/gradient response on hotter or more active states

Avoid:

- loud arcade animation
- bouncing ornaments
- repeated identical tween patterns across every section

The system should feel alive, not noisy.

## 5. Implementation shape

### 5.1 Files to modify

- `config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml`
- `config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml`

### 5.2 New file

Add a dedicated home-scoped component:

- `config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml`

This should be a custom surface responsible for:

- loading the relevant live services
- sampling short metric histories for graph lanes
- rendering the mixed telemetry UI

Keeping it isolated avoids turning `DashHome.qml` into a large, hard-to-read visual file.

### 5.3 Existing services to reuse

The redesign should reuse the existing Brain Shell services already used by `DashStats.qml`:

- `CpuService`
- `MemService`
- `NetService`
- `ThermalService`
- `DiskService`
- `CpuFreqService`
- `GpuService`
- `EnvyControlService` so `GpuService` keeps the same `envyMode` input it already uses in `DashStats.qml`

The key rule is to **reuse data sources but not reuse the old system-tab composition**.

### 5.4 Existing files to keep but de-emphasize

`DashStats.qml` does not need to stay wired into the dashboard. It may remain vendored on disk, but it should no longer define the user’s primary system experience in the popup.

## 6. Layout behavior

### 6.1 Left and center columns

`ProfileCard`, `CalendarCard`, `ClockCard`, and `PlayerCard` stay in the unified view with minimal internal redesign in this spec.

That is intentional:

- the personal/media cards already do their jobs
- the user’s redesign request is focused on the system presentation
- concentrating changes on the rail lowers risk and keeps the result coherent

### 6.2 Right rail sizing

The telemetry rail should be tall and visually continuous, but not bulky.

Target behavior:

- target rail width of roughly `260px`
- full-height alignment with the left/center content stack
- internal spacing that creates hierarchy rather than equal-box repetition

### 6.3 Responsive tolerance

The dashboard lives in a constrained popup, so the rail should avoid layouts that require large minimum widths.

Preferred strategies:

- compact typography
- shallow graphs instead of huge chart canvases
- summary rows that truncate gracefully

The design should stay readable at the current Ryoku laptop-oriented popup sizes.

## 7. Error handling and degraded states

The telemetry rail must behave cleanly when a data source is unavailable.

Examples:

- GPU section should gracefully de-emphasize or collapse when no meaningful GPU telemetry is present.
- Network lanes should show idle state rather than blank or broken values.
- CPU/RAM/temp sections should still render stable placeholder states if a service has not produced data yet.

This is especially important because a custom graph-based surface can otherwise look broken during startup.

## 8. Testing strategy

### 8.1 Static checks

Extend the existing static dashboard smoke test to verify:

- dashboard tab-switcher wiring is gone
- dashboard page model is removed or reduced to the single home surface
- `DashHome.qml` mounts `TelemetryRail`
- the old `QuickSettings` block is still absent
- the home redesign does not mount repeated `Speedometer` widgets in the home view

### 8.2 Visual/manual verification

Manual verification should confirm:

1. Clicking the center pill opens a slimmer dashboard without a tab bar.
2. `Profile`, `Calendar`, `Clock`, and `Player` are all visible in one view.
3. The right rail looks custom and visually distinct from `StatCard`.
4. CPU graph animates over time.
5. RAM bar eases as usage changes.
6. Temperature and network sections remain readable at idle and under activity.
7. GPU/disk summaries stay compact and do not dominate the panel.

## 9. Acceptance criteria

This redesign is complete when all of the following are true:

- Opening the dashboard shows a single unified home surface.
- No dashboard tab bar is visible.
- The unified view includes `Profile`, `Calendar`, `Clock`, `Player`, and system telemetry together.
- The system surface no longer reads as repeated cards or repeated gauges.
- The telemetry rail mixes graphs, bars, and compact summary treatments appropriately.
- CPU, RAM, temps, and network are immediately legible.
- GPU/disk information is present but secondary.
- The overall popup feels slimmer and more modern than the previous tabbed dashboard.

## 10. Out of scope

This spec does not include:

- a full redesign of `ProfileCard`, `CalendarCard`, `ClockCard`, or `PlayerCard`
- reviving the old `System` tab in a different place
- turning the dashboard into a general-purpose app launcher or task manager again
- adding new external dependencies for charting

The change is specifically a **home/dashboard redesign** centered on replacing the old system-stats presentation with a custom telemetry rail.
