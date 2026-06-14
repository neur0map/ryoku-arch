# Ryoku's own typed configuration options. v1 seeds only the primary username
# (set at install time via disko-install --system-config). The full typed
# config layer (options.ryoku.*) is built out in v2.
{ lib, ... }:
{
  options.ryoku.username = lib.mkOption {
    type = lib.types.str;
    default = "ryoku";
    example = "alice";
    description = "Primary user account name.";
  };
}
