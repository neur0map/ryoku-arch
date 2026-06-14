# v1-MINIMAL Wayland utilities: a terminal, launcher, screenshot/clipboard
# tools, media controls, and a file manager. The full Ryoku application set
# (browsers, editors, the curated app catalogue) lands in v2.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    kitty
    fuzzel
    grim
    slurp
    wl-clipboard
    brightnessctl
    playerctl
    mpv
    imv
    nautilus
  ];
}
