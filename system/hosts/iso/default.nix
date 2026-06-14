# Branded installer ISO: the official console-only minimal installer plus the
# Ryoku ISO branding/installer layer (volumeID, isoName, overlay, ryoku-install
# in the live session). `nix build .#iso` builds this host's isoImage.
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ../../modules/nix
    ../../../installer/iso
  ];

  system.stateVersion = "26.05";
}
