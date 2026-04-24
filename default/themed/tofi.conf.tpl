# Ryoku tofi config rendered per-theme. Every theme with a colors.toml
# gets its own rendering of this template dropped at
# ~/.config/ryoku/current/theme/tofi.conf. bin/ryoku-launch-walker
# prefers that path; this template is the source of those colors.

font = JetBrainsMono Nerd Font
font-size = 12
prompt-text = "> "

width = 50%
height = 40%
anchor = center
horizontal = false

background-color = {{ background }}
text-color = {{ foreground }}
selection-color = {{ accent }}
selection-background = {{ color8 }}
selection-background-padding = 4
prompt-color = {{ accent }}
input-color = {{ foreground }}

border-width = 2
border-color = {{ active_border_color }}
outline-width = 0
corner-radius = 6

padding-top = 8
padding-bottom = 8
padding-left = 8
padding-right = 8
prompt-padding = 4

num-results = 10
result-spacing = 2

hide-cursor = true
ascii-input = false

# Tofi defaults drun-launch to false, which only prints the Exec= line
# to stdout instead of launching. ryoku-launch-walker does not capture
# that output, so leaving the default means Super+Space silently fails.
drun-launch = true
