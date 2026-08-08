.pragma library

// Theme scheme catalog for the Hub Appearance page picker (COLOUR SCHEME).
//
// The two dynamic variants (Default, Wallpaper) then the 57 static themes, each with a
// 7-swatch preview projection [surface, onSurface, primary, secondary, tertiary, error,
// outline] and a dark flag (surface luma < 0.5). This is picker cosmetics ONLY: the daemon
// owns the authoritative 30-role palettes (ryoku/shell/ipc/themes_gen.go) and resolves the
// selected theme into shell.json `themePalette`, which every surface consumes. The id is the
// theme.theme value written through the settings seam -- the same key the sidebar theme
// picker (pill MenuTheme) reads and writes, so the two stay one truth on the selection.
//
// Generated from themes_gen.go (cross-checked byte-for-byte against MenuTheme.qml). Regenerate
// when the daemon catalog changes; a Go `theme` topic serving this projection would retire
// both this literal and the sidebar's.
var schemes = [
    { id: "Default", label: "Default", dynamic: true, icon: "palette" },
    { id: "Wallpaper", label: "Wallpaper", dynamic: true, icon: "wallpaper" },
    { id: "Bauhaus", label: "Bauhaus", dark: true, sw: ["#101318", "#EAEFF5", "#E37B66", "#E0A568", "#809D9E", "#CB886D", "#98A0AE"] },
    { id: "Black Turq", label: "Black Turq", dark: true, sw: ["#0a0a0a", "#c8dcdc", "#ADF0E9", "#8FECD5", "#A9D1D7", "#D35F5F", "#485362"] },
    { id: "Blood Rust", label: "Blood Rust", dark: true, sw: ["#1F2932", "#AFB3BD", "#7C545F", "#54737C", "#547C71", "#7C545F", "#2F3E4C"] },
    { id: "Boo", label: "Boo", dark: true, sw: ["#111113", "#e4dcec", "#9c75dd", "#63b0b0", "#5786bc", "#cd749c", "#5d6f74"] },
    { id: "Catppuccin Frappe", label: "Catppuccin Frapp\u00e9", dark: true, sw: ["#303446", "#c6d0f5", "#babbf1", "#eebebe", "#81c8be", "#e78284", "#a5adce"] },
    { id: "Catppuccin Latte", label: "Catppuccin Latte", dark: false, sw: ["#eff1f5", "#4c4f69", "#7287fd", "#dd7878", "#179299", "#d20f39", "#6c6f85"] },
    { id: "Catppuccin Macchiato", label: "Catppuccin Macchiato", dark: true, sw: ["#24273a", "#cad3f5", "#b7bdf8", "#f0c6c6", "#8bd5ca", "#ed8796", "#a5adcb"] },
    { id: "Catppuccin Mocha", label: "Catppuccin Mocha", dark: true, sw: ["#1e1e2e", "#cdd6f4", "#b4befe", "#f2cdcd", "#94e2d5", "#f38ba8", "#a6adc8"] },
    { id: "Crimson Moonlight", label: "Crimson Moonlight", dark: true, sw: ["#0f0e0e", "#f9f2f3", "#e15774", "#fca2ae", "#714e75", "#dd5571", "#796769"] },
    { id: "Cyberpunk", label: "Cyberpunk", dark: true, sw: ["#000000", "#FFFF00", "#00FFFF", "#FF00FF", "#00FF00", "#FF0000", "#4B0082"] },
    { id: "Desert Power", label: "Desert Power", dark: true, sw: ["#11100F", "#A1A09F", "#55504D", "#8EBABB", "#AF8F6B", "#B5745A", "#33302D"] },
    { id: "Dracula", label: "Dracula", dark: true, sw: ["#282A36", "#F8F8F2", "#BD93F9", "#FF79C6", "#8BE9FD", "#FF5555", "#6272A4"] },
    { id: "Eldritch", label: "Eldritch", dark: true, sw: ["#212337", "#ebfafa", "#37f499", "#04d1f9", "#a48cf2", "#f16c75", "#7081d0"] },
    { id: "Ethereal", label: "Ethereal", dark: true, sw: ["#060B1E", "#ffcead", "#7d82d9", "#ffcead", "#c89dc1", "#ED5B5A", "#6d7db6"] },
    { id: "Everforest Dark Hard", label: "Everforest Dark Hard", dark: true, sw: ["#1E2326", "#D3C6AA", "#A7C080", "#7FBBB3", "#83C092", "#E67E80", "#7A8478"] },
    { id: "Everforest Dark Medium", label: "Everforest Dark Medium", dark: true, sw: ["#232A2E", "#D3C6AA", "#A7C080", "#7FBBB3", "#83C092", "#E67E80", "#7A8478"] },
    { id: "Everforest Dark Soft", label: "Everforest Dark Soft", dark: true, sw: ["#293136", "#D3C6AA", "#A7C080", "#7FBBB3", "#83C092", "#E67E80", "#7A8478"] },
    { id: "Everforest Light Hard", label: "Everforest Light Hard", dark: false, sw: ["#FFFBEF", "#5C6A72", "#8DA101", "#3A94C5", "#35A77C", "#F85552", "#A6B0A0"] },
    { id: "Everforest Light Medium", label: "Everforest Light Medium", dark: false, sw: ["#FDF6E3", "#5C6A72", "#8DA101", "#3A94C5", "#35A77C", "#F85552", "#A6B0A0"] },
    { id: "Everforest Light Soft", label: "Everforest Light Soft", dark: false, sw: ["#F3EAD3", "#5C6A72", "#8DA101", "#3A94C5", "#35A77C", "#F85552", "#A6B0A0"] },
    { id: "Forest Stream", label: "Forest Stream", dark: true, sw: ["#0b0c0b", "#e3f5e7", "#41b193", "#3788a2", "#7a77cd", "#c7566f", "#3c7153"] },
    { id: "Gruvbox Dark Hard", label: "Gruvbox Dark Hard", dark: true, sw: ["#1D2021", "#EBDBB2", "#83A598", "#B8BB26", "#8EC07C", "#FB4934", "#928374"] },
    { id: "Gruvbox Dark Medium", label: "Gruvbox Dark Medium", dark: true, sw: ["#282828", "#EBDBB2", "#83A598", "#B8BB26", "#8EC07C", "#FB4934", "#928374"] },
    { id: "Gruvbox Dark Soft", label: "Gruvbox Dark Soft", dark: true, sw: ["#32302F", "#EBDBB2", "#83A598", "#B8BB26", "#8EC07C", "#FB4934", "#928374"] },
    { id: "Gruvbox Light Hard", label: "Gruvbox Light Hard", dark: false, sw: ["#F9F5D7", "#3C3836", "#076678", "#79740E", "#427B58", "#9D0006", "#928374"] },
    { id: "Gruvbox Light Medium", label: "Gruvbox Light Medium", dark: false, sw: ["#FBF1C7", "#3C3836", "#076678", "#79740E", "#427B58", "#9D0006", "#928374"] },
    { id: "Gruvbox Light Soft", label: "Gruvbox Light Soft", dark: false, sw: ["#F2E5BC", "#3C3836", "#076678", "#79740E", "#427B58", "#9D0006", "#928374"] },
    { id: "Hackerman", label: "Hackerman", dark: true, sw: ["#0B0C16", "#ddf7ff", "#4fe88f", "#7cf8f7", "#829dd4", "#50f872", "#6a6e95"] },
    { id: "InkyPinky", label: "InkyPinky", dark: true, sw: ["#13131D", "#c8c8c8", "#EA90A8", "#7c7ca8", "#9f859f", "#EA90A8", "#7c7ca8"] },
    { id: "Kanagawa Dragon", label: "Kanagawa Dragon", dark: true, sw: ["#181616", "#c5c9c5", "#8ba4b0", "#8992a7", "#8ea4a2", "#E82424", "#7a8382"] },
    { id: "Kanagawa Lotus", label: "Kanagawa Lotus", dark: false, sw: ["#f2ecbc", "#545464", "#4d699b", "#624c83", "#597b75", "#e82424", "#716e61"] },
    { id: "Kanagawa Wave", label: "Kanagawa Wave", dark: true, sw: ["#1F1F28", "#DCD7BA", "#7E9CD8", "#957FB8", "#7AA89F", "#E82424", "#938AA9"] },
    { id: "Miasma", label: "Miasma", dark: true, sw: ["#222222", "#c2c2b0", "#5f875f", "#c9a554", "#bb7744", "#685742", "#666666"] },
    { id: "Monokai Classic", label: "Monokai Classic", dark: true, sw: ["#221F22", "#FCFCFA", "#A9DC76", "#FFD866", "#FF6188", "#FF6188", "#727072"] },
    { id: "Nightfox", label: "Nightfox", dark: true, sw: ["#192330", "#cdcecf", "#719cd6", "#9d79d6", "#63cdcf", "#c94f6d", "#39506d"] },
    { id: "Nord Dark", label: "Nord Dark", dark: true, sw: ["#2E3440", "#ECEFF4", "#88C0D0", "#81A1C1", "#8FBCBB", "#BF616A", "#4C566A"] },
    { id: "Nord Light", label: "Nord Light", dark: false, sw: ["#ECEFF4", "#2E3440", "#5E81AC", "#81A1C1", "#8FBCBB", "#BF616A", "#D8DEE9"] },
    { id: "Oceanic Next", label: "Oceanic Next", dark: true, sw: ["#1B2B34", "#D8DEE9", "#6699CC", "#5FB3B3", "#99C794", "#EC5F67", "#4F5B66"] },
    { id: "One Dark", label: "One Dark", dark: true, sw: ["#282C34", "#ABB2BF", "#61AFEF", "#C678DD", "#56B6C2", "#E06C75", "#636D83"] },
    { id: "Osaka Jade", label: "Osaka Jade", dark: true, sw: ["#111c18", "#C1C497", "#509475", "#2DD5B7", "#D2689C", "#FF5345", "#53685B"] },
    { id: "Poimandres", label: "Poimandres", dark: true, sw: ["#1B1E28", "#E4F0FB", "#ADD7FF", "#5DE4C7", "#FCC5E9", "#D0679D", "#767C9D"] },
    { id: "Radioactive", label: "Radioactive", dark: true, sw: ["#1a1a14", "#d9d9cf", "#bbbc57", "#7b6c97", "#e3e3a8", "#cd749c", "#74745d"] },
    { id: "Retro 82", label: "Retro 82", dark: true, sw: ["#00172e", "#f6dcac", "#faa968", "#028391", "#f85525", "#f85525", "#3f8f8a"] },
    { id: "Rose Pine", label: "Ros\u00e9 Pine", dark: true, sw: ["#191724", "#E0DEF4", "#C4A7E7", "#9CCFD8", "#EBBCBA", "#EB6F92", "#6E6A86"] },
    { id: "Rose Pine Dawn", label: "Ros\u00e9 Pine Dawn", dark: false, sw: ["#FAF4ED", "#575279", "#907AA9", "#56949F", "#D7827E", "#B4637A", "#9893A5"] },
    { id: "Rose Pine Moon", label: "Ros\u00e9 Pine Moon", dark: true, sw: ["#232136", "#E0DEF4", "#C4A7E7", "#9CCFD8", "#EA9A97", "#EB6F92", "#6E6A86"] },
    { id: "Saga", label: "Saga", dark: true, sw: ["#05080a", "#fff6ff", "#b2fff3", "#dfbaff", "#ff9fbc", "#ff9fbc", "#4b4c4d"] },
    { id: "Seoul", label: "Seoul", dark: true, sw: ["#333233", "#DFDEBD", "#9A7372", "#98BC99", "#98BCBD", "#BE7572", "#565656"] },
    { id: "Solarized Dark", label: "Solarized Dark", dark: true, sw: ["#002b36", "#93a1a1", "#268bd2", "#2aa198", "#b58900", "#dc322f", "#839496"] },
    { id: "Solarized Light", label: "Solarized Light", dark: false, sw: ["#fdf6e3", "#586e75", "#268bd2", "#2aa198", "#b58900", "#dc322f", "#657b83"] },
    { id: "Solitude", label: "Solitude", dark: true, sw: ["#101315", "#cacccc", "#798186", "#a8adb0", "#de6145", "#de6145", "#565d60"] },
    { id: "Sunset Cloud", label: "Sunset Cloud", dark: true, sw: ["#0e0f06", "#ffffcf", "#bbc373", "#cd6d91", "#71d17c", "#bc5050", "#5d6f74"] },
    { id: "Synthwave 84", label: "Synthwave 84", dark: true, sw: ["#18191F", "#C4C4D6", "#FF536C", "#7F9FFF", "#C080FF", "#FF536C", "#484953"] },
    { id: "Tokyo Night", label: "Tokyo Night", dark: true, sw: ["#1a1b26", "#a9b1d6", "#7aa2f7", "#bb9af7", "#73daca", "#f7768e", "#9aa5ce"] },
    { id: "Tokyo Night Light", label: "Tokyo Night Light", dark: false, sw: ["#e6e7ed", "#343b58", "#2959aa", "#5a3e8e", "#33635c", "#8c4351", "#6c6e75"] },
    { id: "Tokyo Night Storm", label: "Tokyo Night Storm", dark: true, sw: ["#24283b", "#a9b1d6", "#7aa2f7", "#bb9af7", "#73daca", "#f7768e", "#9aa5ce"] },
    { id: "Varda", label: "Varda", dark: true, sw: ["#0C0E11", "#D0EBEE", "#52677C", "#665276", "#257B76", "#733447", "#8295A9"] },
];
