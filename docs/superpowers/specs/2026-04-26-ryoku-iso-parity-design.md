# Ryoku ISO Parity With Live System Design

## Goal

Ryoku's install ISO must produce the same first-boot experience as the intended live Ryoku system and the Omarchy model it forks from, without depending on hardware-specific behavior and without requiring network access during install.

The required user-visible path is:

1. Boot the installed system through the normal Ryoku path used for production.
2. Show Ryoku-branded boot visuals instead of generic Arch/Limine fallback visuals.
3. Show the branded encrypted-volume passphrase prompt.
4. Land on the bundled `pixel-rainyroom` SDDM login screen.
5. Enter the Ryoku session from SDDM.

This must work on a fully offline install. Post-install Wi-Fi setup can remain a first-run task, but wired networking in VM environments must work when the installed system boots.

## Problem Statement

The current Ryoku ISO does not fail because archinstall's generated JSON is wildly different from Omarchy's. The generated JSON is materially the same kind of minimal handoff Omarchy uses: encrypted disk, Limine bootloader, `network_config.type = "iso"`, no declared greeter, no declared desktop profile, and no service list.

The real breakage is architectural:

1. Ryoku's ISO currently installs a generic Arch base first and relies on a second-stage Ryoku chroot install to convert that into the real product.
2. Ryoku does not currently have Omarchy's equivalent of an offline custom package source that guarantees boot-critical packages are available during that second stage.
3. Ryoku currently accepts degraded boot outcomes instead of treating them as install failures.
4. Ryoku currently diverges from Omarchy's normal boot model by removing direct EFI UKI entries instead of using them for the normal production boot path.
5. The repo is not yet guaranteed to be the canonical copy of the live system's actual shipped assets and boot UX.

This combination explains the observed failures:

- booting to `tty1`
- generic Limine menu instead of Ryoku-branded flow
- terminal-style LUKS prompt instead of the branded prompt
- inconsistent first-boot VM networking
- repo contents diverging from the intended live-system source of truth

## Confirmed Findings

### 1. The archinstall JSON is too minimal to guarantee Ryoku UX by itself

Ryoku's generated `user_configuration.json` asks archinstall for:

- `bootloader: "Limine"`
- encrypted Btrfs root
- `network_config: { "type": "iso" }`
- `services: []`
- `profile_config.greeter: null`
- `profile_config.profile: {}`

That means archinstall is only creating a base encrypted Arch install plus the initial Limine layout. Ryoku-specific session, boot branding, decrypt branding, SDDM setup, and VM networking all depend on the later Ryoku install layer.

This is the same overall pattern Omarchy uses, so the JSON itself is not the main defect.

### 2. Omarchy guarantees boot-critical packages offline; Ryoku does not

Omarchy's ISO builder and package set include Omarchy-specific boot packages in the offline install path, including:

- `limine-mkinitcpio-hook`
- `limine-snapper-sync`

Ryoku currently does not provide equivalent offline parity. Instead:

- the ISO builder pulls only official Arch packages today
- `limine-mkinitcpio-hook` is deferred into the AUR-core path
- `limine-snapper-sync` is not part of the current Ryoku offline package inputs

This means Ryoku cannot guarantee the same branded boot stack offline the way Omarchy does.

### 3. Ryoku currently permits degraded success states

Ryoku's `install/login/limine-snapper.sh` currently warns and continues if Limine helper packages are unavailable. In that case it preserves or lightly patches the stock archinstall Limine config instead of enforcing the branded Ryoku path.

That degraded path is the direct reason a VM can still boot with generic Limine visuals and a non-parity boot experience.

### 4. Ryoku currently diverges from Omarchy's normal boot model

Omarchy's migration path creates a direct EFI UKI boot entry for the normal production boot path.

Ryoku currently does the opposite in the independence cutover migration: it explicitly removes pre-existing direct Ryoku EFI entries and does not recreate them. That makes the normal Ryoku boot path materially different from the Omarchy model and is a likely contributor to the visible Limine-first boot behavior.

### 5. The repo is not yet guaranteed to match the live machine's shipped assets

The committed `pixel-rainyroom` SDDM theme does not currently byte-match the installed live theme on this machine. That means the repo is not yet the canonical representation of the intended shipped greeter experience.

The same standard must be applied to the other first-experience assets:

- SDDM theme
- Plymouth theme
- Limine templates and update flow
- direct-boot policy
- any first-boot config files required to match the current live system

### 6. VM wired networking is second-stage dependent

The generated archinstall JSON uses `network_config.type = "iso"`, which only copies the live ISO network state. Ryoku's guaranteed wired-network behavior is currently added later by Ryoku config scripts. If the second stage is incomplete or partially degraded, NAT ethernet in the VM is not guaranteed to come up correctly on first boot.

## Design Decision

Use a two-phase product strategy:

### Phase A: Immediate hardening

Stop shipping degraded installs. The current installer must no longer declare success if it failed to produce the branded Ryoku boot/session path.

### Phase B: Omarchy-style parity architecture

Move Ryoku toward Omarchy's production model by making the offline ISO carry the Ryoku-specific boot-critical package stack and by restoring the correct production boot path for normal EFI boots.

This gives the fastest route to production safety without locking the project into the wrong architecture.

## Target Architecture

### 1. Repo becomes the canonical source of the shipped live system

