package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"testing"
)

// moveStashRight flips frameBars.surfaces.stash.anchor from "left" to "right",
// leaves sibling surfaces, the stash panes/minWidth and every top-level key
// untouched, and does nothing once the anchor is already right.
func TestMoveStashRight(t *testing.T) {
	// Only stash.anchor flips; an unrelated future surface and top-level keys stay.
	full := []byte(`{"frameBars":{"surfaces":{"stash":{"anchor":"left","minWidth":340,"panes":["stash"]},"future":{"anchor":"top","minWidth":500}},"dock":{"pinned":[]}},"fontScale":1.3}`)
	out, changed, err := moveStashRight(full)
	if err != nil || !changed {
		t.Fatalf("stash left anchor must be flipped: changed=%v err=%v", changed, err)
	}
	var cfg map[string]any
	if err := json.Unmarshal(out, &cfg); err != nil {
		t.Fatalf("migrated JSON does not parse: %v", err)
	}
	surfaces := cfg["frameBars"].(map[string]any)["surfaces"].(map[string]any)
	stash := surfaces["stash"].(map[string]any)
	if stash["anchor"] != "right" {
		t.Errorf("stash anchor not flipped to right: %v", stash["anchor"])
	}
	if stash["minWidth"].(float64) != 340 {
		t.Errorf("stash minWidth was lost or changed: %v", stash["minWidth"])
	}
	if panes, ok := stash["panes"].([]any); !ok || len(panes) != 1 || panes[0] != "stash" {
		t.Errorf("stash panes were lost or changed: %v", stash["panes"])
	}
	if surfaces["future"].(map[string]any)["anchor"] != "top" {
		t.Errorf("sibling surface was disturbed: %v", surfaces["future"])
	}
	if cfg["fontScale"].(float64) != 1.3 {
		t.Errorf("passthrough key fontScale was lost: %v", cfg["fontScale"])
	}

	// migrating is idempotent: the corrected store is now a no-op.
	if _, changed, err := moveStashRight(out); err != nil || changed {
		t.Errorf("re-migrating a corrected store must be a no-op: changed=%v err=%v", changed, err)
	}

	// an anchor already right is untouched.
	if _, changed, err := moveStashRight([]byte(`{"frameBars":{"surfaces":{"stash":{"anchor":"right"}}}}`)); err != nil || changed {
		t.Errorf("a right-anchored stash must be untouched: changed=%v err=%v", changed, err)
	}

	// missing frameBars / surfaces / stash subtrees are each a no-op.
	for _, store := range []string{
		`{"fontScale":1}`,
		`{"frameBars":{"dock":{"pinned":[]}}}`,
		`{"frameBars":{"surfaces":{"future":{"anchor":"top"}}}}`,
		`{"frameBars":{"surfaces":{"stash":{"minWidth":340}}}}`,
	} {
		if _, changed, err := moveStashRight([]byte(store)); err != nil || changed {
			t.Errorf("store %s must be untouched: changed=%v err=%v", store, changed, err)
		}
	}

	// garbage errors rather than silently rewriting.
	if _, _, err := moveStashRight([]byte("not json")); err == nil {
		t.Fatal("garbage must error, not silently rewrite")
	}
}

// the reconciler reads the persisted store: check reports without mutating, fix
// flips the anchor in place and reports the change, and a clean store is a no-op.
func TestReconcileStashSidebar(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	path := filepath.Join(sys.ConfigHome(), "ryoku", "shell.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}

	// no shell.json yet: ok, nothing to do.
	if r := reconcileStashSidebar(false); r.status != recOK {
		t.Fatalf("missing shell.json: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}

	stored := `{"frameBars":{"surfaces":{"stash":{"anchor":"left","panes":["stash"]},"future":{"anchor":"top"}}}}`
	if err := os.WriteFile(path, []byte(stored), 0o644); err != nil {
		t.Fatal(err)
	}

	// check-only reports the stale anchor but leaves the file byte-for-byte.
	if r := reconcileStashSidebar(true); r.status != recWouldFix {
		t.Fatalf("check with left anchor: status=%s detail=%q, want todo", r.status.label(), r.detail)
	}
	if got, _ := os.ReadFile(path); string(got) != stored {
		t.Fatalf("check-only mutated the store: %s", got)
	}

	// fix flips it and reports the change.
	if r := reconcileStashSidebar(false); r.status != recFixed {
		t.Fatalf("fix with left anchor: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var cfg map[string]any
	if err := json.Unmarshal(raw, &cfg); err != nil {
		t.Fatalf("rewritten store does not parse: %v", err)
	}
	surfaces := cfg["frameBars"].(map[string]any)["surfaces"].(map[string]any)
	if surfaces["stash"].(map[string]any)["anchor"] != "right" {
		t.Error("fix did not flip stash anchor to right")
	}
	if surfaces["future"].(map[string]any)["anchor"] != "top" {
		t.Error("fix disturbed the sibling surface")
	}

	// second run is a no-op: the store is now correct.
	if r := reconcileStashSidebar(false); r.status != recOK {
		t.Fatalf("clean store: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}
}
