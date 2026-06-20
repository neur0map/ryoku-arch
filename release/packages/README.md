# Ryoku packages

The Ryoku desktop ships as signed pacman packages served from the `[ryoku]`
repository (`Server = https://repo.ryoku.dev/stable/$arch`). Each directory here is one
package; the publish CI builds every `PKGBUILD` and pushes the results to the
repo. Packages publish only from `main` release tags, never from `unstable-dev`.

## The set

- `ryoku-keyring` -- the release signing key, into `/usr/share/pacman/keyrings`.
  Installed first so pacman trusts the repo. (Built from key material beside its
  own PKGBUILD; the only package that is not built from the source tree.)
- `ryoku-shell` -- the shell IPC daemon (Go), to `/usr/bin/ryoku-shell`.
- `ryoku-hub` -- the Hub backend (Go), to `/usr/bin/ryoku-hub`.
- `ryoku` -- the control CLI (update / rollback / snapshots / materialize / ...),
  to `/usr/bin/ryoku`.
- `ryoku-blobs` -- the `Ryoku.Blobs` QML plugin, to
  `/usr/lib/qt6/qml/Ryoku/Blobs`.
- `ryoku-desktop` -- the umbrella. Depends on the five above plus the user-facing
  desktop runtime, lays the base configuration under `/usr/share/ryoku/config`,
  and installs the helper scripts (`ryoku-cmd-*`, the hardware `ryoku-*`,
  `ryoku-fastfetch`) to `/usr/bin` and the GPU udev rule to
  `/usr/lib/udev/rules.d`.

## Build-from-checkout model

These PKGBUILDs build from the checked-out monorepo, not from release tarballs.
`source=()` is empty; each PKGBUILD derives the repo root as `$startdir/../../..`,
because the CI runs `makepkg` in place inside each package directory within a
full checkout. The Go binaries and the QML plugin are built into `$srcdir`, so
the source tree is never modified, and `makepkg --clean` removes `$srcdir` and
`$pkgdir` afterward.

makedepends across the set: `go` (ryoku-shell, ryoku-hub, ryoku) and
`cmake ninja qt6-shadertools qt6-declarative` (ryoku-blobs), on top of the
assumed `base-devel`. `ryoku-hub` is the only Go package with an external module
(`github.com/BurntSushi/toml`, pinned in `go.sum`), so its build needs network.

## Configs and materialize

`ryoku-desktop` installs the base configs to `/usr/share/ryoku/config`, mirroring
the `~/.config` layout (for example `hypr/hyprland.lua`, `quickshell/...`,
`quickshell/hub/...`, `fish/config.fish`, `kdeglobals`, `starship.toml`). The
Hyprland tree includes `scripts/`, so after materialize the `ryoku-cmd-*` and
`*.sh` helpers also sit at `~/.config/hypr/scripts`, where the shell invokes them
by absolute path.

`ryoku materialize` (run as the user, on login or by hand) copies that tree into
`~/.config`: it clobbers the files it owns and prunes files dropped from a
release, but never touches user files such as `hypr/user.lua` or
`fish/user.fish`. Package install runs as root and cannot write a user's home, so
the `ryoku-desktop` install scriptlet only prints the materialize hint.
