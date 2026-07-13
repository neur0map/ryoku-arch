package main

// The friendly editor behind the Hub's Fastfetch section. config.jsonc stays the
// source of truth (user-owned, hand-editable, seed-once); this reads it into a
// small model the GUI edits and writes it back, so GUI edits and hand-edits share
// one file. Unknown modules pass through verbatim, so a hand-added line is never
// lost. Custom brand lines (tagline, section headers) are rebuilt from templates
// that reproduce the shipped styling, so a no-op round-trip is stable.

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"unicode/utf8"
)

// fixed brand palette used by the custom-line templates, matching the shipped
// config.jsonc. only the accent is user-facing (it also drives display.color).
const (
	ffTan    = "143;135;112"
	ffBright = "243;237;225"
	ffDim    = "58;46;36"
	ffAccent = "226;52;42"
)

var (
	ffAnsiRe    = regexp.MustCompile("\x1b\\[[0-9;]*m")
	ffTanRe     = regexp.MustCompile("\x1b\\[38;2;" + regexp.QuoteMeta(ffTan) + "m(.*?)\x1b\\[0m")
	ffLabelRe   = regexp.MustCompile("\x1b\\[1;38;2;" + regexp.QuoteMeta(ffBright) + "m(.*?)\x1b\\[0m")
	ffKeysColor = regexp.MustCompile(`(?:38;2;)?([0-9]+;[0-9]+;[0-9]+)`)
)

func fastfetchDir() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	return filepath.Join(base, "fastfetch")
}

func fastfetchConfigPath() string { return filepath.Join(fastfetchDir(), "config.jsonc") }

// stripJSONC removes // line and /* */ block comments from a JSONC document,
// leaving comment-like text inside string literals (a $schema URL) intact so
// encoding/json can parse the rest.
func stripJSONC(b []byte) []byte {
	out := make([]byte, 0, len(b))
	inStr, esc, inLine, inBlock, skip := false, false, false, false, false
	for i := range b {
		if skip {
			skip = false
			continue
		}
		c := b[i]
		var next byte
		if i+1 < len(b) {
			next = b[i+1]
		}
		switch {
		case inLine:
			if c == '\n' {
				inLine = false
				out = append(out, c)
			}
		case inBlock:
			if c == '*' && next == '/' {
				inBlock = false
				skip = true
			}
		case inStr:
			out = append(out, c)
			switch {
			case esc:
				esc = false
			case c == '\\':
				esc = true
			case c == '"':
				inStr = false
			}
		case c == '"':
			inStr = true
			out = append(out, c)
		case c == '/' && next == '/':
			inLine = true
			skip = true
		case c == '/' && next == '*':
			inBlock = true
			skip = true
		default:
			out = append(out, c)
		}
	}
	return out
}

// ---- model ------------------------------------------------------------------

type ffLogo struct {
	Kind    string `json:"kind"` // image | ascii | builtin | none
	Source  string `json:"source"`
	Width   int    `json:"width"`
	Height  int    `json:"height"`
	Padding int    `json:"padding"`
}

// ffRow is one readout line. break/colors/title/module keep their original JSON in
// Raw so extra fields (a gpu detectionMethod, a command's echo) survive; tagline
// and header carry editable Text and are rebuilt from a template.
type ffRow struct {
	Kind    string          `json:"kind"` // title|tagline|header|module|break|colors|raw
	Enabled bool            `json:"enabled"`
	Label   string          `json:"label,omitempty"`
	Module  string          `json:"module,omitempty"`
	Key     string          `json:"key,omitempty"`
	Text    string          `json:"text,omitempty"`
	Raw     json.RawMessage `json:"raw,omitempty"`
}

type ffModel struct {
	Logo    ffLogo          `json:"logo"`
	Accent  string          `json:"accent"`
	Rows    []ffRow         `json:"rows"`
	Display json.RawMessage `json:"display,omitempty"`
	Schema  string          `json:"schema,omitempty"`
}

