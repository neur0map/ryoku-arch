# Ryoku CLI Changelog

## Unreleased

### Added
- `ryoku` (Go): the user-facing update CLI and single front door to the distro.
  - `update`: snapper pre-snapshot, `pacman -Syu` + `yay`, `materialize`, shell
    reload, snapper post-snapshot. Aborts safely on a package failure.
  - `rollback` / `snapshots`: snapper-backed restore + listing.
  - `status [--json]`: installed/available version, pending updates, snapshot
    count (the `--json` form is the Hub's data seam).
  - `materialize`: lays `/usr/share/ryoku/config` into `~/.config` declaratively --
    copies shipped files, prunes ones dropped from a release, and NEVER touches
    user overrides (`hypr/user.lua`, `kitty/user.conf`, `fish/user.fish`). No
    migrations directory; the production replacement for `deploy.sh`'s config copy.
  - `reload`: delegates to `ryoku-shell reload` (removes the triplicated restart
    logic).
  - `deploy`: DEV-only build-from-checkout loop (RYOKU_REPO).

### Verified
- Builds clean, `go vet` clean. `materialize` tested end to end: copies base
  configs, prunes dropped files, and leaves a user override intact.