The repo must become the exact source of truth for the intended shipped first-boot experience. That means the committed assets and config generators must match the live system Ryoku is supposed to ship, not an approximation and not an older Omarchy carryover.

Required parity areas:

- `default/sddm/pixel-rainyroom/**`
- `default/plymouth/**`
- Limine templates and generated boot config defaults
- direct EFI UKI boot policy
- installer-time first-boot config required for VM ethernet and SDDM/session landing

### 2. Normal production boot matches the Omarchy model

Normal boot should follow the Ryoku UKI direct EFI path where firmware compatibility allows it, with Limine retained as the recovery/snapshots path rather than the primary user-facing normal boot path.

That keeps the installed experience aligned with the user's stated target:

- no generic bootloader menu as the normal first impression
- branded decrypt prompt
- SDDM after unlock

### 3. Branded boot path is mandatory, not best-effort

The installer must treat these as required deliverables:

- Ryoku-branded normal boot path
- Ryoku-branded decrypt prompt
- Ryoku SDDM greeter setup
- graphical target and session landing

If these cannot be produced, the install must fail instead of silently degrading to a generic Arch path.

### 4. Offline boot-critical package parity must be built into the ISO path

Ryoku needs an Omarchy-equivalent answer for boot-critical custom packages. Whether that is a real Ryoku package repo plus keyring or another local package feed embedded in the ISO, the important property is the same:

- boot-critical Ryoku packages must be available offline during install
- they must not depend on post-install AUR retries
- the branded boot path must not rely on a warning-tolerant fallback

### 5. VM first-boot validation becomes part of the product contract

The VM is not just a smoke test. It is a required release gate. The installed VM must prove:

1. boot succeeds through the intended production path
2. branded decrypt prompt appears
3. `pixel-rainyroom` appears
4. Ryoku session starts correctly after login
5. NAT ethernet comes up on first boot of the installed system

## Work Phases

### Phase 1: Eliminate degraded success paths

Purpose:
Make broken boot/session parity fail fast.

Includes:

- remove or reject the current "continue with stock Limine" success path
- make missing boot-critical branding/setup a fatal install error
- ensure `tty1` after install is treated as a release-blocking failure state

### Phase 2: Reconcile repo with the intended live system

Purpose:
Make the repo the source of truth.

Includes:

- sync committed SDDM theme assets to the intended live version
- sync Plymouth assets and config behavior
- audit boot templates and current live boot config expectations
- remove leftover Omarchy-specific identifiers where they are now wrong

### Phase 3: Restore the correct normal EFI boot model

Purpose:
Match Omarchy's user-facing boot behavior while keeping Ryoku branding.

Includes:

- switch normal boot policy to Ryoku UKI direct EFI path where supported
- keep Limine for snapshots/recovery paths
- fix the current direct-boot script bug that still searches for `omarchy*.efi`
- align migrations and installed-state behavior with the intended policy

### Phase 4: Add offline package-source parity

Purpose:
Make the branded boot path fully available offline.

Includes:

- create a Ryoku package/keyring story or equivalent embedded package feed
- supply boot-critical packages offline
- stop relying on post-install AUR availability for production boot correctness

### Phase 5: Clean installer inputs and network behavior

Purpose:
Remove invalid config and stabilize first-boot networking.

Includes:

- remove bad generated pacman mirror data from the archinstall JSON
- ensure installed VM NAT ethernet comes up deterministically
- preserve the "offline install, Wi-Fi later" product model

### Phase 6: Replace broken test artifacts and revalidate from scratch

Purpose:
Ensure old broken artifacts do not contaminate verification.

Includes:

- replace the currently known-bad ISO artifact
- remove stale/bad VM disk data created from broken installers
- clear the relevant ISO build cache used for offline mirror reuse
- boot the rebuilt ISO into a fresh VM machine
- validate only against the fresh machine, not mutated prior test disks

## Risks

### 1. Direct EFI boot compatibility varies by firmware

The normal direct-boot path must stay compatible with the non-hardware-specific requirement. Firmware exceptions must be explicit and narrow, not the default behavior for all installs.

### 2. Repo/live reconciliation can uncover more drift

Once the repo is treated as canonical, additional mismatches may appear beyond SDDM, Plymouth, and boot config. That is expected and should be resolved systematically rather than patched ad hoc.

### 3. Offline package parity requires infrastructure choices

Ryoku cannot indefinitely avoid the package-source problem if it wants Omarchy-level offline parity. Even if Phase 1 hardening ships first, Phase 4 is still required to fully close the architectural gap.

## Verification Standard

The work is only complete when a fresh install from a newly built ISO onto a new VM disk proves all of the following:

1. No reuse of the previously broken ISO artifact.
2. No reuse of the previously broken VM disk/install state.
3. ISO/offline cache state refreshed so stale package artifacts do not mask problems.
4. Installed system boots through the intended Ryoku production path.
5. Boot visuals are Ryoku-branded instead of generic fallback visuals.
6. Encrypted-volume passphrase prompt is Ryoku-branded.
7. SDDM shows `pixel-rainyroom`.
8. User can log into the Ryoku session successfully.
9. VM NAT ethernet works on the installed system's first boot.

## Decision

Proceed with Option 3:

- immediate hardening of the current installer so broken parity fails
- then convergence to Omarchy-style offline package and boot-path architecture

This is the safest route to production because it stops accepting broken installs while still moving Ryoku to the correct long-term model.
