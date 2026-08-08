package updater

import (
	"os"
	"path/filepath"
	"runtime"
	"ryoku-cli/internal/sys"
	"strings"
	"testing"
)

// materialize must never overwrite a per-machine generated seed (monitors.lua,
// gpu.lua) or a user file, so `ryoku update` can't change a user's settings
// while it refreshes the managed config the package ships.
func TestMaterializePreservesGeneratedAndUserFiles(t *testing.T) {
	base, dest := t.TempDir(), t.TempDir()
	t.Setenv("RYOKU_CONFIG_BASE", base)
	t.Setenv("XDG_CONFIG_HOME", dest)
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	// Package ships a managed module and seeds for the generated drop-ins
	// plus the user-owned keyboard layout and fastfetch readout.
	writeFile(t, filepath.Join(base, "hypr/hyprland.lua"), "require(\"monitors\")\n")
	writeFile(t, filepath.Join(base, "hypr/monitors.lua"), "-- seed\n")
	writeFile(t, filepath.Join(base, "hypr/gpu.lua"), "-- seed\n")
	writeFile(t, filepath.Join(base, "hypr/keyboard.lua"), "kb_layout = \"us\"\n")
	writeFile(t, filepath.Join(base, "hypr/user.lua"), "-- seed header\n")
	writeFile(t, filepath.Join(base, "fastfetch/config.jsonc"), "\"source\": \"ryoku\"\n")
	writeFile(t, filepath.Join(base, "kitty/current-theme.conf"), "background #16110b\n")

	// fresh install: every file lands, seeds included so first boot works.
	if err := Materialize(); err != nil {
		t.Fatalf("fresh materialize: %v", err)
	}
	wantFile(t, filepath.Join(dest, "hypr/monitors.lua"), "-- seed")
	wantFile(t, filepath.Join(dest, "hypr/gpu.lua"), "-- seed")
	wantFile(t, filepath.Join(dest, "hypr/keyboard.lua"), "kb_layout = \"us\"")
	wantFile(t, filepath.Join(dest, "hypr/user.lua"), "seed header")
	wantFile(t, filepath.Join(dest, "fastfetch/config.jsonc"), "ryoku")
	wantFile(t, filepath.Join(dest, "kitty/current-theme.conf"), "16110b")
	// the shell's JSON stores live in ~/.config/ryoku, which no shipped file
	// creates; materialize guarantees it so the QML self-seed can write there.
	if st, err := os.Stat(filepath.Join(dest, "ryoku")); err != nil || !st.IsDir() {
		t.Errorf("materialize did not create the ryoku config dir: %v", err)
	}

	// Runtime regenerates the drop-in seeds; user adds extra keyboard layouts,
	// a user file, and customizes the fastfetch readout.
	writeFile(t, filepath.Join(dest, "hypr/monitors.lua"), "DISPLAY\n")
	writeFile(t, filepath.Join(dest, "hypr/gpu.lua"), "GPUPIN\n")
	writeFile(t, filepath.Join(dest, "hypr/keyboard.lua"), "kb_layout = \"us,ru,de,fr\"\n")
	writeFile(t, filepath.Join(dest, "hypr/user.lua"), "USER\n")
	writeFile(t, filepath.Join(dest, "fastfetch/config.jsonc"), "\"source\": \"my-custom-logo\"\n")
	writeFile(t, filepath.Join(dest, "kitty/current-theme.conf"), "background #3a5f8a\n") // matugen from the wallpaper
	// later release changes the managed module and reworks the shipped readout.
	writeFile(t, filepath.Join(base, "hypr/hyprland.lua"), "require(\"monitors_user\")\n")
	writeFile(t, filepath.Join(base, "fastfetch/config.jsonc"), "\"source\": \"ryoku-redesigned\"\n")

	// update: managed file is refreshed; the generated seeds, the user file,
	// and the customized fastfetch readout stay exactly as the machine had them.
	if err := Materialize(); err != nil {
		t.Fatalf("update materialize: %v", err)
	}
	wantFile(t, filepath.Join(dest, "hypr/hyprland.lua"), "monitors_user")
	wantFile(t, filepath.Join(dest, "hypr/monitors.lua"), "DISPLAY")
	wantFile(t, filepath.Join(dest, "hypr/gpu.lua"), "GPUPIN")
	wantFile(t, filepath.Join(dest, "hypr/user.lua"), "USER")
	wantFile(t, filepath.Join(dest, "hypr/keyboard.lua"), "us,ru,de,fr")
	wantFile(t, filepath.Join(dest, "fastfetch/config.jsonc"), "my-custom-logo")
	wantFile(t, filepath.Join(dest, "kitty/current-theme.conf"), "3a5f8a")
}

