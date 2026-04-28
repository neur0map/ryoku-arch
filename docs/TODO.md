# TODO

Project-level work that is queued but not yet in a plan or spec. Each item is one-line per task with enough context that the next person reading it can decide whether to pick it up.

## ISO release pipeline

- [ ] **GitHub Actions workflow that builds + signs + uploads ISOs to Cloudflare R2.**
  - Trigger: `workflow_dispatch` (manual) for now; add tag-push trigger (`v*`) once the manual path is proven.
  - Channel: `stable` only at first; add `rc` and `edge` once the workflow is stable.
  - Runner: GitHub-hosted `ubuntu-latest` with a free-disk-space step at the top (the build needs ~10 GB transient space and the runner only ships 14 GB free).
  - Steps: free disk -> docker build via `iso/bin/ryoku-iso-make` -> import GPG private key from secret -> `ryoku-iso-sign` -> `sha256sum` -> `rclone copy` to R2.
  - Secrets needed: `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ENDPOINT`, `R2_BUCKET`, `GPG_PRIVATE_KEY` (armored), `GPG_PASSPHRASE` (if the key is passphrase-protected).
  - Bucket layout: `ryoku/ryoku-stable.iso` (always-latest, overwritten each release) + `ryoku/archive/ryoku-<version>-<channel>.iso` (versioned, retained for rollback). `.sig` and `.sha256` next to each `.iso`.
  - Local equivalent already exists: `iso/bin/ryoku-iso-release v1.2.3` does the same chain via 1Password CLI for credentials. Port that flow to CI.

- [ ] **R2 public access for downloads.**
  - Pick: `r2.dev` subdomain (zero-config, ugly URL) for the first ISO drop, or custom domain (`iso.ryoku.dev`) once `ryoku.dev` is registered.
  - Add the resulting download URL to README install instructions.

## Site

- [ ] **Stand up `https://ryoku.dev`.** Domain not registered / site not live as of this TODO. See `docs/branding.md` for the suggested subdomain layout (`ryoku.dev`, `iso.ryoku.dev`, `docs.ryoku.dev`).

## Verification gaps from the offline ISO recipe

- [ ] **Real-hardware install test.** Everything in `docs/iso-build-recipe.md` was verified in QEMU/UEFI. Drive a bare-metal install on at least one machine (laptop without ethernet at install is a representative case for the offline path) before promoting the ISO past "tester-grade".
- [ ] **Online install path smoke test.** `RYOKU_ONLINE_INSTALL=1` in the chroot env was deliberately turned off (laptops without ethernet at install must not fail), but the path still exists and has a fix in `5a554eee` that has never been exercised end-to-end.

## Build/runtime polish (low priority)

- [ ] **Suppress the chroot pacman-hook noise during install.** `limine-mkinitcpio-hook` and `limine-snapper-sync` print "detected chroot env, skipping" / "kernel cmdline is not available" / "this does not update limine" during the chroot install. Harmless but ugly. Reorder `mkinitcpio -P` + `limine-update` so the user-facing transcript stays clean.
- [ ] **Direct EFI UKI normal-boot path** (Task 3 of `docs/superpowers/plans/2026-04-26-ryoku-iso-parity-implementation.md`). Limine is currently the normal path, which is fine; the parity plan also wants a direct UKI option.
