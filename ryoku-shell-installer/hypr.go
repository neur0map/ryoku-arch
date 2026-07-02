package main

// hypr.go reads a legacy hyprlang config tree (hyprland.conf plus source=
// includes) and salvages monitor and keyboard intent for an existing plain
// Hyprland or rice setup. hyprland 0.55 moved to lua config and only loads
// the .conf grammar when hyprland.lua is absent; the salvage follows the
// same rule. runs in detect(), before the backup moves ~/.config/hypr aside.

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

var (
	hyprVarRe     = regexp.MustCompile(`^\s*\$([A-Za-z0-9_]+)\s*=\s*(.+)$`)
	hyprSourceRe  = regexp.MustCompile(`^\s*source\s*=\s*(.+)$`)
	hyprMonitorRe = regexp.MustCompile(`^\s*monitor\s*=\s*(.+)$`)
	hyprMonV2Re   = regexp.MustCompile(`^\s*monitorv2\s*\{`)
	hyprInputRe   = regexp.MustCompile(`^\s*input\s*\{`)
	// [ \t] on purpose: \s would swallow the newline of an empty value and
	// hand the next line to the capture group.
	hyprKvRe       = func(key string) *regexp.Regexp { return regexp.MustCompile(`(?m)^\s*` + key + `[ \t]*=[ \t]*(.*)$`) }
	hyprV2Output   = hyprKvRe("output")
	hyprV2Mode     = hyprKvRe("mode")
	hyprV2Pos      = hyprKvRe("position")
	hyprV2Scale    = hyprKvRe("scale")
	hyprV2Trans    = hyprKvRe("transform")
	hyprV2Disabled = hyprKvRe("disabled")
	hyprV2Vrr      = hyprKvRe("vrr")
	hyprKbLayout   = hyprKvRe("kb_layout")
	hyprKbVariant  = hyprKvRe("kb_variant")
	hyprKbOptions  = hyprKvRe("kb_options")
	hyprKbFile     = hyprKvRe("kb_file")
)

// stripHyprComment cuts a # comment off; hyprlang's ## literal-hash escape is
// rare enough to ignore for salvage purposes.
func stripHyprComment(ln string) string {
	if i := strings.Index(ln, "#"); i >= 0 {
		ln = ln[:i]
	}
	return ln
}

// expandHyprVars substitutes collected $vars, longest name first so $configs
// does not eat $config. one level deep, hyprlang style.
func expandHyprVars(s string, vars map[string]string) string {
	if !strings.Contains(s, "$") {
		return s
	}
	names := make([]string, 0, len(vars))
	for n := range vars {
		names = append(names, n)
	}
	sort.Slice(names, func(i, j int) bool { return len(names[i]) > len(names[j]) })
	for _, n := range names {
		s = strings.ReplaceAll(s, n, vars[n])
	}
	return s
}

// readHyprTree walks hyprland.conf and its source= includes linearly, the
// way hyprlang loads them: $var assignments seen so far apply to include
// paths, later files just append. globs and ~ expand in source paths.
func readHyprTree(path, home string, vars map[string]string, seen map[string]bool, depth int) string {
	if depth > 6 || seen[path] {
		return ""
	}
	seen[path] = true
	b, err := os.ReadFile(path)
	if err != nil || len(b) > 1<<20 {
		return ""
	}
	var sb strings.Builder
	for _, raw := range strings.Split(string(b), "\n") {
		ln := stripHyprComment(raw)
		if m := hyprVarRe.FindStringSubmatch(ln); m != nil {
			vars["$"+m[1]] = strings.TrimSpace(expandHyprVars(m[2], vars))
			continue
		}
		if m := hyprSourceRe.FindStringSubmatch(ln); m != nil {
			p := strings.TrimSpace(expandHyprVars(m[1], vars))
			if strings.HasPrefix(p, "~/") {
				p = filepath.Join(home, p[2:])
			}
			if !filepath.IsAbs(p) {
				p = filepath.Join(filepath.Dir(path), p)
			}
			matches, _ := filepath.Glob(p)
			for _, mm := range matches {
				sb.WriteString("\n")
				sb.WriteString(readHyprTree(mm, home, vars, seen, depth+1))
			}
			continue
		}
		sb.WriteString(ln)
		sb.WriteString("\n")
	}
	return sb.String()
}

// loadHyprConfig returns the flattened, variable-expanded config text, or ""
// when there is nothing to salvage (no tree, or a lua-era config owns it).
func loadHyprConfig(home string) string {
	root := filepath.Join(home, ".config/hypr")
	if _, err := os.Stat(filepath.Join(root, "hyprland.lua")); err == nil {
		return "" // lua config present: hyprland ignores the .conf tree
	}
	vars := map[string]string{"$HOME": home}
	seen := map[string]bool{}
	text := readHyprTree(filepath.Join(root, "hyprland.conf"), home, vars, seen, 0)
	return expandHyprVars(text, vars)
}

