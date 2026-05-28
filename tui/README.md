# ryoku-tui - the Ryoku control center

One folder, one binary. This is the single place for Ryoku's interactive
terminal UI: the **visual** layer (bubbletea v2 + lipgloss v2 + harmonica) and
the **backend** that drives the system live together here, so fixing or
extending the experience never means hunting across `bin/`, `lib/`, and
`install/`. It replaces gum entirely.

## What it does

Run with **no arguments** to open the control center: a fixed branded header
(with a harmonica-driven activity sweep) over a menu. Selection happens in the
TUI; the heavy actions then HAND THE TERMINAL to their bash engine via
`tea.ExecProcess`, so each tool renders its own full-fidelity, real-time output
instead of being captured and re-rendered:

- **Update** - hands off to `ryoku-update`, whose scroll-region dashboard
  (RYOKU ascii + frozen header) shows pacman/git output live
- **Doctor** - hands off to `ryoku-doctor` (its own styled output)
- **Recovery** - hands off to `ryoku-call911now` (MedEvac)
- **Logs** - renders the most recent update log in a scrollable viewport
- **Manage packages** - reroutes to the GUI package manager (`gpk`)

Actions that need root first show an **in-TUI sudo prompt** (password masked as
bullets, piped once to `sudo -S -v`); on success the engine runs without
re-prompting.

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