func runFastfetch(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("fastfetch needs get|save|preview|import-logo")
	}
	switch args[0] {
	case "get":
		m, err := loadFastfetch()
		if err != nil {
			return err
		}
		return printJSON(m)
	case "save":
		if len(args) < 2 {
			return fmt.Errorf("fastfetch save needs a JSON argument")
		}
		var m ffModel
		if err := json.Unmarshal([]byte(args[1]), &m); err != nil {
			return err
		}
		b, err := buildFastfetch(m)
		if err != nil {
			return err
		}
		return atomicWrite(fastfetchConfigPath(), b, 0o644)
	case "preview":
		if len(args) < 2 {
			return fmt.Errorf("fastfetch preview needs a JSON argument")
		}
		var m ffModel
		if err := json.Unmarshal([]byte(args[1]), &m); err != nil {
			return err
		}
		return previewFastfetch(m)
	case "import-logo":
		if len(args) < 2 {
			return fmt.Errorf("fastfetch import-logo needs a path")
		}
		p, err := importFastfetchLogo(args[1])
		if err != nil {
			return err
		}
		fmt.Println(p)
		return nil
	default:
		return fmt.Errorf("unknown fastfetch subcommand: %s", args[0])
	}
}

// ---- read: config.jsonc -> model --------------------------------------------

func loadFastfetch() (ffModel, error) {
	raw, err := os.ReadFile(fastfetchConfigPath())
	if err != nil {
		return defaultFastfetchModel(), nil
	}
	var doc struct {
		Schema  string            `json:"$schema"`
		Logo    map[string]any    `json:"logo"`
		Display json.RawMessage   `json:"display"`
		Modules []json.RawMessage `json:"modules"`
	}
	if err := json.Unmarshal(stripJSONC(raw), &doc); err != nil {
		return ffModel{}, fmt.Errorf("parse config.jsonc: %w", err)
	}
	m := ffModel{Schema: doc.Schema, Display: doc.Display, Accent: ffDisplayAccent(doc.Display), Logo: ffNormalizeLogo(doc.Logo)}
	for _, rm := range doc.Modules {
		m.Rows = append(m.Rows, ffNormalizeModule(rm))
	}
	return m, nil
}

func ffNormalizeLogo(l map[string]any) ffLogo {
	out := ffLogo{Kind: "none", Width: 28, Height: 14, Padding: 3}
	if l == nil {
		return out
	}
	t, _ := l["type"].(string)
	switch t {
	case "kitty", "kitty-direct", "kitty-icat", "chafa", "sixel", "iterm", "raw":
		out.Kind = "image"
	case "file", "file-raw", "data", "data-raw":
		out.Kind = "ascii"
	case "builtin", "small":
		out.Kind = "builtin"
	default:
		out.Kind = "none"
	}
	if s, ok := l["source"].(string); ok {
		out.Source = s
	}
	if w, ok := l["width"].(float64); ok {
		out.Width = int(w)
	}
	if h, ok := l["height"].(float64); ok {
		out.Height = int(h)
	}
	switch p := l["padding"].(type) {
	case float64:
		out.Padding = int(p)
	case map[string]any:
		if lp, ok := p["left"].(float64); ok {
			out.Padding = int(lp)
		}
	}
	return out
}

func ffNormalizeModule(rm json.RawMessage) ffRow {
	s := strings.TrimSpace(string(rm))
	if strings.HasPrefix(s, "\"") { // a bare string module ("break")
		var str string
		_ = json.Unmarshal(rm, &str)
		return ffRow{Kind: "break", Enabled: true, Label: "Spacer", Raw: rm}
	}
	var obj struct {
		Type   string `json:"type"`
		Key    string `json:"key"`
		Format string `json:"format"`
	}
	_ = json.Unmarshal(rm, &obj)
	switch obj.Type {
	case "title":
		return ffRow{Kind: "title", Enabled: true, Label: "Host / user", Raw: rm}
	case "custom":
		if strings.Contains(ffStripAnsi(obj.Format), "─") {
			return ffRow{Kind: "header", Enabled: true, Text: ffHeaderLabel(obj.Format), Label: "Section header", Raw: rm}
		}
		return ffRow{Kind: "tagline", Enabled: true, Text: ffTaglineText(obj.Format), Label: "Tagline", Raw: rm}
	case "colors":
		return ffRow{Kind: "colors", Enabled: true, Label: "Colour swatches", Raw: rm}
	default:
		label := obj.Key
		if label == "" {
			label = ffTitleCase(obj.Type)
		}
		return ffRow{Kind: "module", Enabled: true, Module: obj.Type, Key: obj.Key, Label: label, Raw: rm}
	}
}

func ffStripAnsi(s string) string { return ffAnsiRe.ReplaceAllString(s, "") }

func ffTaglineText(format string) string {
	if mm := ffTanRe.FindStringSubmatch(format); mm != nil {
		return mm[1]
	}
	return strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(ffStripAnsi(format)), "■"))
}

