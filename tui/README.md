# ryoku-tui - the Ryoku control center

One folder, one binary. This is the single place for Ryoku's interactive
terminal UI: the **visual** layer (bubbletea v2 + lipgloss v2 + harmonica) and
the **backend** that drives the system live together here, so fixing or
extending the experience never means hunting across `bin/`, `lib/`, and
`install/`. It replaces gum entirely.

## What it does

Run with **no arguments** to open the control center - a fixed branded header
over a menu whose selection streams its live output into a viewport below:

- **Update** - runs `ryoku-update` (plain mode), captured live
- **Doctor** - runs `ryoku-doctor` (plain mode), captured live
- **Recovery** - runs `ryoku-call911now` (MedEvac), captured live
- **Logs** - renders the most recent update log
- **Manage packages** - reroutes to the GUI package manager (`gpk`)

Run with a **widget subcommand** to get a gum-free, drop-in replacement for the
corresponding `gum` command (same flags, same stdout/exit-code contract), so a
call site only swaps `gum` for `ryoku-tui`:

| subcommand | replaces | status |
|------------|----------|--------|
| `ryoku-tui confirm` | `gum confirm` | done |
| `ryoku-tui style`   | `gum style`   | done |
| `ryoku-tui choose`  | `gum choose`  | planned |
| `ryoku-tui input`   | `gum input`   | planned |
| `ryoku-tui filter`  | `gum filter`  | planned |
| `ryoku-tui spin`    | `gum spin`    | planned |

When every gum call site has been swapped, the `gum` package is dropped.

## Layout

| file | role |
|------|------|
| `main.go` | entry + subcommand dispatch + the control-center model (state, update loop, layout) |
| `theme.go` | **visual**: the fixed Ryoku palette and lipgloss styles |
| `widgets.go` | the gum-replacement screens (`confirm`, `style`, …) |
| `backend.go` | **backend**: detection (channel/version/sudo), subprocess capture, log reading, detached launch, action→command mapping |
| `render_test.go` | deterministic render tests (no TTY needed) |

The action engines themselves (`ryoku-update`, `ryoku-doctor`,
`ryoku-call911now`) stay as the bash source of truth; this app orchestrates and
presents them. To add a menu action, add a `menuItem` + a case in
`commandFor` (backend.go). To add a widget, add a `run*` function in
widgets.go and a dispatch case in main.go.

## Build

```sh
cd tui && go build -o ryoku-tui .
```

Packaged via `distro/arch/ryoku-tui/PKGBUILD` (built with the other local
packages by `install/packaging/distro-arch.sh`). Dependencies: bubbletea v2,
lipgloss v2, bubbles v2, harmonica (all `charm.land/*` for v2).
