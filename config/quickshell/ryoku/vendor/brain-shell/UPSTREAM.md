# Vendored Brain_Shell

Source:        https://github.com/Brainitech/Brain_Shell
Author:        Venkat Saahit Kamu (Brainitech), aka Brainiac on GitHub
License:       MIT (see LICENSE)
Vendored at:   4e04412ad3b404fcccb5ee80649e3bc82a546d08
Vendored by:   Ryoku Project, with explicit permission from upstream.

This directory is the Ryoku Quickshell visual layer, derived from
Brain_Shell. Modifications below preserve the MIT license and the
upstream copyright. Future cherry-picks from upstream re-apply each
modification listed here.

## Modifications

1. Security: AppLauncher.qml line 71. Parse Exec field per freedesktop
   spec instead of shell-interpolating the raw string. Prevents command
   injection from malicious or buggy .desktop entries.
2. Security: CpuFreqService.qml line 116. Validate gov against an
   allowlist (`performance`, `powersave`, `ondemand`, `conservative`,
   `schedutil`, `userspace`) before shell interpolation.
3. Security: WallpaperService.qml line 62. Replace `bash -c "cat
   '<path>'"` with direct `["cat", path]` Process command. Removes
   single-quote-escape injection in path strings.
4. Branding: ColorLoader.qml line 39. Read colors from
   `$HOME/.config/ryoku/current/theme/ryoku-shell-colors.json`,
   written by Ryoku's theme pipeline.
5. Branding: CavaService.qml. Cava temp config path moved from
   `/tmp/brain_shell/` to `/tmp/ryoku-shell/`.
6. Branding: ScreenRecService.qml. Cava recording temp config path
   moved from `/tmp/brain_shell/` to `/tmp/ryoku-shell/`.
7. Activation: PopupLayer.qml. Only Dashboard is instantiated in
   Ryoku Spec 1; other popups are commented out and re-enabled in
   follow-up specs. Border anchor properties softened from
   `required property var` to `property var ... : null`.

## Cherry-pick procedure

When pulling a fresh upstream snapshot:

1. `git clone https://github.com/Brainitech/Brain_Shell /tmp/brainshell-fresh`
2. Note new commit SHA.
3. `cp -r /tmp/brainshell-fresh/src/* config/quickshell/ryoku/vendor/brain-shell/src/`
4. `cp /tmp/brainshell-fresh/shell.qml config/quickshell/ryoku/vendor/brain-shell/shell.qml`
5. Re-apply each modification listed above. Diffs of prior patches
   live in git history; `git log --follow config/quickshell/ryoku/vendor/brain-shell/src/<file>`.
6. Update commit SHA at the top of this file.
7. Run the smoke test (`tests/brain-shell-spec1.sh`).

## Upstream qmldir notes

Upstream `src/services/qmldir` contains a typo on the line
`TempService ./system/empService.qml` (should be `TempService.qml`).
This is an upstream bug. If `TempService` is referenced anywhere in
the active component graph, QML will fail to resolve it. Spec 1
activates only Dashboard; if Dashboard's transitive imports do NOT
touch TempService, the typo is dormant and we leave it untouched
(preserving verbatim upstream). If Dashboard does touch TempService,
patch the qmldir to the correct filename and add Patch 8 to this file.
