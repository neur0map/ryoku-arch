# Branch model and the product / provisioning boundary

Ryoku ships from **two branches only**: `main` (stable) and `unstable-dev`
(rolling preview). Both carry the *whole* product, the shell and the OS/ISO layer
together, so the shell and the ISO can never drift. There is **no generated
`ryoku-shell` branch** any more: standalone shell installs pull a channel branch
directly.

> **History:** a generated `ryoku-shell` branch (`main` minus `iso/`) used to be
> published by a `publish-ryoku-shell` workflow so non-Arch users skipped the ISO
> builder on clone. It was dropped: the standalone deploy already excludes `iso/`
> from what lands on a machine, so the only cost of cloning `main` is a little
> bandwidth, and removing the branch removes a whole publish-and-sync chore.

## The one boundary: product vs provisioning

The repo has two responsibilities. Keeping them legible is the whole point; they
are separated by purpose (and enforced by the install profiles + manifest tags
below), not by living in different branches.

| Surface | What it is | Lives in |
|---|---|---|
| **Product** (everything the shell *is* and runs) | the shell, its commands, config, libs, themes, in-tree packages | `shell/`, `bin/`, `config/`, `lib/`, `default/`, `themes/`, `vendor/`, `wallpapers/`, `applications/`, `assets/`, `migrations/`, `distro/arch/` |
| **Provisioning** (how the product gets onto a machine) | the install engine, dependency/driver manifests, ISO builder, standalone bootstrap | `install/`, `iso/`, `shell-install/` |

A machine receives a **git checkout** of the channel branch at
`~/.local/share/ryoku` (both the ISO install and the standalone installer deploy
this way), so an installed user can `ryoku-update` (which is `git pull` based) on
the same channel they installed.

## One source of truth, consumed by both installers

- **Dependencies + drivers:** `install/ryoku-{base,aur,other}.packages` are the
  only package lists. Packages the OS layer owns (bootloader, display manager,
  kernel hooks) sit inside an `# @os-only` ... `# @end` region; the OS install
  ignores the tags and installs everything, the standalone skips `@os-only`.
- **cava-ryoku / libcava:** built once by `install/packaging/distro-arch.sh`
  (prebuilt-first), used by the ISO install, `ryoku-update`, and the standalone.
- **Drivers:** `install/config/hardware/*.sh`. The OS install applies them in
  full; the standalone runs the GPU/firmware subset with `RYOKU_BOOT_CONFIG=0`
  (driver packages only, no `/etc`/initramfs/bootloader writes). Pass
  `shell-install/install --with-boot-config` for full ISO parity.

Net: edit `shell/` (and the manifests / driver scripts / `distro-arch.sh`) once,
and the ISO, OS install, and standalone all get it. There is nothing to hand-sync
and no branch to publish.

## How a standalone install picks its channel

`shell-install/boot.sh` defaults `RYOKU_REF=main`; override with
`RYOKU_REF=unstable-dev`. The deploy then makes `~/.local/share/ryoku` a git
checkout that tracks that branch, so `ryoku-update` follows the same channel
(channels are defined in `lib/ryoku-update-core.sh`).

## Adding support for another distro (future)

Only `shell-install/distros/` changes: register the distro's `/etc/os-release`
`ID` in `detect.sh` and implement the contract in a `<family>.sh` adapter
(`ryoku_distro_system_update`, `ryoku_distro_prereqs`,
`ryoku_distro_install_full`). The adapter decides *how* to install; the package
data stays in the shared manifests. The OS/ISO layer is never touched.
