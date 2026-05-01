import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"
import "../shapes"

PanelWindow {
  id: root

  Binding { target: Popups; property: "legacySettingsMenuVisible"; value: card.visible }

  readonly property int fw: Theme.notchRadius
  readonly property int fh: Theme.notchRadius
  readonly property int menuWidth: 456
  readonly property int menuHeight: 520
  readonly property int fullCardWidth: root.menuWidth + 2 * root.fw
  readonly property int fullCardHeight: Theme.notchHeight + root.menuHeight
  readonly property int initialCardHeight: Theme.notchHeight
  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string ryokuConfigPath: Quickshell.env("RYOKU_CONFIG_PATH") !== "" ? Quickshell.env("RYOKU_CONFIG_PATH") : root.homeDir + "/.config/ryoku"

  property bool windowVisible: false
  property real openProgress: Popups.legacySettingsMenuOpen ? 1 : 0
  property string currentPage: "home"
  property string currentSubpage: ""
  property string pageTitle: "Ryoku"
  property string pageKicker: "Control center"
  property string manageTab: "install"
  property bool wifiOn: false
  property string wifiSSID: ""
  property bool btOn: false
  property string btDevice: ""
  property bool airplaneOn: false
  property bool hotspotOn: false
  property bool hotspotBusy: false
  property bool hotspotWifiWasOff: false
  property bool hotspotOwnedByControlCenter: false
  property string hotspotLabel: ""
  property string hotspotSSID: "BrainShell"
  property string hotspotPassword: "changeme1"
  property string hotspotWifiIface: "wlan0"
  property string hotspotConfigPath: Quickshell.shellDir + "/src/user_data/hotspot.json"
  property bool nightLightOn: false
  property string currentFilter: ""
  property var filterList: []
  property bool filterPickerOpen: false
  property bool focusOwnedByControlCenter: false
  property string focusLabel: ""
  property bool rollbackAvailable: false
  property int savedGapsIn: 5
  property int savedGapsOut: 10

  Behavior on openProgress {
    enabled: !Theme.staticMode
    NumberAnimation {
      duration: Theme.motionExpandDuration
      easing.type: Popups.legacySettingsMenuOpen ? Easing.OutBack : Easing.OutQuart
      easing.overshoot: 1.06
    }
  }

  color: "transparent"
  visible: root.windowVisible
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  ListModel {
    id: quickControlsModel
    ListElement { label: "Wi-Fi"; icon: "wifi"; action: "wifi-toggle"; accent: "#7dc4e4" }
    ListElement { label: "Bluetooth"; icon: "bluetooth"; action: "bluetooth-toggle"; accent: "#8aadf4" }
    ListElement { label: "Airplane Mode"; icon: "airplane"; action: "airplane-toggle"; accent: "#f5a97f" }
    ListElement { label: "Hotspot"; icon: "hotspot"; action: "hotspot-toggle"; accent: "#91d7e3" }
    ListElement { label: "Night Light"; icon: "night"; action: "nightlight-toggle"; accent: "#eed49f" }
    ListElement { label: "Focus Mode"; icon: "focus"; action: "focus-toggle"; accent: "#a6da95" }
    ListElement { label: "Do Not Disturb"; icon: "dnd"; action: "dnd-toggle"; accent: "#ed8796" }
    ListElement { label: "Filter"; icon: "filter"; action: "filter-open"; accent: "#c6a0f6" }
  }

  ListModel {
    id: nativeSectionsModel
    ListElement { label: "Learn"; hint: "Docs and keys"; page: "learn"; accent: "#8aadf4" }
    ListElement { label: "Share"; hint: "Clipboard and files"; page: "share"; accent: "#91d7e3" }
    ListElement { label: "Style"; hint: "Theme and text"; page: "style"; accent: "#c6a0f6" }
    ListElement { label: "Setup"; hint: "Controls and config"; page: "setup"; accent: "#a6da95" }
    ListElement { label: "Manage"; hint: "Install, remove, maintain"; page: "manage"; accent: "#eed49f" }
    ListElement { label: "About"; hint: "Ryoku details"; page: "about"; accent: "#f5a97f" }
  }

  ListModel {
    id: learnActions
    ListElement { label: "Keybindings"; icon: "keys"; hint: "Shortcut reference"; action: "learn-keybindings"; accent: "#8aadf4" }
    ListElement { label: "Omarchy Manual"; icon: "docs"; hint: "Upstream manual"; action: "learn-omarchy"; accent: "#91d7e3" }
    ListElement { label: "Hyprland"; icon: "hypr"; hint: "Window manager docs"; action: "learn-hyprland"; accent: "#c6a0f6" }
    ListElement { label: "Arch"; icon: "arch"; hint: "Arch Wiki"; action: "learn-arch"; accent: "#7dc4e4" }
    ListElement { label: "Helix"; icon: "editor"; hint: "Editor docs"; action: "learn-helix"; accent: "#a6da95" }
    ListElement { label: "Bash"; icon: "terminal"; hint: "Shell cheatsheet"; action: "learn-bash"; accent: "#eed49f" }
  }

  ListModel {
    id: shareActions
    ListElement { label: "Clipboard"; icon: "clipboard"; hint: "Send text"; action: "share-clipboard"; accent: "#8bd5ca" }
    ListElement { label: "File"; icon: "file"; hint: "Pick file"; action: "share-file"; accent: "#f5a97f" }
    ListElement { label: "Folder"; icon: "folder"; hint: "Pick directory"; action: "share-folder"; accent: "#c6a0f6" }
  }

  ListModel {
    id: styleActions
    ListElement { label: "Theme"; icon: "palette"; hint: "Choose color theme"; action: "style-theme"; accent: "#c6a0f6" }
    ListElement { label: "Font"; icon: "type"; hint: "Choose interface font"; action: "style-font"; accent: "#eed49f" }
    ListElement { label: "Background"; icon: "image"; hint: "Choose wallpaper"; action: "style-background"; accent: "#91d7e3" }
    ListElement { label: "Hyprland look and feel"; icon: "hypr"; hint: "Edit compositor style"; action: "edit-hypr-look"; accent: "#8aadf4" }
    ListElement { label: "Screensaver text"; icon: "text"; hint: "Edit lock display copy"; action: "edit-screensaver-text"; accent: "#a6da95" }
    ListElement { label: "About text"; icon: "info"; hint: "Edit about copy"; action: "edit-about-text"; accent: "#f5a97f" }
  }

  ListModel {
    id: setupActions
    ListElement { label: "Audio"; icon: "audio"; hint: "Open audio controls"; action: "setup-audio"; accent: "#7dc4e4" }
    ListElement { label: "Wi-Fi setup"; icon: "wifi"; hint: "Open network setup"; action: "setup-wifi"; accent: "#8aadf4" }
    ListElement { label: "Bluetooth setup"; icon: "bluetooth"; hint: "Open device setup"; action: "setup-bluetooth"; accent: "#91d7e3" }
    ListElement { label: "Power Profile"; icon: "power"; hint: "Choose performance profile"; action: "page-power-profile"; accent: "#eed49f" }
    ListElement { label: "System Sleep"; icon: "sleep"; hint: "Suspend and hibernate setup"; action: "page-system-sleep"; accent: "#f5a97f" }
    ListElement { label: "Monitors"; icon: "display"; hint: "Edit monitor layout"; action: "edit-monitors"; accent: "#c6a0f6" }
    ListElement { label: "DNS"; icon: "dns"; hint: "Configure DNS"; action: "setup-dns"; accent: "#8bd5ca" }
    ListElement { label: "Security"; icon: "shield"; hint: "Auth devices"; action: "page-security"; accent: "#ed8796" }
    ListElement { label: "Config"; icon: "sliders"; hint: "Dotfiles and defaults"; action: "page-config"; accent: "#a6da95" }
    ListElement { label: "Hardware"; icon: "chip"; hint: "Device controls"; action: "page-hardware"; accent: "#7dc4e4" }
  }

  ListModel {
    id: setupPowerProfileActions
    ListElement { label: "Performance"; icon: "power"; hint: "Prefer speed"; action: "power-performance"; accent: "#ed8796" }
    ListElement { label: "Balanced"; icon: "power"; hint: "Default profile"; action: "power-balanced"; accent: "#eed49f" }
    ListElement { label: "Power Saver"; icon: "power"; hint: "Prefer battery"; action: "power-saver"; accent: "#a6da95" }
  }

  ListModel {
    id: setupSystemSleepActions
    ListElement { label: "Suspend toggle"; icon: "sleep"; hint: "Enable or disable suspend"; action: "sleep-suspend-toggle"; accent: "#f5a97f" }
    ListElement { label: "Hibernate setup"; icon: "sleep"; hint: "Configure hibernation"; action: "sleep-hibernate-setup"; accent: "#8aadf4" }
    ListElement { label: "Hibernate removal"; icon: "sleep"; hint: "Remove hibernation"; action: "sleep-hibernate-remove"; accent: "#ed8796" }
  }

  ListModel {
    id: setupSecurityActions
    ListElement { label: "Fingerprint"; icon: "fingerprint"; hint: "Configure fingerprint auth"; action: "setup-fingerprint"; accent: "#8aadf4" }
    ListElement { label: "Fido2"; icon: "key"; hint: "Configure hardware key auth"; action: "setup-fido2"; accent: "#c6a0f6" }
  }

  ListModel {
    id: setupConfigActions
    ListElement { label: "Dotfiles Hub"; icon: "folder-cog"; hint: "Open config browser"; action: "config-dotfiles"; accent: "#a6da95" }
    ListElement { label: "Defaults"; icon: "default"; hint: "Edit default apps"; action: "edit-defaults"; accent: "#eed49f" }
    ListElement { label: "Hyprland config"; icon: "hypr"; hint: "Edit main config"; action: "edit-hyprland"; accent: "#8aadf4" }
    ListElement { label: "Hypridle"; icon: "hypr"; hint: "Edit idle config"; action: "edit-hypridle"; accent: "#91d7e3" }
    ListElement { label: "Hyprlock"; icon: "hypr"; hint: "Edit lock config"; action: "edit-hyprlock"; accent: "#c6a0f6" }
    ListElement { label: "Hyprsunset"; icon: "hypr"; hint: "Edit sunset config"; action: "edit-hyprsunset"; accent: "#f5a97f" }
    ListElement { label: "Swayosd"; icon: "osd"; hint: "Edit OSD config"; action: "edit-swayosd"; accent: "#a6da95" }
    ListElement { label: "Launcher"; icon: "launcher"; hint: "Edit launcher config"; action: "edit-launcher"; accent: "#7dc4e4" }
    ListElement { label: "Waybar"; icon: "bar"; hint: "Edit legacy bar config"; action: "edit-waybar"; accent: "#ed8796" }
    ListElement { label: "XCompose"; icon: "keyboard"; hint: "Edit compose keys"; action: "edit-xcompose"; accent: "#8bd5ca" }
  }

  ListModel {
    id: setupHardwareActions
    ListElement { label: "Laptop Display"; icon: "display"; hint: "Toggle panel"; action: "hardware-laptop-display"; accent: "#7dc4e4" }
    ListElement { label: "Hybrid GPU"; icon: "gpu"; hint: "Switch mode"; action: "hardware-hybrid-gpu"; accent: "#eed49f" }
    ListElement { label: "Touchpad"; icon: "touchpad"; hint: "Toggle input"; action: "hardware-touchpad"; accent: "#a6da95" }
  }

  ListModel {
    id: manageTabsModel
    ListElement { label: "Install"; icon: "plus"; hint: "Add software"; action: "manage-install"; accent: "#a6da95" }
    ListElement { label: "Remove"; icon: "minus"; hint: "Clean software"; action: "manage-remove"; accent: "#ed8796" }
    ListElement { label: "Maintain"; icon: "wrench"; hint: "Care tasks"; action: "manage-maintain"; accent: "#eed49f" }
  }

  ListModel {
    id: manageInstallActions
    ListElement { label: "Package"; icon: "package"; hint: "Install packages"; action: "install-package"; accent: "#a6da95" }
    ListElement { label: "AUR"; icon: "arch"; hint: "Install AUR packages"; action: "install-aur"; accent: "#eed49f" }
    ListElement { label: "Web App"; icon: "web"; hint: "Install web app"; action: "install-webapp"; accent: "#91d7e3" }
    ListElement { label: "TUI"; icon: "terminal"; hint: "Install terminal UI"; action: "install-tui"; accent: "#8aadf4" }
    ListElement { label: "Service"; icon: "service"; hint: "Service installers"; action: "page-install-service"; accent: "#c6a0f6" }
    ListElement { label: "Style pack"; icon: "palette"; hint: "Theme, background, font"; action: "page-install-style"; accent: "#f5a97f" }
    ListElement { label: "Development"; icon: "code"; hint: "Language environments"; action: "page-install-development"; accent: "#7dc4e4" }
    ListElement { label: "Editor"; icon: "editor"; hint: "Editor installers"; action: "page-install-editor"; accent: "#a6da95" }
    ListElement { label: "Terminal"; icon: "terminal"; hint: "Terminal installers"; action: "page-install-terminal"; accent: "#8bd5ca" }
    ListElement { label: "AI"; icon: "ai"; hint: "AI tools"; action: "page-install-ai"; accent: "#c6a0f6" }
    ListElement { label: "Windows"; icon: "windows"; hint: "Install Windows VM"; action: "install-windows"; accent: "#8aadf4" }
    ListElement { label: "Gaming"; icon: "game"; hint: "Gaming installers"; action: "page-install-gaming"; accent: "#ed8796" }
  }

  ListModel {
    id: manageRemoveActions
    ListElement { label: "Package"; icon: "package"; hint: "Remove packages"; action: "remove-package"; accent: "#ed8796" }
    ListElement { label: "Web App"; icon: "web"; hint: "Remove web app"; action: "remove-webapp"; accent: "#91d7e3" }
    ListElement { label: "TUI"; icon: "terminal"; hint: "Remove terminal UI"; action: "remove-tui"; accent: "#8aadf4" }
    ListElement { label: "Development"; icon: "code"; hint: "Remove language environments"; action: "page-remove-development"; accent: "#7dc4e4" }
    ListElement { label: "Preinstalls"; icon: "clean"; hint: "Remove default extras"; action: "remove-preinstalls"; accent: "#f5a97f" }
    ListElement { label: "Dictation"; icon: "mic"; hint: "Remove voice input"; action: "remove-dictation"; accent: "#c6a0f6" }
    ListElement { label: "Theme"; icon: "palette"; hint: "Remove theme"; action: "remove-theme"; accent: "#eed49f" }
    ListElement { label: "Windows"; icon: "windows"; hint: "Remove Windows VM"; action: "remove-windows"; accent: "#8aadf4" }
    ListElement { label: "Fingerprint"; icon: "fingerprint"; hint: "Remove fingerprint auth"; action: "remove-fingerprint"; accent: "#a6da95" }
    ListElement { label: "Fido2"; icon: "key"; hint: "Remove hardware key auth"; action: "remove-fido2"; accent: "#8bd5ca" }
  }

  ListModel {
    id: manageMaintainActions
    ListElement { label: "Ryoku"; icon: "update"; hint: "Update Ryoku"; action: "maintain-ryoku"; accent: "#a6da95" }
    ListElement { label: "Channel"; icon: "branch"; hint: "Choose update channel"; action: "page-maintain-channel"; accent: "#eed49f" }
    ListElement { label: "Config refresh"; icon: "refresh"; hint: "Refresh default configs"; action: "page-maintain-config"; accent: "#91d7e3" }
    ListElement { label: "Extra Themes"; icon: "palette"; hint: "Update themes"; action: "maintain-extra-themes"; accent: "#c6a0f6" }
    ListElement { label: "Process"; icon: "process"; hint: "Restart user services"; action: "page-maintain-process"; accent: "#8aadf4" }
    ListElement { label: "Hardware restart"; icon: "hardware"; hint: "Restart hardware services"; action: "page-maintain-hardware"; accent: "#7dc4e4" }
    ListElement { label: "Firmware"; icon: "firmware"; hint: "Update firmware"; action: "maintain-firmware"; accent: "#f5a97f" }
    ListElement { label: "Password"; icon: "key"; hint: "Update passwords"; action: "page-maintain-password"; accent: "#ed8796" }
    ListElement { label: "Timezone"; icon: "globe"; hint: "Select timezone"; action: "maintain-timezone"; accent: "#8bd5ca" }
    ListElement { label: "Time"; icon: "clock"; hint: "Sync system time"; action: "maintain-time"; accent: "#a6da95" }
    ListElement { label: "Rollback to Omarchy"; icon: "rollback"; hint: "Restore migration snapshot"; action: "maintain-rollback"; accent: "#ed8796" }
  }

  ListModel {
    id: installServiceActions
    ListElement { label: "Dropbox"; icon: "service"; hint: "Install Dropbox"; action: "install-service-dropbox"; accent: "#8aadf4" }
    ListElement { label: "Tailscale"; icon: "service"; hint: "Install Tailscale"; action: "install-service-tailscale"; accent: "#91d7e3" }
    ListElement { label: "NordVPN"; icon: "service"; hint: "Install NordVPN"; action: "install-service-nordvpn"; accent: "#7dc4e4" }
    ListElement { label: "ONCE"; icon: "service"; hint: "Install ONCE"; action: "install-service-once"; accent: "#c6a0f6" }
    ListElement { label: "Bitwarden"; icon: "service"; hint: "Install Bitwarden"; action: "install-service-bitwarden"; accent: "#ed8796" }
    ListElement { label: "Chromium Account"; icon: "service"; hint: "Install Chromium account sync"; action: "install-service-chromium"; accent: "#eed49f" }
  }

  ListModel {
    id: installStyleActions
    ListElement { label: "Theme"; icon: "palette"; hint: "Install theme"; action: "install-style-theme"; accent: "#c6a0f6" }
    ListElement { label: "Background"; icon: "image"; hint: "Install background"; action: "install-style-background"; accent: "#91d7e3" }
    ListElement { label: "Font"; icon: "type"; hint: "Font installers"; action: "page-install-font"; accent: "#eed49f" }
  }

  ListModel {
    id: installFontActions
    ListElement { label: "Cascadia Mono"; icon: "type"; hint: "Install Cascadia"; action: "font-cascadia"; accent: "#8aadf4" }
    ListElement { label: "Meslo LG Mono"; icon: "type"; hint: "Install Meslo"; action: "font-meslo"; accent: "#91d7e3" }
    ListElement { label: "Fira Code"; icon: "type"; hint: "Install Fira Code"; action: "font-fira"; accent: "#a6da95" }
    ListElement { label: "Victor Code"; icon: "type"; hint: "Install Victor"; action: "font-victor"; accent: "#c6a0f6" }
    ListElement { label: "Bitstream Vera Mono"; icon: "type"; hint: "Install Bitstream Vera"; action: "font-bitstream"; accent: "#f5a97f" }
    ListElement { label: "Iosevka"; icon: "type"; hint: "Install Iosevka"; action: "font-iosevka"; accent: "#eed49f" }
  }

  ListModel {
    id: developmentActions
    ListElement { label: "Ruby on Rails"; icon: "code"; hint: "Ruby environment"; action: "install-dev-ruby"; accent: "#ed8796" }
    ListElement { label: "Docker DB"; icon: "database"; hint: "Database containers"; action: "install-dev-docker-dbs"; accent: "#8aadf4" }
    ListElement { label: "JavaScript"; icon: "code"; hint: "JavaScript runtimes"; action: "page-install-javascript"; accent: "#eed49f" }
    ListElement { label: "Go"; icon: "code"; hint: "Go environment"; action: "install-dev-go"; accent: "#91d7e3" }
    ListElement { label: "PHP"; icon: "code"; hint: "PHP frameworks"; action: "page-install-php"; accent: "#c6a0f6" }
    ListElement { label: "Python"; icon: "code"; hint: "Python environment"; action: "install-dev-python"; accent: "#7dc4e4" }
    ListElement { label: "Elixir"; icon: "code"; hint: "Elixir frameworks"; action: "page-install-elixir"; accent: "#a6da95" }
    ListElement { label: "Zig"; icon: "code"; hint: "Zig environment"; action: "install-dev-zig"; accent: "#f5a97f" }
    ListElement { label: "Rust"; icon: "code"; hint: "Rust environment"; action: "install-dev-rust"; accent: "#ed8796" }
    ListElement { label: "Java"; icon: "code"; hint: "Java environment"; action: "install-dev-java"; accent: "#8aadf4" }
    ListElement { label: ".NET"; icon: "code"; hint: ".NET environment"; action: "install-dev-dotnet"; accent: "#91d7e3" }
    ListElement { label: "OCaml"; icon: "code"; hint: "OCaml environment"; action: "install-dev-ocaml"; accent: "#c6a0f6" }
    ListElement { label: "Clojure"; icon: "code"; hint: "Clojure environment"; action: "install-dev-clojure"; accent: "#a6da95" }
    ListElement { label: "Scala"; icon: "code"; hint: "Scala environment"; action: "install-dev-scala"; accent: "#eed49f" }
  }

  ListModel {
    id: javascriptActions
    ListElement { label: "Node.js"; icon: "code"; hint: "Install Node.js"; action: "install-dev-node"; accent: "#a6da95" }
    ListElement { label: "Bun"; icon: "code"; hint: "Install Bun"; action: "install-dev-bun"; accent: "#eed49f" }
    ListElement { label: "Deno"; icon: "code"; hint: "Install Deno"; action: "install-dev-deno"; accent: "#8aadf4" }
  }

  ListModel {
    id: phpActions
    ListElement { label: "PHP"; icon: "code"; hint: "Install PHP"; action: "install-dev-php"; accent: "#c6a0f6" }
    ListElement { label: "Laravel"; icon: "code"; hint: "Install Laravel"; action: "install-dev-laravel"; accent: "#ed8796" }
    ListElement { label: "Symfony"; icon: "code"; hint: "Install Symfony"; action: "install-dev-symfony"; accent: "#91d7e3" }
  }

  ListModel {
    id: elixirActions
    ListElement { label: "Elixir"; icon: "code"; hint: "Install Elixir"; action: "install-dev-elixir"; accent: "#a6da95" }
    ListElement { label: "Phoenix"; icon: "code"; hint: "Install Phoenix"; action: "install-dev-phoenix"; accent: "#f5a97f" }
  }

  ListModel {
    id: installEditorActions
    ListElement { label: "VSCode"; icon: "editor"; hint: "Install VSCode"; action: "editor-vscode"; accent: "#8aadf4" }
    ListElement { label: "Cursor"; icon: "editor"; hint: "Install Cursor"; action: "editor-cursor"; accent: "#91d7e3" }
    ListElement { label: "Zed"; icon: "editor"; hint: "Install Zed"; action: "editor-zed"; accent: "#a6da95" }
    ListElement { label: "Sublime Text"; icon: "editor"; hint: "Install Sublime"; action: "editor-sublime"; accent: "#f5a97f" }
    ListElement { label: "Helix"; icon: "editor"; hint: "Install Helix"; action: "editor-helix"; accent: "#c6a0f6" }
    ListElement { label: "Emacs"; icon: "editor"; hint: "Install Emacs"; action: "editor-emacs"; accent: "#eed49f" }
  }

  ListModel {
    id: installTerminalActions
    ListElement { label: "Alacritty"; icon: "terminal"; hint: "Install Alacritty"; action: "terminal-alacritty"; accent: "#f5a97f" }
    ListElement { label: "Ghostty"; icon: "terminal"; hint: "Install Ghostty"; action: "terminal-ghostty"; accent: "#8aadf4" }
    ListElement { label: "Kitty"; icon: "terminal"; hint: "Install Kitty"; action: "terminal-kitty"; accent: "#a6da95" }
  }

  ListModel {
    id: installAiActions
    ListElement { label: "Dictation"; icon: "ai"; hint: "Install voice input"; action: "ai-dictation"; accent: "#c6a0f6" }
    ListElement { label: "LM Studio"; icon: "ai"; hint: "Install LM Studio"; action: "ai-lmstudio"; accent: "#8aadf4" }
    ListElement { label: "Ollama"; icon: "ai"; hint: "Install Ollama"; action: "ai-ollama"; accent: "#a6da95" }
    ListElement { label: "Crush"; icon: "ai"; hint: "Install Crush"; action: "ai-crush"; accent: "#ed8796" }
  }

  ListModel {
    id: installGamingActions
    ListElement { label: "Steam"; icon: "game"; hint: "Install Steam"; action: "gaming-steam"; accent: "#8aadf4" }
    ListElement { label: "NVIDIA GeForce NOW"; icon: "game"; hint: "Install GeForce NOW"; action: "gaming-geforce-now"; accent: "#a6da95" }
    ListElement { label: "RetroArch"; icon: "game"; hint: "Install RetroArch"; action: "gaming-retroarch"; accent: "#ed8796" }
    ListElement { label: "Minecraft"; icon: "game"; hint: "Install Minecraft"; action: "gaming-minecraft"; accent: "#91d7e3" }
    ListElement { label: "Xbox Controller"; icon: "game"; hint: "Install controller support"; action: "gaming-xbox"; accent: "#eed49f" }
  }

  ListModel {
    id: removeDevelopmentActions
    ListElement { label: "Ruby on Rails"; icon: "code"; hint: "Remove Ruby environment"; action: "remove-dev-ruby"; accent: "#ed8796" }
    ListElement { label: "JavaScript"; icon: "code"; hint: "JavaScript runtimes"; action: "page-remove-javascript"; accent: "#eed49f" }
    ListElement { label: "Go"; icon: "code"; hint: "Remove Go environment"; action: "remove-dev-go"; accent: "#91d7e3" }
    ListElement { label: "PHP"; icon: "code"; hint: "PHP frameworks"; action: "page-remove-php"; accent: "#c6a0f6" }
    ListElement { label: "Python"; icon: "code"; hint: "Remove Python environment"; action: "remove-dev-python"; accent: "#7dc4e4" }
    ListElement { label: "Elixir"; icon: "code"; hint: "Elixir frameworks"; action: "page-remove-elixir"; accent: "#a6da95" }
    ListElement { label: "Zig"; icon: "code"; hint: "Remove Zig environment"; action: "remove-dev-zig"; accent: "#f5a97f" }
    ListElement { label: "Rust"; icon: "code"; hint: "Remove Rust environment"; action: "remove-dev-rust"; accent: "#ed8796" }
    ListElement { label: "Java"; icon: "code"; hint: "Remove Java environment"; action: "remove-dev-java"; accent: "#8aadf4" }
    ListElement { label: ".NET"; icon: "code"; hint: "Remove .NET environment"; action: "remove-dev-dotnet"; accent: "#91d7e3" }
    ListElement { label: "OCaml"; icon: "code"; hint: "Remove OCaml environment"; action: "remove-dev-ocaml"; accent: "#c6a0f6" }
    ListElement { label: "Clojure"; icon: "code"; hint: "Remove Clojure environment"; action: "remove-dev-clojure"; accent: "#a6da95" }
    ListElement { label: "Scala"; icon: "code"; hint: "Remove Scala environment"; action: "remove-dev-scala"; accent: "#eed49f" }
  }

  ListModel {
    id: removeJavascriptActions
    ListElement { label: "Node.js"; icon: "code"; hint: "Remove Node.js"; action: "remove-dev-node"; accent: "#a6da95" }
    ListElement { label: "Bun"; icon: "code"; hint: "Remove Bun"; action: "remove-dev-bun"; accent: "#eed49f" }
    ListElement { label: "Deno"; icon: "code"; hint: "Remove Deno"; action: "remove-dev-deno"; accent: "#8aadf4" }
  }

  ListModel {
    id: removePhpActions
    ListElement { label: "PHP"; icon: "code"; hint: "Remove PHP"; action: "remove-dev-php"; accent: "#c6a0f6" }
    ListElement { label: "Laravel"; icon: "code"; hint: "Remove Laravel"; action: "remove-dev-laravel"; accent: "#ed8796" }
    ListElement { label: "Symfony"; icon: "code"; hint: "Remove Symfony"; action: "remove-dev-symfony"; accent: "#91d7e3" }
  }

  ListModel {
    id: removeElixirActions
    ListElement { label: "Elixir"; icon: "code"; hint: "Remove Elixir"; action: "remove-dev-elixir"; accent: "#a6da95" }
    ListElement { label: "Phoenix"; icon: "code"; hint: "Remove Phoenix"; action: "remove-dev-phoenix"; accent: "#f5a97f" }
  }

  ListModel {
    id: maintainChannelActions
    ListElement { label: "Stable"; icon: "branch"; hint: "Use stable channel"; action: "channel-stable"; accent: "#a6da95" }
    ListElement { label: "RC"; icon: "branch"; hint: "Use release candidate"; action: "channel-rc"; accent: "#eed49f" }
    ListElement { label: "Edge"; icon: "branch"; hint: "Use edge channel"; action: "channel-edge"; accent: "#f5a97f" }
    ListElement { label: "Dev"; icon: "branch"; hint: "Use dev channel"; action: "channel-dev"; accent: "#ed8796" }
  }

  ListModel {
    id: maintainConfigActions
    ListElement { label: "Hyprland"; icon: "refresh"; hint: "Refresh Hyprland"; action: "refresh-hyprland"; accent: "#8aadf4" }
    ListElement { label: "Hypridle"; icon: "refresh"; hint: "Refresh Hypridle"; action: "refresh-hypridle"; accent: "#91d7e3" }
    ListElement { label: "Hyprlock"; icon: "refresh"; hint: "Refresh Hyprlock"; action: "refresh-hyprlock"; accent: "#c6a0f6" }
    ListElement { label: "Hyprsunset"; icon: "refresh"; hint: "Refresh Hyprsunset"; action: "refresh-hyprsunset"; accent: "#f5a97f" }
    ListElement { label: "Plymouth"; icon: "refresh"; hint: "Refresh Plymouth"; action: "refresh-plymouth"; accent: "#7dc4e4" }
    ListElement { label: "Swayosd"; icon: "refresh"; hint: "Refresh Swayosd"; action: "refresh-swayosd"; accent: "#a6da95" }
    ListElement { label: "Tmux"; icon: "refresh"; hint: "Refresh Tmux"; action: "refresh-tmux"; accent: "#8bd5ca" }
    ListElement { label: "Launcher"; icon: "refresh"; hint: "Refresh launcher"; action: "refresh-launcher"; accent: "#eed49f" }
    ListElement { label: "Waybar"; icon: "refresh"; hint: "Refresh Waybar"; action: "refresh-waybar"; accent: "#ed8796" }
  }

  ListModel {
    id: maintainProcessActions
    ListElement { label: "Hypridle"; icon: "process"; hint: "Restart Hypridle"; action: "restart-hypridle"; accent: "#91d7e3" }
    ListElement { label: "Hyprsunset"; icon: "process"; hint: "Restart Hyprsunset"; action: "restart-hyprsunset"; accent: "#f5a97f" }
    ListElement { label: "Mako"; icon: "process"; hint: "Restart Mako"; action: "restart-mako"; accent: "#8aadf4" }
    ListElement { label: "Swayosd"; icon: "process"; hint: "Restart Swayosd"; action: "restart-swayosd"; accent: "#a6da95" }
    ListElement { label: "Launcher"; icon: "process"; hint: "No daemon to restart"; action: "restart-launcher"; accent: "#eed49f" }
    ListElement { label: "Waybar"; icon: "process"; hint: "Restart Waybar"; action: "restart-waybar"; accent: "#ed8796" }
  }

  ListModel {
    id: maintainHardwareActions
    ListElement { label: "Audio"; icon: "hardware"; hint: "Restart audio"; action: "restart-audio"; accent: "#7dc4e4" }
    ListElement { label: "Wi-Fi"; icon: "hardware"; hint: "Restart Wi-Fi"; action: "restart-wifi"; accent: "#8aadf4" }
    ListElement { label: "Bluetooth"; icon: "hardware"; hint: "Restart Bluetooth"; action: "restart-bluetooth"; accent: "#91d7e3" }
    ListElement { label: "Trackpad"; icon: "hardware"; hint: "Restart trackpad"; action: "restart-trackpad"; accent: "#a6da95" }
  }

  ListModel {
    id: maintainPasswordActions
    ListElement { label: "Drive Encryption"; icon: "key"; hint: "Update disk password"; action: "password-drive"; accent: "#ed8796" }
    ListElement { label: "User"; icon: "key"; hint: "Update user password"; action: "password-user"; accent: "#8aadf4" }
  }

  ListModel {
    id: aboutActions
    ListElement { label: "Launch About"; icon: "info"; hint: "Open Ryoku about"; action: "about-launch"; accent: "#f5a97f" }
    ListElement { label: "Open about text"; icon: "editor"; hint: "Edit about copy"; action: "about-open-text"; accent: "#a6da95" }
  }

  Connections {
    target: Popups

    function onLegacySettingsMenuOpenChanged() {
      if (Popups.legacySettingsMenuOpen) {
        closeTimer.stop()
        root.openRequestedRoute()
        root.windowVisible = true
        root.pollQuickControls()
        root.pollRollbackAvailability()
      } else {
        root.filterPickerOpen = false
        closeTimer.restart()
      }
    }
  }

  Timer {
    id: closeTimer
    interval: Theme.motionExpandDuration + 50
    onTriggered: root.windowVisible = false
  }

  Process {
    id: actionRunner
    command: []
    running: false
    onRunningChanged: if (!running) command = []
  }

  Process {
    id: rollbackCheck
    command: ["bash", "-c", "[[ -f $HOME/.local/state/ryoku/migration-state.txt ]] && echo yes || echo no"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.rollbackAvailable = text.trim() === "yes"
    }
  }

  Process {
    id: wifiRadioRead
    command: ["bash", "-c", "nmcli radio wifi"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        root.wifiOn = text.trim() === "enabled"
        ShellState.wifiOn = root.wifiOn && !root.hotspotOn
      }
    }
  }

  Process {
    id: wifiSSIDRead
    command: ["bash", "-c", "nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | head -1 | cut -d: -f2"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.wifiSSID = text.trim()
    }
  }

  Process {
    id: wifiToggleProc
    command: []
    running: false
    onRunningChanged: if (!running) root.pollWifi()
  }

  Process {
    id: btPowerRead
    command: ["bash", "-c", "bluetoothctl show 2>/dev/null | grep '^\\s*Powered:' | awk '{print $2}'"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        root.btOn = text.trim() === "yes"
        ShellState.btPowered = root.btOn
        if (!root.btOn) {
          ShellState.btConnected = false
        }
      }
    }
  }

  Process {
    id: btDeviceRead
    command: ["bash", "-c", "bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        root.btDevice = text.trim()
        ShellState.btConnected = root.btDevice !== ""
      }
    }
  }

  Process {
    id: btToggleProc
    command: []
    running: false
    onRunningChanged: if (!running) root.pollBluetooth()
  }

  Process {
    id: airplaneCheck
    command: ["bash", "-c", "notBlocked=$(rfkill list all 2>/dev/null | grep -c 'Soft blocked: no'); total=$(rfkill list all 2>/dev/null | grep -c 'Soft blocked:'); if (( total > 0 && notBlocked == 0 )); then echo yes; else echo no; fi"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.airplaneOn = text.trim() === "yes"
    }
  }

  Process {
    id: airplaneOnProc
    command: ["bash", "-c", "rfkill block all"]
    running: false
    onRunningChanged: if (!running) root.airplaneOn = true
  }

  Process {
    id: airplaneOffProc
    command: ["bash", "-c", "rfkill unblock all"]
    running: false
    onRunningChanged: if (!running) root.airplaneOn = false
  }

  Process {
    id: nightLightCheck
    command: ["bash", "-c", "pgrep -x hyprsunset"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.nightLightOn = text.trim() !== ""
    }
  }

  Process {
    id: nightLightStart
    command: ["hyprsunset", "-t", "5600"]
    running: false
  }

  Process {
    id: nightLightStop
    command: ["bash", "-c", "pkill hyprsunset"]
    running: false
  }

  Process {
    id: hotspotIfaceRead
    command: ["bash", "-c", "nmcli -g DEVICE,TYPE dev 2>/dev/null | awk -F: '$2==\"wifi\"{print $1; exit}'"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var iface = text.trim()
        if (iface !== "") {
          root.hotspotWifiIface = iface
        }
      }
    }
  }

  Process {
    id: hotspotEthernetCheck
    command: ["bash", "-c", "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -c 'ethernet:connected'"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        if (parseInt(text.trim()) > 0) {
          root.hotspotWifiWasOff = !root.wifiOn
          hotspotConfigLoad.running = false
          hotspotConfigLoad.running = true
        } else {
          root.hotspotLabel = "No ethernet"
          root.hotspotBusy = false
        }
      }
    }
  }

  Process {
    id: hotspotConfigLoad
    command: ["bash", "-c",
      "cfg=" + root.shellQuote(root.hotspotConfigPath) + "; " +
      "if [[ ! -f $cfg ]]; then " +
      "mkdir -p \"$(dirname \"$cfg\")\" && " +
      "printf '%s' '{\"ssid\":\"BrainShell\",\"password\":\"changeme1\"}' > \"$cfg\"; " +
      "fi; " +
      "cat \"$cfg\""]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var cfg = JSON.parse(text.trim())
          if (cfg.ssid) {
            root.hotspotSSID = cfg.ssid
          }
          if (cfg.password) {
            root.hotspotPassword = cfg.password
          }
        } catch (e) {}
        root.startHotspot()
      }
    }
  }

  Process {
    id: hotspotActiveCheck
    command: ["bash", "-c", "nmcli -t -f NAME,STATE,DEVICE con show --active 2>/dev/null | awk -F: '$1==\"BrainShellHotspot\"{found=1} END{print found+0}'"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        root.hotspotOn = parseInt(text.trim()) > 0
        ShellState.hotspot = root.hotspotOn
        root.hotspotLabel = root.hotspotOn ? (root.hotspotOwnedByControlCenter ? "Active" : "External") : ""
        if (root.hotspotOn) {
          ShellState.wifiOn = false
        } else {
          root.hotspotOwnedByControlCenter = false
          ShellState.wifiOn = root.wifiOn
        }
      }
    }
  }

  Process {
    id: hotspotStartProc
    command: []
    running: false
    stderr: StdioCollector {}
    onRunningChanged: if (!running) {
      root.hotspotBusy = false
      hotspotActiveCheck.running = false
      hotspotActiveCheck.running = true
    }
    onExited: function(code, status) {
      if (code === 0) {
        root.hotspotOn = true
        root.hotspotOwnedByControlCenter = true
        root.hotspotLabel = "Active"
        ShellState.hotspot = true
        ShellState.wifiOn = false
      } else {
        root.hotspotOn = false
        root.hotspotOwnedByControlCenter = false
        root.hotspotLabel = "Failed"
        ShellState.hotspot = false
        hotspotLabelReset.restart()
      }
    }
  }

  Process {
    id: hotspotStopProc
    command: []
    running: false
    onRunningChanged: if (!running) {
      root.hotspotBusy = false
      root.hotspotOn = false
      root.hotspotOwnedByControlCenter = false
      root.hotspotLabel = ""
      ShellState.hotspot = false
      if (root.hotspotWifiWasOff) {
        root.wifiOn = false
        ShellState.wifiOn = false
        wifiToggleProc.command = ["bash", "-c", "nmcli radio wifi off"]
        wifiToggleProc.running = false
        wifiToggleProc.running = true
        root.hotspotWifiWasOff = false
      } else {
        ShellState.wifiOn = root.wifiOn
        root.pollWifi()
      }
    }
  }

  Timer {
    id: hotspotLabelReset
    interval: 3000
    repeat: false
    onTriggered: if (root.hotspotLabel === "Failed" || root.hotspotLabel === "No ethernet") root.hotspotLabel = ""
  }

  Timer {
    id: focusLabelReset
    interval: 3000
    repeat: false
    onTriggered: if (root.focusLabel === "External") root.focusLabel = ""
  }

  Process {
    id: focusGapsInRead
    command: ["bash", "-c", "hyprctl getoption general:gaps_in -j | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('int',5))\""]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var value = parseInt(text.trim())
        if (!isNaN(value)) {
          root.savedGapsIn = value
        }
      }
    }
    onRunningChanged: if (!running) {
      focusGapsOutRead.running = false
      focusGapsOutRead.running = true
    }
  }

  Process {
    id: focusGapsOutRead
    command: ["bash", "-c", "hyprctl getoption general:gaps_out -j | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('int',10))\""]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var value = parseInt(text.trim())
        if (!isNaN(value)) {
          root.savedGapsOut = value
        }
      }
    }
    onRunningChanged: if (!running) {
      focusApplyProc.running = false
      focusApplyProc.running = true
    }
  }

  Process {
    id: focusApplyProc
    command: ["bash", "-c", "hyprctl keyword general:gaps_in 0 && hyprctl keyword general:gaps_out 10"]
    running: false
    onExited: function(code, status) {
      if (code === 0) {
        ShellState.focusMode = true
        root.focusOwnedByControlCenter = true
        root.focusLabel = ""
      }
    }
  }

  Process {
    id: focusRestoreProc
    command: []
    running: false
    onExited: function(code, status) {
      if (code === 0) {
        ShellState.focusMode = false
        root.focusOwnedByControlCenter = false
        root.focusLabel = ""
      }
    }
  }

  Process {
    id: filterCheckProc
    command: ["bash", "-c", "hyprctl getoption decoration:screen_shader -j 2>/dev/null | python3 -c \"import sys,json,os; d=json.load(sys.stdin); s=d.get('str','').strip(); print('' if s in ('','[[EMPTY]]') else os.path.splitext(os.path.basename(s))[0])\""]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.currentFilter = text.trim()
    }
  }

  Process {
    id: filterListProc
    command: ["hyprshade", "ls"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n")
        var filters = []
        for (var i = 0; i < lines.length; i++) {
          var name = lines[i].trim()
          if (name !== "") {
            filters.push(name)
          }
        }
        root.filterList = filters
      }
    }
  }

  Process {
    id: filterApplyProc
    command: []
    running: false
    onRunningChanged: if (!running) {
      filterCheckProc.running = false
      filterCheckProc.running = true
    }
  }

  Timer {
    interval: 5000
    running: root.windowVisible
    repeat: true
    onTriggered: root.pollQuickControls()
  }

  function openRequestedRoute() {
    root.openPage(Popups.legacySettingsMenuRequestedPage, Popups.legacySettingsMenuRequestedSubpage)
  }

  function openPage(page, subpage) {
    root.currentPage = page && page !== "" ? page : "home"
    root.currentSubpage = subpage && subpage !== "" ? subpage : ""
    if (root.currentPage === "home") {
      root.pageTitle = "Ryoku"
      root.pageKicker = "Control center"
    } else if (root.currentSubpage !== "") {
      root.pageTitle = root.pageLabel(root.currentSubpage)
      root.pageKicker = root.pageLabel(root.currentPage)
    } else {
      root.pageTitle = root.pageLabel(root.currentPage)
      root.pageKicker = "Control center"
    }
  }

  function back() {
    if (root.currentSubpage !== "") {
      root.openPage(root.currentPage, "")
    } else {
      root.openPage("home", "")
    }
  }

  function pageLabel(page) {
    switch (page) {
    case "learn": return "Learn"
    case "share": return "Share"
    case "style": return "Style"
    case "setup": return "Setup"
    case "power-profile": return "Power Profile"
    case "system-sleep": return "System Sleep"
    case "security": return "Security"
    case "config": return "Config"
    case "hardware": return "Hardware"
    case "install-service": return "Service"
    case "install-style": return "Style pack"
    case "install-font": return "Font"
    case "install-development": return "Development"
    case "install-javascript": return "JavaScript"
    case "install-php": return "PHP"
    case "install-elixir": return "Elixir"
    case "install-editor": return "Editor"
    case "install-terminal": return "Terminal"
    case "install-ai": return "AI"
    case "install-gaming": return "Gaming"
    case "remove-development": return "Development"
    case "remove-javascript": return "JavaScript"
    case "remove-php": return "PHP"
    case "remove-elixir": return "Elixir"
    case "maintain-channel": return "Channel"
    case "maintain-config": return "Config refresh"
    case "maintain-process": return "Process"
    case "maintain-hardware": return "Hardware restart"
    case "maintain-password": return "Password"
    case "manage": return "Manage"
    case "about": return "About"
    default: return "Ryoku"
    }
  }

  function pageModel() {
    if (root.currentPage === "learn") return learnActions
    if (root.currentPage === "share") return shareActions
    if (root.currentPage === "style") return styleActions
    if (root.currentPage === "setup" && root.currentSubpage === "power-profile") return setupPowerProfileActions
    if (root.currentPage === "setup" && root.currentSubpage === "system-sleep") return setupSystemSleepActions
    if (root.currentPage === "setup" && root.currentSubpage === "security") return setupSecurityActions
    if (root.currentPage === "setup" && root.currentSubpage === "config") return setupConfigActions
    if (root.currentPage === "setup" && root.currentSubpage === "hardware") return setupHardwareActions
    if (root.currentPage === "setup") return setupActions
    if (root.currentPage === "manage" && root.currentSubpage === "install-service") return installServiceActions
    if (root.currentPage === "manage" && root.currentSubpage === "install-style") return installStyleActions
    if (root.currentPage === "manage" && root.currentSubpage === "install-font") return installFontActions
    if (root.currentPage === "manage" && root.currentSubpage === "install-development") return developmentActions
    if (root.currentPage === "manage" && root.currentSubpage === "install-javascript") return javascriptActions
    if (root.currentPage === "manage" && root.currentSubpage === "install-php") return phpActions
    if (root.currentPage === "manage" && root.currentSubpage === "install-elixir") return elixirActions
    if (root.currentPage === "manage" && root.currentSubpage === "install-editor") return installEditorActions
    if (root.currentPage === "manage" && root.currentSubpage === "install-terminal") return installTerminalActions
    if (root.currentPage === "manage" && root.currentSubpage === "install-ai") return installAiActions
    if (root.currentPage === "manage" && root.currentSubpage === "install-gaming") return installGamingActions
    if (root.currentPage === "manage" && root.currentSubpage === "remove-development") return removeDevelopmentActions
    if (root.currentPage === "manage" && root.currentSubpage === "remove-javascript") return removeJavascriptActions
    if (root.currentPage === "manage" && root.currentSubpage === "remove-php") return removePhpActions
    if (root.currentPage === "manage" && root.currentSubpage === "remove-elixir") return removeElixirActions
    if (root.currentPage === "manage" && root.currentSubpage === "maintain-channel") return maintainChannelActions
    if (root.currentPage === "manage" && root.currentSubpage === "maintain-config") return maintainConfigActions
    if (root.currentPage === "manage" && root.currentSubpage === "maintain-process") return maintainProcessActions
    if (root.currentPage === "manage" && root.currentSubpage === "maintain-hardware") return maintainHardwareActions
    if (root.currentPage === "manage" && root.currentSubpage === "maintain-password") return maintainPasswordActions
    if (root.currentPage === "manage" && root.manageTab === "remove") return manageRemoveActions
    if (root.currentPage === "manage" && root.manageTab === "maintain") return manageMaintainActions
    if (root.currentPage === "manage") return manageInstallActions
    if (root.currentPage === "about") return aboutActions
    return nativeSectionsModel
  }

  function runCommand(command) {
    actionRunner.command = command
    actionRunner.running = true
    Popups.closeAll()
  }

  function runTerminal(command) {
    actionRunner.command = ["ryoku-launch-floating-terminal-with-presentation", command]
    actionRunner.running = true
    Popups.closeAll()
  }

  function editFile(path) {
    root.runCommand(["ryoku-launch-editor", path])
  }

  function openAppearance(mode) {
    Popups.closeAll()
    Popups.wallpaperMode = mode
    Popups.wallpaperOpen = true
  }

  function runAction(action) {
    switch (action) {
    case "learn-keybindings":
      root.runCommand(["ryoku-menu-keybindings"])
      return
    case "learn-omarchy":
      root.runCommand(["ryoku-launch-webapp", "https://learn.omacom.io/2/the-omarchy-manual"])
      return
    case "learn-hyprland":
      root.runCommand(["ryoku-launch-webapp", "https://wiki.hypr.land/"])
      return
    case "learn-arch":
      root.runCommand(["ryoku-launch-webapp", "https://wiki.archlinux.org/title/Main_page"])
      return
    case "learn-helix":
      root.runCommand(["ryoku-launch-webapp", "https://docs.helix-editor.com/"])
      return
    case "learn-bash":
      root.runCommand(["ryoku-launch-webapp", "https://devhints.io/bash"])
      return
    case "share-clipboard":
      root.runCommand(["ryoku-cmd-share", "clipboard"])
      return
    case "share-file":
      root.runTerminal("ryoku-cmd-share file")
      return
    case "share-folder":
      root.runTerminal("ryoku-cmd-share folder")
      return
    case "style-theme":
      root.openAppearance("theme")
      return
    case "style-font":
      root.openAppearance("font")
      return
    case "style-background":
      root.openAppearance("wallpaper")
      return
    case "edit-hypr-look":
      root.editFile(root.homeDir + "/.config/hypr/looknfeel.conf")
      return
    case "edit-screensaver-text":
      root.editFile(root.ryokuConfigPath + "/branding/screensaver.txt")
      return
    case "edit-about-text":
    case "about-open-text":
      root.editFile(root.ryokuConfigPath + "/branding/about.txt")
      return
    case "setup-audio":
      root.runCommand(["ryoku-launch-audio"])
      return
    case "setup-wifi":
      root.runCommand(["ryoku-launch-wifi"])
      return
    case "setup-bluetooth":
      root.runCommand(["ryoku-launch-bluetooth"])
      return
    case "page-power-profile":
      root.openPage("setup", "power-profile")
      return
    case "page-system-sleep":
      root.openPage("setup", "system-sleep")
      return
    case "edit-monitors":
      root.editFile(root.homeDir + "/.config/hypr/monitors.conf")
      return
    case "setup-dns":
      root.runTerminal("ryoku-setup-dns")
      return
    case "page-security":
      root.openPage("setup", "security")
      return
    case "page-config":
      root.openPage("setup", "config")
      return
    case "page-hardware":
      root.openPage("setup", "hardware")
      return
    case "config-dotfiles":
      Popups.closeAll()
      Popups.dotfilesOpen = true
      return
    case "power-performance":
      root.runCommand(["powerprofilesctl", "set", "performance"])
      return
    case "power-balanced":
      root.runCommand(["powerprofilesctl", "set", "balanced"])
      return
    case "power-saver":
      root.runCommand(["powerprofilesctl", "set", "power-saver"])
      return
    case "sleep-suspend-toggle":
      root.runTerminal("ryoku-toggle-suspend")
      return
    case "sleep-hibernate-setup":
      root.runTerminal("ryoku-hibernation-setup")
      return
    case "sleep-hibernate-remove":
      root.runTerminal("ryoku-hibernation-remove")
      return
    case "setup-fingerprint":
      root.runTerminal("ryoku-setup-fingerprint")
      return
    case "setup-fido2":
      root.runTerminal("ryoku-setup-fido2")
      return
    case "edit-defaults":
      root.editFile(root.homeDir + "/.config/uwsm/default")
      return
    case "edit-hyprland":
      root.editFile(root.homeDir + "/.config/hypr/hyprland.conf")
      return
    case "edit-hypridle":
      root.editFile(root.homeDir + "/.config/hypr/hypridle.conf")
      return
    case "edit-hyprlock":
      root.editFile(root.homeDir + "/.config/hypr/hyprlock.conf")
      return
    case "edit-hyprsunset":
      root.editFile(root.homeDir + "/.config/hypr/hyprsunset.conf")
      return
    case "edit-swayosd":
      root.editFile(root.homeDir + "/.config/swayosd/config.toml")
      return
    case "edit-launcher":
      root.editFile(root.ryokuConfigPath + "/tofi/config")
      return
    case "edit-waybar":
      root.editFile(root.homeDir + "/.config/waybar/config.jsonc")
      return
    case "edit-xcompose":
      root.editFile(root.homeDir + "/.XCompose")
      return
    case "hardware-laptop-display":
      root.runCommand(["ryoku-hyprland-monitor-internal", "toggle"])
      return
    case "hardware-hybrid-gpu":
      root.runTerminal("ryoku-toggle-hybrid-gpu")
      return
    case "hardware-touchpad":
      root.runCommand(["ryoku-toggle-touchpad"])
      return
    case "manage-install":
    case "manage-remove":
    case "manage-maintain":
      root.manageTab = action.replace("manage-", "")
      root.currentSubpage = ""
      root.pageTitle = "Manage"
      root.pageKicker = "Control center"
      return
    case "page-install-service":
      root.openPage("manage", "install-service")
      return
    case "page-install-style":
      root.openPage("manage", "install-style")
      return
    case "page-install-font":
      root.openPage("manage", "install-font")
      return
    case "page-install-development":
      root.openPage("manage", "install-development")
      return
    case "page-install-javascript":
      root.openPage("manage", "install-javascript")
      return
    case "page-install-php":
      root.openPage("manage", "install-php")
      return
    case "page-install-elixir":
      root.openPage("manage", "install-elixir")
      return
    case "page-install-editor":
      root.openPage("manage", "install-editor")
      return
    case "page-install-terminal":
      root.openPage("manage", "install-terminal")
      return
    case "page-install-ai":
      root.openPage("manage", "install-ai")
      return
    case "page-install-gaming":
      root.openPage("manage", "install-gaming")
      return
    case "page-remove-development":
      root.openPage("manage", "remove-development")
      return
    case "page-remove-javascript":
      root.openPage("manage", "remove-javascript")
      return
    case "page-remove-php":
      root.openPage("manage", "remove-php")
      return
    case "page-remove-elixir":
      root.openPage("manage", "remove-elixir")
      return
    case "page-maintain-channel":
      root.openPage("manage", "maintain-channel")
      return
    case "page-maintain-config":
      root.openPage("manage", "maintain-config")
      return
    case "page-maintain-process":
      root.openPage("manage", "maintain-process")
      return
    case "page-maintain-hardware":
      root.openPage("manage", "maintain-hardware")
      return
    case "page-maintain-password":
      root.openPage("manage", "maintain-password")
      return
    case "install-package":
      root.runTerminal("ryoku-pkg-install")
      return
    case "install-aur":
      root.runTerminal("ryoku-pkg-aur-install")
      return
    case "install-webapp":
      root.runTerminal("ryoku-webapp-install")
      return
    case "install-tui":
      root.runTerminal("ryoku-tui-install")
      return
    case "install-windows":
      root.runTerminal("ryoku-windows-vm install")
      return
    case "remove-package":
      root.runTerminal("ryoku-pkg-remove")
      return
    case "remove-webapp":
      root.runTerminal("ryoku-webapp-remove")
      return
    case "remove-tui":
      root.runTerminal("ryoku-tui-remove")
      return
    case "remove-preinstalls":
      root.runTerminal("ryoku-remove-preinstalls")
      return
    case "remove-dictation":
      root.runTerminal("ryoku-voxtype-remove")
      return
    case "remove-theme":
      root.runTerminal("ryoku-theme-remove")
      return
    case "remove-windows":
      root.runTerminal("ryoku-windows-vm remove")
      return
    case "remove-fingerprint":
      root.runTerminal("ryoku-setup-fingerprint --remove")
      return
    case "remove-fido2":
      root.runTerminal("ryoku-setup-fido2 --remove")
      return
    case "maintain-ryoku":
      root.runTerminal("ryoku-update")
      return
    case "maintain-extra-themes":
      root.runTerminal("ryoku-theme-update")
      return
    case "maintain-firmware":
      root.runTerminal("ryoku-update-firmware")
      return
    case "maintain-timezone":
      root.runTerminal("ryoku-tz-select")
      return
    case "maintain-time":
      root.runTerminal("ryoku-update-time")
      return
    case "maintain-rollback":
      root.runTerminal("ryoku-rollback")
      return
    case "about-launch":
      root.runCommand(["ryoku-launch-about"])
      return
    default:
      if (root.runMappedTerminalAction(action)) return
      return
    }
  }

  function runMappedTerminalAction(action) {
    var commands = {
      "install-service-dropbox": "ryoku-install-dropbox",
      "install-service-tailscale": "ryoku-install-tailscale",
      "install-service-nordvpn": "ryoku-install-nordvpn",
      "install-service-once": "ryoku-install-once",
      "install-service-bitwarden": "ryoku-pkg-add bitwarden bitwarden-cli && setsid gtk-launch bitwarden",
      "install-service-chromium": "ryoku-install-chromium-google-account",
      "install-style-theme": "ryoku-theme-install",
      "install-style-background": "ryoku-theme-bg-install",
      "font-cascadia": "ryoku-pkg-add ttf-cascadia-mono-nerd && sleep 2 && ryoku-font-set 'CaskaydiaMono Nerd Font'",
      "font-meslo": "ryoku-pkg-add ttf-meslo-nerd && sleep 2 && ryoku-font-set 'MesloLGL Nerd Font'",
      "font-fira": "ryoku-pkg-add ttf-firacode-nerd && sleep 2 && ryoku-font-set 'FiraCode Nerd Font'",
      "font-victor": "ryoku-pkg-add ttf-victor-mono-nerd && sleep 2 && ryoku-font-set 'VictorMono Nerd Font'",
      "font-bitstream": "ryoku-pkg-add ttf-bitstream-vera-mono-nerd && sleep 2 && ryoku-font-set 'BitstromWera Nerd Font'",
      "font-iosevka": "ryoku-pkg-add ttf-iosevka-nerd && sleep 2 && ryoku-font-set 'Iosevka Nerd Font Mono'",
      "install-dev-ruby": "ryoku-install-dev-env ruby",
      "install-dev-docker-dbs": "ryoku-install-docker-dbs",
      "install-dev-go": "ryoku-install-dev-env go",
      "install-dev-python": "ryoku-install-dev-env python",
      "install-dev-zig": "ryoku-install-dev-env zig",
      "install-dev-rust": "ryoku-install-dev-env rust",
      "install-dev-java": "ryoku-install-dev-env java",
      "install-dev-dotnet": "ryoku-install-dev-env dotnet",
      "install-dev-ocaml": "ryoku-install-dev-env ocaml",
      "install-dev-clojure": "ryoku-install-dev-env clojure",
      "install-dev-scala": "ryoku-install-dev-env scala",
      "install-dev-node": "ryoku-install-dev-env node",
      "install-dev-bun": "ryoku-install-dev-env bun",
      "install-dev-deno": "ryoku-install-dev-env deno",
      "install-dev-php": "ryoku-install-dev-env php",
      "install-dev-laravel": "ryoku-install-dev-env laravel",
      "install-dev-symfony": "ryoku-install-dev-env symfony",
      "install-dev-elixir": "ryoku-install-dev-env elixir",
      "install-dev-phoenix": "ryoku-install-dev-env phoenix",
      "editor-vscode": "ryoku-install-vscode",
      "editor-cursor": "ryoku-pkg-add cursor-bin && setsid gtk-launch cursor",
      "editor-zed": "ryoku-pkg-add zed && setsid gtk-launch dev.zed.Zed",
      "editor-sublime": "ryoku-pkg-add sublime-text-4 && setsid gtk-launch sublime_text",
      "editor-helix": "ryoku-pkg-add helix",
      "editor-emacs": "ryoku-pkg-add emacs-wayland && systemctl --user enable --now emacs.service",
      "terminal-alacritty": "ryoku-install-terminal alacritty",
      "terminal-ghostty": "ryoku-install-terminal ghostty",
      "terminal-kitty": "ryoku-install-terminal kitty",
      "ai-dictation": "ryoku-voxtype-install",
      "ai-lmstudio": "ryoku-pkg-add lmstudio-bin",
      "ai-ollama": "ryoku-pkg-add ollama",
      "ai-crush": "ryoku-pkg-add crush-bin",
      "gaming-steam": "ryoku-install-steam",
      "gaming-geforce-now": "ryoku-install-geforce-now",
      "gaming-retroarch": "ryoku-pkg-aur-install retroarch retroarch-assets libretro libretro-fbneo",
      "gaming-minecraft": "ryoku-pkg-add minecraft-launcher && setsid gtk-launch minecraft-launcher",
      "gaming-xbox": "ryoku-install-xbox-controllers",
      "remove-dev-ruby": "ryoku-remove-dev-env ruby",
      "remove-dev-go": "ryoku-remove-dev-env go",
      "remove-dev-python": "ryoku-remove-dev-env python",
      "remove-dev-zig": "ryoku-remove-dev-env zig",
      "remove-dev-rust": "ryoku-remove-dev-env rust",
      "remove-dev-java": "ryoku-remove-dev-env java",
      "remove-dev-dotnet": "ryoku-remove-dev-env dotnet",
      "remove-dev-ocaml": "ryoku-remove-dev-env ocaml",
      "remove-dev-clojure": "ryoku-remove-dev-env clojure",
      "remove-dev-scala": "ryoku-remove-dev-env scala",
      "remove-dev-node": "ryoku-remove-dev-env node",
      "remove-dev-bun": "ryoku-remove-dev-env bun",
      "remove-dev-deno": "ryoku-remove-dev-env deno",
      "remove-dev-php": "ryoku-remove-dev-env php",
      "remove-dev-laravel": "ryoku-remove-dev-env laravel",
      "remove-dev-symfony": "ryoku-remove-dev-env symfony",
      "remove-dev-elixir": "ryoku-remove-dev-env elixir",
      "remove-dev-phoenix": "ryoku-remove-dev-env phoenix",
      "channel-stable": "ryoku-channel-set stable",
      "channel-rc": "ryoku-channel-set rc",
      "channel-edge": "ryoku-channel-set edge",
      "channel-dev": "ryoku-channel-set dev",
      "refresh-hyprland": "ryoku-refresh-hyprland",
      "refresh-hypridle": "ryoku-refresh-hypridle",
      "refresh-hyprlock": "ryoku-refresh-hyprlock",
      "refresh-hyprsunset": "ryoku-refresh-hyprsunset",
      "refresh-plymouth": "ryoku-refresh-plymouth",
      "refresh-swayosd": "ryoku-refresh-swayosd",
      "refresh-tmux": "ryoku-refresh-tmux",
      "refresh-launcher": "mkdir -p " + root.shellQuote(root.ryokuConfigPath + "/tofi") + " && cp " + root.shellQuote(root.homeDir + "/.local/share/ryoku/default/tofi/config") + " " + root.shellQuote(root.ryokuConfigPath + "/tofi/config"),
      "refresh-waybar": "ryoku-refresh-waybar",
      "restart-hypridle": "ryoku-restart-hypridle",
      "restart-hyprsunset": "ryoku-restart-hyprsunset",
      "restart-mako": "ryoku-restart-mako",
      "restart-launcher": "notify-send 'Launcher' 'Tofi has no daemon; nothing to restart.'",
      "restart-swayosd": "ryoku-restart-swayosd",
      "restart-waybar": "ryoku-restart-waybar",
      "restart-audio": "ryoku-restart-pipewire",
      "restart-wifi": "ryoku-restart-wifi",
      "restart-bluetooth": "ryoku-restart-bluetooth",
      "restart-trackpad": "ryoku-restart-trackpad",
      "password-drive": "ryoku-drive-set-password",
      "password-user": "passwd"
    }

    if (commands[action]) {
      var command = commands[action]
      if (root.currentSubpage.indexOf("remove-") === 0 && action.indexOf("install-dev-") === 0) {
        command = command.replace("ryoku-install-dev-env", "ryoku-remove-dev-env")
      }
      root.runTerminal(command)
      return true
    }
    return false
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function wifiStatusText() {
    if (root.hotspotOn) return "Used by Hotspot"
    if (!root.wifiOn) return "Off"
    return root.wifiSSID !== "" ? root.wifiSSID : "On"
  }

  function bluetoothStatusText() {
    if (!root.btOn) return "Off"
    return root.btDevice !== "" ? root.btDevice : "On"
  }

  function quickActive(action) {
    switch (action) {
    case "wifi-toggle": return root.wifiOn && !root.hotspotOn
    case "bluetooth-toggle": return root.btOn
    case "airplane-toggle": return root.airplaneOn
    case "hotspot-toggle": return root.hotspotOn || root.hotspotBusy
    case "nightlight-toggle": return root.nightLightOn
    case "focus-toggle": return ShellState.focusMode
    case "dnd-toggle": return ShellState.dnd
    case "filter-open": return root.currentFilter !== ""
    default: return false
    }
  }

  function runQuickAction(action) {
    switch (action) {
    case "wifi-toggle":
      root.toggleWifi()
      return
    case "bluetooth-toggle":
      root.toggleBluetooth()
      return
    case "airplane-toggle":
      root.toggleAirplane()
      return
    case "hotspot-toggle":
      root.toggleHotspot()
      return
    case "nightlight-toggle":
      root.toggleNightLight()
      return
    case "focus-toggle":
      root.toggleFocus()
      return
    case "dnd-toggle":
      ShellState.dnd = !ShellState.dnd
      return
    case "filter-open":
      root.openFilterPicker()
      return
    default:
      return
    }
  }

  function pollQuickControls() {
    root.pollWifi()
    root.pollBluetooth()
    hotspotIfaceRead.running = false
    hotspotIfaceRead.running = true
    hotspotActiveCheck.running = false
    hotspotActiveCheck.running = true
    airplaneCheck.running = false
    airplaneCheck.running = true
    nightLightCheck.running = false
    nightLightCheck.running = true
    filterCheckProc.running = false
    filterCheckProc.running = true
  }

  function pollRollbackAvailability() {
    rollbackCheck.running = false
    rollbackCheck.running = true
  }

  function pollWifi() {
    wifiRadioRead.running = false
    wifiRadioRead.running = true
    wifiSSIDRead.running = false
    wifiSSIDRead.running = true
  }

  function pollBluetooth() {
    btPowerRead.running = false
    btPowerRead.running = true
    btDeviceRead.running = false
    btDeviceRead.running = true
  }

  function toggleWifi() {
    if (root.hotspotOn || root.hotspotBusy) {
      return
    }
    root.wifiOn = !root.wifiOn
    ShellState.wifiOn = root.wifiOn
    wifiToggleProc.command = ["bash", "-c", "nmcli radio wifi " + (root.wifiOn ? "on" : "off")]
    wifiToggleProc.running = false
    wifiToggleProc.running = true
  }

  function toggleBluetooth() {
    root.btOn = !root.btOn
    ShellState.btPowered = root.btOn
    if (!root.btOn) {
      root.btDevice = ""
      ShellState.btConnected = false
    }
    btToggleProc.command = ["bash", "-c", "bluetoothctl power " + (root.btOn ? "on" : "off")]
    btToggleProc.running = false
    btToggleProc.running = true
  }

  function toggleAirplane() {
    if (root.airplaneOn) {
      airplaneOffProc.running = false
      airplaneOffProc.running = true
    } else {
      airplaneOnProc.running = false
      airplaneOnProc.running = true
    }
  }

  function toggleNightLight() {
    if (root.nightLightOn) {
      nightLightStart.running = false
      nightLightStop.running = false
      nightLightStop.running = true
      root.nightLightOn = false
    } else {
      nightLightStart.running = false
      nightLightStart.running = true
      root.nightLightOn = true
    }
  }

  function startHotspot() {
    var iface = root.shellQuote(root.hotspotWifiIface)
    hotspotStartProc.command = ["bash", "-c",
      "nmcli radio wifi on 2>/dev/null; " +
      "sleep 1; " +
      "nmcli device disconnect " + iface + " 2>/dev/null; " +
      "nmcli con delete BrainShellHotspot 2>/dev/null; " +
      "nmcli device wifi hotspot " +
      "ifname " + iface + " " +
      "ssid " + root.shellQuote(root.hotspotSSID) + " " +
      "password " + root.shellQuote(root.hotspotPassword) + " " +
      "con-name BrainShellHotspot 2>&1"]
    hotspotStartProc.running = false
    hotspotStartProc.running = true
  }

  function toggleHotspot() {
    if (root.hotspotBusy) {
      return
    }
    if (root.hotspotOn) {
      if (!root.hotspotOwnedByControlCenter) {
        root.hotspotLabel = "External"
        return
      }
      root.hotspotBusy = true
      root.hotspotLabel = ""
      hotspotStopProc.command = ["bash", "-c",
        "nmcli device disconnect " + root.shellQuote(root.hotspotWifiIface) + " 2>/dev/null; " +
        "nmcli con delete BrainShellHotspot 2>/dev/null; true"]
      hotspotStopProc.running = false
      hotspotStopProc.running = true
    } else {
      root.hotspotBusy = true
      root.hotspotOwnedByControlCenter = false
      root.hotspotLabel = ""
      hotspotEthernetCheck.running = false
      hotspotEthernetCheck.running = true
    }
  }

  function toggleFocus() {
    if (ShellState.focusMode) {
      if (!root.focusOwnedByControlCenter) {
        root.focusLabel = "External"
        focusLabelReset.restart()
        return
      }
      focusRestoreProc.command = ["bash", "-c",
        "hyprctl keyword general:gaps_in " + root.savedGapsIn +
        " && hyprctl keyword general:gaps_out " + root.savedGapsOut]
      focusRestoreProc.running = false
      focusRestoreProc.running = true
    } else {
      root.focusLabel = ""
      focusGapsInRead.running = false
      focusGapsInRead.running = true
    }
  }

  function openFilterPicker() {
    root.filterList = []
    filterListProc.running = false
    filterListProc.running = true
    root.filterPickerOpen = true
  }

  function applyFilter(name) {
    var turningOff = name === "" || name === root.currentFilter
    filterApplyProc.command = turningOff ? ["hyprshade", "off"] : ["hyprshade", "on", name]
    root.currentFilter = turningOff ? "" : name
    root.filterPickerOpen = false
    filterApplyProc.running = false
    filterApplyProc.running = true
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.windowVisible
    onClicked: Popups.closeAll()
  }

  Item {
    id: card

    anchors.right: parent.right
    anchors.top: parent.top

    width: root.fullCardWidth
    height: root.initialCardHeight + (root.fullCardHeight - root.initialCardHeight) * root.openProgress
    visible: root.openProgress > 0
    clip: true

    PopupShape {
      anchors.fill: parent
      attachedEdge: "top"
      color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.95)
      strokeColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22)
      strokeWidth: 1
      radius: 8
      flareWidth: root.fw
      flareHeight: root.fh
    }

    MouseArea {
      anchors.fill: parent
      onClicked: mouse.accepted = true
    }

    Item {
      anchors {
        fill: parent
        topMargin: Theme.notchHeight + 10
        leftMargin: root.fw + 12
        rightMargin: root.fw + 12
        bottomMargin: 12
      }

      opacity: Math.min(1, root.openProgress * 1.35)

      Behavior on opacity {
        enabled: !Theme.staticMode
        NumberAnimation { duration: Theme.motionEffectsDuration }
      }

      Column {
        anchors.fill: parent
        spacing: 10

        Item {
          id: header
          width: parent.width
          height: 42

          Rectangle {
            id: headerRule
            width: 3
            height: 28
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.active
          }

          MouseArea {
            id: backControl
            width: 28
            height: 28
            anchors {
              left: headerRule.right
              leftMargin: root.currentPage === "home" ? 0 : 9
              verticalCenter: parent.verticalCenter
            }
            enabled: root.currentPage !== "home"
            visible: root.currentPage !== "home"
            hoverEnabled: true
            onClicked: root.back()

            Rectangle {
              anchors.fill: parent
              radius: 6
              color: backControl.pressed ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22)
                                         : backControl.containsMouse ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                                                                     : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.04)
              border.width: 1
              border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)

              Text {
                anchors.centerIn: parent
                text: "<"
                color: Theme.text
                font.pixelSize: 18
              }
            }
          }

          Column {
            anchors {
              left: root.currentPage === "home" ? headerRule.right : backControl.right
              leftMargin: 9
              verticalCenter: parent.verticalCenter
            }
            spacing: 0

            Text {
              text: root.pageTitle
              color: Theme.text
              font.pixelSize: 14
              font.bold: true
            }

            Text {
              text: root.pageKicker
              color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.46)
              font.pixelSize: 10
            }
          }

          Text {
            anchors {
              right: parent.right
              verticalCenter: parent.verticalCenter
            }
            text: root.currentPage === "home" ? "settings" : root.currentPage
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.36)
            font.pixelSize: 9
          }
        }

        Item {
          id: pageStack
          width: parent.width
          height: parent.height - header.height - 10
          clip: true

          Column {
            id: homePage
            width: parent.width
            height: parent.height
            spacing: 12
            visible: root.currentPage === "home"

            Text {
              width: parent.width
              text: "Control center"
              color: Theme.text
              font.pixelSize: 12
              font.bold: true
            }

            Grid {
              id: quickGrid
              width: parent.width
              columns: 4
              rowSpacing: 7
              columnSpacing: 7

              Repeater {
                model: quickControlsModel

                delegate: Rectangle {
                  id: quickTile

                  required property string label
                  required property string icon
                  required property string action
                  required property color accent
                  property bool active: root.quickActive(action)
                  property string status: {
                    switch (action) {
                    case "wifi-toggle": return root.wifiStatusText()
                    case "bluetooth-toggle": return root.bluetoothStatusText()
                    case "hotspot-toggle": return root.hotspotLabel !== "" ? root.hotspotLabel : (root.hotspotOn ? "Active" : "Off")
                    case "focus-toggle": return root.focusLabel !== "" ? root.focusLabel : (active ? "On" : "Off")
                    case "filter-open": return root.currentFilter !== "" ? root.currentFilter : "Off"
                    default: return active ? "On" : "Off"
                    }
                  }

                  width: (quickGrid.width - quickGrid.columnSpacing * 3) / 4
                  height: 62
                  radius: 7
                  color: quickMouse.pressed ? Qt.rgba(quickTile.accent.r, quickTile.accent.g, quickTile.accent.b, quickTile.active ? 0.24 : 0.18)
                                            : quickTile.active ? Qt.rgba(quickTile.accent.r, quickTile.accent.g, quickTile.accent.b, 0.16)
                                                               : quickMouse.containsMouse ? Qt.rgba(quickTile.accent.r, quickTile.accent.g, quickTile.accent.b, 0.11)
                                                                                          : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.035)
                  border.width: 1
                  border.color: quickTile.active ? Qt.rgba(quickTile.accent.r, quickTile.accent.g, quickTile.accent.b, 0.42)
                                                 : quickMouse.containsMouse ? Qt.rgba(quickTile.accent.r, quickTile.accent.g, quickTile.accent.b, 0.32)
                                                                            : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.055)

                  Behavior on color { ColorAnimation { duration: 120 } }
                  Behavior on border.color { ColorAnimation { duration: 120 } }

                  Rectangle {
                    width: 22
                    height: 3
                    radius: 2
                    anchors {
                      top: parent.top
                      left: parent.left
                      topMargin: 8
                      leftMargin: 8
                    }
                    color: quickTile.accent
                    opacity: quickTile.active ? 0.95 : quickMouse.containsMouse ? 0.8 : 0.5
                  }

                  Column {
                    anchors {
                      left: parent.left
                      right: parent.right
                      bottom: parent.bottom
                      leftMargin: 8
                      rightMargin: 8
                      bottomMargin: 7
                    }
                    spacing: 1

                    Text {
                      width: parent.width
                      height: 13
                      text: quickTile.label
                      color: Theme.text
                      font.pixelSize: 10
                      font.bold: true
                      elide: Text.ElideRight
                      horizontalAlignment: Text.AlignLeft
                      verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                      width: parent.width
                      height: 11
                      text: quickTile.status
                      color: quickTile.active ? Qt.rgba(quickTile.accent.r, quickTile.accent.g, quickTile.accent.b, 0.88)
                                              : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
                      font.pixelSize: 8
                      elide: Text.ElideRight
                      horizontalAlignment: Text.AlignLeft
                      verticalAlignment: Text.AlignVCenter
                    }
                  }

                  MouseArea {
                    id: quickMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runQuickAction(action)
                  }
                }
              }
            }

            Grid {
              id: sectionGrid
              width: parent.width
              columns: 2
              rowSpacing: 7
              columnSpacing: 7

              Repeater {
                model: nativeSectionsModel

                delegate: Rectangle {
                  id: sectionTile

                  required property string label
                  required property string hint
                  required property string page
                  required property color accent

                  width: (sectionGrid.width - sectionGrid.columnSpacing) / 2
                  height: 54
                  radius: 7
                  color: sectionMouse.pressed ? Qt.rgba(sectionTile.accent.r, sectionTile.accent.g, sectionTile.accent.b, 0.17)
                                              : sectionMouse.containsMouse ? Qt.rgba(sectionTile.accent.r, sectionTile.accent.g, sectionTile.accent.b, 0.12)
                                                                           : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.035)
                  border.width: 1
                  border.color: sectionMouse.containsMouse ? Qt.rgba(sectionTile.accent.r, sectionTile.accent.g, sectionTile.accent.b, 0.34)
                                                           : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.055)

                  Behavior on color { ColorAnimation { duration: 120 } }
                  Behavior on border.color { ColorAnimation { duration: 120 } }

                  Rectangle {
                    width: 3
                    radius: 2
                    anchors {
                      top: parent.top
                      bottom: parent.bottom
                      left: parent.left
                      topMargin: 10
                      bottomMargin: 10
                    }
                    color: sectionTile.accent
                    opacity: sectionMouse.containsMouse ? 0.95 : 0.55
                  }

                  Column {
                    anchors {
                      left: parent.left
                      right: parent.right
                      verticalCenter: parent.verticalCenter
                      leftMargin: 13
                      rightMargin: 10
                    }
                    spacing: 1

                    Text {
                      width: parent.width
                      text: sectionTile.label
                      color: Theme.text
                      font.pixelSize: 11
                      font.bold: true
                      elide: Text.ElideRight
                    }

                    Text {
                      width: parent.width
                      text: sectionTile.hint
                      color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
                      font.pixelSize: 9
                      elide: Text.ElideRight
                    }
                  }

                  MouseArea {
                    id: sectionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openPage(sectionTile.page, "")
                  }
                }
              }
            }
          }

          Column {
            id: detailPage
            width: parent.width
            height: parent.height
            spacing: 8
            visible: root.currentPage !== "home"

            Row {
              id: manageTabs
              width: parent.width
              height: root.currentPage === "manage" && root.currentSubpage === "" ? 30 : 0
              spacing: 6
              visible: height > 0

              Repeater {
                model: manageTabsModel

                delegate: Rectangle {
                  id: manageTab

                  required property string label
                  required property string action
                  required property color accent
                  property bool selected: root.manageTab === action.replace("manage-", "")

                  width: (manageTabs.width - manageTabs.spacing * 2) / 3
                  height: manageTabs.height
                  radius: 6
                  color: manageTabMouse.pressed ? Qt.rgba(manageTab.accent.r, manageTab.accent.g, manageTab.accent.b, 0.18)
                                                : manageTab.selected ? Qt.rgba(manageTab.accent.r, manageTab.accent.g, manageTab.accent.b, 0.14)
                                                                     : manageTabMouse.containsMouse ? Qt.rgba(manageTab.accent.r, manageTab.accent.g, manageTab.accent.b, 0.10)
                                                                                                     : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.035)
                  border.width: 1
                  border.color: manageTab.selected ? Qt.rgba(manageTab.accent.r, manageTab.accent.g, manageTab.accent.b, 0.38)
                                                   : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.055)

                  Text {
                    anchors.centerIn: parent
                    text: manageTab.label
                    color: manageTab.selected ? manageTab.accent : Theme.text
                    font.pixelSize: 10
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  MouseArea {
                    id: manageTabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runAction(manageTab.action)
                  }
                }
              }
            }

            Grid {
              id: actionGrid
              width: parent.width
              columns: 2
              rowSpacing: 7
              columnSpacing: 7

              Repeater {
                model: root.pageModel()

                delegate: Rectangle {
                  id: actionTile

                  required property string label
                  required property string hint
                  required property string icon
                  required property string action
                  required property color accent
                  property bool actionAvailable: action === "maintain-rollback" ? root.rollbackAvailable : true

                  width: (actionGrid.width - actionGrid.columnSpacing) / 2
                  height: actionAvailable ? 58 : 0
                  visible: actionAvailable
                  radius: 7
                  color: actionMouse.pressed ? Qt.rgba(actionTile.accent.r, actionTile.accent.g, actionTile.accent.b, 0.18)
                                             : actionMouse.containsMouse ? Qt.rgba(actionTile.accent.r, actionTile.accent.g, actionTile.accent.b, 0.12)
                                                                         : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.035)
                  border.width: 1
                  border.color: actionMouse.containsMouse ? Qt.rgba(actionTile.accent.r, actionTile.accent.g, actionTile.accent.b, 0.36)
                                                          : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.055)

                  Behavior on color { ColorAnimation { duration: 120 } }
                  Behavior on border.color { ColorAnimation { duration: 120 } }

                  Rectangle {
                    width: 3
                    radius: 2
                    anchors {
                      top: parent.top
                      bottom: parent.bottom
                      left: parent.left
                      topMargin: 10
                      bottomMargin: 10
                    }
                    color: actionTile.accent
                    opacity: actionMouse.containsMouse ? 0.95 : 0.55
                  }

                  Column {
                    anchors {
                      left: parent.left
                      right: parent.right
                      verticalCenter: parent.verticalCenter
                      leftMargin: 13
                      rightMargin: 10
                    }
                    spacing: 1

                    Text {
                      width: parent.width
                      text: actionTile.label
                      color: Theme.text
                      font.pixelSize: 11
                      font.bold: true
                      elide: Text.ElideRight
                    }

                    Text {
                      width: parent.width
                      text: actionTile.hint
                      color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
                      font.pixelSize: 9
                      elide: Text.ElideRight
                    }
                  }

                  MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runAction(actionTile.action)
                  }
                }
              }
            }
          }

          Rectangle {
            id: filterPicker
            visible: root.filterPickerOpen
            z: 20
            anchors {
              right: parent.right
              bottom: parent.bottom
              rightMargin: 6
              bottomMargin: 6
            }
            width: 188
            height: Math.min(236, filterPickerColumn.implicitHeight + 14)
            radius: 7
            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.98)
            border.width: 1
            border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.24)

            MouseArea {
              anchors.fill: parent
              onClicked: mouse.accepted = true
            }

            Flickable {
              anchors {
                fill: parent
                margins: 7
              }
              contentWidth: width
              contentHeight: filterPickerColumn.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              Column {
                id: filterPickerColumn
                width: parent.width
                spacing: 3

                Text {
                  width: parent.width
                  height: 16
                  text: "Filter"
                  color: Theme.text
                  font.pixelSize: 10
                  font.bold: true
                  elide: Text.ElideRight
                  verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                  id: filterOffRow
                  property bool isActive: root.currentFilter === ""

                  width: parent.width
                  height: 28
                  radius: 6
                  color: filterOffMouse.pressed ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.20)
                                                : filterOffRow.isActive ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                                                                        : filterOffMouse.containsMouse ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
                                                                                                       : "transparent"

                  Text {
                    anchors {
                      left: parent.left
                      right: parent.right
                      verticalCenter: parent.verticalCenter
                      leftMargin: 9
                      rightMargin: 9
                    }
                    text: "Off"
                    color: filterOffRow.isActive ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.72)
                    font.pixelSize: 11
                    elide: Text.ElideRight
                  }

                  MouseArea {
                    id: filterOffMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.applyFilter("")
                  }
                }

                Repeater {
                  model: root.filterList

                  delegate: Rectangle {
                    id: filterRow

                    required property string modelData
                    property bool isActive: root.currentFilter === modelData

                    width: filterPickerColumn.width
                    height: 28
                    radius: 6
                    color: filterMouse.pressed ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.20)
                                               : filterRow.isActive ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                                                                    : filterMouse.containsMouse ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
                                                                                                : "transparent"

                    Text {
                      anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 9
                        rightMargin: 9
                      }
                      text: filterRow.modelData
                      color: filterRow.isActive ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.72)
                      font.pixelSize: 11
                      elide: Text.ElideRight
                    }

                    MouseArea {
                      id: filterMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.applyFilter(filterRow.modelData)
                    }
                  }
                }

                Text {
                  width: parent.width
                  height: 24
                  visible: root.filterList.length === 0
                  text: "Loading..."
                  color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.38)
                  font.pixelSize: 10
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }
              }
            }
          }
        }
      }
    }
  }

  Item {
    anchors.fill: parent
    focus: root.visible
    Keys.onEscapePressed: Popups.closeAll()
  }
}
