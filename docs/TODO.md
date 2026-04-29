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

## Brain_Shell migration follow-up specs

Spec 1 of the Brain_Shell port shipped 2026-04-28: vendored Brain_Shell under MIT, applied 3 security patches and 4 branding patches, theme-bridged Ryoku's `colors.toml` palette into Brain_Shell's ColorLoader, mounted TopBar plus Dashboard in `config/quickshell/ryoku/shell.qml`. waybar retired during runtime verification. See `docs/superpowers/specs/2026-04-28-brain-shell-port-spec1.md` and `docs/superpowers/plans/2026-04-28-brain-shell-port-spec1.md`. Future specs:

- [ ] **Spec 2: TopBar visual rework.** Default Brain_Shell TopBar visuals "kinda look bad" per user. Override `Theme.qml` constants (notch sizes, padding, corner radius, color usage) without touching vendored code. Brainstorm what specifically to change before writing the spec.
- [ ] **Spec 3: Activate NotificationsPopup + NotificationToast; retire mako.** Uncomment in `vendor/brain-shell/src/popups/PopupLayer.qml`. Disable mako via existing toggle pattern. Patch the upstream notification-server registration if needed (mako-conflict warning currently shows in stderr).
- [ ] **Spec 4: Activate AudioPopup + QuickControl; retire swayosd.** Uncomment in PopupLayer.qml. Disable swayosd-server via toggle. Verify volume/brightness/audio events surface through Brain_Shell instead.
- [ ] **Spec 5: Activate NetworkPopup (wifi/bluetooth/vpn).** Uncomment in PopupLayer.qml. Wire to existing network state. Decide on retirement of `bin/ryoku-launch-wifi`, `bin/ryoku-launch-bluetooth`. May require adding `wireguard-tools` or `iwd` to package set.
- [ ] **Spec 6: Activate WallpaperPopup; retire tofi backgrounds picker.** Uncomment in PopupLayer.qml. Replace the matugen call in `vendor/brain-shell/src/services/WallpaperService.qml` with `ryoku-theme-bg-set` so wallpaper changes flow through Ryoku's pipeline. Retire `default/tofi/pickers/backgrounds.sh`.
- [ ] **Spec 7: Activate ScreenRecOptionsPopup.** Uncomment in PopupLayer.qml. Decide if it replaces or augments `ryoku-cmd-screenrecord`. Address the `user_data/screenrec.json missing` warning from runtime.
- [ ] **Spec 8: Activate ArchMenu and Brain_Shell Border.** Uncomment in PopupLayer.qml. Decide whether Brain_Shell Border replaces the existing decorative Frame, or if Frame stays. If Border replaces Frame, retire `config/quickshell/ryoku/modules/frame/` and `bin/ryoku-toggle-frame`.
- [ ] **Spec 9: Cleanup pass after Brain_Shell migration.** Rename `bin/ryoku-toggle-frame` to `bin/ryoku-toggle-shell` since it now controls more than the Frame. Update `bin/ryoku-menu`'s `Update -> Process -> Launcher` entry. Remove tofi shim references where Brain_Shell handles the surface. Update CREDITS / UPSTREAM for any new modifications.

## Build/runtime polish (low priority)

- [ ] **Suppress the chroot pacman-hook noise during install.** `limine-mkinitcpio-hook` and `limine-snapper-sync` print "detected chroot env, skipping" / "kernel cmdline is not available" / "this does not update limine" during the chroot install. Harmless but ugly. Reorder `mkinitcpio -P` + `limine-update` so the user-facing transcript stays clean.
- [ ] **Direct EFI UKI normal-boot path** (Task 3 of `docs/superpowers/plans/2026-04-26-ryoku-iso-parity-implementation.md`). Limine is currently the normal path, which is fine; the parity plan also wants a direct UKI option.
