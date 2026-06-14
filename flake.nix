{
  description = "Ryoku: a NixOS-based Hyprland distribution (v1: base OS, shell lands in v2)";

  inputs = {
    # Official source, pinned. Latest stable: 25.11 reaches end of life 2026-06-30,
    # so v1 tracks 26.05. flake.lock is the reproducibility artifact.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned by the lock but wired to nothing in v1; reserved for the v2 shell + home layer.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Flake-output pkgs. Host pkgs get the same overlay + unfree predicate via
      # system/modules/nix, so nvidia evaluates inside hosts too.
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
          config.allowUnfreePredicate =
            pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [
              "nvidia-x11"
              "nvidia-settings"
              "nvidia-persistenced"
            ];
        };

      ryokuLib = import ./lib { inherit inputs; };
      inherit (ryokuLib) mkHost;
    in
    {
      # Hosts and image targets. Names double as the installer profile keys
      # (disko-install --flake .#<name>); the dev laptop installs amd-nvidia.
      nixosConfigurations = {
        iso = mkHost { modules = [ ./system/hosts/iso ]; };
        vm = mkHost { modules = [ ./system/hosts/vm ]; };
        amd-nvidia = mkHost { modules = [ ./system/hosts/amd-nvidia ]; };
        amd = mkHost { modules = [ ./system/hosts/amd ]; };
        intel = mkHost { modules = [ ./system/hosts/intel ]; };
      };

      # Ryoku-built packages plus the ISO image: nix build .#iso
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          ryoku-cli = pkgs.ryoku-cli;
          ryoku-install = pkgs.ryoku-install;
          iso = self.nixosConfigurations.iso.config.system.build.isoImage;
          default = pkgs.ryoku-cli;
        }
      );

      # Reusable surface for v2 and external importers.
      nixosModules = {
        base = ./system/roles/base.nix;
        nix = ./system/modules/nix;
        desktop = ./system/modules/desktop;
      };

      overlays.default = import ./overlays/default.nix;

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nixfmt
              nil
              disko
              git
            ];
          };
        }
      );
    };
}
