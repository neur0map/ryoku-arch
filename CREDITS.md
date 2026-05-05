# Credits

Ryoku is built on the work of others. The most significant external
contributions are below.

## iNiR

Ryoku's current Niri session UI is built around iNiR by SnowArch.
iNiR provides the Quickshell-based overlays, lock UI, launcher, settings,
clipboard, wallpaper tools, OSD feedback, and session surfaces that Ryoku
installs for the Niri transition.

- Upstream: https://github.com/snowarch/iNiR
- Integration: `install/config/inir.sh`, `config/systemd/user/inir.service`,
  `config/niri/config.d/70-binds.kdl`

## Omarchy

Ryoku's tooling backbone (the ryoku-* script ecosystem, theme
pipeline shape, menu architecture) descends from Omarchy. Reference
is preserved in script structure and patterns rather than file
headers.

- Upstream: https://github.com/basecamp/omarchy
- Notice: see NOTICE

## qylock

Ryoku's optional SDDM theme switcher can still install qylock themes by
Darkkal44. The current default Niri path uses the shell-provided greeter,
but qylock remains available through `ryoku-install-qylock`.

- Upstream: https://github.com/Darkkal44/qylock
- Usage: optional SDDM greeter and lockscreen theme integration

Preview screenshots in `shell/assets/sddm-providers/qylock/themes/` are
derived from qylock's upstream theme directories
(https://github.com/Darkkal44/qylock) and are redistributed under
qylock's GPL-3.0 license. The hero composite at
`shell/assets/sddm-providers/qylock/hero.png` is an original Ryoku
composition assembled from those screenshots.

## Retired Prototype References

Earlier Ryoku prototypes experimented with Brain_Shell and Noctalia Shell
components. Those vendored runtime trees are not part of the current
Niri source track.

- Brain_Shell: https://github.com/Brainitech/Brain_Shell
- Noctalia Shell: https://github.com/noctalia-dev/noctalia-shell
