# v1-MINIMAL desktop substrate: just enough to reach a bare Hyprland session
# for manual hardware testing. NO Quickshell shell, NO bar, NO widgets, NO theme
# engine here. In v2 this is replaced by SDDM + qylock for the greeter/lock path
# and the Quickshell-based Ryoku shell for the session itself.
{ pkgs, ... }:

{
  imports = [
    ../../packages/desktop.nix
    ../../packages/fonts.nix
    ../../packages/theming.nix
    ./shell.nix
  ];

  # Hyprland compositor. withUWSM wraps the session in the Universal Wayland
  # Session Manager (systemd user session, cleaner service scoping).
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # Wayland desktop portals. The Hyprland portal is pulled in automatically by
  # programs.hyprland; the GTK portal covers file chooser / settings.
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
  };

  # Minimal login manager: tuigreet launches Hyprland directly.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ryoku-hypr-session";
      user = "greeter";
    };
  };

  # Audio stack.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  security.rtkit.enable = true;

  # Input handling for the Wayland session.
  services.libinput.enable = true;

  # Power management. The shell's battery indicator and power-profile switcher
  # talk to UPower and power-profiles-daemon over D-Bus; without them the qs log
  # reports both as ServiceUnknown and those widgets have no data.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
}
