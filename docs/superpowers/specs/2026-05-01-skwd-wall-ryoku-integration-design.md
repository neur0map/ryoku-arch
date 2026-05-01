# SKWD-Wall Ryoku Integration Design

## Context

Community feedback on the `Super+Ctrl+Space` appearance selector is that the wallpaper carousel feels detached from the rest of Ryoku's rounded, Caelestia-like shell language. The current Ryoku implementation is a partial SKWD-wall-inspired port inside Brain_Shell popup files, but it diverges visually: the card masks and surrounding controls are simplified and sharper than upstream SKWD-wall.

The desired result is not a small corner patch. Ryoku should use upstream SKWD-wall as the visual source of truth, including the selector, settings, rounded skewed cards, filter bar, tag cloud, Wallhaven, Steam, grid, hex, and mosaic views. Ryoku should still own system integration, paths, commands, wallpaper apply behavior, and the additional appearance sections for themes, fonts, and cursors.

Upstream references checked during design:

- `liixini/skwd-wall` at `f8e22a4`
- `liixini/skwd-daemon` at `2d48800`

## Goals

- Preserve SKWD-wall visuals as exactly as practical in Ryoku.
- Keep Ryoku command names and service names on the `ryoku-` prefix.
- Use Ryoku wallpaper paths, apply commands, theme pipeline, and IPC boundaries.
- Retain SKWD-wall settings surfaces visually, with unsupported backend actions either adapted or clearly disabled until implemented.
- Add Ryoku theme, font, and cursor browsing/apply sections using SKWD visual primitives, not the current Ryoku-styled card clone.
- Add SKWD-wall attribution to the `README.md` Credits section and maintain existing vendored license/notice attribution.
- Make the daemon source, build/install path, and user-service lifecycle explicit.
- Preserve existing Ryoku popup state contracts so current keybinds, IPC commands, dismissal behavior, and tests keep working.

## Non-Goals

- Do not ship an unmodified SKWD daemon that owns its own wallpaper state outside Ryoku.
- Do not replace the entire Ryoku shell with SKWD components.
- Do not preserve the current partial `WallpaperPopup.qml` visual implementation as the long-term wallpaper UI.
- Do not expose `skwd` command names as new public Ryoku commands. Protocol/event names can remain upstream-compatible internally when that reduces QML drift.

## Architecture

### Vendored Upstream QML

Add upstream SKWD-wall QML under:

`config/quickshell/ryoku/vendor/skwd-wall/upstream/`

Add Ryoku-only wrappers/adapters under:

`config/quickshell/ryoku/vendor/skwd-wall/ryoku/`

The vendor tree should include upstream `shell.qml`, `qml/`, `data/matugen/templates/`, `LICENSE`, and `UPSTREAM.md` with the pinned upstream commit. The implementation should avoid broad cosmetic edits in the upstream tree. Local Ryoku integration files should wrap or adapt upstream files where possible.

If a direct upstream-file edit is unavoidable, it must be small, documented in `config/quickshell/ryoku/vendor/skwd-wall/UPSTREAM.md`, and covered by a drift test or allowlist. Visual changes should be treated as suspicious by default because the purpose of this port is to preserve SKWD's look.

Expected Ryoku-specific wrapper:

- A Brain_Shell popup host or loader remains reachable through existing Ryoku popup IPC.
- The host opens the SKWD selector at Ryoku's appearance popup location and keeps the existing keybind behavior.
- The SKWD selector can run as part of the existing `qs -c ryoku` process if practical; if isolation is needed for stability, the Ryoku daemon launches a separate Quickshell process with Ryoku environment variables.

### Popup State Contract

The implementation must keep these existing shell contracts stable:

- `BS.Popups.wallpaperOpen`
- `BS.Popups.wallpaperVisible`
- `BS.Popups.wallpaperMode`
- `PopupLayer` dismissal behavior
- `ryoku-ipc shell toggle wallpaper|themes|fonts|cursors`

The old Brain_Shell `WallpaperPopup.qml` should stop owning the wallpaper visual implementation, but it can remain temporarily as a compatibility wrapper if that reduces risk. The wrapper is responsible for translating Ryoku popup state into the SKWD selector's open/close and mode state, then translating selection/dismissal back into Ryoku state.

### Ryoku Wallpaper Daemon Adapter

Port the upstream `skwd-daemon` protocol into Ryoku as a Ryoku-owned backend, with public binaries/services named with the `ryoku-` prefix.

Recommended names:

