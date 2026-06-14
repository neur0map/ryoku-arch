# v1-MINIMAL font set: Noto for broad coverage (incl. CJK + emoji), Font Awesome
# for icon glyphs, and a JetBrains Mono Nerd Font for the terminal/monospace.
{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      font-awesome
      nerd-fonts.jetbrains-mono
    ];
    enableDefaultPackages = true;
  };
}
