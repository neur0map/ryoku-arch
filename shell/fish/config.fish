source /usr/share/arch-fish-config/arch-config.fish

zoxide init fish | source

abbr -a ff fastfetch

function fish_greeting
    ~/.config/fish/ryoku-greeting.sh
end
