{ pkgs, ... }:
{
  # Intel iGPU. ANV (Vulkan) + iris ship inside mesa; VAAPI/QSV extras only:
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # iHD VAAPI (Gen8+)
      vpl-gpu-rt # oneVPL runtime (QSV)
      libvpl
    ];
  };
}
