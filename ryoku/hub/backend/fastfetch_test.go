package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// a representative JSONC config: comments, a $schema URL (whose // must survive
// the comment strip), an image logo, and one of every row kind the model knows
// (title, tagline, header, plain module, a module with an extra field, a command
// module, colours), plus a leading break.
const sampleFF = `{
  // editorial dossier
  "$schema": "https://example.com/schema.json",
  "logo": { "type": "kitty-direct", "source": "~/.config/fastfetch/emblem.png", "width": 28, "height": 14, "padding": { "top": 5, "right": 5, "left": 3 } },
  "display": { "color": { "keys": "38;2;226;52;42" }, "separator": "  " },
  "modules": [
    "break",
    { "type": "title", "format": "{user-name}@{host-name}" },
    { "type": "custom", "format": "\u001b[38;2;226;52;42m■\u001b[0m \u001b[38;2;143;135;112mRYOKU \u00b7 \u529b \u00b7 a hand-built Arch desktop\u001b[0m" },
    "break",
    { "type": "custom", "format": "\u001b[38;2;226;52;42m\u2500\u2500\u001b[0m \u001b[1;38;2;243;237;225mVITALS\u001b[0m \u001b[38;2;58;46;36m\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u001b[0m" },
    { "type": "cpu", "key": "CPU" },
    { "type": "gpu", "key": "GPU", "detectionMethod": "pci" },
    { "type": "command", "key": "OS", "text": "echo hi" },
    { "type": "colors", "symbol": "circle" }
  ]
}`

func loadSample(t *testing.T) ffModel {
	t.Helper()
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	if err := os.MkdirAll(filepath.Join(dir, "fastfetch"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "fastfetch", "config.jsonc"), []byte(sampleFF), 0o644); err != nil {
		t.Fatal(err)
	}
	m, err := loadFastfetch()
	if err != nil {
		t.Fatalf("loadFastfetch: %v", err)
	}
	return m
}

func rowByKind(rows []ffRow, kind string) *ffRow {
	for i := range rows {
		if rows[i].Kind == kind {
			return &rows[i]
		}
	}
	return nil
}

func TestStripJSONC(t *testing.T) {
	in := `{ "$schema": "https://x/y.json", // trailing
  "a": 1, /* block */ "b": "//not a comment" }`
	out := string(stripJSONC([]byte(in)))
	var v map[string]any
	if err := json.Unmarshal([]byte(out), &v); err != nil {
		t.Fatalf("stripped output does not parse: %v\n%s", err, out)
	}
	if v["$schema"] != "https://x/y.json" {
		t.Errorf("schema URL mangled: %v", v["$schema"])
	}
	if v["b"] != "//not a comment" {
		t.Errorf("string-internal // was stripped: %v", v["b"])
	}
}

func TestLoadFastfetchModel(t *testing.T) {
	m := loadSample(t)
	if m.Logo.Kind != "image" || m.Logo.Width != 28 || m.Logo.Padding != 3 {
		t.Errorf("logo = %+v, want image/28/3", m.Logo)
	}
	if m.Accent != "226;52;42" {
		t.Errorf("accent = %q, want 226;52;42", m.Accent)
	}
	if r := rowByKind(m.Rows, "tagline"); r == nil || r.Text != "RYOKU \u00b7 \u529b \u00b7 a hand-built Arch desktop" {
		t.Errorf("tagline text = %+v", r)
	}
	if r := rowByKind(m.Rows, "header"); r == nil || r.Text != "VITALS" {
		t.Errorf("header label = %+v", r)
	}
	cpu := rowByKind(m.Rows, "module")
	if cpu == nil || cpu.Module != "cpu" || cpu.Key != "CPU" {
		t.Errorf("first module = %+v, want cpu/CPU", cpu)
	}
}

func TestBuildRoundTripStable(t *testing.T) {
	m := loadSample(t)
	b, err := buildFastfetch(m)
	if err != nil {
		t.Fatal(err)
	}
	// the rebuilt config must parse and reload to an equivalent model.
	if err := os.WriteFile(filepath.Join(os.Getenv("XDG_CONFIG_HOME"), "fastfetch", "config.jsonc"), b, 0o644); err != nil {
		t.Fatal(err)
	}
	m2, err := loadFastfetch()
	if err != nil {
		t.Fatal(err)
	}
	if len(m2.Rows) != len(m.Rows) {
		t.Fatalf("row count changed: %d -> %d", len(m.Rows), len(m2.Rows))
	}
	if rowByKind(m2.Rows, "tagline").Text != "RYOKU \u00b7 \u529b \u00b7 a hand-built Arch desktop" {
		t.Errorf("tagline drifted on round-trip")
	}
	if rowByKind(m2.Rows, "header").Text != "VITALS" {
		t.Errorf("header drifted on round-trip")
	}
	// a module's extra field (gpu detectionMethod) survives the rebuild.
	if !strings.Contains(string(b), "detectionMethod") {
		t.Errorf("gpu detectionMethod dropped on rebuild")
	}
	// the command module's echo text survives.
	if !strings.Contains(string(b), "echo hi") {
		t.Errorf("command module text dropped on rebuild")
	}
}

func TestBuildTaglineFormatMatchesShipped(t *testing.T) {
	got := ffTaglineFormat("226;52;42", "RYOKU \u00b7 \u529b \u00b7 a hand-built Arch desktop")
	want := "\x1b[38;2;226;52;42m\u25a0\x1b[0m \x1b[38;2;143;135;112mRYOKU \u00b7 \u529b \u00b7 a hand-built Arch desktop\x1b[0m"
	if got != want {
		t.Errorf("tagline format:\n got %q\nwant %q", got, want)
	}
}

func TestToggleModuleDropsIt(t *testing.T) {
	m := loadSample(t)
	// disable the cpu module.
	for i := range m.Rows {
		if m.Rows[i].Kind == "module" && m.Rows[i].Module == "cpu" {
			m.Rows[i].Enabled = false
		}
	}
	b, err := buildFastfetch(m)
	if err != nil {
		t.Fatal(err)
	}
	var doc struct {
		Modules []json.RawMessage `json:"modules"`
	}
	if err := json.Unmarshal(b, &doc); err != nil {
		t.Fatal(err)
	}
	for _, rm := range doc.Modules {
		if strings.Contains(string(rm), `"cpu"`) {
			t.Errorf("disabled cpu module still present: %s", rm)
		}
	}
}

func TestAccentDrivesTemplates(t *testing.T) {
	m := loadSample(t)
	m.Accent = "10;20;30"
	b, err := buildFastfetch(m)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(b), "38;2;10;20;30") {
		t.Errorf("custom lines did not pick up the new accent")
	}
	// the accent must also land in display.color.keys so it colours the key
	// labels and reloads (get reads the accent back from there).
	if err := os.WriteFile(filepath.Join(os.Getenv("XDG_CONFIG_HOME"), "fastfetch", "config.jsonc"), b, 0o644); err != nil {
		t.Fatal(err)
	}
	m2, err := loadFastfetch()
	if err != nil {
		t.Fatal(err)
	}
	if m2.Accent != "10;20;30" {
		t.Errorf("accent did not round-trip: got %q", m2.Accent)
	}
}