// A managed file dropped from a release is pruned; a generated seed is never
// pruned, even after the base stops shipping it.
func TestMaterializePrunesManagedNotSeeds(t *testing.T) {
	base, dest := t.TempDir(), t.TempDir()
	t.Setenv("RYOKU_CONFIG_BASE", base)
	t.Setenv("XDG_CONFIG_HOME", dest)
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	writeFile(t, filepath.Join(base, "hypr/old.lua"), "x\n")
	writeFile(t, filepath.Join(base, "hypr/monitors.lua"), "-- seed\n")
	if err := Materialize(); err != nil {
		t.Fatalf("first materialize: %v", err)
	}
	writeFile(t, filepath.Join(dest, "hypr/monitors.lua"), "DISPLAY\n") // runtime-regenerated

	// next release drops both the managed file and the monitors seed.
	os.Remove(filepath.Join(base, "hypr/old.lua"))
	os.Remove(filepath.Join(base, "hypr/monitors.lua"))
	if err := Materialize(); err != nil {
		t.Fatalf("second materialize: %v", err)
	}
	if sys.Exists(filepath.Join(dest, "hypr/old.lua")) {
		t.Error("a managed file dropped from the release should be pruned")
	}
	wantFile(t, filepath.Join(dest, "hypr/monitors.lua"), "DISPLAY") // seed survives
}

// ~/.config/quickshell converges against the shipped tree even when the
// manifest never recorded a stale file (a lost state file, an old deploy.sh
// run): leftovers are swept, files outside quickshell stay manifest-ruled.
func TestMaterializeSweepsStaleQuickshell(t *testing.T) {
	base, dest := t.TempDir(), t.TempDir()
	t.Setenv("RYOKU_CONFIG_BASE", base)
	t.Setenv("XDG_CONFIG_HOME", dest)
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	writeFile(t, filepath.Join(base, "quickshell/shell/shell.qml"), "NEW\n")
	// stale leftovers no manifest knows about, plus an unmanaged file outside
	// quickshell that must survive.
	writeFile(t, filepath.Join(dest, "quickshell/shell/Removed.qml"), "OLD\n")
	writeFile(t, filepath.Join(dest, "quickshell/plugins/shell.qml"), "OLD\n")
	writeFile(t, filepath.Join(dest, "hypr/user.lua"), "USER\n")

	if err := Materialize(); err != nil {
		t.Fatalf("materialize: %v", err)
	}
	wantFile(t, filepath.Join(dest, "quickshell/shell/shell.qml"), "NEW")
	if sys.Exists(filepath.Join(dest, "quickshell/shell/Removed.qml")) {
		t.Error("stale quickshell file should be swept without a manifest entry")
	}
	if sys.Exists(filepath.Join(dest, "quickshell/plugins")) {
		t.Error("emptied stale quickshell dir should be pruned")
	}
	wantFile(t, filepath.Join(dest, "hypr/user.lua"), "USER")
}

// The user overlay lays user_edits over the freshly materialized base: a fork
// wins over the base file it shadows, a file base never shipped still lands (the
// overlay is sparse), and a base file the user did not touch stays base's, so an
// update keeps delivering fixes everywhere the user has not overridden.
func TestMaterializeUserEditsOverlay(t *testing.T) {
	base, dest := t.TempDir(), t.TempDir()
	t.Setenv("RYOKU_CONFIG_BASE", base)
	t.Setenv("XDG_CONFIG_HOME", dest)
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	writeFile(t, filepath.Join(base, "hypr/modules/binds.lua"), "-- base binds v1\n")
	writeFile(t, filepath.Join(base, "hypr/modules/window_rules.lua"), "-- base rules\n")

	edits := sys.UserEditsDir()
	writeFile(t, filepath.Join(edits, "hypr/modules/binds.lua"), "-- my binds\n") // fork
	writeFile(t, filepath.Join(edits, "hypr/user.lua"), "-- my overlay\n")        // addition

	if err := Materialize(); err != nil {
		t.Fatalf("materialize: %v", err)
	}
	wantFile(t, filepath.Join(dest, "hypr/modules/binds.lua"), "my binds")          // fork wins
	wantFile(t, filepath.Join(dest, "hypr/user.lua"), "my overlay")                 // addition lands
	wantFile(t, filepath.Join(dest, "hypr/modules/window_rules.lua"), "base rules") // untouched = base

	// a later base changes the forked file: the fork still wins (the user owns it).
	writeFile(t, filepath.Join(base, "hypr/modules/binds.lua"), "-- base binds v2 (a fix)\n")
	if err := Materialize(); err != nil {
		t.Fatalf("re-materialize: %v", err)
	}
	wantFile(t, filepath.Join(dest, "hypr/modules/binds.lua"), "my binds")

	// dropping the fork reverts live to base on the next materialize.
	if err := os.Remove(filepath.Join(edits, "hypr/modules/binds.lua")); err != nil {
		t.Fatal(err)
	}
	if err := Materialize(); err != nil {
		t.Fatalf("revert materialize: %v", err)
	}
	wantFile(t, filepath.Join(dest, "hypr/modules/binds.lua"), "base binds v2")
}

