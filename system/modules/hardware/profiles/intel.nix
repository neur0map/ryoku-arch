{ inputs, ... }:
{
  imports = [
    ../gpu-intel.nix
    ../laptop.nix
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
  ];
  services.thermald.enable = true; # Intel-only thermal management
}
