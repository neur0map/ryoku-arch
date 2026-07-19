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

// adopt copies a machine's loose user files into the overlay, idempotently, and
// leaves the live copy alone so a running session is never disturbed.
func TestReconcileUserEditsAdopt(t *testing.T) {
	ueSetup(t)
	cfg := sys.ConfigHome()
	edits := sys.UserEditsDir()

	if r := reconcileUserEditsAdopt(false); r.status != recOK {
		t.Fatalf("empty: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}

	ueWrite(t, filepath.Join(cfg, "hypr/user.lua"), "-- my hypr\n")
	ueWrite(t, filepath.Join(cfg, "kitty/user.conf"), "font_size 12\n")

	if r := reconcileUserEditsAdopt(true); r.status != recWouldFix {
		t.Fatalf("check: status=%s detail=%q, want todo", r.status.label(), r.detail)
	}
	if sys.Exists(filepath.Join(edits, "hypr/user.lua")) {
		t.Fatal("check-only must not copy anything")
	}
	if r := reconcileUserEditsAdopt(false); r.status != recFixed {
		t.Fatalf("fix: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}
	for _, rel := range []string{"hypr/user.lua", "kitty/user.conf"} {
		if !sys.Exists(filepath.Join(edits, rel)) {
			t.Fatalf("adopt did not copy %s into the overlay", rel)
		}
		if !sys.Exists(filepath.Join(cfg, rel)) {
			t.Fatalf("adopt removed the live %s; it must stay put", rel)
		}
	}
	if r := reconcileUserEditsAdopt(false); r.status != recOK {
		t.Fatalf("idempotent: status=%s, want ok", r.status.label())
	}
}

// fork drift reports a forked file whose base changed since the user took it
// over, once, then advances the ancestor so it rests.
func TestReconcileForkDrift(t *testing.T) {
	base := ueSetup(t)

	if r := reconcileForkDrift(false); r.status != recOK {
		t.Fatalf("no ledger: status=%s, want ok", r.status.label())
	}

	ueWrite(t, filepath.Join(base, "hypr/modules/binds.lua"), "-- base v1\n")
	v1 := sys.FileHash(filepath.Join(base, "hypr/modules/binds.lua"))
	if err := sys.WriteForkLedger(map[string]string{"hypr/modules/binds.lua": v1}); err != nil {
		t.Fatal(err)
	}
	if r := reconcileForkDrift(false); r.status != recOK {
		t.Fatalf("in-sync fork: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}

	ueWrite(t, filepath.Join(base, "hypr/modules/binds.lua"), "-- base v2 (a fix)\n")
	if r := reconcileForkDrift(true); r.status != recWouldFix {
		t.Fatalf("drift check: status=%s detail=%q, want todo", r.status.label(), r.detail)
	}
	if got := sys.ReadForkLedger()["hypr/modules/binds.lua"]; got != v1 {
		t.Fatal("check-only must not advance the ancestor")
	}
	if r := reconcileForkDrift(false); r.status != recNote {
		t.Fatalf("drift notice: status=%s detail=%q, want note", r.status.label(), r.detail)
	}
	if r := reconcileForkDrift(false); r.status != recOK {
		t.Fatalf("after notice: status=%s, want ok", r.status.label())
	}
}

// the mirror surfaces an existing store as a symlink into the overlay, and heals
// a hand-broken link (a real file where the symlink belongs).
func TestReconcileUserEditsMirror(t *testing.T) {
	ueSetup(t)
	cfg := sys.ConfigHome()
	mirror := filepath.Join(sys.UserEditsDir(), "ryoku")

	if r := reconcileUserEditsMirror(false); r.status != recOK {
		t.Fatalf("no stores: status=%s, want ok", r.status.label())
	}

	real := filepath.Join(cfg, "ryoku", "shell.json")
	ueWrite(t, real, `{"barStyle":"delos"}`)

	if r := reconcileUserEditsMirror(true); r.status != recWouldFix {
		t.Fatalf("check: status=%s, want todo", r.status.label())
	}
	if r := reconcileUserEditsMirror(false); r.status != recFixed {
		t.Fatalf("fix: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}
	link := filepath.Join(mirror, "shell.json")
	if dst, err := os.Readlink(link); err != nil || dst != real {
		t.Fatalf("shell.json not linked to the real store: dst=%q err=%v", dst, err)
	}
	if r := reconcileUserEditsMirror(false); r.status != recOK {
		t.Fatalf("idempotent: status=%s, want ok", r.status.label())
	}

	os.Remove(link)
	ueWrite(t, link, `{"barStyle":"nacre"}`)
	if r := reconcileUserEditsMirror(false); r.status != recFixed {
		t.Fatalf("heal: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}
	if dst, err := os.Readlink(link); err != nil || dst != real {
		t.Fatalf("link not restored after heal: dst=%q err=%v", dst, err)
	}
	if b, _ := os.ReadFile(real); string(b) != `{"barStyle":"nacre"}` {
		t.Fatalf("heal did not adopt the hand edit into the real store: %q", string(b))
	}
}
