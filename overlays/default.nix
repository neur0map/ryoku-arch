# nixpkgs overlay exposing the Ryoku-built packages. Wired into both the
# flake-output pkgs and host pkgs (via system/modules/nix) so pkgs.ryoku-*
# resolve everywhere.
final: prev: {
  ryoku-cli = final.callPackage ../pkgs/ryoku-cli { };
  ryoku-install = final.callPackage ../pkgs/ryoku-install { };
}
