package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"testing"
)

func TestStripLegacySystemSidebar(t *testing.T) {
	raw := []byte(`{"frameBars":{"surfaces":{"stash":{"anchor":"right","panes":["stash"]},"system":{"anchor":"right","panes":["notifications","media"]}},"menus":{"quick-settings":{"modules":["home","media"]}}},"weatherLocation":"Oslo"}`)
	out, changed, err := stripLegacySystemSidebar(raw)
	if err != nil || !changed {
		t.Fatalf("system sidebar must be stripped: changed=%v err=%v", changed, err)
	}

	var cfg map[string]any
	if err := json.Unmarshal(out, &cfg); err != nil {
		t.Fatalf("rewritten JSON does not parse: %v", err)
	}
	frameBars := cfg["frameBars"].(map[string]any)
	surfaces := frameBars["surfaces"].(map[string]any)
	if _, present := surfaces["system"]; present {
		t.Error("retired frameBars.surfaces.system survived the migration")
	}
	if _, present := surfaces["stash"]; !present {
		t.Error("migration dropped the sibling stash surface")
	}
	menus := frameBars["menus"].(map[string]any)
	quickSettings := menus["quick-settings"].(map[string]any)
	modules := quickSettings["modules"].([]any)
	if len(modules) != 2 || modules[0] != "home" || modules[1] != "media" {
		t.Errorf("migration changed quick-settings modules: %v", modules)
	}
	if cfg["weatherLocation"] != "Oslo" {
		t.Errorf("migration changed unrelated settings: %v", cfg)
	}

	if _, changed, err := stripLegacySystemSidebar(out); err != nil || changed {
		t.Errorf("second strip must be a no-op: changed=%v err=%v", changed, err)
	}
	for _, clean := range []string{
		`{"frameBars":{"surfaces":{"stash":{}}}}`,
		`{"frameBars":{"menus":{}}}`,
		`{"weatherLocation":"Oslo"}`,
	} {
		if _, changed, err := stripLegacySystemSidebar([]byte(clean)); err != nil || changed {
			t.Errorf("clean store %s must be untouched: changed=%v err=%v", clean, changed, err)
		}
	}
	if _, _, err := stripLegacySystemSidebar([]byte("not json")); err == nil {
		t.Fatal("invalid JSON must error rather than being rewritten")
	}
}

func TestReconcileLegacySystemSidebar(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	path := filepath.Join(sys.ConfigHome(), "ryoku", "shell.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}

	if r := reconcileLegacySystemSidebar(false); r.status != recOK {
		t.Fatalf("missing shell.json: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}

	stored := `{"frameBars":{"surfaces":{"stash":{"anchor":"right"},"system":{"anchor":"right","panes":["notifications"]}}},"theme":"paper"}`
	if err := os.WriteFile(path, []byte(stored), 0o644); err != nil {
		t.Fatal(err)
	}
	if r := reconcileLegacySystemSidebar(true); r.status != recWouldFix {
		t.Fatalf("check with system sidebar: status=%s detail=%q, want todo", r.status.label(), r.detail)
	}
	if got, _ := os.ReadFile(path); string(got) != stored {
		t.Fatalf("check-only mutated shell.json: %s", got)
	}
	if r := reconcileLegacySystemSidebar(false); r.status != recFixed {
		t.Fatalf("fix with system sidebar: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}

	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var cfg map[string]any
	if err := json.Unmarshal(raw, &cfg); err != nil {
		t.Fatal(err)
	}
	frameBars := cfg["frameBars"].(map[string]any)
	surfaces := frameBars["surfaces"].(map[string]any)
	if _, present := surfaces["system"]; present {
		t.Error("fix did not strip frameBars.surfaces.system")
	}
	if _, present := surfaces["stash"]; !present {
		t.Error("fix dropped the sibling stash surface")
	}
	if cfg["theme"] != "paper" {
		t.Error("fix changed an unrelated top-level setting")
	}
	if r := reconcileLegacySystemSidebar(false); r.status != recOK {
		t.Fatalf("clean store: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}
}
