{ ... }:
{
  # nixos-generate-config also emits this in hardware-configuration.nix; declaring it
  # here keeps the AMD profile self-contained.
  hardware.cpu.amd.updateMicrocode = true;
  boot.kernelModules = [ "kvm-amd" ];
}
