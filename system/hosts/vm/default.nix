# VM test host for `nixos-rebuild build-vm` and the PR-gate toplevel build.
# The fileSystems and bootloader entries are minimal stubs so the config
# evaluates and builds outside a VM; `build-vm` overrides the disk via
# mkVMOverride, and vmVariant pins headless serial-friendly resources.
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../roles/base.nix
    ../../modules/desktop
    ../../modules/hardware/profiles/generic.nix
  ];

  networking.hostName = "ryoku-vm";

  virtualisation.vmVariant = {
    virtualisation.memorySize = 4096;
    virtualisation.cores = 2;
    virtualisation.graphics = false;
  };

  # Stubs so the host evaluates and builds outside build-vm; build-vm supplies
  # its own virtual disk and bootloader.
  fileSystems."/" = {
    device = "/dev/vda";
    fsType = "ext4";
  };
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  system.stateVersion = "26.05";
}
