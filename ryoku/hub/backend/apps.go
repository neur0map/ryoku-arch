package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"strings"
)

// Default Apps: the swappable roles the Default Apps page offers, each with a
// short list of common candidates. `ryoku-hub apps` reports which candidates are
// installed (a binary on PATH) so the page can show them as chips; the field
// still accepts any command. The chosen command is stored in hypr.json "apps"
// and launched by the ryoku-app resolver (and exported as env by genApps).

type appCandidate struct {
	Label     string `json:"label"`
	Cmd       string `json:"cmd"`
	Installed bool   `json:"installed"`
}

type appRole struct {
	Role       string         `json:"role"`
	Label      string         `json:"label"`
	Fallback   string         `json:"fallback"` // the shipped default when unset
	Candidates []appCandidate `json:"candidates"`
}

// role -> {label, fallback, candidates}. Candidates are {label, cmd}; the cmd's
// meaningful binary (the app after `-e`, else the first word) is probed on PATH.
var appRoleDefs = []struct {
	Role, Label, Fallback string
	Cands                 [][2]string
}{
	{"browser", "Browser", "chromium", [][2]string{
		{"Firefox", "firefox"}, {"Chromium", "chromium"}, {"Chrome", "google-chrome-stable"},
		{"Brave", "brave"}, {"Vivaldi", "vivaldi-stable"}, {"Zen", "zen-browser"},
		{"LibreWolf", "librewolf"}, {"Qutebrowser", "qutebrowser"},
	}},
	{"terminal", "Terminal", "kitty", [][2]string{
		{"Kitty", "kitty"}, {"Alacritty", "alacritty"}, {"Foot", "foot"},
		{"WezTerm", "wezterm"}, {"Ghostty", "ghostty"}, {"Konsole", "konsole"},
	}},
	{"editor", "Editor", "kitty -e nvim", [][2]string{
		{"Neovim", "kitty -e nvim"}, {"Helix", "kitty -e hx"}, {"Vim", "kitty -e vim"},
		{"VS Code", "code"}, {"VSCodium", "codium"}, {"Zed", "zed"}, {"Sublime Text", "subl"},
	}},
	{"files", "File manager", "nautilus", [][2]string{
		{"Files (Nautilus)", "nautilus"}, {"Thunar", "thunar"}, {"Dolphin", "dolphin"},
		{"Nemo", "nemo"}, {"PCManFM", "pcmanfm-qt"}, {"Yazi", "kitty -e yazi"},
	}},
	{"notes", "Notes", "", [][2]string{
		{"Obsidian", "obsidian"}, {"Logseq", "logseq"}, {"Joplin", "joplin-desktop"},
		{"Standard Notes", "standard-notes"}, {"Zettlr", "zettlr"},
	}},
}

// binOf returns the binary a launch command actually depends on: the token after
// `-e` for a terminal-wrapped app (kitty -e nvim -> nvim), else the first word.
func binOf(cmd string) string {
	f := strings.Fields(cmd)
	for i, t := range f {
		if t == "-e" && i+1 < len(f) {
			return f[i+1]
		}
	}
	if len(f) > 0 {
		return f[0]
	}
	return ""
}

func appRoles() []appRole {
	out := make([]appRole, 0, len(appRoleDefs))
	for _, d := range appRoleDefs {
		r := appRole{Role: d.Role, Label: d.Label, Fallback: d.Fallback}
		for _, c := range d.Cands {
			_, err := exec.LookPath(binOf(c[1]))
			r.Candidates = append(r.Candidates, appCandidate{Label: c[0], Cmd: c[1], Installed: err == nil})
		}
		out = append(out, r)
	}
	return out
}

func printApps() error {
	b, err := json.Marshal(appRoles())
	if err != nil {
		return err
	}
	_, err = os.Stdout.Write(b)
	return err
}
