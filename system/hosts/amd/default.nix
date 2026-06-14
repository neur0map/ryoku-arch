# Generic AMD-only install target (no dGPU); imports the amd-only profile.
# Machine specifics (real hardware-configuration) are resolved at install time
# by ryoku-install.
{ inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ../../../installer/disko/btrfs-uefi.nix
    ./hardware-configuration.nix
    ../../roles/base.nix
    ../../modules/desktop
    ../../modules/hardware/profiles/amd-only.nix
  ];

  networking.hostName = "ryoku";

  # Set ONCE at install; never bump. Tracks the install release, not the running version.
  system.stateVersion = "26.05";
}
