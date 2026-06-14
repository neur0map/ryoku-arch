# Always-on baseline role: nix/boot/services modules + core/networking packages,
# plus locale, timezone, console, and the default distro user.
{ lib, pkgs, ... }:
{
  imports = [
    ../modules/nix
    ../modules/boot
    ../modules/services
    ../packages/core.nix
    ../packages/networking.nix
  ];

  # Locale, timezone, console. mkDefault so a host or the installer can override.
  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # Default distro user. wheel grants sudo. The installer (or first login) MUST
  # change initialPassword: it is a known bootstrap secret, not a real password.
  users.users.ryoku = {
    isNormalUser = true;
    description = "Ryoku";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    shell = pkgs.fish;
    initialPassword = "ryoku";
  };

  programs.fish.enable = true;

  security.sudo.wheelNeedsPassword = true;
}