func ffHeaderLabel(format string) string {
	if mm := ffLabelRe.FindStringSubmatch(format); mm != nil {
		return mm[1]
	}
	return strings.TrimSpace(strings.Trim(ffStripAnsi(format), "─ "))
}

// ffDisplayAccent lifts the "R;G;B" of the readout keys out of the display block,
// so the templates and a colour picker share one accent. Defaults to the brand
// vermilion when the block is missing or unparseable.
func ffDisplayAccent(display json.RawMessage) string {
	if len(display) == 0 {
		return ffAccent
	}
	var d struct {
		Color json.RawMessage `json:"color"`
	}
	if json.Unmarshal(display, &d) != nil {
		return ffAccent
	}
	var keys string
	var cobj struct {
		Keys string `json:"keys"`
	}
	if json.Unmarshal(d.Color, &cobj) == nil && cobj.Keys != "" {
		keys = cobj.Keys
	} else {
		_ = json.Unmarshal(d.Color, &keys)
	}
	if mm := ffKeysColor.FindStringSubmatch(keys); mm != nil {
		return mm[1]
	}
	return ffAccent
}

// ---- write: model -> config.jsonc -------------------------------------------

type ffOutLogo struct {
	Type    string         `json:"type"`
	Source  string         `json:"source,omitempty"`
	Width   int            `json:"width,omitempty"`
	Height  int            `json:"height,omitempty"`
	Padding map[string]int `json:"padding,omitempty"`
}

type ffOutConfig struct {
	Schema  string            `json:"$schema,omitempty"`
	Logo    ffOutLogo         `json:"logo"`
	Display json.RawMessage   `json:"display,omitempty"`
	Modules []json.RawMessage `json:"modules"`
}

func buildFastfetch(m ffModel) ([]byte, error) {
	accent := m.Accent
	if ffKeysColor.FindStringSubmatch(accent) == nil {
		accent = ffAccent
	}
	var mods []json.RawMessage
	for _, r := range m.Rows {
		if !r.Enabled {
			continue
		}
		rm, err := ffBuildRow(r, accent)
		if err != nil {
			return nil, err
		}
		if rm != nil {
			mods = append(mods, rm)
		}
	}
	out := ffOutConfig{Schema: m.Schema, Display: ffApplyAccentToDisplay(m.Display, accent), Modules: mods, Logo: ffBuildLogo(m.Logo)}
	b, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(b, '\n'), nil
}

// ffApplyAccentToDisplay writes the accent into display.color.keys so the key
// labels match the accent the custom-line templates use, and so a saved accent
// reloads (get reads it back from here). Other display fields are preserved.
func ffApplyAccentToDisplay(display json.RawMessage, accent string) json.RawMessage {
	var d map[string]any
	if len(display) == 0 || json.Unmarshal(display, &d) != nil {
		d = map[string]any{}
	}
	color, _ := d["color"].(map[string]any)
	if color == nil {
		color = map[string]any{}
	}
	color["keys"] = "38;2;" + accent
	d["color"] = color
	b, err := json.Marshal(d)
	if err != nil {
		return display
	}
	return b
}

func ffBuildLogo(l ffLogo) ffOutLogo {
	out := ffOutLogo{Width: l.Width, Height: l.Height}
	switch l.Kind {
	case "image":
		out.Type = "kitty-direct"
		out.Source = l.Source
	case "ascii":
		out.Type = "file"
		out.Source = l.Source
	case "builtin":
		out.Type = "builtin"
		out.Width, out.Height = 0, 0
	default:
		out.Type = "none"
		out.Width, out.Height = 0, 0
	}
	if out.Type != "none" && out.Type != "builtin" {
		out.Padding = map[string]int{"top": 5, "right": 5, "left": l.Padding}
	}
	return out
}

func ffBuildRow(r ffRow, accent string) (json.RawMessage, error) {
	switch r.Kind {
	case "break":
		if len(r.Raw) > 0 {
			return r.Raw, nil
		}
		return json.RawMessage(`"break"`), nil
	case "tagline":
		return ffCustomModule(ffTaglineFormat(accent, r.Text)), nil
	case "header":
		return ffCustomModule(ffHeaderFormat(accent, r.Text)), nil
	case "module":
		// start from the original object so extras (detectionMethod, echo text)
		// survive, then apply the edited key.
		obj := map[string]any{}
		if len(r.Raw) > 0 {
			_ = json.Unmarshal(r.Raw, &obj)
		}
		if obj["type"] == nil {
			obj["type"] = r.Module
		}
		if r.Key != "" {
			obj["key"] = r.Key
		}
		return json.Marshal(obj)
	default: // title, colors, raw: verbatim
		if len(r.Raw) > 0 {
			return r.Raw, nil
		}
		return nil, nil
	}
}

