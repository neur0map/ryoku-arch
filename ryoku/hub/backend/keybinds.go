package main

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// keybind legend = whatever binds.lua actually has live
// (ryoku/hyprland/modules/binds.lua, deployed to ~/.config/hypr). one source of
// truth; no second hand-maintained list to drift.

type bind struct {
	Keys       []string `json:"keys"`
	Combo      string   `json:"combo"`
	Desc       string   `json:"desc"`
	Rebindable bool     `json:"rebindable"`
}

type category struct {
	Name  string `json:"name"`
	Binds []bind `json:"binds"`
}

type legend struct {
	Categories []category `json:"categories"`
}

func bindsPath() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	return filepath.Join(base, "hypr", "modules", "binds.lua")
}

func keybinds() legend {
	b, err := os.ReadFile(bindsPath())
	if err != nil {
		return legend{Categories: []category{}}
	}
	return parseBinds(string(b))
}

var (
	reHeader = regexp.MustCompile(`^--\s+(.+?)\s*$`)
	reBind   = regexp.MustCompile(`hl\.bind\((.*?),\s*(.+)$`)
	reTrail  = regexp.MustCompile(`\s--\s+(.+?)\s*$`)
	reExec   = regexp.MustCompile(`exec_cmd\("([^"]*)"`)
)

// parseBinds walks binds.lua a line at a time. section comments (`-- Apps`)
// open a category; each hl.bind adds an entry, description = the trailing
// comment if present, else derived from the dispatcher. the 1..0 workspace
// loop collapses into two range entries.
func parseBinds(src string) legend {
	var cats []category
	cur := -1
	inLoop := false

	add := func(b bind) {
		if cur < 0 {
			cats = append(cats, category{Name: "General"})
			cur = 0
		}
		cats[cur].Binds = append(cats[cur].Binds, b)
	}

	for _, line := range strings.Split(src, "\n") {
		trimmed := strings.TrimSpace(line)

		if strings.HasPrefix(trimmed, "for ") {
			inLoop = true
			continue
		}
		if inLoop && trimmed == "end" {
			inLoop = false
			continue
		}

		if !strings.Contains(trimmed, "hl.bind(") {
			if m := reHeader.FindStringSubmatch(trimmed); m != nil {
				cats = append(cats, category{Name: m[1]})
				cur = len(cats) - 1
			}
			continue
		}

		comment := ""
		if m := reTrail.FindStringSubmatch(line); m != nil {
			comment = m[1]
		}
		m := reBind.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		loopVar := ""
		if inLoop {
			loopVar = "1\u20260" // 1…0
		}
		keys, combo := resolveKeys(m[1], loopVar)
		add(bind{
			Keys:       keys,
			Combo:      combo,
			Desc:       describe(comment, m[2]),
			Rebindable: rebindable(combo),
		})
	}

	if cats == nil {
		cats = []category{}
	}
	return legend{Categories: cats}
}

// resolveKeys: first hl.bind arg -> (display tokens, raw combo). the arg may be
// wrapped in the K() rebind helper (K(mod .. " + Q")); unwrap it first. then it
// is either a quoted key literal ("XF86AudioRaiseVolume") or a Lua concat
// (mod .. " + SHIFT + A"); inside the workspace loop the key/i identifier becomes
// the 1…0 range. the raw combo is what K() keys on at runtime, i.e. the rebind id.
func resolveKeys(arg, loopVar string) ([]string, string) {
	arg = strings.TrimSpace(arg)
	if strings.HasPrefix(arg, "K(") && strings.HasSuffix(arg, ")") {
		arg = strings.TrimSpace(arg[2 : len(arg)-1])
	}
	if strings.HasPrefix(arg, "\"") {
		s := unquote(arg)
		return splitCombo(s), s
	}
	var sb strings.Builder
	for _, p := range strings.Split(arg, "..") {
		p = strings.TrimSpace(p)
		switch {
		case p == "mod":
			sb.WriteString("SUPER")
		case strings.HasPrefix(p, "\""):
			sb.WriteString(unquote(p))
		case p == "key" || p == "i":
			sb.WriteString(loopVar)
		default:
			sb.WriteString(p)
		}
	}
	raw := sb.String()
	return splitCombo(raw), raw
}