- `bin/ryoku-wallpaper-daemon`
- Optional client/debug command: `bin/ryoku-wallpaperctl`
- User service: `config/systemd/user/ryoku-wallpaper-daemon.service`

Daemon source should live in the repository, not as an unexplained generated binary. Recommended layout:

- `src/ryoku-wallpaper-daemon/` for the adapted Rust workspace copied from `liixini/skwd-daemon`
- `bin/ryoku-wallpaper-daemon` as a Ryoku command entry point or installed wrapper
- `config/systemd/user/ryoku-wallpaper-daemon.service` for the user service

The implementation plan must spell out how this binary is built and installed. Acceptable options are:

- build the Rust workspace during Ryoku install/refresh and install the resulting binary under `$RYOKU_PATH/bin`
- ship a small `bin/ryoku-wallpaper-daemon` wrapper that runs the checked-in Rust workspace with `cargo run --release --manifest-path ...`

The final plan should choose one option and add verification that the service can start from a clean checkout. It must not assume a compiled daemon exists outside git.

The daemon should expose an upstream-compatible JSON-RPC shape to keep SKWD QML close to upstream:

- request/response lines over a Unix socket
- methods such as `wall.list`, `wall.apply`, `wall.cache_rebuild`, `wall.set_favourite`, `wall.update_analysis`, `wall.random_start`
- events such as `skwd.wall.cached`, `skwd.wall.applied`, `skwd.wall.cache`

The socket path should move to a Ryoku namespace, for example:

`$XDG_RUNTIME_DIR/ryoku/wallpaper-daemon.sock`

`DaemonClient.qml` should be adapted only enough to use that path and Ryoku lifecycle assumptions.

Daemon startup must be idempotent:

- The shell wrapper can request the service/socket when opening the selector.
- The user service should be installable through a concrete first-run/config/migration path, not merely checked into `config/systemd/user/`.
- Existing systems need a migration or setup step that copies the unit to `~/.config/systemd/user/`, runs `systemctl --user daemon-reload`, and enables/starts the daemon when the required binary is available.
- If the daemon is missing or fails to start, the UI shows the SKWD-styled retry/error state and does not wedge Ryoku popup state open forever.

### Backend Responsibilities

The Ryoku daemon adapter should provide SKWD's expected data model while delegating system actions to Ryoku:

- Wallpaper list/cache:
  - read from Ryoku wallpaper directories
  - preserve thumbnails, hue/saturation sorting, tags, favourites, metadata, and current wallpaper state
  - store daemon state under Ryoku state/cache paths, not SKWD paths
  - migrate existing Ryoku wallpaper metadata where possible instead of dropping favourites, tags, Wallhaven entries, or the current wallpaper marker
- Wallpaper apply:
  - call `ryoku-wallpaper-apply --type image PATH` for static images
  - call `ryoku-wallpaper-apply --type video PATH` for videos
  - keep Wallpaper Engine support behind settings and feature detection
- Wallhaven:
  - reuse Ryoku's `ryoku-wallhaven-search` and download helpers where possible
  - keep the upstream browser UI
- Matugen:
  - do not let upstream SKWD silently replace Ryoku's theme pipeline
  - settings can be shown with Ryoku-safe backing behavior, or disabled with status text until fully adapted
- Random rotation:
  - implement through daemon scheduling, but apply via Ryoku commands
- Optimization/conversion/Ollama:
  - port incrementally behind feature flags so settings remain visually present without pretending unavailable work is running

Settings must remain visually present when matching upstream SKWD, but backend behavior must be honest:

- Supported settings should work through Ryoku commands/state.
- Unsupported settings should be disabled, read-only, or return a clear unavailable status.
- Settings must not silently write to upstream SKWD paths or start non-Ryoku services.

### Dependencies

Before implementation, audit upstream SKWD-wall and SKWD-daemon runtime dependencies against Ryoku package lists. Known relevant package files include:

- `install/ryoku-base.packages`
- `install/ryoku-aur.packages`
- `install/ryoku-other.packages`
- ISO package overlays under `iso/`

Ryoku already has several required pieces, including `quickshell`, `rust`, `swaybg`, `mpvpaper`, `ffmpegthumbnailer`, and Qt 6 packages. The implementation plan must still verify whether SKWD-specific dependencies such as image formats, multimedia plugins, Wallpaper Engine support, Matugen support, and font assets are present or intentionally optional.

Missing required dependencies should be added to the appropriate package list. Optional features should be feature-detected at runtime and surfaced in SKWD settings as available/unavailable.

### Themes, Fonts, And Cursors

