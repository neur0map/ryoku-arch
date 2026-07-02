package main

// sway.go salvages output and input intent from a sway config tree, same
// model as niri.go: parse in detect(), render pins in stepConfigs. sway
// itself stays installed as a fallback session and its config rides the
// backup copy list.

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var swayIncludeRe = regexp.MustCompile(`^\s*include\s+(.+)$`)

// swayTokens splits a config line on whitespace honoring double quotes, so
// `output "Make Model Serial" scale 2` keeps the description together.
func swayTokens(ln string) []string {
	var toks []string
	var cur strings.Builder
	inq := false
	flush := func() {
		if cur.Len() > 0 {
			toks = append(toks, cur.String())
			cur.Reset()
		}
	}
	for _, r := range ln {
		switch {
		case r == '"':
			inq = !inq
		case !inq && (r == ' ' || r == '\t'):
			flush()
		default:
			cur.WriteRune(r)
		}
	}
	flush()
	return toks
}

// readSwayTree loads a config and its includes. include paths get the useful
// subset of wordexp: ~, $HOME, $XDG_CONFIG_HOME, globs; command substitution
// is treated as unsalvageable and skipped. paths are relative to the
// including file's directory and a file is included at most once.
func readSwayTree(path, home string, seen map[string]bool, depth int) string {
	if depth > 6 || seen[path] {
		return ""
	}
	seen[path] = true
	b, err := os.ReadFile(path)
	if err != nil || len(b) > 1<<20 {
		return ""
	}
	var sb strings.Builder
	sb.Write(b)
	for _, ln := range strings.Split(string(b), "\n") {
		m := swayIncludeRe.FindStringSubmatch(ln)
		if m == nil {
			continue
		}
		p := strings.Trim(strings.TrimSpace(m[1]), `"'`)
		if strings.Contains(p, "$(") || strings.Contains(p, "`") {
			continue
		}
		p = strings.NewReplacer(
			"$XDG_CONFIG_HOME", filepath.Join(home, ".config"),
			"${XDG_CONFIG_HOME}", filepath.Join(home, ".config"),
			"$HOME", home, "${HOME}", home,
		).Replace(p)
		if strings.HasPrefix(p, "~/") {
			p = filepath.Join(home, p[2:])
		}
		if !filepath.IsAbs(p) {
			p = filepath.Join(filepath.Dir(path), p)
		}
		matches, _ := filepath.Glob(p)
		for _, mm := range matches {
			sb.WriteString("\n")
			sb.WriteString(readSwayTree(mm, home, seen, depth+1))
		}
	}
	return sb.String()
}

// loadSwayConfig reads the first config in sway's search order that exists
// (the i3 fallbacks carry no output/xkb grammar worth salvaging).
func loadSwayConfig(home string) string {
	for _, p := range []string{
		filepath.Join(home, ".sway/config"),
		filepath.Join(home, ".config/sway/config"),
	} {
		if _, err := os.Stat(p); err == nil {
			return readSwayTree(p, home, map[string]bool{}, 0)
		}
	}
	return ""
}

// parseSwayOutputs folds output lines by name: one output may be configured
// across several lines or as one line with several subcommands, later wins
// per field. `*` matches everything and is too dangerous to pin; quoted
// "Make Model Serial" names fall into renderPins' skipped bucket.
func parseSwayOutputs(text string) []niriOutput {
	byName := map[string]int{}
	var outs []niriOutput
	for _, ln := range strings.Split(text, "\n") {
		if t := strings.TrimSpace(ln); strings.HasPrefix(t, "#") {
			continue
		}
		toks := swayTokens(ln)
		if len(toks) < 3 || toks[0] != "output" || toks[1] == "*" {
			continue
		}
		var o niriOutput
		if at, ok := byName[toks[1]]; ok {
			o = outs[at]
		} else {
			o = niriOutput{name: toks[1]}
		}
		parseSwayOutputArgs(&o, toks[2:])
		if !o.meaningful() {
			continue
		}
		if at, ok := byName[o.name]; ok {
			outs[at] = o
		} else {
			byName[o.name] = len(outs)
			outs = append(outs, o)
		}
	}
	return outs
}

func parseSwayOutputArgs(o *niriOutput, args []string) {
	i := 0
	next := func() string {
		i++
		if i < len(args) {
			return args[i]
		}
		return ""
	}
	for ; i < len(args); i++ {
		switch args[i] {
		case "mode", "resolution", "res":
			v := next()
			if v == "--custom" {
				v = next()
			}
			o.mode = strings.TrimSuffix(v, "Hz")
		case "position", "pos":
			x, y := next(), next()
			if x != "" && y != "" {
				o.position = x + "x" + y
			}
		case "scale":
			o.scale = next()
		case "transform":
			// same wl_output enum as niri, the map carries over verbatim;
			// clockwise/anticlockwise modifiers are runtime-only
			if t, ok := niriTransform[next()]; ok {
				o.transform = t
			}
		case "disable":
			o.off = true
		case "enable":
			o.off = false
		case "adaptive_sync":
			if next() == "on" {
				o.vrr = 1
			}
		case "scale_filter", "subpixel", "max_render_time", "render_bit_depth", "power", "dpms":
			next() // known one-arg subcommands we don't carry over
		default:
			return // bg and friends take free-form args, stop here
		}
	}
}

// per-identifier keyboard fields; sway allows both one-line commands and
// brace blocks.
type swayKb struct {
	layout, variant, options string
	hasFile                  bool
}

// parseSwayInput picks the keyboard setup with sway's practical precedence
// for a one-keyboard config model: type:keyboard beats * beats the first
// specific device. an xkb_file overrides everything, nothing to salvage.
func parseSwayInput(text string) (layout, variant, options string, hasFile bool) {
	kbs := map[string]*swayKb{}
	var firstDev string
	lines := strings.Split(text, "\n")
	get := func(ident string) *swayKb {
		if kbs[ident] == nil {
			kbs[ident] = &swayKb{}
		}
		return kbs[ident]
	}
	apply := func(ident, key, val string) {
		val = strings.Trim(val, `"'`)
		kb := get(ident)
		switch key {
		case "xkb_layout":
			kb.layout = val
		case "xkb_variant":
			kb.variant = val
		case "xkb_options":
			kb.options = val
		case "xkb_file":
			kb.hasFile = true
		default:
			return
		}
		if ident != "type:keyboard" && ident != "*" && firstDev == "" {
			firstDev = ident
		}
	}
	for n := 0; n < len(lines); n++ {
		toks := swayTokens(lines[n])
		if len(toks) < 2 || toks[0] != "input" {
			continue
		}
		ident := toks[1]
		if strings.Contains(lines[n], "{") {
			t, end := blockText(lines, n)
			n = end
			for _, bl := range strings.Split(t, "\n") {
				if bt := swayTokens(bl); len(bt) >= 2 {
					apply(ident, bt[0], strings.Join(bt[1:], " "))
				}
			}
			continue
		}
		if len(toks) >= 4 {
			apply(ident, toks[2], strings.Join(toks[3:], " "))
		}
	}
	for _, ident := range []string{"type:keyboard", "*", firstDev} {
		if kb := kbs[ident]; kb != nil {
			if kb.hasFile {
				return "", "", "", true
			}
			if kb.layout != "" || kb.variant != "" || kb.options != "" {
				return kb.layout, kb.variant, kb.options, false
			}
		}
	}
	return "", "", "", false
}
