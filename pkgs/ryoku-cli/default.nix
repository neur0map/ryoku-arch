# ryoku-cli: a symlinkJoin of the Ryoku management commands. v1 ships one
# command (ryoku-update); later commands are added to ./commands and joined
# the same way.
{
  writeShellApplication,
  symlinkJoin,
  nixos-rebuild,
  git,
}:
let
  ryoku-update = writeShellApplication {
    name = "ryoku-update";
    runtimeInputs = [
      nixos-rebuild
      git
    ];
    text = builtins.readFile ./commands/ryoku-update;
  };
in
symlinkJoin {
  name = "ryoku-cli";
  paths = [ ryoku-update ];
}
