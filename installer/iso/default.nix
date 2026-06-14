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
  isoImage.isoName = lib.mkDefault "ryoku.iso";
  isoImage.volumeID = lib.mkDefault "RYOKU";
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  # Bake the repo into the live image so the installer can build offline
  # from /etc/ryoku/flake (RYOKU_FLAKE default in ryoku-install).
  isoImage.contents = [
    {
      source = ../..;
      target = "/etc/ryoku/flake";
    }
  ];

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
  ];

  services.getty.autologinUser = lib.mkDefault "root";

  # Auto-run the installer on the primary VT and the serial console.
  programs.bash.loginShellInit = ''[[ $(tty) =~ tty1|ttyS0 ]] && exec ryoku-install'';

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
