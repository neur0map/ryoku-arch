# Credits

Ryoku is built on the work of others. The most significant external
contributions are below.

## Noctalia Shell

Ryoku's centered settings panel UI, layout, widgets, and settings-page structure are adapted from Noctalia Shell.

- Repository: https://github.com/noctalia-dev/noctalia-shell
- License: MIT
- Pinned snapshot: `9f8dd48c8df5ab1f7f87ddf9842627e1e5682186`

## Brain_Shell

The Ryoku Quickshell visual layer is derived from Brain_Shell by
Venkat Saahit Kamu (Brainitech), aka Brainiac on GitHub. MIT licensed
and used with explicit permission.

- Upstream: https://github.com/Brainitech/Brain_Shell
- Vendored under: config/quickshell/ryoku/vendor/brain-shell/
- License: MIT (see config/quickshell/ryoku/vendor/brain-shell/LICENSE)
- Modifications recorded in config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md

## Omarchy

Ryoku's tooling backbone (the ryoku-* script ecosystem, theme
pipeline shape, menu architecture) descends from Omarchy. Reference
is preserved in script structure and patterns rather than file
headers.

- Upstream: https://github.com/basecamp/omarchy
- Notice: see NOTICE

## qylock

Ryoku's optional SDDM greeter and Quickshell lockscreen themes use
the qylock theme bundle by Darkkal44. The install and switch flow is
handled through ryoku-install-qylock.

- Upstream: https://github.com/Darkkal44/qylock
- Usage: optional SDDM greeter and lockscreen theme integration

## ilyamiro/nixos-configuration

Ryoku's dashboard audio equalizer screen and music-popup interaction
direction were inspired by ilyamiro's NixOS configuration, especially
the Quickshell music popup and equalizer work. Ryoku does not vendor
source from this repository; the dashboard player is a separate
implementation shaped for Ryoku's visual system, Cava animation, and
EasyEffects helper wiring.

- Upstream: https://github.com/ilyamiro/nixos-configuration
- Relevant references:
  - config/sessions/hyprland/scripts/quickshell/music/MusicPopup.qml
  - config/sessions/hyprland/scripts/quickshell/music/equalizer.sh
