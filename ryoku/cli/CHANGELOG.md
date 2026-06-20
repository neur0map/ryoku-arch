# Ryoku CLI Changelog

## Unreleased

### Fixed
- `status` bounds the `checkupdates` call (120s) so a slow or stuck update check
  can never hang `ryoku status` -- the data seam the Hub and the update island
  poll for pending updates.
- Ryoku Hub "check for updates" surfaced nothing on a live mirror: `status` read
  only the `[ryoku]` pacman repo and `checkupdates`, neither of which a dev
  checkout has, so commits pushed to `main` never showed. It now reads the git
  channel below.
- `ryoku update` on a dev checkout crashed at "Materializing desktop configs"
  (`base config dir not found: /usr/share/ryoku/config`): it fell through to the
  packaged path. A checkout now always updates through the git channel + deploy.

### Changed
- `status` and `update` track a git **update channel** (`main` for everyone) on a
  Ryoku checkout, the model the Hub and update island were built for. `status`
  reports how far the **deployed commit** (what the machine is running, recorded
  at deploy) is behind `origin/main`, listing the incoming commits (subject +
  bare short hash). The version it shows is the channel's latest commit, a 7-char
  hash matching GitHub, so a commit pushed to the channel shows as an update until
  the machine redeploys onto it. The fetch takes no credential prompt and is
  bounded so it never hangs. `update` brings
  the channel in (fast-forwarding a clean on-channel checkout) and redeploys from
  the checkout. A packaged install has no checkout, so both fall back to the
  `[ryoku]` pacman view. The `--json` seam gains a `channel` field and
  `pendingUpdates` counts the channel's commits. New `channel.go`;
  `ryoku/shell/deploy.sh` records the checkout and the deployed commit;
  `RYOKU_CHANNEL` overrides the branch.

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
- `go test ./...` covers the channel: the deployed-commit baseline, behind counts,
  the commit list, the fast-forward update, and the off-channel/dirty redeploy
  guards. Confirmed live: `ryoku status --json` reports `channel: main` and the
  count goes from 0 to N when `main` advances past the deployed commit.
