# Baseline CLI tier: shells helpers, finders, TUIs, and system utilities. No GUI apps.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Editors and version control
    git
    vim
    neovim

    # Network fetchers
    curl
    wget

    # Search and navigation
    ripgrep
    fd
    fzf
    bat
    eza
    zoxide

    # Data and inspection
    jq
    tree

    # Process and system monitors
    htop
    btop
    fastfetch

    # Sessions and archives
    tmux
    unzip

    # Hardware and system utilities
    pciutils
    usbutils
    util-linux

    # Build tooling
    gnumake
  ];
}
