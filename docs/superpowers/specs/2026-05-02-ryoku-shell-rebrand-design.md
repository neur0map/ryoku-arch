# Ryoku Shell Rebrand Design

Date: 2026-05-02

## Goal

Move the Niri shell experience from upstream-visible naming and defaults to Ryoku-visible naming, branding, colors, and first-run behavior without doing a risky full source fork during this session.

This keeps the current working Niri session stable while preparing the repository for a clean merge and a later ISO build. The upstream shell project remains credited in documentation, but the installed system should present itself as Ryoku.

## Non-Goals

- Do not rebuild or verify an ISO in this phase.
- Do not run the full Ryoku rebrand pass for every historical document in this phase.
- Do not rename every internal upstream QML property, config key, or executable in this phase.
- Do not remove compatibility with the current upstream shell command path until wrappers and migrations are proven.

## Constraints

- The live system is disposable Omarchy-derived state. The repository and Ryoku install state are the source of truth.
- The repository must remain mergeable onto main without losing commit history.
- Phase 1 must be reversible and idempotent.
- Low-level compatibility paths can remain temporarily when required by upstream scripts, but user-facing labels, comments, installer output, and default visuals should say Ryoku.
- Upstream credit belongs in credit/documentation areas only, not in normal system UI.

## Recommended Safe Path

Use a Ryoku overlay that runs after the upstream shell install. The overlay patches only stable, visible surfaces:

- application and service display names
- welcome screen copy
- default shell config overrides
- icons and visible logos
- SDDM visible labels where available
- Ryoku theme defaults in this repository

This avoids a full source rename while the Niri session is still being stabilized. The actual binary and a few internal paths may stay in compatibility form until Phase 2.

## Phase Map

### Phase 0: Planning And Safety Gates

1. Document the rebrand approach and boundaries.
2. Create a task plan with phase ordering and verification commands.
3. Commit the design and plan before touching runtime files.

Verification:

- The plan clearly separates the safe overlay work from later full rename work.
- The plan states which phase is being executed now and which phases are deferred.

### Phase 1: Ryoku Overlay And Default Theme

1. Add a repository test for the rebrand overlay contract.
2. Add a shipped `ryoku` theme with Ryoku colors and branding assets.
3. Change the default theme installer to use the shipped Ryoku theme instead of an external Omarchy-derived theme.
4. Add a Ryoku shell branding overlay script that patches the installed upstream shell checkout idempotently.
5. Wire the overlay script into the current shell installer after upstream setup completes.
6. Update repository-provided user service descriptions and helper messages so normal user-visible text says Ryoku.
7. Add a migration to apply the overlay and default theme on existing Ryoku installs.
8. Run the new tests and relevant existing shell checks.
9. Apply the overlay on the live system if the local install path exists.

Verification:

- The new test passes.
- The shell installer has no user-facing upstream shell name in output.
- The default theme installer selects `ryoku`.
- The live shell checkout receives Ryoku visible labels and assets when the overlay runs.

### Phase 2: Ryoku Shell Command And Service Wrappers

1. Add a `ryoku-shell` command wrapper for the current upstream shell launcher.
2. Add a `ryoku-shell.service` user unit that uses Ryoku naming while delegating to the proven launcher.
3. Migrate Niri binds and Ryoku helper commands to use Ryoku wrapper names.
4. Keep old unit and command compatibility for one migration window.
5. Update migrations to enable the Ryoku service and disable legacy service autostart only after the Ryoku service is confirmed healthy.

Verification:

- `systemctl --user status ryoku-shell.service` is healthy.
- Restart helpers bring back the shell through the Ryoku wrapper.
- Existing sessions survive logout/login.

### Phase 3: Offline ISO Source And Patch Pinning

1. Pin the upstream shell source or release artifact for offline ISO builds.
2. Store the Ryoku patchset or overlay inputs in the repository.
3. Make the installer prefer bundled offline content before network cloning.
4. Add an ISO-side verification script that checks the bundled shell source, patches, theme, and assets are present.

Verification:

- A clean offline install path can install the Niri shell without network access.
- Patch application fails loudly if upstream content changes in incompatible ways.

### Phase 4: Full Source Fork Rebrand

1. Fork or vendor the shell source under a Ryoku-owned path.
2. Rename public command names, service names, desktop files, schema labels, and documentation.
3. Rename internal QML properties and config keys only where it lowers long-term maintenance risk.
4. Provide one-time migration from compatibility paths to Ryoku paths.

Verification:

- No normal installed file exposes upstream system naming outside credit/license docs.
- Existing user config migrates without losing panel, launcher, wallpaper, or theme settings.

### Phase 5: Compatibility Cleanup

1. Remove old command and service bridges after the migration window.
2. Remove legacy path fallbacks from installers and helpers.
3. Tighten leak scanners so legacy upstream shell names are allowed only in credit/license files.

Verification:

- Fresh install and upgraded install both boot to Ryoku Niri session.
- Repo scanners reject accidental personal paths, Omarchy residue, and obsolete shell branding.

## Phase 1 Acceptance Criteria

- Ryoku theme exists in `themes/ryoku`.
- Fresh install theme setup selects `ryoku`.
- The post-install overlay script can run repeatedly without corrupting the shell checkout.
- User-facing shell service descriptions say Ryoku.
- Upstream shell credit remains in `CREDITS.md` and selected implementation docs only.
- No full source rename is attempted in this phase.
