package main

// niri.go reads a niri config tree (config.kdl + includes) and carries the
// xkb keyboard setup and per-output monitor intent over to Hyprland-Lua.

import (
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

type niriOutput struct {
	name      string
	mode      string // "2560x1440@165.004" pass-through, "" = none set
	position  string // "1280x0", "" = auto
	transform int    // wl_output.transform 0..7
	scale     string // bare number as written, "" = niri auto
	off       bool
	vrr       int // 0 none, 1 always, 2 on-demand
}

// identity mapping: both compositors pass the raw wl_output.transform enum,
// so niri "90" really is hyprland 1. don't "fix" the direction.
var niriTransform = map[string]int{
	"normal": 0, "90": 1, "180": 2, "270": 3,
	"flipped": 4, "flipped-90": 5, "flipped-180": 6, "flipped-270": 7,
}

var niriIncludeRe = regexp.MustCompile(`(?m)^\s*include\s+(?:optional=true\s+)?"([^"]+)"`)

// stripKdl drops // line comments and /- commented nodes (cachyos ships its
// display.kdl fully /- commented; importing those blocks would be wrong).
func stripKdl(ln string) string {
	t := strings.TrimSpace(ln)
	if strings.HasPrefix(t, "/-") || strings.HasPrefix(t, "//") {
		return ""
	}
	if i := strings.Index(ln, "//"); i >= 0 {
		ln = ln[:i]
	}
	return ln
}

// readNiriTree loads a config file and everything it includes. include paths
// are relative to the including file; globs and ~ work.
func readNiriTree(path, home string, seen map[string]bool, depth int) string {
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
	for _, m := range niriIncludeRe.FindAllStringSubmatch(string(b), -1) {
		p := m[1]
		if strings.HasPrefix(p, "~/") {
			p = filepath.Join(home, p[2:])
		}
		if !filepath.IsAbs(p) {
			p = filepath.Join(filepath.Dir(path), p)
		}
		matches, _ := filepath.Glob(p)
		for _, mm := range matches {
			sb.WriteString("\n")
			sb.WriteString(readNiriTree(mm, home, seen, depth+1))
		}
	}
	return sb.String()
}

// loadNiriConfig concatenates config.kdl, its includes, and the common
// modular layouts (inir config.d, cachyos cfg).
func loadNiriConfig(home string) string {
	seen := map[string]bool{}
	root := filepath.Join(home, ".config/niri")
	text := readNiriTree(filepath.Join(root, "config.kdl"), home, seen, 0)
	for _, glob := range []string{"config.d/*.kdl", "cfg/*.kdl"} {
		matches, _ := filepath.Glob(filepath.Join(root, glob))
		for _, m := range matches {
			text += "\n" + readNiriTree(m, home, seen, 0)
		}
	}
	return text
}

// blockText collects the brace-block opened at lines[start], returning its
// content and the closing line's index. the header line's tail rides along
// (split on ;) so one-liners like `output "DP-1" { scale 2 }` parse too.
func blockText(lines []string, start int) (string, int) {
	hdr := stripKdl(lines[start])
	depth := strings.Count(hdr, "{") - strings.Count(hdr, "}")
	rest := hdr[strings.Index(hdr, "{")+1:]
	body := []string{strings.NewReplacer(";", "\n", "}", "").Replace(rest)}
	i := start
	for depth > 0 && i+1 < len(lines) {
		i++
		ln := stripKdl(lines[i])
		depth += strings.Count(ln, "{") - strings.Count(ln, "}")
		body = append(body, ln)
	}
	return strings.Join(body, "\n"), i
}

var (
	niriOutputHdrRe = regexp.MustCompile(`^\s*output\s+"([^"]+)"\s*\{`)
	niriXkbHdrRe    = regexp.MustCompile(`^\s*xkb\s*\{`)
	niriModeRe      = regexp.MustCompile(`(?m)^\s*mode\s+(?:custom=true\s+)?"([^"]+)"`)
	niriScaleRe     = regexp.MustCompile(`(?m)^\s*scale\s+([0-9]+(?:\.[0-9]+)?)\s*$`)
	niriTransformRe = regexp.MustCompile(`(?m)^\s*transform\s+"([^"]+)"`)
	niriPosRe       = regexp.MustCompile(`(?m)^\s*position\s+x=(-?[0-9]+)\s+y=(-?[0-9]+)`)
	niriOffRe       = regexp.MustCompile(`(?m)^\s*off\s*$`)
	niriVrrRe       = regexp.MustCompile(`(?m)^\s*variable-refresh-rate(\s+on-demand=true)?\s*$`)
	kdlStrField     = func(field string) *regexp.Regexp {
		return regexp.MustCompile(`(?m)^\s*` + field + `\s+"([^"]*)"`)
	}
	niriXkbLayoutRe  = kdlStrField("layout")
	niriXkbVariantRe = kdlStrField("variant")
	niriXkbOptionsRe = kdlStrField("options")
	niriXkbFileRe    = kdlStrField("file")
)

// parseNiriOutputs extracts every non-default output block; later blocks for
// the same name win, like niri's include override order.
func parseNiriOutputs(text string) []niriOutput {
	lines := strings.Split(text, "\n")
	byName := map[string]int{}
	var outs []niriOutput
	for i := 0; i < len(lines); i++ {
		ln := stripKdl(lines[i])
		m := niriOutputHdrRe.FindStringSubmatch(ln)
		if m == nil {
			continue
		}
		text, end := blockText(lines, i)
		i = end
		o := niriOutput{name: m[1]}
		if mm := niriModeRe.FindStringSubmatch(text); mm != nil {
			o.mode = mm[1]
		}
		if mm := niriScaleRe.FindStringSubmatch(text); mm != nil {
			o.scale = mm[1]
		}
		if mm := niriTransformRe.FindStringSubmatch(text); mm != nil {
			o.transform = niriTransform[mm[1]]
		}
		if mm := niriPosRe.FindStringSubmatch(text); mm != nil {
			o.position = mm[1] + "x" + mm[2]
		}
		o.off = niriOffRe.MatchString(text)
		if mm := niriVrrRe.FindStringSubmatch(text); mm != nil {
			if mm[1] != "" {
				o.vrr = 2
			} else {
				o.vrr = 1
			}
		}
		if !o.meaningful() {
			continue
		}
		if at, dup := byName[o.name]; dup {
			outs[at] = o
			continue
		}
		byName[o.name] = len(outs)
		outs = append(outs, o)
	}
	return outs
}

func (o niriOutput) meaningful() bool {
	return o.off || o.mode != "" || o.position != "" || o.transform != 0 || o.scale != "" || o.vrr > 0
}

// parseNiriXkb pulls layout/variant/options from the xkb block. a keymap
// file overrides all fields, so hasFile means don't salvage.
func parseNiriXkb(text string) (layout, variant, options string, hasFile bool) {
	lines := strings.Split(text, "\n")
	for i := 0; i < len(lines); i++ {
		if !niriXkbHdrRe.MatchString(stripKdl(lines[i])) {
			continue
		}
		t, end := blockText(lines, i)
		i = end
		if niriXkbFileRe.FindStringSubmatch(t) != nil {
			return "", "", "", true
		}
		if m := niriXkbLayoutRe.FindStringSubmatch(t); m != nil {
			layout = m[1]
		}
		if m := niriXkbVariantRe.FindStringSubmatch(t); m != nil {
			variant = m[1]
		}
		if m := niriXkbOptionsRe.FindStringSubmatch(t); m != nil {
			options = m[1]
		}
	}
	return layout, variant, options, false
}

// renderNiriPins turns salvaged niri outputs into monitors_user.lua pins.
func renderNiriPins(outs []niriOutput) (pins string, skipped []string) {
	return renderPins(outs, false, "niri")
}

// renderPins turns salvaged outputs into monitors_user.lua pins, which
// autoscale leaves alone. description-style names ("Make Model Serial")
// can't be matched to a connector and come back in skipped, except for the
// hyprland source whose desc: pins translate 1:1 (allowDesc).
func renderPins(outs []niriOutput, allowDesc bool, source string) (pins string, skipped []string) {
	var b strings.Builder
	wrote := false
	for _, o := range outs {
		if strings.ContainsAny(o.name, "\"\\") || (!allowDesc && strings.Contains(o.name, " ")) {
			skipped = append(skipped, o.name)
			continue
		}
		if o.off {
			b.WriteString(`hl.monitor({ output = "` + o.name + `", disabled = true })` + "\n")
			wrote = true
			continue
		}
		mode := o.mode
		if mode == "" {
			mode = "highrr"
		}
		pos := o.position
		if pos == "" {
			pos = "auto"
		}
		scale, scaleNote := o.scale, ""
		if scale == "" {
			scale, scaleNote = "1", " -- "+source+" had no explicit scale; raise this if the panel is HiDPI"
		}
		b.WriteString(`hl.monitor({ output = "` + o.name + `", mode = "` + mode + `", position = "` + pos + `", scale = ` + scale)
		if o.transform != 0 {
			b.WriteString(", transform = " + strconv.Itoa(o.transform))
		}
		if o.vrr > 0 {
			b.WriteString(", vrr = " + strconv.Itoa(o.vrr))
		}
		b.WriteString(" })" + scaleNote + "\n")
		wrote = true
	}
	if !wrote {
		return "", skipped
	}
	hdr := "-- migrated from your " + source + " output settings by ryoku-shell-install.\n" +
		"-- ryoku-monitor autoscale leaves the outputs named here alone; edit or\n" +
		"-- delete lines to hand control back. see monitors_user.lua.example.\n"
	return hdr + b.String(), skipped
}
