# Generic Intel CPU/iGPU install target; imports the intel profile.
# Machine specifics (real hardware-configuration) are resolved at install time
# by ryoku-install.
{ inputs, lib, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ../../../installer/disko/btrfs-uefi.nix
    ./hardware-configuration.nix
    ../../roles/base.nix
    ../../modules/desktop
    ../../modules/hardware/profiles/intel.nix
  ];

  networking.hostName = lib.mkDefault "ryoku";

  # Set ONCE at install; never bump. Tracks the install release, not the running version.
  system.stateVersion = "26.05";
}
