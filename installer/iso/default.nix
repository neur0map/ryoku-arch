# Ryoku live-ISO layer. Pure additions on top of the upstream
# installation-cd-minimal module imported by the iso host. Sets branding,
# bakes the flake into the image, and auto-starts the installer on the
# console getty.
#
# v2 brings boot-splash / Plymouth art and the Cachix substituter + public
# key; v1 ships no branding asset and substitutes from cache.nixos.org only.
{
  pkgs,
  lib,
  self ? null,
  ...
}:
{
  # Fixed name and label. self may be unavailable at eval, so the image
  # name is a stable constant rather than a flake rev.
  image.fileName = lib.mkDefault "ryoku.iso";
  isoImage.volumeID = lib.mkDefault "RYOKU";
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  # Bake the flake SOURCE into the live system at /etc/ryoku/flake (the
  # RYOKU_FLAKE default), so the installer can target .#<profile>. cleanSource
  # drops .git and build outputs. Flake inputs and the system closure resolve
  # over the network or a substituter; fully-offline media is a v2 task.
  environment.etc."ryoku/flake".source = lib.cleanSource ../..;

  # Installer toolchain available in the live session.
  environment.systemPackages =
    (with pkgs; [
      gum
      disko
    ])
    ++ [ pkgs.ryoku-install ];

  # Serial + VGA console so the CI smoke-test can read the installer header
  # off the serial log.
  boot.kernelParams = [
    "console=ttyS0,115200"
    "console=tty0"
    "consoleblank=0"
  ];

  # Adopt the 26.11 default early: silences the warning and avoids risky imports.
  boot.zfs.forceImportRoot = false;

  # Force root so the auto-started installer has the privileges it needs; the
  # upstream installer image autologs in as the unprivileged "nixos" user.
  services.getty.autologinUser = lib.mkForce "root";

  # Auto-run the installer on the primary framebuffer VT only. Restricting to
  # tty1 avoids a second instance racing on the serial console (both gettys
  # autologin root); headless installs run ryoku-install by hand.
  programs.bash.loginShellInit = ''[[ $(tty) == /dev/tty1 ]] && exec ryoku-install'';

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
