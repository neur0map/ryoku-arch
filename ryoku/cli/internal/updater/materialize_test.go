package updater

import (
	"os"
	"path/filepath"
	"runtime"
	"ryoku-cli/internal/sys"
	"slices"
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

// The default-app map used to be laid at ~/.config/mimeapps.list, which is the
// file "Set as default" writes: an update copied Ryoku's map over the user's
// picks. Ryoku ships it to the vendor layer now, and the prune must not take the
// user's file with it when it leaves the release, or the update would still
// throw the picks away.
func TestMaterializeKeepsRetiredMimeappsList(t *testing.T) {
	base, dest := t.TempDir(), t.TempDir()
	t.Setenv("RYOKU_CONFIG_BASE", base)
	t.Setenv("XDG_CONFIG_HOME", dest)
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	writeFile(t, filepath.Join(base, "mimeapps.list"), "[Default Applications]\ntext/html=ryoku-nvim.desktop\n")
	if err := Materialize(); err != nil {
		t.Fatalf("first materialize: %v", err)
	}
	// the user then makes Firefox their browser, which writes this same file.
	writeFile(t, filepath.Join(dest, "mimeapps.list"), "[Default Applications]\nx-scheme-handler/http=firefox.desktop\n")

	// the release stops shipping the map: it moved to /usr/share/applications.
	os.Remove(filepath.Join(base, "mimeapps.list"))
	if err := Materialize(); err != nil {
		t.Fatalf("second materialize: %v", err)
	}
	wantFile(t, filepath.Join(dest, "mimeapps.list"), "firefox.desktop")
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

// A withdrawn Ryoku drop-in is swept with no manifest entry and WirePlumber
// restarts, while the user's own drop-in in the same directory survives.
func TestMaterializeSweepsWithdrawnRyokuDropIn(t *testing.T) {
	base, dest := t.TempDir(), t.TempDir()
	t.Setenv("RYOKU_CONFIG_BASE", base)
	t.Setenv("XDG_CONFIG_HOME", dest)
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	const dir = "wireplumber/wireplumber.conf.d"
	writeFile(t, filepath.Join(base, dir, "51-ryoku-bluetooth.conf"), "SHIPPED\n")
	writeFile(t, filepath.Join(dest, dir, "50-ryoku-alsa-soft-mixer.conf"), "OLD\n")
	writeFile(t, filepath.Join(dest, dir, "99-my-own.conf"), "MINE\n")

	bin := t.TempDir()
	log := filepath.Join(t.TempDir(), "systemctl.log")
	t.Setenv("RYOKU_TEST_SYSTEMCTL_LOG", log)
	writeFile(t, filepath.Join(bin, "systemctl"), "#!/bin/sh\nprintf '%s\\n' \"$*\" >>\"$RYOKU_TEST_SYSTEMCTL_LOG\"\n")
	if err := os.Chmod(filepath.Join(bin, "systemctl"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	if err := Materialize(); err != nil {
		t.Fatalf("materialize: %v", err)
	}
	if sys.Exists(filepath.Join(dest, dir, "50-ryoku-alsa-soft-mixer.conf")) {
		t.Error("withdrawn Ryoku drop-in should be swept without a manifest entry")
	}
	wantFile(t, filepath.Join(dest, dir, "99-my-own.conf"), "MINE")
	wantFile(t, filepath.Join(dest, dir, "51-ryoku-bluetooth.conf"), "SHIPPED")

	restarts, err := os.ReadFile(log)
	if err != nil {
		t.Fatalf("WirePlumber was not restarted after the sweep: %v", err)
	}
	if !strings.Contains(string(restarts), "--user try-restart wireplumber.service") {
		t.Errorf("sweeping a drop-in should restart WirePlumber; log: %q", restarts)
	}
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
	writeFile(t, filepath.Join(base, "hypr/user.lua"), "-- seed header\n") // live-owned seed

	edits := sys.UserEditsDir()
	writeFile(t, filepath.Join(edits, "hypr/modules/binds.lua"), "-- my binds\n") // fork
	writeFile(t, filepath.Join(edits, "hypr/settings.lua"), "-- my settings\n")   // addition (a Hub file)
	writeFile(t, filepath.Join(edits, "hypr/user.lua"), "-- overlay junk\n")      // live-owned: must be ignored

	if err := Materialize(); err != nil {
		t.Fatalf("materialize: %v", err)
	}
	wantFile(t, filepath.Join(dest, "hypr/modules/binds.lua"), "my binds")          // fork wins
	wantFile(t, filepath.Join(dest, "hypr/settings.lua"), "my settings")            // addition lands
	wantFile(t, filepath.Join(dest, "hypr/modules/window_rules.lua"), "base rules") // untouched = base
	// a live-owned file is NEVER laid from the overlay: the live seed stands, so a
	// stale overlay copy cannot wipe the user's in-place edits (if it had clobbered,
	// the file would read "overlay junk", which does not contain "seed header").
	wantFile(t, filepath.Join(dest, "hypr/user.lua"), "seed header")

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

// activeFlags: the lines a chromium-flags.conf actually applies. Asserting on
// these rather than the whole file means a commented-out flag reads as absent,
// and adding a comment does not fail the build.
func activeFlags(conf string) []string {
	var flags []string
	for _, ln := range strings.Split(conf, "\n") {
		ln = strings.TrimSpace(ln)
		if ln == "" || strings.HasPrefix(ln, "#") {
			continue
		}
		flags = append(flags, ln)
	}
	return flags
}

// chromium-flags.conf is a root-level config: chromium reads
// $XDG_CONFIG_HOME/chromium-flags.conf at launch, so it is shipped under the
// base config dir and laid at ~/.config/chromium-flags.conf on install and every
// update. This pins the flags and that materialize routes it to the config root
// as a managed file, not a one-time seed. Unlike the default-app map, nothing
// else writes it, so clobbering it takes nothing from the user.
func TestMaterializeDeliversChromiumFlags(t *testing.T) {
	// Both are load-bearing for sharing a screen: gnome-libsecret so chromium
	// shares the keyring the desktop unlocks, wayland so it reaches the PipeWire
	// capturer at all.
	want := []string{"--password-store=gnome-libsecret", "--ozone-platform=wayland"}

	_, thisFile, _, _ := runtime.Caller(0)
	shipped := filepath.Join(filepath.Dir(thisFile), "..", "..", "..", "apps", "chromium-flags.conf")
	src, err := os.ReadFile(shipped)
	if err != nil {
		t.Fatalf("read shipped chromium-flags.conf: %v", err)
	}
	if got := activeFlags(string(src)); !slices.Equal(got, want) {
		t.Fatalf("shipped chromium-flags.conf applies %q, want exactly %q", got, want)
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
	if b, err := os.ReadFile(routed); err != nil || string(b) != string(src) {
		t.Fatalf("chromium-flags.conf not routed to ~/.config: got %q err %v", b, err)
	}

	// managed, not a seed: a later `ryoku update` re-lays it, restoring a drifted
	// copy to the shipped flags.
	writeFile(t, routed, "--password-store=basic\n")
	if err := Materialize(); err != nil {
		t.Fatalf("re-materialize: %v", err)
	}
	if b, err := os.ReadFile(routed); err != nil || string(b) != string(src) {
		t.Fatalf("update did not re-deliver chromium-flags.conf: got %q err %v", b, err)
	}
}
