package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestMigrateLauncherLocalFrost(t *testing.T) {
	t.Run("retired integer default", func(t *testing.T) {
		raw := []byte(`{
			"bgBlur": 12,
			"radius": 19,
			"heroImage": "/wallpapers/green.png",
			"nested": {"keep": [true, 7, "yes"]}
		}`)
		out, changed, err := migrateLauncherLocalFrost(raw)
		if err != nil || !changed {
			t.Fatalf("exact old default should migrate: changed=%v err=%v", changed, err)
		}

		var got map[string]any
		if err := json.Unmarshal(out, &got); err != nil {
			t.Fatalf("migrated launcher JSON does not parse: %v", err)
		}
		if got["bgBlur"] != float64(2) {
			t.Errorf("bgBlur = %#v, want 2", got["bgBlur"])
		}
		if got["radius"] != float64(19) || got["heroImage"] != "/wallpapers/green.png" {
			t.Errorf("unrelated launcher fields changed: %#v", got)
		}
		nested, ok := got["nested"].(map[string]any)
		if !ok || len(nested["keep"].([]any)) != 3 {
			t.Errorf("nested launcher data changed: %#v", got["nested"])
		}
	})

	t.Run("equivalent decimal default", func(t *testing.T) {
		out, changed, err := migrateLauncherLocalFrost([]byte(`{"bgBlur":12.0,"radius":16}`))
		if err != nil || !changed {
			t.Fatalf("12.0 should be recognized as the retired default: changed=%v err=%v", changed, err)
		}
		var got map[string]any
		_ = json.Unmarshal(out, &got)
		if got["bgBlur"] != float64(2) {
			t.Errorf("bgBlur = %#v, want 2", got["bgBlur"])
		}
	})

	for _, tc := range []struct {
		name string
		raw  string
	}{
		{"custom zero", `{"bgBlur":0,"radius":16}`},
		{"custom two", `{"bgBlur":2,"radius":16}`},
		{"custom twelve point five", `{"bgBlur":12.5,"radius":16}`},
		{"near twelve stays custom", `{"bgBlur":12.0000000000000000001,"radius":16}`},
		{"missing key", `{"radius":16}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			out, changed, err := migrateLauncherLocalFrost([]byte(tc.raw))
			if err != nil || changed || out != nil {
				t.Fatalf("custom/current config must pass through: out=%s changed=%v err=%v", out, changed, err)
			}
		})
	}

	for _, tc := range []struct {
		name string
		raw  string
	}{
		{"malformed", `{"bgBlur":`},
		{"string value", `{"bgBlur":"12"}`},
		{"null value", `{"bgBlur":null}`},
		{"boolean value", `{"bgBlur":true}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if _, _, err := migrateLauncherLocalFrost([]byte(tc.raw)); err == nil {
				t.Fatal("invalid launcher config must error instead of being rewritten or marked")
			}
		})
	}
}

func TestReconcileLauncherLocalFrostCheckOnly(t *testing.T) {
	configRoot, stateRoot := launcherMigrationRoots(t)
	path := writeLauncherConfig(t, configRoot, `{"bgBlur":12,"radius":21}`, 0o600)
	before, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}

	res := reconcileLauncherLocalFrostDefault(true)
	if res.status != recWouldFix {
		t.Fatalf("check-only old default = %s (%s), want todo", res.status.label(), res.detail)
	}
	after, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(after) != string(before) {
		t.Fatalf("check-only changed launcher.json:\nbefore %s\nafter  %s", before, after)
	}
	if _, err := os.Stat(filepath.Join(stateRoot, "ryoku", "migrations", "launcher-local-frost-default")); !os.IsNotExist(err) {
		t.Fatalf("check-only wrote the migration marker: %v", err)
	}
}

func TestReconcileLauncherLocalFrostMigratesOnce(t *testing.T) {
	configRoot, stateRoot := launcherMigrationRoots(t)
	path := writeLauncherConfig(t, configRoot, `{"bgBlur":12,"radius":21,"heroStrength":0.75}`, 0o600)

	res := reconcileLauncherLocalFrostDefault(false)
	if res.status != recFixed {
		t.Fatalf("old default = %s (%s), want fixed", res.status.label(), res.detail)
	}
	assertLauncherBlur(t, path, 2)
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Errorf("launcher.json mode = %o, want original 600", info.Mode().Perm())
	}
	marker := filepath.Join(stateRoot, "ryoku", "migrations", "launcher-local-frost-default")
	if _, err := os.Stat(marker); err != nil {
		t.Fatalf("migration marker was not written: %v", err)
	}

	if err := os.WriteFile(path, []byte(`{"bgBlur":12,"radius":21}`), 0o600); err != nil {
		t.Fatal(err)
	}
	res = reconcileLauncherLocalFrostDefault(false)
	if res.status != recOK {
		t.Fatalf("marked deliberate 12 = %s (%s), want ok", res.status.label(), res.detail)
	}
	assertLauncherBlur(t, path, 12)
}

