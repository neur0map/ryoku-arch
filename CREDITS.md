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

## HyprMod

Ryoku includes Hyprland GUI configuration integration informed by HyprMod.

- Upstream: https://github.com/BlueManCZ/hyprmod

## Bundled Shell Components

Ryoku's current shell contains GPL-3.0 components that have been adapted into
Ryoku-owned product surfaces. Upstream notices and license headers must remain
with the source files or bundled license metadata that require them.

- License: GPL-3.0-only for bundled shell components that carry that license.
- Integration: current code should expose Ryoku names, paths, commands, and
  workstation behavior in user-facing documentation.
