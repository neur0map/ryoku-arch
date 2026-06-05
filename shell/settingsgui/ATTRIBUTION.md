# Third-party code: Noctalia Shell

The contents of this `noctalia/` subtree are integrated Ryoku code originally
derived from the **Noctalia** desktop shell (import roots re-rooted to
`qs.noctalia.*` and `Quickshell.shellDir` paths redirected to this subdirectory).

- Upstream: https://github.com/noctalia-dev/noctalia-shell
- Vendored at commit: `272cd91408b5ff6e329e6397eed042fe422069e7`
- License: MIT — see `LICENSE` in this directory.
- Copyright (c) 2025 noctalia-dev.

Per the upstream notice: *"Forks and modifications are allowed under the MIT
License, but proper credit must be given to the original author."* This file and
the bundled `LICENSE` satisfy that attribution requirement.

Only the settings UI and its dependency closure were vendored to embed Noctalia's
Settings panel inside ryoku's shell. Backend behavior is wired to ryoku where a
backend exists; unsupported controls are greyed out and marked `// TODO`.
