# Documentation

This directory holds the tracked Ryoku documentation. Public docs are listed in
`docs.json`; maintainer-only docs stay here when they support release, ISO,
shell, branding, or configuration work.

## User Docs

- `install.mdx`: build or prepare a local ISO, verify it, flash it, and install Ryoku.
- `first-boot.mdx`: first login expectations and initial actions.
- `tour.mdx`: Hyprland workspace model and shell surfaces.
- `keybindings.md`: shipped Hyprland keybinding reference.
- `updates.mdx`: update channels, terminal update flow, recovery, and bootstrap.
- `customize.mdx`: Settings-backed customization and safe manual config entry points.
- `plugins.mdx`: current plugin lanes and how shell settings connect to commands.
- `troubleshoot.mdx`: logs, common failures, and bug-report details.

## Project Docs

- `vision.md`: product direction, audience, and non-goals.
- `omarchy-heritage.md`: inherited pieces, compatibility names, and active boundaries.
- `branding.md`: name, color anchors, logos, and where branding appears.

## Maintainer Docs

- `maintenance.md`: branch topology, update path, migrations, CI, and safety rules.
- `iso-build-recipe.md`: local ISO build and VM verification recipe.
- `release-pipeline.md`: GitHub Actions ISO build, signing, artifact handling, and release manifests.
- `ui-patterns.md`: shell runtime paths, UI patterns, and QML boundaries.
- `popup-animations.md`: the frame popout animation contract every popup (and plugin or bar/frame addition) must follow.
- `customization-inventory.md`: tracked config and theme surfaces.
- `ryoku-shell-branch.md`: the product (shell) vs provisioning (install) boundary, and how the ISO and standalone `shell-install/` share one source of truth. `main`/`unstable-dev` are the only branches; standalone installs track a channel directly (no generated `ryoku-shell` branch).
- `ryoku-config-architecture.md`: the rice/default-config consolidation plan (`shell/rice/`) and the `[global]` migration contract that governs which changes reach existing installs.

## Accuracy Review

This cleanup checked active docs against the tracked command, shell-module,
config, keybinding, ISO, and release files in this repository. User-facing docs
should describe the current Hyprland + Ryoku shell surface, `~/.config/ryoku`
typed config, `ryoku-update`, `ryoku-snapshot`, and the paused public ISO
availability state.

Before a release, re-check live website copy, release metadata, and runtime
service behavior because those can drift faster than repo docs.

## Retired Notes

Retired design notes may be moved into local `docs/_archive/`. That directory is
gitignored so old planning material stays available on this workstation without
shipping as active documentation.
