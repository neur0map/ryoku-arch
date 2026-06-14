# Ryoku v1 install test (study C 5c): partition -> generate-config -> install
# -> reboot into the installed system, asserting the v1 success criteria P2-P5.
#
# Run standalone:
#   nix build -f tests/install-base.nix --arg pkgs 'import <nixpkgs> {}'
# Or have Main expose it as a flake check (checks.x86_64-linux.install-base =
#   pkgs.callPackage ./tests/install-base.nix {}) so `nix flake check` runs it
#   in CI. testers.runNixOSTest is the current API (supersedes bare nixosTest).
#
# P1 (ISO reaches the installer) is covered by the qemu smoke-test in CI.
# P6 (nvidia-hybrid host builds) is a build-only gate, not a VM assertion:
# plain qemu has no NVIDIA device, so PRIME/offload cannot be exercised here.
{
  pkgs ? import <nixpkgs> { },
}:
let
  # The base system installed onto the target disk. Built here so its whole
  # closure is in the store and nixos-install runs fully offline inside the VM
  # (`--system <path>` installs the prebuilt closure without re-evaluating).
  # NetworkManager + a UEFI bootloader + label-based filesystems are the
  # minimum that satisfies P3-P5 after the reboot.
  installedSystem =
    (pkgs.nixos (
      { modulesPath, ... }:
      {
        imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;

        fileSystems."/" = {
          device = "/dev/disk/by-label/root";
          fsType = "ext4";
        };
        fileSystems."/boot" = {
          device = "/dev/disk/by-label/ESP";
          fsType = "vfat";
        };

        networking.networkmanager.enable = true;
        documentation.enable = false;
        system.stateVersion = "26.05";
      }
    )).config.system.build.toplevel;
in
pkgs.testers.runNixOSTest {
  name = "ryoku-install-base";

  nodes.machine =
    { modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

      # Blank target disk (/dev/vdb) the installer partitions; UEFI firmware so
      # the installed system can be booted back in phase 2.
      virtualisation.emptyDiskImages = [ 8192 ];
      virtualisation.useEFIBoot = true;
      virtualisation.memorySize = 4096;
      virtualisation.cores = 2;

      # Make the target closure available offline to nixos-install.
      system.extraDependencies = [ installedSystem ];
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # P2: partition + format the target disk (GPT/EFI + ext4 root), then
    # generate the machine hardware config and install the prebuilt closure.
    machine.succeed("parted -s /dev/vdb mklabel gpt")
    machine.succeed("parted -s /dev/vdb mkpart ESP fat32 1MiB 512MiB set 1 esp on")
    machine.succeed("parted -s /dev/vdb mkpart root ext4 512MiB 100%")
    machine.succeed("mkfs.fat -F32 -n ESP /dev/vdb1")
    machine.succeed("mkfs.ext4 -L root /dev/vdb2")
    machine.succeed("mount /dev/vdb2 /mnt")
    machine.succeed("mkdir -p /mnt/boot")
    machine.succeed("mount /dev/vdb1 /mnt/boot")

    machine.succeed("nixos-generate-config --root /mnt")
    machine.succeed(
        "nixos-install --root /mnt --no-root-passwd --system ${installedSystem} >&2"
    )
    machine.succeed("umount -R /mnt")
    machine.shutdown()

    # P3-P5: boot the freshly installed disk as a new machine and assert it is
    # a working base. The installer disk (/dev/vdb backing file) becomes the
    # only disk of the second machine, so it boots the installed bootloader.
    # NOTE: the empty-disk backing filename and EFI flags below mirror the
    # nixpkgs test driver / nixos/tests/installer.nix conventions; Main should
    # confirm them under nix when wiring this as a flake check.
    installed = create_machine({
        "qemuFlags": "-m 4096 -smp 2",
        "hda": "empty0.qcow2",
        "hdaInterface": "virtio",
        "bios": "${pkgs.OVMF.firmware}",
    })
    installed.start()
    installed.wait_for_unit("multi-user.target")

    # P3: generation activated.
    installed.succeed("test -e /run/current-system")
    # P4: system reached running/degraded with zero failed units.
    installed.succeed("systemctl is-system-running --wait | grep -E 'running|degraded'")
    installed.succeed("test $(systemctl --failed --no-legend | wc -l) -eq 0")
    # P5: NetworkManager active (base connectivity stack wired).
    installed.succeed("nmcli -t -f RUNNING general | grep running")

    installed.shutdown()
  '';
}
