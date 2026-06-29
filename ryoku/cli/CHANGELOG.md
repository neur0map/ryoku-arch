# Ryoku CLI Changelog

## Unreleased

### Added
- `ryoku update` offers to install the snapshot helpers when they are missing
  (`snap-pac`, and `limine-snapper-sync` on a Limine system) rather than leaving
  them as a standing `doctor` recommendation. It asks first: a Hub-launched update
  (`RYOKU_UPDATE_UI=hub`) raises the question in the Hub's Updates page and waits
  for the answer; a terminal update asks y/N; a non-interactive run declines. Skip
  or no answer leaves them to `ryoku doctor`, and a failed install never aborts the
  update. The consent rides the existing run-state file (a `prompt` phase plus a
  one-line answer back-channel). Standalone `ryoku doctor` stays recommend-only.

### Fixed
- `doctor` gains a "stale install crypt mapper" reconciler. ryoku-install opens
  the encrypted root as `/dev/mapper/root`; a run that died after the open, or a
  retry in the same live session, left that name held, so the next
  `cryptsetup open ... root` aborted with "Device root already exists" and a
  reinstall could not proceed. The reconciler closes a `root` crypt node only
  when it is a true orphan (present, not the device backing `/`, and holding no
  mount anywhere), so a normal encrypted box, where `/dev/mapper/root` IS the
  running root, is never touched. The installer self-heals too (see
  `installation/backend`). Covered by `doctor_test.go`.
- `materialize` now seeds `hypr/keyboard.lua` the way it seeds `monitors.lua` and
  `gpu.lua`: laid down only on a fresh install, never clobbered on update. The
  file documents itself as user-owned ("edits here survive Ryoku updates"), but it
  was overwritten back to the `us` default on every `ryoku update`, so anyone with
  several keyboard layouts had to re-add them after each update. Its comment now
  shows the multi-layout syntax (`kb_layout = "us,ru,de,fr"` with a switch key).
  Covered by `materialize_test.go`.
- `doctor` gains a "cursor theme" reconciler: it warns when a Ryoku desktop has no
  Bibata cursor theme and points at `ryoku-pkg-aur-add bibata-cursor-theme-bin`.
  A failed AUR source build, or a dev checkout (which installs no AUR packages),
  could leave the Ryoku Settings cursor picker with a single fallback theme; the
  prebuilt `-bin` package installs the whole Bibata family. Covered by
  `doctor_test.go`.
- `doctor` gains a "display resolution" reconciler that recovers a monitor a
  degraded link left below its available resolution. A cold boot or the
  post-upgrade `hyprctl reload` can briefly leave a DP/HDMI link advertising only
  a fallback mode (e.g. 800x600); Hyprland resolves `monitors.lua`'s `highrr`
  against that list and never re-picks once the link trains, so the panel stays
  low-res until a relogin. The reconciler (run by every `ryoku update` and by
  hand) re-asserts each output's intended mode via `ryoku-monitor settle`,
  respecting an explicit Ryoku Settings resolution and `monitors_user.lua`.
  Covered by `doctor_test.go` and `tests/monitor-profiles.sh`.
- `materialize` now points at `ryoku deploy` when the base config dir is absent,
  instead of failing with a bare `base config dir not found: /usr/share/ryoku/config`.
  That path only exists on a packaged install; on a dev checkout `ryoku deploy` is
  the command, and the error now says so (a set-but-missing `RYOKU_CONFIG_BASE` is
  called out separately).
- `bin/ryoku-recovery` (the `curl | bash` panic button) now always restores the
  stable `main` branch and repairs the broken checkout in place. A machine from
  an old ISO could be stranded on `unstable-dev`: that ISO's `ryoku-update`
  switched the checkout to a release branch, but the rewritten tree ships none of
  its old helper commands (`ryoku-snapshot`, `ryoku-update-perform`), so the
  update self-destructed and every `ryoku` command broke. Recovery could not dig
  the box out because it honored a leaked `RYOKU_CHANNEL` and cloned a fresh
  checkout beside the broken one, leaving it on `unstable-dev`. Recovery now
  hardcodes `main`, force-resets whichever checkout the machine actually has (the
  pre-rewrite one at the data root, or the current `repo/`) to `origin/main` and
  cleans its stale `bin/` scripts, and drops the dangling pre-rewrite
  `~/.local/lib/runtime-env.sh` PATH bridge. Covered by `tests/ryoku-recovery.sh`.
- `doctor` now creates the snapper `root` config when it is missing instead of
  reporting "not configured" as healthy. The snapshot safety net behind every
  `ryoku update` (the pre/post snapshot pair and the Limine rollback entries) was
  set up only by the installer, so a `ryoku deploy` box, an upgrade from an older
  release, or hand drift left a machine with no snapshots and nothing to restore
  them, and `ryoku snapshots` failed with "config 'root' does not exist". On a
  btrfs root `ryoku doctor` now lays down the same layout the installer writes
  (the `/.snapshots` subvolume, `/etc/snapper/configs/root`, `/etc/conf.d/snapper`,
  ownership, the cleanup timer, and limine-snapper-sync), and on a non-btrfs root
  it warns honestly that snapshots are unavailable. `ryoku status` and the
  pre-update note now distinguish "not configured" from an empty snapshot list.
  When a prerequisite is missing (`snapper` itself, or `snap-pac` and
  `limine-snapper-sync`), doctor does not write a config nothing can use: it
  reports the gap and recommends the exact install command instead.