// parseHyprMonitors reads flat monitor= lines and monitorv2 blocks. unlike
// niri, hyprland desc: names are kept: they translate 1:1 into Ryoku pins.
func parseHyprMonitors(text string) []niriOutput {
	lines := strings.Split(text, "\n")
	byName := map[string]int{}
	var outs []niriOutput
	record := func(o niriOutput) {
		if o.name == "" || !o.meaningful() {
			return
		}
		if at, dup := byName[o.name]; dup {
			outs[at] = o
			return
		}
		byName[o.name] = len(outs)
		outs = append(outs, o)
	}
	for i := 0; i < len(lines); i++ {
		ln := lines[i]
		if hyprMonV2Re.MatchString(ln) {
			t, end := blockText(lines, i)
			i = end
			record(hyprMonitorV2(t))
			continue
		}
		if m := hyprMonitorRe.FindStringSubmatch(ln); m != nil {
			record(hyprMonitorLine(m[1]))
		}
	}
	return outs
}

// hyprMonitorLine parses `NAME, RES, POS, SCALE[, key, value]...`; hyprlang
// keeps empty slots between commas, each field is trimmed.
func hyprMonitorLine(rest string) niriOutput {
	f := strings.Split(rest, ",")
	for i := range f {
		f[i] = strings.TrimSpace(f[i])
	}
	o := niriOutput{name: f[0]}
	if len(f) < 2 {
		return niriOutput{}
	}
	switch f[1] {
	case "disable":
		o.off = true
		return o
	case "addreserved":
		return niriOutput{} // reserved-area rule, a layout concern, not a pin
	}
	o.mode = f[1] // WxH@Hz, preferred, highres, highrr, maxwidth pass through
	if len(f) > 2 {
		o.position = f[2]
	}
	if len(f) > 3 && f[3] != "auto" {
		o.scale = f[3]
	}
	for j := 4; j+1 < len(f); j += 2 {
		v, err := strconv.Atoi(f[j+1])
		if err != nil {
			continue
		}
		switch f[j] {
		case "transform":
			if v >= 0 && v <= 7 {
				o.transform = v
			}
		case "vrr":
			if v >= 0 && v <= 2 {
				o.vrr = v
			}
		}
	}
	return o
}

func hyprMonitorV2(t string) niriOutput {
	get := func(re *regexp.Regexp) string {
		if m := re.FindStringSubmatch(t); m != nil {
			return strings.TrimSpace(m[1])
		}
		return ""
	}
	o := niriOutput{name: get(hyprV2Output)}
	o.mode = get(hyprV2Mode)
	o.position = get(hyprV2Pos)
	if s := get(hyprV2Scale); s != "auto" {
		o.scale = s
	}
	if v, err := strconv.Atoi(get(hyprV2Trans)); err == nil && v >= 0 && v <= 7 {
		o.transform = v
	}
	if v, err := strconv.Atoi(get(hyprV2Vrr)); err == nil && v >= 0 && v <= 2 {
		o.vrr = v
	}
	o.off = get(hyprV2Disabled) == "true"
	return o
}

// parseHyprInput pulls the keyboard fields from the global input block; the
// flat input:kb_layout form counts too. per-device blocks are ignored, the
// Ryoku keyboard.lua is global. a kb_file keymap overrides everything, so
// nothing is salvaged then.
func parseHyprInput(text string) (layout, variant, options string, hasFile bool) {
	lines := strings.Split(text, "\n")
	for i := 0; i < len(lines); i++ {
		var t string
		if hyprInputRe.MatchString(lines[i]) {
			t, i = blockText(lines, i)
		} else if strings.Contains(lines[i], "input:kb_") {
			t = strings.ReplaceAll(lines[i], "input:kb_", "kb_")
		} else {
			continue
		}
		if m := hyprKbFile.FindStringSubmatch(t); m != nil && strings.TrimSpace(m[1]) != "" {
			return "", "", "", true
		}
		if m := hyprKbLayout.FindStringSubmatch(t); m != nil {
			layout = strings.TrimSpace(m[1])
		}
		if m := hyprKbVariant.FindStringSubmatch(t); m != nil {
			variant = strings.TrimSpace(m[1])
		}
		if m := hyprKbOptions.FindStringSubmatch(t); m != nil {
			options = strings.TrimSpace(m[1])
		}
	}
	return layout, variant, options, false
}
