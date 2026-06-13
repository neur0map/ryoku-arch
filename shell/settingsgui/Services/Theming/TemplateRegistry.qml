pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settingsgui.Commons
import Ryoku.Config

Singleton {
  id: root

  Component.onCompleted: {
    if (GlobalConfig.templates.enableUserTheming)
    writeUserTemplatesToml();
  }

  readonly property string templateApplyScript: Quickshell.shellDir + "/settingsgui" + '/Scripts/bash/template-apply.sh'
  readonly property string gtkRefreshScript: Quickshell.shellDir + "/settingsgui" + '/Scripts/python/src/theming/gtk-refresh.py'
  readonly property string kdeApplyScript: Quickshell.shellDir + "/settingsgui" + '/Scripts/python/src/theming/kde-apply-scheme.py'
  readonly property string vscodeHelperScript: Quickshell.shellDir + "/settingsgui" + '/Scripts/python/src/theming/vscode-helper.py'

  // Dynamically resolved VSCode extension theme paths (matching the installed theme extension)
  property var resolvedCodePaths: []
  property var resolvedCodiumPaths: []

  // Terminal configurations (for wallpaper-based templates)
  // Each terminal must define a postHook that sets up config includes and triggers reload
  readonly property var terminals: [
    {
      "id": "foot",
      "name": "Foot",
      "templatePath": "terminal/foot",
      "predefinedTemplatePath": "terminal/foot-predefined",
      "outputPath": "~/.config/foot/themes/ryoku",
      "postHook": `${templateApplyScript} foot`
    },
    {
      "id": "ghostty",
      "name": "Ghostty",
      "templatePath": "terminal/ghostty",
      "predefinedTemplatePath": "terminal/ghostty-predefined",
      "outputPath": "~/.config/ghostty/themes/ryoku",
      "postHook": `${templateApplyScript} ghostty`
    },
    {
      "id": "kitty",
      "name": "Kitty",
      "templatePath": "terminal/kitty.conf",
      "predefinedTemplatePath": "terminal/kitty-predefined.conf",
      "outputPath": "~/.config/kitty/themes/ryoku.conf",
      "postHook": `${templateApplyScript} kitty`
    },
    {
      "id": "alacritty",
      "name": "Alacritty",
      "templatePath": "terminal/alacritty.toml",
      "predefinedTemplatePath": "terminal/alacritty-predefined.toml",
      "outputPath": "~/.config/alacritty/themes/ryoku.toml",
      "postHook": `${templateApplyScript} alacritty`
    },
    {
      "id": "wezterm",
      "name": "Wezterm",
      "templatePath": "terminal/wezterm.toml",
      "predefinedTemplatePath": "terminal/wezterm-predefined.toml",
      "outputPath": "~/.config/wezterm/colors/Ryoku.toml",
      "postHook": `${templateApplyScript} wezterm`
    },
    {
      "id": "starship",
      "name": "Starship",
      "templatePath": "terminal/starship.toml",
      "predefinedTemplatePath": "terminal/starship-predefined.toml",
      "outputPath": "~/.cache/ryoku/settings-gui/starship-palette.toml",
      "postHook": `${templateApplyScript} starship`
    }
  ]

  readonly property var applications: [
    {
      "id": "gtk",
      "name": "GTK",
      "category": "system",
      "input": "gtk4.css",
      "outputs": [
        {
          "path": "~/.config/gtk-3.0/ryoku.css",
          "input": "gtk3.css"
        },
        {
          "path": "~/.config/gtk-4.0/ryoku.css",
          "input": "gtk4.css"
        }
      ],
      "postProcess": mode => `python3 ${gtkRefreshScript} ${mode}`
    },
    {
      "id": "qt",
      "name": "Qt",
      "category": "system",
      "input": "qtct.conf",
      "outputs": [
        {
          "path": "~/.config/qt5ct/colors/ryoku.conf"
        },
        {
          "path": "~/.config/qt6ct/colors/ryoku.conf"
        }
      ]
    },
    {
      "id": "kcolorscheme",
      "name": "KColorScheme",
      "category": "system",
      "input": "kcolorscheme.colors",
      "outputs": [
        {
          "path": "~/.local/share/color-schemes/ryoku.colors"
        }
      ],
      "postProcess": () => `${kdeApplyScript} ryoku`
    },
    {
      "id": "fuzzel",
      "name": "Fuzzel",
      "category": "launcher",
      "input": "fuzzel.conf",
      "outputs": [
        {
          "path": "~/.config/fuzzel/themes/ryoku"
        }
      ],
      "postProcess": () => `${templateApplyScript} fuzzel`
    },
    {
      "id": "vicinae",
      "name": "Vicinae",
      "category": "launcher",
      "input": "vicinae.toml",
      "outputs": [
        {
          "path": "~/.local/share/vicinae/themes/ryoku.toml"
        }
      ],
      "postProcess": () => `cp --update=none ${Quickshell.shellDir + "/settingsgui"}/Assets/ryoku-logo.svg ~/.local/share/vicinae/themes/ryoku-logo.svg && ${templateApplyScript} vicinae`
    },
    {
      "id": "walker",
      "name": "Walker",
      "category": "launcher",
      "input": "walker.css",
      "outputs": [
        {
          "path": "~/.config/walker/themes/ryoku/style.css"
        }
      ],
      "postProcess": () => `${templateApplyScript} walker`,
      "strict": true // Use strict mode for palette generation (preserves custom surface/outline values)
    },
    {
      "id": "pywalfox",
      "name": "Pywalfox",
      "category": "browser",
      "input": "pywalfox.json",
      "outputs": [
        {
          "path": "~/.cache/wal/colors.json"
        }
      ],
      "postProcess": mode => `${templateApplyScript} pywalfox ${mode}`
    }
    ,
    {
      "id": "discord",
      "name": "Discord",
      "category": "misc",
      "input": ["discord-midnight.css", "discord-material.css"],
      "clients": [
        {
          "name": "vesktop",
          "path": "~/.config/vesktop"
        },
        {
          "name": "webcord",
          "path": "~/.config/webcord"
        },
        {
          "name": "armcord",
          "path": "~/.config/armcord"
        },
        {
          "name": "equibop",
          "path": "~/.config/equibop"
        },
        {
          "name": "equicord",
          "path": "~/.config/Equicord"
        },
        {
          "name": "lightcord",
          "path": "~/.config/lightcord"
        },
        {
          "name": "dorion",
          "path": "~/.config/dorion"
        },
        {
          "name": "vencord",
          "path": "~/.config/Vencord"
        },
        {
          "name": "vencord-flatpak",
          "path": "~/.var/app/com.discordapp.Discord/config/Vencord"
        },
        {
          "name": "betterdiscord",
          "path": "~/.config/BetterDiscord"
        }
      ]
    },
    {
      "id": "code",
      "name": "VSCode",
      "category": "editor",
      "input": "code.json",
      "clients": [
        {
          "name": "code",
          "path": "~/.vscode/extensions/noctalia.noctaliatheme-0.0.5/themes/NoctaliaTheme-color-theme.json"
        },
        {
          "name": "codium",
          "path": "~/.vscode-oss/extensions/noctalia.noctaliatheme-0.0.5-universal/themes/NoctaliaTheme-color-theme.json"
        }
      ]
    },
    {
      "id": "zed",
      "name": "Zed",
      "category": "editor",
      "input": "zed.json",
      "outputs": [
        {
          "path": "~/.config/zed/themes/ryoku.json"
        }
      ],
      "dualMode": true // Template contains both dark and light theme patterns
    },
    {
      "id": "helix",
      "name": "Helix",
      "category": "editor",
      "input": "helix.toml",
      "outputs": [
        {
          "path": "~/.config/helix/themes/ryoku.toml"
        }
      ]
    },
    {
      "id": "spicetify",
      "name": "Spicetify",
      "category": "audio",
      "input": "spicetify.ini",
      "outputs": [
        {
          "path": "~/.config/spicetify/Themes/Comfy/color.ini"
        }
      ],
      "postProcess": () => `spicetify -q apply --no-restart`
    },
    {
      "id": "telegram",
      "name": "Telegram",
      "category": "misc",
      "input": "telegram.tdesktop-theme",
      "outputs": [
        {
          "path": "~/.config/telegram-desktop/themes/ryoku.tdesktop-theme"
        }
      ]
    },
    {
      "id": "zenBrowser",
      "name": "Zen Browser",
      "category": "browser",
      "input": "zen-browser/zen-userChrome.css",
      "outputs": [
        {
          "path": "~/.cache/ryoku/settings-gui/zen-browser/zen-userChrome.css"
        },
        {
          "path": "~/.cache/ryoku/settings-gui/zen-browser/zen-userContent.css",
          "input": "zen-browser/zen-userContent.css"
        }
      ],
      "postProcess": ()
                     => "sh -c 'CSS_CHROME=\"$HOME/.cache/ryoku/settings-gui/zen-browser/zen-userChrome.css\"; CSS_CONTENT=\"$HOME/.cache/ryoku/settings-gui/zen-browser/zen-userContent.css\"; LINE_CHROME=\"@import \\\"$CSS_CHROME\\\";\"; LINE_CONTENT=\"@import \\\"$CSS_CONTENT\\\";\"; find \"$HOME/.config/zen\" \"$HOME/.zen\" -mindepth 2 -maxdepth 2 -type d -name chrome -print0 2>/dev/null | while IFS= read -r -d \"\" dir; do USER_CHROME=\"$dir/userChrome.css\"; USER_CONTENT=\"$dir/userContent.css\"; mkdir -p \"$dir\"; touch \"$USER_CHROME\" \"$USER_CONTENT\"; sed -i \"/zen-browser\\/zen-userChrome\\.css/d\" \"$USER_CHROME\"; sed -i \"/zen-browser\\/zen-userContent\\.css/d\" \"$USER_CONTENT\"; if ! grep -Fq \"$LINE_CHROME\" \"$USER_CHROME\"; then printf \"%s\\n\" \"$LINE_CHROME\" >> \"$USER_CHROME\"; fi; if ! grep -Fq \"$LINE_CONTENT\" \"$USER_CONTENT\"; then printf \"%s\\n\" \"$LINE_CONTENT\" >> \"$USER_CONTENT\"; fi; done'"
    },
    {
      "id": "cava",
      "name": "Cava",
      "category": "audio",
      "input": "cava.ini",
      "outputs": [
        {
          "path": "~/.config/cava/themes/ryoku"
        }
      ],
      "postProcess": () => `${templateApplyScript} cava`
    },
    {
      "id": "yazi",
      "name": "Yazi",
      "category": "misc",
      "input": "yazi.toml",
      "outputs": [
        {
          "path": "~/.config/yazi/flavors/ryoku.yazi/flavor.toml"
        }
      ],
      "postProcess": () => `${templateApplyScript} yazi`
    },
    {
      "id": "emacs",
      "name": "Emacs",
      "category": "editor",
      "input": "emacs.el",
      "postProcess": () => `emacsclient -e "(load-theme 'ryoku t)"`
    },
    {
      "id": "labwc",
      "name": "Labwc",
      "category": "compositor",
      "input": "labwc.conf",
      "outputs": [
        {
          "path": "~/.config/labwc/themerc-override"
        }
      ],
      "postProcess": () => `${templateApplyScript} labwc`
    },
    {
      "id": "niri",
      "name": "Niri",
      "category": "compositor",
      "input": "niri.kdl",
      "outputs": [
        {
          "path": "~/.config/niri/ryoku.kdl"
        }
      ],
      "postProcess": () => `${templateApplyScript} niri`
    },
    {
      "id": "sway",
      "name": "Sway",
      "category": "compositor",
      "input": "sway",
      "outputs": [
        {
          "path": "~/.config/sway/ryoku"
        }
      ],
      "postProcess": () => `${templateApplyScript} sway`
    },
    {
      "id": "scroll",
      "name": "Scroll",
      "category": "compositor",
      "input": "scroll",
      "outputs": [
        {
          "path": "~/.config/scroll/ryoku"
        }
      ],
      "postProcess": () => `${templateApplyScript} scroll`
    },
    {
      "id": "hyprland",
      "name": "Hyprland",
      "category": "compositor",
      "input": "hyprland.lua",
      "outputs": [
        {
          "path": "~/.config/hypr/colors.lua"
        }
      ],
      "postProcess": () => "hyprctl reload"
    },
    {
      "id": "hyprtoolkit",
      "name": "Hyprtoolkit",
      "category": "system",
      "input": "hyprtoolkit.conf",
      "outputs": [
        {
          "path": "~/.config/hypr/hyprtoolkit.conf"
        }
      ]
    },
    {
      "id": "mango",
      "name": "Mango",
      "category": "compositor",
      "input": "mango.conf",
      "outputs": [
        {
          "path": "~/.config/mango/ryoku.conf"
        }
      ],
      "postProcess": () => `${templateApplyScript} mango`
    },
    {
      "id": "btop",
      "name": "btop",
      "category": "misc",
      "input": "btop.theme",
      "outputs": [
        {
          "path": "~/.config/btop/themes/ryoku.theme"
        }
      ],
      "postProcess": () => `${templateApplyScript} btop`
    },
    {
      "id": "zathura",
      "name": "Zathura",
      "category": "misc",
      "input": "zathurarc",
      "outputs": [
        {
          "path": "~/.config/zathura/ryokurc"
        }
      ],
      "postProcess": () => `${templateApplyScript} zathura`
    },
    {
      "id": "steam",
      "name": "Steam",
      "category": "misc",
      "input": "steam.css",
      "outputs": [
        {
          "path": "~/.steam/steam/steamui/skins/Material-Theme/css/main/colors/matugen.css"
        }
      ]
    }
  ]

  // Extract Discord clients for ProgramCheckerService compatibility
  readonly property var discordClients: {
    var clients = [];
    var discordApp = applications.find(app => app.id === "discord");
    if (discordApp && discordApp.clients) {
      discordApp.clients.forEach(client => {
                                   clients.push({
                                                  "name": client.name,
                                                  "configPath": client.path,
                                                  "themePath": `${client.path}/themes/ryoku.theme.css`
                                                });
                                 });
    }
    return clients;
  }

  function resolvedCodeClientPaths(clientName) {
    if (clientName === "code")
      return resolvedCodePaths;
    if (clientName === "codium")
      return resolvedCodiumPaths;
    return [];
  }

  // Extract Code clients for ProgramCheckerService compatibility
  readonly property var codeClients: {
    var clients = [];
    var codeApp = applications.find(app => app.id === "code");
    if (codeApp && codeApp.clients) {
      codeApp.clients.forEach(client => {
                                var themePath = client.path;
                                var baseConfigDir = "";
                                if (client.name === "code") {
                                  // For VSCode: ~/.vscode/extensions/... -> ~/.vscode
                                  baseConfigDir = "~/.vscode";
                                } else if (client.name === "codium") {
                                  // For VSCodium: ~/.vscode-oss/extensions/... -> ~/.vscode-oss
                                  baseConfigDir = "~/.vscode-oss";
                                }
                                clients.push({
                                               "name": client.name,
                                               "configPath": baseConfigDir,
                                               "themePath": "" // resolved dynamically via resolvedCodeClientPaths()
                                             });
                              });
    }
    return clients;
  }

  Process {
    id: codeResolverProcess
    command: ["python3", vscodeHelperScript, "~/.vscode/extensions"]
    running: true
    property var paths: []
    stdout: SplitParser {
      onRead: data => {
        var line = data.trim();
        if (line)
        codeResolverProcess.paths.push(line);
      }
    }
    onExited: {
      root.resolvedCodePaths = paths;
    }
  }

  Process {
    id: codiumResolverProcess
    command: ["python3", vscodeHelperScript, "~/.vscode-oss/extensions"]
    running: true
    property var paths: []
    stdout: SplitParser {
      onRead: data => {
        var line = data.trim();
        if (line)
        codiumResolverProcess.paths.push(line);
      }
    }
    onExited: {
      root.resolvedCodiumPaths = paths;
    }
  }
  function buildUserTemplatesToml() {
    var lines = [];
    lines.push("[config]");
    lines.push("");
    lines.push("[templates]");
    lines.push("");
    lines.push("# User-defined templates");
    lines.push("# Add your custom templates below");
    lines.push("# Example:");
    lines.push("# [templates.myapp]");
    lines.push("# input_path = \"~/.config/ryoku/settings-gui/templates/myapp.css\"");
    lines.push("# output_path = \"~/.config/myapp/theme.css\"");
    lines.push("# post_hook = \"myapp --reload-theme\"");
    lines.push("");
    lines.push("# Remove this section and add your own templates");
    lines.push("#[templates.placeholder]");
    lines.push("#input_path = \"" + Quickshell.shellDir + "/settingsgui" + "/Assets/Templates/ryoku.json\"");
    lines.push("#output_path = \"" + Settings.cacheDir + "placeholder.json\"");
    lines.push("");

    return lines.join("\n") + "\n";
  }

  function writeUserTemplatesToml() {
    var userConfigPath = Settings.configDir + "user-templates.toml";

    fileCheckProcess.command = ["test", "-s", userConfigPath];
    fileCheckProcess.running = true;
  }

  function doWriteUserTemplatesToml() {
    var userConfigPath = Settings.configDir + "user-templates.toml";
    var configContent = buildUserTemplatesToml();
    var userConfigPathEsc = userConfigPath.replace(/'/g, "'\\''");
    var configDirEsc = Settings.configDir.replace(/'/g, "'\\''");

    // Combine mkdir and write in a single script to avoid race condition
    var script = `mkdir -p '${configDirEsc}' && cat > '${userConfigPathEsc}' << 'EOF'\n`;
    script += configContent;
    script += "EOF\n";
    fileWriteProcess.command = ["sh", "-c", script];
    fileWriteProcess.running = true;
  }

  // Extract Emacs clients for ProgramCheckerService compatibility
  readonly property var emacsClients: [
    {
      "name": "doom",
      "path": "~/.config/doom"
    },
    {
      "name": "modern",
      "path": "~/.config/emacs"
    },
    {
      "name": "traditional",
      "path": "~/.emacs.d"
    }
  ]

  Process {
    id: fileCheckProcess
    running: false

    onExited: function (exitCode) {
      if (exitCode === 0) {
        Logger.d("TemplateRegistry", "User templates config already exists, skipping creation");
      } else {
        doWriteUserTemplatesToml();
      }
    }
  }

  Process {
    id: fileWriteProcess
    running: false

    onExited: function (exitCode) {
      if (exitCode === 0) {
        Logger.d("TemplateRegistry", "User templates config written to:", Settings.configDir + "user-templates.toml");
      } else {
        Logger.e("TemplateRegistry", "Failed to write user templates config (exit code:", exitCode + ")");
      }
    }
  }
}
