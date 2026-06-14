{ pkgs, ... }:
{
  # Radeon 780M (Phoenix1) iGPU, the primary renderer on the hybrid box.
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # lib32 (Steam / 32-bit games)
    # RADV (Vulkan) + radeonsi ship inside mesa on modern nixpkgs; VAAPI/VDPAU extras only:
    extraPackages = with pkgs; [
      libva-vdpau-driver # VA-API
      libvdpau-va-gl
    ];
  };
  # amdgpu loads automatically for Phoenix1; force early KMS for a clean handoff.
  boot.initrd.kernelModules = [ "amdgpu" ];
}