// rebindable: only a single literal combo can be recorded over. the workspace
// loop (its combo carries the 1…0 range) and the pointer binds cannot.
func rebindable(combo string) bool {
	return combo != "" && !strings.Contains(combo, "\u2026") && !strings.Contains(combo, "mouse")
}

func splitCombo(s string) []string {
	var out []string
	for _, p := range strings.Split(s, "+") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, prettyKey(p))
		}
	}
	return out
}

func unquote(s string) string {
	s = strings.TrimSpace(s)
	if len(s) >= 2 && strings.HasPrefix(s, "\"") && strings.HasSuffix(s, "\"") {
		return s[1 : len(s)-1]
	}
	return s
}

var keyNames = map[string]string{
	"SUPER":   "Super",
	"SHIFT":   "Shift",
	"ALT":     "Alt",
	"CTRL":    "Ctrl",
	"CONTROL": "Ctrl",
	"Return":  "Enter",
	"comma":   ",",
	"grave":   "\u0060",
	"Left":    "\u2190",
	"Right":   "\u2192",
	"Up":      "\u2191",
	"Down":    "\u2193",

	"mouse:272":  "LMB",
	"mouse:273":  "RMB",
	"mouse_up":   "Scroll \u2191",
	"mouse_down": "Scroll \u2193",

	"XF86AudioRaiseVolume": "Vol +",
	"XF86AudioLowerVolume": "Vol \u2212",
	"XF86AudioMute":        "Mute",
	"XF86AudioPlay":        "Play",
	"XF86AudioNext":        "Next",
	"XF86AudioPrev":        "Prev",
}

func prettyKey(tok string) string {
	if v, ok := keyNames[tok]; ok {
		return v
	}
	return tok
}

func describe(comment, dispatcher string) string {
	if comment != "" {
		return capitalize(comment)
	}
	return capitalize(describeDispatcher(dispatcher))
}

func describeDispatcher(d string) string {
	if m := reExec.FindStringSubmatch(d); m != nil {
		return describeExec(m[1])
	}
	switch {
	case strings.Contains(d, "window.close"):
		return "close window"
	case strings.Contains(d, "window.fullscreen"):
		return "fullscreen"
	case strings.Contains(d, "window.float") && strings.Contains(d, "enable"):
		return "float window"
	case strings.Contains(d, "window.float") && strings.Contains(d, "disable"):
		return "tile window"
	case strings.Contains(d, "window.drag"):
		return "move window"
	case strings.Contains(d, "window.resize"):
		return "resize window"
	case strings.Contains(d, "window.move"):
		return "move window to workspace"
	case strings.Contains(d, "focus"):
		switch {
		case strings.Contains(d, "r-1"):
			return "previous workspace"
		case strings.Contains(d, "r+1"):
			return "next workspace"
		}
		return "focus workspace"
	}
	return d
}

func describeExec(cmd string) string {
	if strings.HasPrefix(cmd, "ryoku-app ") {
		return strings.TrimPrefix(cmd, "ryoku-app ")
	}
	switch {
	case cmd == "kitty":
		return "terminal"
	case cmd == "nautilus":
		return "files"
	case cmd == "chromium":
		return "browser"
	case strings.Contains(cmd, "hyprpicker"):
		return "pick a color"
	case strings.Contains(cmd, "set-volume") && strings.Contains(cmd, "%+"):
		return "volume up"
	case strings.Contains(cmd, "set-volume"):
		return "volume down"
	case strings.Contains(cmd, "set-mute"):
		return "mute toggle"
	case strings.Contains(cmd, "play-pause"):
		return "play / pause"
	case strings.Contains(cmd, "playerctl next"):
		return "next track"
	case strings.Contains(cmd, "playerctl previous"):
		return "previous track"
	}
	return cmd
}

func capitalize(s string) string {
	if s == "" {
		return s
	}
	r := []rune(s)
	r[0] = []rune(strings.ToUpper(string(r[0])))[0]
	return string(r)
}
