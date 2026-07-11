# installation/tests/

Install tests that prove a real Ryoku install succeeds before a user hits a
broken one. Run by the Install test workflow (after a Build ISO, weekly, and on
demand); see `docs/updates.md` for the delivery contract they guard.

- `container-install.sh [arch|cachyos]` builds the Ryoku packages from the
  checkout, installs `ryoku-desktop`, runs `ryoku materialize` as a throwaway
  user, and asserts the materialized `~/.config` is complete. Fast and hermetic
  (a container, no VM). Catches a config that reaches no install and a package
  whose dependencies do not resolve.

- `install-vm.py --iso <iso>` boots the ISO in QEMU, runs the installer
  unattended against a virtual disk (driving the live root shell over the serial
  console), waits for `@@RYOKU_DONE`, then mounts the installed root and asserts
  the tree (the package, the materialized config, the bootloader, the greeter).
  `--boot-only` just reaches the live shell; `--dry` runs the installer in
  `RYOKU_DRYRUN` mode. Uses KVM when `/dev/kvm` is present, else TCG. Needs
  `qemu`, `edk2-ovmf`, and `python-pexpect`.

- `iso-stage-check.sh` stages the ISO profile twice (`iso/build.sh --stage-only`
  into two throwaway dirs) and diffs the trees, proving the prebuilt binaries and
  the baked payload are byte-reproducible for a fixed commit (see
  `iso/README.md`, "Reproducibility"). It strips the `.payload` provenance stamp
  before diffing, and skips cleanly (exit 0) when `go`/`cmake`/`ninja` are absent
  so CI without the build toolchain stays green.
