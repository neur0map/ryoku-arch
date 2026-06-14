# Placeholder hardware profile. Regenerate per machine at install with
# `nixos-generate-config --no-filesystems` (disko owns fileSystems, so the
# generator must not emit mount definitions). The values below are a safe
# minimal default that lets the host evaluate before generation.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "sd_mod" "virtio_pci" "virtio_blk" "virtio_scsi" "virtio_net" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
