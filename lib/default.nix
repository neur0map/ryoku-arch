# Ryoku Nix helpers. Kept tiny: mkHost is the only v1 export.
{ inputs }:
{
  # Build a NixOS system from a module list, exposing flake inputs to every
  # module via specialArgs (so hardware profiles can import nixos-hardware
  # and disko without touching flake.nix).
  mkHost =
    {
      system ? "x86_64-linux",
      modules,
    }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system modules;
      specialArgs = { inherit inputs; };
    };
}
