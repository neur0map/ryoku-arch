# Noctalia Shell Upstream Snapshot

Repository: https://github.com/noctalia-dev/noctalia-shell
Pinned commit: 9f8dd48c8df5ab1f7f87ddf9842627e1e5682186
License: MIT
Imported for: Ryoku centered settings panel UI, layout, widgets, and settings-page structure.

## Local Integration

- `upstream/` is a source snapshot for attribution and drift review.
- Runtime QML used by Ryoku lives in `../../Noctalia/`.
- Runtime changes are limited to import namespace rewrites, Ryoku backend adapters, disabled-feature guards, settings paths, and screen-safe geometry caps.
- Ryoku must not instantiate Noctalia `ShellRoot`, bar, dock, desktop widgets, setup wizard, plugin loader, updater, telemetry, or autonomous migrations.

## Update Procedure

1. Review upstream settings, widgets, services, and license changes.
2. Replace `upstream/` with the new pinned snapshot.
3. Rebuild the runtime namespace from the settings-related modules only.
4. Re-apply Ryoku adapter changes.
5. Run `tests/quickshell-noctalia-settings.sh` and `tests/quickshell-noctalia-network-providers.sh`.
6. Update this file with the new commit.
