# TODO

Project-level work that is queued but not yet in a plan or spec. Each item is one-line per task with enough context that the next person reading it can decide whether to pick it up.

## ISO release pipeline

The workflow + R2 wiring landed in `.github/workflows/build-iso.yml` and `docs/release-pipeline.md`. Outstanding setup tasks before the first run:

- [ ] **Configure GitHub Secrets** for the workflow: `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ENDPOINT`, optional `R2_BUCKET`, `GPG_PRIVATE_KEY`, optional `GPG_PASSPHRASE`. See `docs/release-pipeline.md`.
- [ ] **Create the R2 bucket** on Cloudflare with `r2.dev` public access enabled, copy the `pub-<hash>.r2.dev` URL into the README once first publish lands.
- [ ] **Generate the Ryoku release signing key** (or use an existing one), add the public key under `keys/ryoku-release-key.pub.asc` so users can verify.
- [ ] **First manual workflow run** to confirm the pipeline lights up end to end before tagging `v0.1.0`.
- [ ] **Add the always-latest pointer** (e.g. `ryoku-stable.iso` overwritten each release) and the optional custom domain (`iso.ryoku.dev`) once `ryoku.dev` is registered.

## Site

- [ ] **Stand up `https://ryoku.dev`.** Domain not registered / site not live as of this TODO. See `docs/branding.md` for the suggested subdomain layout (`ryoku.dev`, `iso.ryoku.dev`, `docs.ryoku.dev`).

## Verification gaps from the offline ISO recipe

- [ ] **Real-hardware install test.** Everything in `docs/iso-build-recipe.md` was verified in QEMU/UEFI. Drive a bare-metal install on at least one machine (laptop without ethernet at install is a representative case for the offline path) before promoting the ISO past "tester-grade".
- [ ] **Online install path smoke test.** `RYOKU_ONLINE_INSTALL=1` in the chroot env was deliberately turned off (laptops without ethernet at install must not fail), but the path still exists and has a fix in `5a554eee` that has never been exercised end-to-end.

## AUR-only hardware drivers

`install/ryoku-other.packages` covers upstream-Arch GPU + hardware drivers. AUR-only drivers are now built into the offline mirror via `iso/builder/ryoku-boot-overlay.packages` (Path 2: makepkg at ISO-build time, no external dep at runtime).

Bundled by the boot overlay (resolved):
- [x] NVIDIA legacy stack (Maxwell/Pascal/Volta): `nvidia-580xx-dkms`, `nvidia-580xx-utils`, `lib32-nvidia-580xx-utils`
- [x] MacBook 12-inch SPI keyboard: `macbook12-spi-driver-dkms`
- [x] Tuxedo laptops backlight fix: `tuxedo-drivers-nocompatcheck-dkms`
- [x] Motorcomm yt6801 ethernet: `yt6801-dkms`

Still deferred:

- [ ] **Intel IPU7 camera firmware**: `intel-ipu7-camera-bin`. The AUR PKGBUILD has a runtime dep on `intel-ipu7-dkms-git` which is itself AUR-only, and makepkg --syncdeps in the bare build container has no AUR helper to resolve transitive AUR deps. Closing this requires either bootstrapping yay/paru into the build container OR listing the dep chain in the overlay manifest AND registering each freshly-built package as a temp pacman repo for subsequent builds to resolve from.
- [ ] **Apple T2 Mac support**: `linux-t2`, `linux-t2-headers`, `apple-t2-audio-config`, `apple-bcm-firmware`, `t2fanrd`, `tiny-dfr`. `linux-t2` is a full kernel build (~30-60 min CI cost) and the audience is small. Pick up once GH Actions release pipeline (above) is up so the cost is amortized across nightly builds, not local dev iterations.
- [ ] **Intel Panther Lake kernel**: `linux-ptl`, `linux-ptl-headers`. Same reason as Apple T2 (kernel compile cost).
- [ ] **Hosted `[ryoku]` pacman repo**. Long-term plan to retire the per-ISO-build AUR rebuild cost: ship pre-built AUR packages from R2 (or wherever the ISO ends up hosted) so users get driver updates without rebuilding the ISO, and so dev iteration speed stops being tied to overlay rebuild time. Comes after the GH Actions + R2 release pipeline above.

## Build/runtime polish (low priority)

- [ ] **Suppress the chroot pacman-hook noise during install.** `limine-mkinitcpio-hook` and `limine-snapper-sync` print "detected chroot env, skipping" / "kernel cmdline is not available" / "this does not update limine" during the chroot install. Harmless but ugly. Reorder `mkinitcpio -P` + `limine-update` so the user-facing transcript stays clean.
- [ ] **Direct EFI UKI normal-boot path** (Task 3 of `docs/superpowers/plans/2026-04-26-ryoku-iso-parity-implementation.md`). Limine is currently the normal path, which is fine; the parity plan also wants a direct UKI option.
