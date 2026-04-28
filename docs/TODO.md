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

## AUR-only hardware drivers not yet in the offline mirror

`install/ryoku-other.packages` covers upstream-Arch GPU + hardware drivers (Vulkan, nvidia-open, intel-media, broadcom-wl, etc.) so an offline install on a standard NVIDIA / AMD / Intel machine has working drivers. The following AUR-only hardware drivers are NOT yet bundled, so an offline install on the affected hardware will silently degrade (the matching `install/config/hardware/*.sh` script will fail with "target not found", but the install continues without that hardware support):

- [ ] **NVIDIA legacy stack** (Maxwell/Pascal/Volta: GTX 9xx/10xx, GT 10xx, MX, Titan X/Xp/V): `nvidia-580xx-dkms`, `nvidia-580xx-utils`, `lib32-nvidia-580xx-utils`. Used by `install/config/hardware/nvidia.sh` for older NVIDIA cards.
- [ ] **Apple T2 Mac support**: `linux-t2`, `linux-t2-headers`, `apple-t2-audio-config`, `apple-bcm-firmware`, `t2fanrd`, `tiny-dfr`. Used by `install/config/hardware/apple/fix-t2.sh`. Apple T2 was explicitly de-scoped in commit `ebdf7906` ("drop ... Apple T2 kernel for now") so this is intentional, not accidental.
- [ ] **MacBook 12-inch SPI keyboard**: `macbook12-spi-driver-dkms`. Used by `install/config/hardware/apple/fix-spi-keyboard.sh`.
- [ ] **Intel Panther Lake kernel**: `linux-ptl`, `linux-ptl-headers`. Used by `install/config/hardware/intel/ptl-kernel.sh`.
- [ ] **Intel IPU7 camera firmware**: `intel-ipu7-camera`. Used by `install/config/hardware/intel/ipu7-camera.sh`.
- [ ] **Tuxedo laptops backlight fix**: `tuxedo-drivers-nocompatcheck-dkms`. Used by `install/config/hardware/fix-tuxedo-backlight.sh`.
- [ ] **Motorcomm yt6801 ethernet**: `yt6801-dkms`. Used by `install/config/hardware/fix-yt6801-ethernet-adapter.sh`.

omarchy ships these via its hosted `[omarchy]` pacman repo, which Ryoku does not yet have (see `iso/builder/build-iso.sh` comment block: "We do not yet ship a custom [ryoku] pacman repo / keyring"). Two ways to close the gap:

1. Add each AUR package to `iso/builder/ryoku-boot-overlay.packages` so the build container makepkgs them at ISO-build time. Cheap per-package but stacks up (each needs full kernel headers + DKMS build inside the container, ~5-10 min each).
2. Stand up a hosted `[ryoku]` pacman repo with pre-built AUR packages, mirror omarchy's model.

Option 2 is the right long-term answer; option 1 is an acceptable bridge for the most-impacted drivers.

## Build/runtime polish (low priority)

- [ ] **Suppress the chroot pacman-hook noise during install.** `limine-mkinitcpio-hook` and `limine-snapper-sync` print "detected chroot env, skipping" / "kernel cmdline is not available" / "this does not update limine" during the chroot install. Harmless but ugly. Reorder `mkinitcpio -P` + `limine-update` so the user-facing transcript stays clean.
- [ ] **Direct EFI UKI normal-boot path** (Task 3 of `docs/superpowers/plans/2026-04-26-ryoku-iso-parity-implementation.md`). Limine is currently the normal path, which is fine; the parity plan also wants a direct UKI option.
