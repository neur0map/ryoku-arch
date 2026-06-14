# v1-MINIMAL toolkit theming: an icon theme, a cursor theme, and Qt platform
# theming so Qt apps follow a consistent look. This is plumbing only; the Ryoku
# theming pipeline (dynamic color schemes, GTK/Qt sync, app-color propagation)
# arrives in v2.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    papirus-icon-theme
    bibata-cursors
    qt6ct
  ];

  qt = {
    enable = true;
    platformTheme = "qt6ct";
  };
}
