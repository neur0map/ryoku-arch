# Ryoku Keybindings

Source of truth: `config/niri/config.d/70-binds.kdl`.

`Mod` means `Super` on a normal Ryoku install. In a nested Niri session, `Mod`
means `Alt`.

## Session And Compositor

| Binding | Action |
| --- | --- |
| `Mod+Tab` | Toggle Niri overview. |
| `Mod+Shift+E` | Quit Niri with confirmation. |
| `Mod+Escape` | Toggle keyboard shortcut inhibition. Use this if a remote desktop or VM grabs shortcuts. |
| `Mod+Shift+O` | Power off monitors. Any input wakes them. |

## Shell Surfaces

| Binding | Action |
| --- | --- |
| `Alt+Tab` | Next window in the shell switcher. |
| `Alt+Shift+Tab` | Previous window in the shell switcher. |
| `Super+G` | Toggle crosshair overlay. |
| `Mod+Space` | Toggle app launcher / shell overview. |
| `Mod+V` | Toggle clipboard history. |
| `Mod+Alt+L` | Lock the session. |
| `Mod+S` | Toggle Dynamic Island tools mode (screenshot, record, lens, color picker, mic, OSK, caffeine, ...). |
| `Mod+Shift+S` | Region screenshot. |
| `Mod+Shift+X` | Region OCR. |
| `Mod+Shift+A` | Region web search. |
| `Ctrl+Alt+T` | Toggle wallpaper selector. |
| `Mod+Comma` | Open settings. |
| `Mod+Slash` | Toggle cheatsheet. |
| `Mod+Shift+W` | Cycle panel family. |
| `Mod+Shift+Q` | Toggle session / power dialog. |

## App Launchers

| Binding | Action |
| --- | --- |
| `Mod+T` | Open terminal. |
| `Mod+Return` | Open terminal. |
| `Super+E` | Open file manager. |
| `Super+W` | Open browser. |

## Window Management

| Binding | Action |
| --- | --- |
| `Mod+Q` | Close focused window. |
| `Mod+D` | Maximize focused column. |
| `Mod+F` | Fullscreen focused window. |
| `Mod+A` | Toggle floating / tiling for focused window. |
| `Mod+Shift+V` | Switch focus between floating and tiling layers. |
| `Mod+R` | Cycle preset column width. |
| `Mod+Shift+R` | Cycle preset window height inside a stacked column. |
| `Mod+Ctrl+R` | Reset focused window height. |
| `Mod+C` | Center focused column. |
| `Mod+Minus` | Decrease focused column width by 10 percent. |
| `Mod+Equal` | Increase focused column width by 10 percent. |
| `Mod+Shift+Minus` | Decrease focused window height by 10 percent. |
| `Mod+Shift+Equal` | Increase focused window height by 10 percent. |
| `Mod+BracketLeft` | Consume or expel a window to the left. |
| `Mod+BracketRight` | Consume or expel a window to the right. |

## Focus And Movement

| Binding | Action |
| --- | --- |
| `Mod+Left`, `Mod+H` | Focus column left. |
| `Mod+Right`, `Mod+L` | Focus column right. |
| `Mod+Up`, `Mod+K` | Focus window up. |
| `Mod+Down`, `Mod+J` | Focus window down. |
| `Mod+Home` | Focus first column. |
| `Mod+End` | Focus last column. |
| `Mod+Shift+Left`, `Mod+Shift+H` | Move focused column left. |
| `Mod+Shift+Right`, `Mod+Shift+L` | Move focused column right. |
| `Mod+Shift+Up`, `Mod+Shift+K` | Move focused window up. |
| `Mod+Shift+Down`, `Mod+Shift+J` | Move focused window down. |
| `Mod+Ctrl+Home` | Move focused column to first position. |
| `Mod+Ctrl+End` | Move focused column to last position. |

## Monitors

| Binding | Action |
| --- | --- |
| `Mod+Ctrl+Left` | Focus monitor left. |
| `Mod+Ctrl+Right` | Focus monitor right. |
| `Mod+Ctrl+Up` | Focus monitor up. |
| `Mod+Ctrl+Down` | Focus monitor down. |
| `Mod+Ctrl+Shift+Left` | Move focused column to monitor left. |
| `Mod+Ctrl+Shift+Right` | Move focused column to monitor right. |
| `Mod+Ctrl+Shift+Up` | Move focused column to monitor up. |
| `Mod+Ctrl+Shift+Down` | Move focused column to monitor down. |

## Workspaces

| Binding | Action |
| --- | --- |
| `Mod+1` through `Mod+9` | Focus workspace by number. |
| `Mod+Ctrl+1` through `Mod+Ctrl+9` | Move focused column to workspace by number. |
| `Mod+Page_Down` | Focus workspace down. |
| `Mod+Page_Up` | Focus workspace up. |
| `Mod+Ctrl+Page_Down` | Move focused column to workspace down. |
| `Mod+Ctrl+Page_Up` | Move focused column to workspace up. |
| `Mod+WheelScrollDown` | Focus workspace down. |
| `Mod+WheelScrollUp` | Focus workspace up. |
| `Mod+Ctrl+WheelScrollDown` | Move focused column to workspace down. |
| `Mod+Ctrl+WheelScrollUp` | Move focused column to workspace up. |
| `Mod+WheelScrollRight` | Focus column right. |
| `Mod+WheelScrollLeft` | Focus column left. |

## Screenshots And Hardware Keys

| Binding | Action |
| --- | --- |
| `Print` | Screenshot selection. |
| `Ctrl+Print` | Screenshot screen. |
| `Alt+Print` | Screenshot window. |
| `XF86AudioRaiseVolume` | Raise volume with OSD feedback. |
| `XF86AudioLowerVolume` | Lower volume with OSD feedback. |
| `XF86AudioMute` | Toggle audio mute. |
| `XF86AudioMicMute` | Toggle microphone mute. |
| `XF86MonBrightnessUp` | Increase display brightness. |
| `XF86MonBrightnessDown` | Decrease display brightness. |
| `XF86AudioPlay`, `XF86AudioPause` | Play / pause current media player. |
| `XF86AudioNext` | Next media track. |
| `XF86AudioPrev` | Previous media track. |

## Media Convenience Binds

| Binding | Action |
| --- | --- |
| `Ctrl+Mod+Space` | Play / pause current media player. |
| `Mod+Alt+N` | Next media track. |
| `Mod+Alt+P` | Previous media track. |
| `Mod+Shift+M` | Toggle audio mute. |
| `Mod+Shift+P` | Play / pause current media player. |
| `Mod+Shift+N` | Next media track. |
| `Mod+Shift+B` | Previous media track. |
