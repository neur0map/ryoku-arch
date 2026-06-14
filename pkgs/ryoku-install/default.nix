# Package the installer script as a ShellCheck-gated wrapper with its
# runtime dependencies on PATH. disko provides disko-install;
# nixos-install-tools provides nixos-enter; util-linux provides lsblk and
# the mount/umount helpers.
#
# Packaging note: in nixpkgs 26.05 disko is a top-level package
# (pkgs.disko), so this callPackage arg resolves from the overlay's pkgs
# set. If a given channel lacks it, pass it through from the disko flake
# input instead: callPackage ./ryoku-install { disko = inputs.disko.packages.${system}.default; }.
{
  writeShellApplication,
  disko,
  util-linux,
  gum,
  nixos-install-tools,
  git,
}:
writeShellApplication {
  name = "ryoku-install";
  runtimeInputs = [
    disko
    util-linux
    gum
    git
    nixos-install-tools
  ];
  text = builtins.readFile ../../installer/script/ryoku-install;
}
