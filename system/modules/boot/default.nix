# Bootloader and initrd. systemd-boot for zero-config UEFI plus a generations menu.
# limine branding is v2; v1 stays on the in-tree, reliable loader.
{ lib, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 20;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.systemd.enable = true;

  # Latest kernel for recent silicon (Phoenix 780M, Ada RTX 4060). mkDefault so a
  # host can pin an older series if a regression appears.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
}
