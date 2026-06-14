# v2 S2: launch the Ryoku Quickshell shell in the Hyprland session. quickshell
# (qs) loads the native Ryoku.* plugins from ryoku-shell's qml dir and runs the
# installed config tree. The shell is started from a minimal system Hyprland
# config via exec-once, so it inherits the compositor environment it needs
# (HYPRLAND_INSTANCE_SIGNATURE, WAYLAND_DISPLAY). greetd launches the session
# script ryoku-hypr-session (see modules/desktop). The full rice (keybinds,
# theming, the ryoku-* runtime) lands in later v2 slices.
{ pkgs, lib, ... }:
let
  shell = pkgs.ryoku-shell;
  qs = pkgs.quickshell;
  shellConfig = "${shell}/etc/xdg/quickshell/ryoku-shell";
  qsipc = "${qs}/bin/qs -p ${shellConfig} ipc call";
  # ryoku-shell installs its native plugins under lib/qt6/qml; the extra Qt QML
  # modules the shell imports beyond quickshell's base Qt (Qt5Compat.GraphicalEffects
  # and QtMultimedia) live under each package's lib/qt-6/qml.
  qmlPath = lib.concatStringsSep ":" (
    [ "${shell}/lib/qt6/qml" ]
    ++ map (p: "${p}/lib/qt-6/qml") [ pkgs.qt6.qt5compat pkgs.qt6.qtmultimedia pkgs.kdePackages.kirigami.unwrapped ]
  );

  wallpapers = pkgs.ryoku-wallpapers;
  wallsDir = "${wallpapers}/share/ryoku/wallpapers";
  defaultWall = "${wallsDir}/ryoku-default.png";

  # greetd launches this. Seed the default wallpaper into user state
  # (fill-if-missing, so a user's own choice is never overwritten) before
  # starting Hyprland; the shell's Wallpapers service watches path.txt.
  ryoku-hypr-session = pkgs.writeShellScriptBin "ryoku-hypr-session" ''
    export PATH=${pkgs.ryoku-theme-tools}/bin:$PATH
    state="''${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-shell"
    mkdir -p "$state/wallpaper"
    if [ ! -s "$state/wallpaper/path.txt" ]; then
      printf '%s' "${defaultWall}" > "$state/wallpaper/path.txt"
      printf 'image' > "$state/wallpaper/type.txt"
    fi
    # Generate the initial Material You scheme from the wallpaper; the shell
    # regenerates it on later wallpaper changes. Best-effort.
    if [ ! -s "$state/scheme.json" ]; then
      ${shellConfig}/scripts/ryoku scheme from-wallpaper >/dev/null 2>&1 || true
    fi
    exec ${pkgs.hyprland}/bin/Hyprland --config /etc/ryoku/hyprland.conf
  '';
in
{
  # Wayland tools the shell shells out to at runtime (clipboard, brightness,
  # screenshots, mpris, sensors, night light, audio visualiser, notifications).
  # The full ryoku-* CLI port is a later v2 slice; these are the in-nixpkgs deps.
  environment.systemPackages = [
    qs
    shell
    ryoku-hypr-session
    pkgs.ryoku-theme-tools
  ]
  ++ (with pkgs; [
    wl-clipboard
    cliphist
    brightnessctl
    ddcutil
    wlsunset
    grim
    slurp
    libnotify
    playerctl
    lm_sensors
    cava
    xdg-utils
    adwaita-icon-theme
    papirus-icon-theme
  ]);

  # Fonts the shell's appearance config names (appearanceconfig.hpp defaults):
  # the Material Symbols icon font is required, else MaterialIcon falls back to
  # rendering glyph NAMES as text and the bar overflows. Rubik = clock, the
  # Caskaydia Nerd Font = monospace.
  fonts.packages = with pkgs; [
    material-symbols
    rubik
    nerd-fonts.caskaydia-cove
  ];

  environment.etc."ryoku/hyprland.conf".text = ''
    # Plugins + the extra Qt QML modules the shell imports.
    env = QML_IMPORT_PATH,${qmlPath}
    env = QML2_IMPORT_PATH,${qmlPath}
    env = RYOKU_SHELL_WALLPAPERS_DIR,${wallsDir}
    env = RYOKU_SHELL_RUNTIME_DIR,${shellConfig}

    exec-once = ${qs}/bin/qs -p ${shellConfig}

    # Window management.
    bind = SUPER, Return, exec, ${pkgs.foot}/bin/foot
    bind = SUPER, Q, killactive
    bind = SUPER, M, exit
    bind = SUPER, F, fullscreen
    bind = SUPER, E, togglefloating
    bind = SUPER, left, movefocus, l
    bind = SUPER, right, movefocus, r
    bind = SUPER, up, movefocus, u
    bind = SUPER, down, movefocus, d

    # Ryoku shell surfaces (Quickshell IPC).
    bind = SUPER, Space, exec, ${qsipc} drawers toggle launcher
    bind = SUPER, Tab, exec, ${qsipc} drawers toggle dashboard
    bind = SUPER, A, exec, ${qsipc} controlCenter toggle
    bind = SUPER, V, exec, ${qsipc} clipboard toggle
    bind = SUPER, Backspace, exec, ${qsipc} lockscreen lock
    bind = , Print, exec, ${qsipc} picker openFreeze

    # Workspaces.
    bind = SUPER, 1, workspace, 1
    bind = SUPER, 2, workspace, 2
    bind = SUPER, 3, workspace, 3
    bind = SUPER, 4, workspace, 4
    bind = SUPER, 5, workspace, 5
    bind = SUPER SHIFT, 1, movetoworkspace, 1
    bind = SUPER SHIFT, 2, movetoworkspace, 2
    bind = SUPER SHIFT, 3, movetoworkspace, 3
    bind = SUPER SHIFT, 4, movetoworkspace, 4
    bind = SUPER SHIFT, 5, movetoworkspace, 5

    # Media and brightness keys.
    bindel = , XF86AudioRaiseVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
    bindel = , XF86AudioLowerVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindl = , XF86AudioMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindel = , XF86MonBrightnessUp, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 5%+
    bindel = , XF86MonBrightnessDown, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 5%-
  '';
}
