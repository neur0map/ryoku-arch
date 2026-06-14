# Ryoku install-mechanism nixos test (P2): in a sandboxed VM, partition a blank
# disk, install the prebuilt base closure offline (nixos-install --system), and
# assert the target holds a bootable system (system profile + NIXOS marker +
# systemd-boot ESP). This is the CI-runnable gate.
#
# Full install + reboot + runtime health (P3-P5) is validated end to end on host
# KVM by ~/Work/ryoku-nix-build/artifacts/install-test.py (real disko +
# ryoku-install -> boot -> tuigreet -> Hyprland). P1 (ISO reaches the installer)
# is the qemu boot smoke-test in CI; P6/P7 are build-only / physical hardware.
#
# Run: nix build .#checks.x86_64-linux.install-base
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
    { pkgs, ... }:
    {
      # A plain NixOS VM with the install tools. Importing installation-cd-minimal
      # pulls the installation-device profile, which sets nixpkgs.overlays and
      # conflicts with runNixOSTest's read-only nixpkgs.
      environment.systemPackages = with pkgs; [
        parted
        dosfstools
        e2fsprogs
        nixos-install-tools
      ];

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

    # P2: partition + format the target disk (GPT/EFI + ext4 root), generate the
    # machine hardware config, and install the prebuilt closure fully offline.
    machine.succeed("parted -s /dev/vdb mklabel gpt")
    machine.succeed("parted -s /dev/vdb mkpart ESP fat32 1MiB 512MiB set 1 esp on")
    machine.succeed("parted -s /dev/vdb mkpart root ext4 512MiB 100%")
    machine.succeed("udevadm settle")
    machine.succeed("mkfs.fat -F32 -n ESP /dev/vdb1")
    machine.succeed("mkfs.ext4 -L root /dev/vdb2")
    machine.succeed("mount /dev/vdb2 /mnt")
    machine.succeed("mkdir -p /mnt/boot")
    machine.succeed("mount /dev/vdb1 /mnt/boot")

    machine.succeed("nixos-generate-config --root /mnt")
    machine.succeed(
        "nixos-install --root /mnt --no-root-passwd --system ${installedSystem} >&2"
    )

    # Assert the install produced a bootable system on the target: the system
    # profile, the NixOS marker, and a systemd-boot ESP. Reboot + runtime health
    # (P3-P5) is covered on host KVM by artifacts/install-test.py.
    machine.succeed("test -L /mnt/nix/var/nix/profiles/system")
    machine.succeed("test -e /mnt/etc/NIXOS")
    machine.succeed("test -d /mnt/boot/EFI")
    machine.succeed("umount -R /mnt")
  '';
}