- `status` no longer escalates to `sudo` unless a real terminal is driving it. The
  Hub and the update island poll `ryoku status --json` on a timer with no
  controlling terminal, but the snapshot count shelled out to interactive
  `sudo snapper list`; with no tty the PAM conversation failed, and `pam_faillock`
  counted every failure until the account was locked out of `sudo` even with the
  right password ("it is not taking my sudo password"). The count now runs only
  from a tty, and even then via `sudo -n` (a cached credential, never a prompt), so
  a background poll can never lock the user out. This also unblocks the Hub Updates
  panel, which sat blank on "checked not yet" while the hung `sudo` kept the status
  query from ever returning.
- `materialize` no longer resets a user's display or GPU configuration on update.
  The package ships seeds for `hypr/monitors.lua` (written by `ryoku-monitor`) and
  `hypr/gpu.lua` (written by `ryoku-gpu`); materialize now seeds them only when
  absent and never clobbers or prunes them. `ryoku update` refreshes shipped
  config while leaving every per-machine and user file (settings.lua, theme.lua,
  user.lua, monitors_user.lua, monitors.lua, gpu.lua) exactly as it found it.
- `doctor` backlight remedy no longer recommends `supergfxctl -m Hybrid` when
  that tool is not installed (it is ASUS-specific and absent on most machines, so
  users hit "Unknown command"). The fix now leads with the universal BIOS GPU/MUX
  route and only mentions the `supergfxctl` shortcut when the binary is present.
  This also cleans up `--explain`, which was echoing the bad command from the
  report it is fed.
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
- On a packaged install `status` now reports the running **commit**. The `[ryoku]`
  packages are versioned `<core>.r<count>.g<sha>` (see release/), so `status` reads
  the `g<sha>` out of the installed and available package versions and shows it as
  the version, with the channel, matching the git-checkout view. The Hub and the
  island then show the commit a machine is on instead of a blank or a static
  `0.1.0-3`.

### Added
- `doctor`: a "Hyprland config integrity" reconciler. It validates that the
  runtime-generated Hyprland drop-ins (`monitors.lua`, `gpu.lua`) still parse and,
  in a live session, reads `hyprctl configerrors`. A corrupt drop-in (a crash or a
  GPU reset that fires monitor events can truncate one mid-write) is regenerated
  from live state, or reset to a safe seed, then the config is reloaded -- so a
  desktop wedged in Hyprland's "emergency mode" recovers without a reboot, which
  `reload`/`update` could not do. Hardware-agnostic. `doctor --report` also gains a
  gpu/compositor stability section (vendor-agnostic GPU resets/hangs across recent
  boots, plus compositor coredumps) so a GPU-reset-induced crash is diagnosable.
- `doctor`: convergent reconcilers for stateful drift the package and config
  layers cannot reach, each idempotent (reports `ok`, converges where safe, or
  proposes the exact fix; `--check` previews) and retireable so the set never
  piles up like ordered migrations. `ryoku update` invokes the `ryoku doctor`
  command after it installs the new binary, so it is one command (not a copy
  baked into update) running the reconcilers from the release just installed. The
  batch covers swap-out-of-snapshots, snapper config consistency, stale pacman
  lock, the `[ryoku]` channel + keyring, desktop session components, the running
  shell daemon (restarted when its control socket is unreachable, so a crashed
  shell with dead keybinds and panels heals itself), failed
  services, btrfs device health, display backlight (no interface, missing
  brightnessctl, or a hybrid-GPU firmware-only backlight that does not dim the
  panel -- read from the kernel's own "no native backlight" verdict, not a sysfs
  value the panel ignores, with the route-to-iGPU fix), pending `.pacnew`, and
  orphaned packages.
- `doctor --report [file]`: when a problem cannot be auto-fixed (or is unknown),
  doctor writes one shareable `.txt` -- the findings plus system state (btrfs
  usage/errors, swaps, failed units, recent journal errors, pacman and ryoku
  channel state, session env) -- and points the user to it, so maintainers have
  the context to diagnose further. Default `~/.local/state/ryoku/doctor-report.txt`;
  no secrets included.
- `doctor --explain`: the reasoning layer over the deterministic reconcilers. It
  sends the diagnostic report to the user's own cloud model (defaults to Groq,
  free; OpenRouter and any OpenAI-compatible endpoint work via `RYOKU_AI_URL`/
  `RYOKU_AI_MODEL`) and prints a root-cause analysis with fix steps, reaching the
  long tail the rules cannot pre-encode. Strictly advisory and read-only: it never
  executes anything (cognition kept separate from actuation), and it is opt-in --
  nothing is sent unless `RYOKU_AI_KEY` (or `~/.config/ryoku/ai-key`) is set.
- `doctor` output is styled for the terminal: colored status glyphs in the Ryoku
  vermilion, terminal-width word-wrap (no more mid-word breaks), and a visible
  `ryoku doctor --explain` hint when issues are found. Color is suppressed when
  the output is piped or `NO_COLOR` is set, so the report file stays plain text.
- `recovery`: a last-resort restore for a broken desktop. It resets a clean
  checkout to `origin/main`, reinstalls the base packages, and rebuilds and
  redeploys the desktop, overwriting the Ryoku configs in `~/.config`. A preflight
  refuses to run on a non-Ryoku machine, and it confirms before touching anything
  (`--yes` skips the prompt, `--no-packages` does configs only). The logic lives
  in the standalone `bin/ryoku-recovery`, which `ryoku recovery` runs from the
  checkout and which doubles as a `curl | bash` rescue when the CLI itself is gone.
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
