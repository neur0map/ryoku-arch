package doctor

import (
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"testing"
)

func ueSetup(t *testing.T) string {
	t.Helper()
	home := t.TempDir()
	base := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	t.Setenv("RYOKU_CONFIG_BASE", base)
	return base
}

func ueWrite(t *testing.T, path, body string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

// adopt seeds the overlay guide and copies a machine's loose user files into the
// overlay, idempotently, leaving the live copy alone so a session is undisturbed.
func TestReconcileUserEditsAdopt(t *testing.T) {
	ueSetup(t)
	cfg := sys.ConfigHome()
	edits := sys.UserEditsDir()

	// fresh box: the guide is missing; check reports it, fix writes it.
	if r := reconcileUserEditsAdopt(true); r.status != recWouldFix {
		t.Fatalf("fresh check: status=%s detail=%q, want todo", r.status.label(), r.detail)
	}
	if r := reconcileUserEditsAdopt(false); r.status != recFixed {
		t.Fatalf("fresh fix: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}
	if !sys.Exists(filepath.Join(edits, "README.md")) {
		t.Fatal("overlay guide not written")
	}

	// loose user files get adopted; the live copies stay put.
	ueWrite(t, filepath.Join(cfg, "hypr/user.lua"), "-- my hypr\n")
	ueWrite(t, filepath.Join(cfg, "kitty/user.conf"), "font_size 12\n")
	if r := reconcileUserEditsAdopt(true); r.status != recWouldFix {
		t.Fatalf("adopt check: status=%s detail=%q, want todo", r.status.label(), r.detail)
	}
	if sys.Exists(filepath.Join(edits, "hypr/user.lua")) {
		t.Fatal("check-only must not copy anything")
	}
	if r := reconcileUserEditsAdopt(false); r.status != recFixed {
		t.Fatalf("adopt fix: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}
	for _, rel := range []string{"hypr/user.lua", "kitty/user.conf"} {
		if !sys.Exists(filepath.Join(edits, rel)) {
			t.Fatalf("adopt did not copy %s into the overlay", rel)
		}
		if !sys.Exists(filepath.Join(cfg, rel)) {
			t.Fatalf("adopt removed the live %s; it must stay put", rel)
		}
	}

	// idempotent: guide present, nothing loose left.
	if r := reconcileUserEditsAdopt(false); r.status != recOK {
		t.Fatalf("idempotent: status=%s, want ok", r.status.label())
	}
}