func TestReconcileLauncherLocalFrostPreservesConfigSymlink(t *testing.T) {
	configRoot, _ := launcherMigrationRoots(t)
	targetDir := t.TempDir()
	target := filepath.Join(targetDir, "launcher.json")
	if err := os.WriteFile(target, []byte(`{"bgBlur":12,"radius":18}`), 0o640); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(configRoot, "ryoku", "launcher.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, path); err != nil {
		t.Fatal(err)
	}

	res := reconcileLauncherLocalFrostDefault(false)
	if res.status != recFixed {
		t.Fatalf("symlinked config = %s (%s), want fixed", res.status.label(), res.detail)
	}
	info, err := os.Lstat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode()&os.ModeSymlink == 0 {
		t.Fatal("migration replaced the user's launcher.json symlink")
	}
	assertLauncherBlur(t, target, 2)
	targetInfo, err := os.Stat(target)
	if err != nil {
		t.Fatal(err)
	}
	if targetInfo.Mode().Perm() != 0o640 {
		t.Errorf("symlink target mode = %o, want original 640", targetInfo.Mode().Perm())
	}
}

func TestReconcileLauncherLocalFrostMarksNonLegacyStates(t *testing.T) {
	for _, tc := range []struct {
		name       string
		write      bool
		raw        string
		checkOnly  bool
		wantStatus recStatus
	}{
		{"missing file", false, "", false, recOK},
		{"missing key", true, `{"radius":16}`, false, recOK},
		{"custom value", true, `{"bgBlur":7}`, false, recOK},
		{"check-only custom value", true, `{"bgBlur":7}`, true, recOK},
	} {
		t.Run(tc.name, func(t *testing.T) {
			configRoot, stateRoot := launcherMigrationRoots(t)
			if tc.write {
				writeLauncherConfig(t, configRoot, tc.raw, 0o644)
			}
			res := reconcileLauncherLocalFrostDefault(tc.checkOnly)
			if res.status != tc.wantStatus {
				t.Fatalf("status = %s (%s), want %s", res.status.label(), res.detail, tc.wantStatus.label())
			}
			marker := filepath.Join(stateRoot, "ryoku", "migrations", "launcher-local-frost-default")
			_, err := os.Stat(marker)
			if tc.checkOnly {
				if !os.IsNotExist(err) {
					t.Fatalf("check-only wrote marker: %v", err)
				}
			} else if err != nil {
				t.Fatalf("non-legacy state was not marked: %v", err)
			}
		})
	}
}

func TestReconcileLauncherLocalFrostInvalidConfigDoesNotMark(t *testing.T) {
	for _, raw := range []string{`{"bgBlur":`, `{"bgBlur":"12"}`} {
		t.Run(raw, func(t *testing.T) {
			configRoot, stateRoot := launcherMigrationRoots(t)
			path := writeLauncherConfig(t, configRoot, raw, 0o640)
			res := reconcileLauncherLocalFrostDefault(false)
			if res.status != recWarn {
				t.Fatalf("invalid config = %s (%s), want warn", res.status.label(), res.detail)
			}
			if _, err := os.Stat(filepath.Join(stateRoot, "ryoku", "migrations", "launcher-local-frost-default")); !os.IsNotExist(err) {
				t.Fatalf("invalid config wrote marker: %v", err)
			}
			got, err := os.ReadFile(path)
			if err != nil {
				t.Fatal(err)
			}
			if string(got) != raw {
				t.Fatalf("invalid config was changed: %q", got)
			}
		})
	}
}

func launcherMigrationRoots(t *testing.T) (string, string) {
	t.Helper()
	configRoot := filepath.Join(t.TempDir(), "config")
	stateRoot := filepath.Join(t.TempDir(), "state")
	t.Setenv("XDG_CONFIG_HOME", configRoot)
	t.Setenv("XDG_STATE_HOME", stateRoot)
	return configRoot, stateRoot
}

func writeLauncherConfig(t *testing.T, configRoot, raw string, mode os.FileMode) string {
	t.Helper()
	path := filepath.Join(configRoot, "ryoku", "launcher.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(raw), mode); err != nil {
		t.Fatal(err)
	}
	return path
}

func assertLauncherBlur(t *testing.T, path string, want float64) {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var cfg map[string]any
	if err := json.Unmarshal(raw, &cfg); err != nil {
		t.Fatal(err)
	}
	if cfg["bgBlur"] != want {
		t.Fatalf("bgBlur = %#v, want %g; file: %s", cfg["bgBlur"], want, raw)
	}
}
