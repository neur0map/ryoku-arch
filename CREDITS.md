# Credits

Ryoku is built on the work of others. The most significant external
contributions are below.

## Omarchy

Ryoku's tooling backbone, script ecosystem, theme pipeline shape, and menu
architecture descend from Omarchy. Reference is preserved in script structure
and patterns rather than file headers.

- Upstream: https://github.com/basecamp/omarchy
- Notice: see NOTICE

## qylock

Ryoku's optional SDDM theme switcher can still install qylock themes by
Darkkal44. The current default path uses the shell-provided greeter, but qylock
remains available through `ryoku-install-qylock`.

- Upstream: https://github.com/Darkkal44/qylock
- Usage: optional SDDM greeter and lockscreen theme integration

Preview screenshots in `shell/assets/sddm-providers/qylock/themes/` are
derived from qylock's upstream theme directories
(https://github.com/Darkkal44/qylock) and are redistributed under qylock's
GPL-3.0 license. The hero composite at
`shell/assets/sddm-providers/qylock/hero.png` is an original Ryoku composition
assembled from those screenshots.

## Caelestia Shell

Ryoku's current Quickshell shell started from the Caelestia shell codebase and
is being adapted into Ryoku-owned user-facing surfaces, commands, and defaults.

- Upstream: https://github.com/caelestia-dots/shell
- License: GPL-3.0-only

## illogical-impulse / iNiR (end-4)

Ryoku's earlier incarnation was a Niri-based rice ("iNiR") built on end-4's
illogical-impulse dotfiles. That heritage informs Ryoku's `ii*` desktop panel
system and components such as BarPopup (see the "inspired by end-4/dots-hyprland"
notes kept in source).

- Upstream: https://github.com/end-4/dots-hyprland

## ActivSpot

Ryoku's island and launcher experiments use Dynamic Island code and interaction
inspiration from ActivSpot by Devvvmn.

- Upstream: https://github.com/Devvvmn/ActivSpot
- Usage: Dynamic Island code adapted into Ryoku's island work, plus
  launcher/island interaction inspiration

## HyprMod

Ryoku includes Hyprland GUI configuration integration informed by HyprMod.

- Upstream: https://github.com/BlueManCZ/hyprmod

## Noctalia Shell

Ryoku's settings UI is built on the Noctalia Shell project, bundled in source
under the `shell/noctalia/` subtree (settings-UI subtree and its dependency
closure).

- Upstream: https://github.com/noctalia-dev/noctalia-shell
- License: MIT, Copyright (c) 2025 noctalia-dev
- Attribution: see `shell/noctalia/ATTRIBUTION.md` and `shell/noctalia/LICENSE`

## Ambxst

Ryoku's dynamic island, dashboard and notifications are built on the Ambxst
shell, bundled in source under the `shell/ambxst/` subtree (island/dashboard/
notifications subtree and its service/theme/component dependencies).

- Upstream: https://github.com/Axenide/Ambxst
- License: AGPL-3.0, Copyright (c) Axenide / Adriano Tisera
- Attribution: see `shell/ambxst/ATTRIBUTION.md` and `shell/ambxst/LICENSE`

## Brain_Shell

Ryoku's optional `top-notch` bar design (a Ryoku-native QML template) takes its
three-notch top-bar layout and proportions as visual inspiration from Brain_Shell
by Brainitech. No Brain_Shell code, IPC, daemons, or runtime are used, only the
declarative look was reinterpreted with Ryoku's own widgets and services.

- Upstream: https://github.com/Brainitech/Brain_Shell
- License: MIT, Copyright (c) 2026 Venkat Saahit Kamu (Brainitech)
- Usage: visual/layout inspiration for the `top-notch` bar design only

## Bundled Shell Components

Ryoku's current shell contains GPL-3.0 components that have been adapted into
Ryoku-owned product surfaces. Upstream notices and license headers must remain
with the source files or bundled license metadata that require them.

- License: GPL-3.0-only for bundled shell components that carry that license.
- Integration: current code should expose Ryoku names, paths, commands, and
  workstation behavior in user-facing documentation.
