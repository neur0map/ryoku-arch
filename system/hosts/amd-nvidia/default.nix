# Generic AMD iGPU + NVIDIA dGPU hybrid install target (nvidia-hybrid profile).
# Machine specifics (real hardware-configuration, PRIME busIds) are resolved at
# install time by ryoku-install; the committed busIds in the profile are dev-box
# defaults the installer overrides per machine.
{ inputs, lib, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ../../../installer/disko/btrfs-uefi.nix
    ./hardware-configuration.nix
    ../../roles/base.nix
    ../../modules/desktop
    ../../modules/hardware/profiles/nvidia-hybrid.nix
  ];

  networking.hostName = lib.mkDefault "ryoku";

  # Set ONCE at install; never bump. Tracks the install release, not the running version.
  system.stateVersion = "26.05";
}
