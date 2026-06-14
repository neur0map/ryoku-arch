# v1-MINIMAL toolkit theming: an icon theme, a cursor theme, and the qt6ct
# config tool. Wiring Qt/GTK platform theming and dynamic color schemes is the
# Ryoku theming pipeline, which arrives in v2.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    papirus-icon-theme
    bibata-cursors
    qt6Packages.qt6ct
  ];
}
