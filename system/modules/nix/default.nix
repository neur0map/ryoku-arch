# Nix daemon settings, the ryoku overlay, the host-side unfree allowlist (nvidia
# only in v1), garbage collection, and the flake registry pin.
{ inputs, lib, ... }:
{
  nixpkgs.overlays = [ (import ../../../overlays/default.nix) ];

  # Auditable allowlist instead of a blanket allowUnfree. Only the nvidia bits.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "nvidia-x11"
      "nvidia-settings"
      "nvidia-persistenced"
    ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" "@wheel" ];
    substituters = [ "https://cache.nixos.org" ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Pin `nix run nixpkgs#...` to the flake's pinned nixpkgs.
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
}