func ffCustomModule(format string) json.RawMessage {
	b, _ := json.Marshal(map[string]string{"type": "custom", "format": format})
	return b
}

func ffTaglineFormat(accent, text string) string {
	return "\x1b[38;2;" + accent + "m■\x1b[0m \x1b[38;2;" + ffTan + "m" + text + "\x1b[0m"
}

func ffHeaderFormat(accent, label string) string {
	n := 32 - utf8.RuneCountInString(label)
	if n < 4 {
		n = 4
	}
	rule := strings.Repeat("─", n)
	return "\x1b[38;2;" + accent + "m──\x1b[0m \x1b[1;38;2;" + ffBright + "m" + label + "\x1b[0m \x1b[38;2;" + ffDim + "m" + rule + "\x1b[0m"
}

// ---- preview + logo import --------------------------------------------------

func previewFastfetch(m ffModel) error {
	b, err := buildFastfetch(m)
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp("", "ryoku-ff-*.jsonc")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(b); err != nil {
		return err
	}
	tmp.Close()
	// --logo none: the emblem is previewed in the Hub, this is just the readout.
	// --pipe false keeps the truecolor SGR the Hub parses into rich text.
	out, _ := exec.Command("fastfetch", "--config", tmp.Name(), "--logo", "none", "--pipe", "false").Output()
	os.Stdout.Write(out)
	return nil
}

// importFastfetchLogo copies a chosen logo into the fastfetch config dir so it is
// self-contained (survives moving the original), rasterizing an SVG to PNG since
// fastfetch has no SVG type. Prints the resulting path for the logo source.
func importFastfetchLogo(src string) (string, error) {
	src = ffExpandTilde(strings.TrimPrefix(src, "file://"))
	if _, err := os.Stat(src); err != nil {
		return "", fmt.Errorf("logo not found: %s", src)
	}
	dir := fastfetchDir()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	if strings.EqualFold(filepath.Ext(src), ".svg") {
		out := filepath.Join(dir, "ryoku-logo.png")
		if err := ffRasterizeSVG(src, out); err != nil {
			return "", err
		}
		return out, nil
	}
	dst := filepath.Join(dir, "ryoku-logo"+strings.ToLower(filepath.Ext(src)))
	if err := ffCopyFile(src, dst); err != nil {
		return "", err
	}
	return dst, nil
}

func ffRasterizeSVG(src, out string) error {
	if _, err := exec.LookPath("rsvg-convert"); err == nil {
		return exec.Command("rsvg-convert", "-w", "512", "-h", "512", "-o", out, src).Run()
	}
	if _, err := exec.LookPath("magick"); err == nil {
		return exec.Command("magick", "-background", "none", "-density", "384", src, "-resize", "512x512", out).Run()
	}
	if _, err := exec.LookPath("convert"); err == nil {
		return exec.Command("convert", "-background", "none", "-density", "384", src, "-resize", "512x512", out).Run()
	}
	return fmt.Errorf("no SVG rasterizer found (install librsvg or imagemagick)")
}

func ffCopyFile(src, dst string) error {
	b, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return atomicWrite(dst, b, 0o644)
}

func ffExpandTilde(p string) string {
	if p == "~" {
		return os.Getenv("HOME")
	}
	if strings.HasPrefix(p, "~/") {
		return filepath.Join(os.Getenv("HOME"), p[2:])
	}
	return p
}

func ffTitleCase(s string) string {
	if s == "" {
		return s
	}
	return strings.ToUpper(s[:1]) + s[1:]
}

// defaultFastfetchModel: a minimal readout for a box with no config.jsonc yet, so
// the section is never empty. materialize seeds the real one on install.
func defaultFastfetchModel() ffModel {
	mk := func(t, k string) ffRow {
		raw, _ := json.Marshal(map[string]string{"type": t, "key": k})
		return ffRow{Kind: "module", Enabled: true, Module: t, Key: k, Label: k, Raw: raw}
	}
	return ffModel{
		Accent: ffAccent,
		Logo:   ffLogo{Kind: "builtin", Width: 28, Height: 14, Padding: 3},
		Rows: []ffRow{
			mk("os", "OS"), mk("kernel", "KERNEL"), mk("cpu", "CPU"),
			mk("memory", "MEMORY"), mk("uptime", "UPTIME"),
		},
	}
}