// WirePlumber reads fragments only at startup. Materialize restarts it when the
// effective Ryoku-owned Bluetooth policy changes, but leaves audio uninterrupted
// on ordinary updates that copy identical bytes.
func TestMaterializeRestartsWirePlumberOnlyWhenPolicyChanges(t *testing.T) {
	base, dest := t.TempDir(), t.TempDir()
	t.Setenv("RYOKU_CONFIG_BASE", base)
	t.Setenv("XDG_CONFIG_HOME", dest)
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	const policy = "wireplumber/wireplumber.conf.d/51-ryoku-bluetooth.conf"
	writeFile(t, filepath.Join(base, policy), "wireplumber.settings = { bluetooth.autoswitch-to-headset-profile = false }\n")

	bin := t.TempDir()
	log := filepath.Join(t.TempDir(), "systemctl.log")
	t.Setenv("RYOKU_TEST_SYSTEMCTL_LOG", log)
	writeFile(t, filepath.Join(bin, "systemctl"), "#!/bin/sh\nprintf '%s\\n' \"$*\" >>\"$RYOKU_TEST_SYSTEMCTL_LOG\"\n")
	if err := os.Chmod(filepath.Join(bin, "systemctl"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	if err := Materialize(); err != nil {
		t.Fatalf("fresh materialize: %v", err)
	}
	first, err := os.ReadFile(log)
	if err != nil {
		t.Fatalf("WirePlumber was not restarted after the policy landed: %v", err)
	}
	if got := strings.Count(string(first), "--user try-restart wireplumber.service"); got != 1 {
		t.Fatalf("fresh policy caused %d WirePlumber restarts, want 1; log: %q", got, first)
	}

	if err := Materialize(); err != nil {
		t.Fatalf("unchanged materialize: %v", err)
	}
	unchanged, err := os.ReadFile(log)
	if err != nil {
		t.Fatal(err)
	}
	if string(unchanged) != string(first) {
		t.Fatalf("unchanged policy restarted WirePlumber again: before %q, after %q", first, unchanged)
	}

	writeFile(t, filepath.Join(base, policy), "# revised\nwireplumber.settings = { bluetooth.autoswitch-to-headset-profile = false }\n")
	if err := Materialize(); err != nil {
		t.Fatalf("changed materialize: %v", err)
	}
	changed, err := os.ReadFile(log)
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.Count(string(changed), "--user try-restart wireplumber.service"); got != 2 {
		t.Fatalf("policy revision caused %d total WirePlumber restarts, want 2; log: %q", got, changed)
	}
}

func wantFile(t *testing.T, path, want string) {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	if !strings.Contains(string(b), want) {
		t.Errorf("%s = %q, want substring %q", path, string(b), want)
	}
}

// chromium-flags.conf is a root-level config: chromium reads
// $XDG_CONFIG_HOME/chromium-flags.conf at launch. It is delivered like
// mimeapps.list, shipped under the base config dir and laid at
// ~/.config/chromium-flags.conf by materialize on install and every update. This
// pins the exact flag and that materialize routes it to the config root as a
// managed file, not a one-time seed.
func TestMaterializeDeliversChromiumFlags(t *testing.T) {
	const want = "--password-store=gnome-libsecret\n"

	// the shipped source carries exactly the one flag: the screen-share keyring
	// only works if chromium uses GNOME Secret Service, not kwallet or basic.
	_, thisFile, _, _ := runtime.Caller(0)
	shipped := filepath.Join(filepath.Dir(thisFile), "..", "..", "..", "apps", "chromium-flags.conf")
	src, err := os.ReadFile(shipped)
	if err != nil {
		t.Fatalf("read shipped chromium-flags.conf: %v", err)
	}
	if string(src) != want {
		t.Fatalf("shipped chromium-flags.conf = %q, want %q", src, want)
	}

	base, dest := t.TempDir(), t.TempDir()
	t.Setenv("RYOKU_CONFIG_BASE", base)
	t.Setenv("XDG_CONFIG_HOME", dest)
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	writeFile(t, filepath.Join(base, "chromium-flags.conf"), string(src))

	// install/update routes the base file to the config root, byte for byte.
	if err := Materialize(); err != nil {
		t.Fatalf("materialize: %v", err)
	}
	routed := filepath.Join(dest, "chromium-flags.conf")
	if b, err := os.ReadFile(routed); err != nil || string(b) != want {
		t.Fatalf("chromium-flags.conf not routed to ~/.config: got %q err %v", b, err)
	}

	// managed, not a seed: a later `ryoku update` re-lays it, restoring a drifted
	// copy to the shipped flag.
	writeFile(t, routed, "--password-store=basic\n")
	if err := Materialize(); err != nil {
		t.Fatalf("re-materialize: %v", err)
	}
	if b, err := os.ReadFile(routed); err != nil || string(b) != want {
		t.Fatalf("update did not re-deliver chromium-flags.conf: got %q err %v", b, err)
	}
}