Upstream SKWD-wall is a wallpaper selector. Ryoku-specific appearance sections should be added as a small extension layer that reuses SKWD visual components.

Expected behavior:

- Existing Ryoku IPC remains the source for theme/font/cursor data:
  - `ryoku-ipc theme list --jsonl`
  - `ryoku-ipc theme apply THEME`
  - `ryoku-ipc font list --jsonl`
  - `ryoku-ipc font apply FONT_FAMILY`
  - `ryoku-ipc cursor list --jsonl`
  - `ryoku-ipc cursor apply THEME [SIZE]`
- The UI uses upstream-style SKWD cards, filtering, motion, and control styling.
- Wallpaper mode remains upstream-exact.
- Theme/font/cursor modes may be a Ryoku extension, but should look native to SKWD rather than like the current Ryoku partial port.

## Popup And IPC Flow

Existing user-facing entry points remain:

- `Super+Ctrl+Space` opens the appearance selector in wallpaper mode.
- `Super+Ctrl+Shift+Space` opens the shared selector in theme mode.
- Existing `ryoku-ipc shell toggle wallpaper|themes|fonts|cursors` commands continue to work.

Internally:

1. Ryoku IPC receives the toggle request.
2. The Ryoku shell or daemon opens the SKWD selector wrapper.
3. The SKWD selector uses the Ryoku daemon adapter for wallpaper data/actions.
4. The Ryoku appearance extension uses existing theme/font/cursor IPC for non-wallpaper sections.

## Error Handling

- If the daemon socket is unavailable, the selector should show a visible SKWD-styled loading/error state and retry.
- If wallpaper cache rebuild fails, preserve the previous model and show an error/status line.
- If apply fails, do not update current wallpaper state.
- If Wallhaven, Steam, Ollama, or optimization features are disabled or missing dependencies, settings should remain visible but actions must report unavailable status.
- If theme/font/cursor apply fails, keep the selector open and show failure status.

## Testing

Add/adjust static regression tests for:

- SKWD vendor files and attribution are present.
- README Credits includes SKWD-wall.
- `CREDITS.md`, `NOTICE`, and `UPSTREAM.md` stay consistent with the vendored upstream code.
- Ryoku shell IPC still exposes wallpaper/theme/font/cursor toggles.
- The old partial `WallpaperPopup.qml` no longer owns the visual SKWD implementation.
- Daemon client uses the Ryoku socket path.
- Wallpaper apply routes through Ryoku commands.
- Theme/font/cursor sections route through Ryoku IPC.
- Upstream SKWD QML still passes `qmllint` where available.
- Upstream SKWD files are either byte-for-byte vendored from the pinned commit or listed in an explicit allowlist with a reason.
- Required packages for enabled features are present in Ryoku package lists.

Add backend tests for:

- JSON-RPC request/response parsing.
- `wall.list` returns SKWD-compatible wallpaper rows from Ryoku paths.
- `wall.apply` delegates static/video apply to Ryoku commands.
- favourites/tags/metadata persist in Ryoku state.
- cache rebuild emits compatible events.
- daemon startup/socket creation from a clean checkout or installed tree.
- migration from the existing Ryoku wallpaper cache/config files.

Manual verification:

- Open wallpaper selector with `Super+Ctrl+Space`.
- Open wallpaper selector through `ryoku-ipc shell toggle wallpaper`.
- Confirm rounded upstream slice cards match SKWD's visual style.
- Open settings and verify the SKWD settings surface is visually intact.
- Apply image and video wallpapers.
- Search/apply Wallhaven item if network is available.
- Open themes, fonts, and cursors through Ryoku keybinds and apply each.

## Documentation And Attribution

Implementation must update:

- `README.md` Credits section with SKWD-wall attribution.
- `CREDITS.md` with SKWD-wall and SKWD-daemon attribution.
- `NOTICE` if new upstream code is vendored or license notices change.
- `config/quickshell/ryoku/vendor/skwd-wall/UPSTREAM.md` with upstream repository, license, copyright, and commit.
- Any copied SKWD-daemon source tree with its upstream license and pinned commit.

## Open Risks

- Full upstream visual fidelity may require a separate Quickshell process if embedding the selector in Brain_Shell causes singleton/import conflicts.
- The SKWD daemon has more features than Ryoku currently supports. Porting every backend feature in one pass may be too large; feature flags may be needed.
- Theme/font/cursor modes cannot be upstream-exact because upstream SKWD-wall does not provide them. They should be SKWD-styled Ryoku extensions.
- Keeping upstream protocol event names reduces QML drift but means internal logs may still mention `skwd.wall.*`.
