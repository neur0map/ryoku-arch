{ config, lib, ... }:
{
  # videoDrivers informs the nvidia module which derivation to pull; "amdgpu" is the iGPU.
  services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];

  hardware.nvidia = {
    open = true; # Ada / Turing+ -> open kernel modules
    modesetting.enable = true; # required for Wayland (KMS)
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
    powerManagement.enable = true; # save/restore VRAM across suspend
    powerManagement.finegrained = true; # power down dGPU when idle (offload)

    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true; # provides the `nvidia-offload` wrapper
      # busIds are dev-box defaults; the installer rewrites them per machine via lspci -D.
      amdgpuBusId = "PCI:101@0:0:0"; # Radeon 780M @ 0000:65:00.0
      nvidiaBusId = "PCI:1@0:0:0"; # RTX 4060   @ 0000:01:00.0
    };
  };
  # Unfree predicate for nvidia userspace lives in system/modules/nix; not duplicated here.
}
