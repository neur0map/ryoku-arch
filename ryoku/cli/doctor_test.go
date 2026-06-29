package main

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestParseProcSwaps(t *testing.T) {
	in := "Filename\t\t\t\tType\t\tSize\t\tUsed\t\tPriority\n" +
		"/swap/swapfile                          file\t\t16777212\t1744224\t\t-1\n" +
		"/dev/nvme0n1p3                          partition\t8388604\t0\t\t-2\n" +
		"/var/lib/with\\040space/swapfile         file\t\t1024\t\t0\t\t-3\n"
	got := parseProcSwaps(in)
	if len(got) != 2 {
		t.Fatalf("got %d file swaps, want 2 (partition excluded): %+v", len(got), got)
	}
	if got[0].path != "/swap/swapfile" || got[0].sizeKB != 16777212 {
		t.Errorf("first swap = %+v, want path /swap/swapfile size 16777212", got[0])
	}
	if got[1].path != "/var/lib/with space/swapfile" {
		t.Errorf("escaped path = %q, want the \\040 unescaped to a space", got[1].path)
	}
}

func TestParseProcSwapsHeaderOnly(t *testing.T) {
	if got := parseProcSwaps("Filename Type Size Used Priority\n"); len(got) != 0 {
		t.Errorf("header-only input should yield no swaps, got %+v", got)
	}
}

func TestDirOnlyContains(t *testing.T) {
	dir := t.TempDir()
	if dirOnlyContains(dir, "swapfile") {
		t.Error("empty dir should not report only-contains")
	}
	if err := os.WriteFile(filepath.Join(dir, "swapfile"), []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	if !dirOnlyContains(dir, "swapfile") {
		t.Error("dir holding only the swapfile should match")
	}
	// a second file must block the auto-fix; surgery never runs on a shared dir.
	if err := os.WriteFile(filepath.Join(dir, "other"), []byte("y"), 0o600); err != nil {
		t.Fatal(err)
	}
	if dirOnlyContains(dir, "swapfile") {
		t.Error("dir with an extra file must not match")
	}
}

func TestNonEmptyLines(t *testing.T) {
	got := nonEmptyLines("a\n\n  \nb\n")
	if len(got) != 2 || got[0] != "a" || got[1] != "b" {
		t.Errorf("nonEmptyLines dropped wrong lines: %q", got)
	}
}

func TestStaleInstallMapper(t *testing.T) {
	const node = "/dev/mapper/root"
	cases := []struct {
		name    string
		nodes   []string
		root    string
		mounted map[string]bool
		want    string
	}{
		{"orphan, nothing mounted", []string{node}, "/dev/nvme0n1p2", nil, "root"},
		{"is the live root", []string{node}, node, map[string]bool{node: true}, ""},
		{"mounted as a target", []string{node}, "/dev/sda1", map[string]bool{node: true}, ""},
		{"absent", nil, "/dev/nvme0n1p2", nil, ""},
		{"only a differently named crypt", []string{"/dev/mapper/cr"}, "/dev/sda1", nil, ""},
	}
	for _, c := range cases {
		if got := staleInstallMapper(c.nodes, c.root, c.mounted); got != c.want {
			t.Errorf("%s: staleInstallMapper = %q, want %q", c.name, got, c.want)
		}
	}
}

func TestParseCryptMapperNodes(t *testing.T) {
	if got := parseCryptMapperNodes("No devices found\n"); got != nil {
		t.Errorf("\"No devices found\" should yield no nodes, got %v", got)
	}
	if got := parseCryptMapperNodes(""); got != nil {
		t.Errorf("empty output should yield no nodes, got %v", got)
	}
	got := parseCryptMapperNodes("root\t(254:0)\nbackup (254:1)\n")
	if len(got) != 2 || got[0] != "/dev/mapper/root" || got[1] != "/dev/mapper/backup" {
		t.Errorf("parseCryptMapperNodes = %v, want the two /dev/mapper paths", got)
	}
}

func TestBaseSource(t *testing.T) {
	if got := baseSource("  /dev/mapper/root[/@home] "); got != "/dev/mapper/root" {
		t.Errorf("baseSource kept the subvolume suffix: %q", got)
	}
	if got := baseSource("/dev/nvme0n1p2"); got != "/dev/nvme0n1p2" {
		t.Errorf("baseSource mangled a plain device: %q", got)
	}
}

func TestTailLines(t *testing.T) {
	if got := tailLines("1\n2\n3\n4\n5", 2); got != "4\n5" {
		t.Errorf("tailLines = %q, want \"4\\n5\"", got)
	}
	if got := tailLines("1\n2", 10); got != "1\n2" {
		t.Errorf("tailLines fewer-than-n = %q, want \"1\\n2\"", got)
	}
}

func TestReportPathOverride(t *testing.T) {
	if got := reportPath("/tmp/x.txt"); got != "/tmp/x.txt" {
		t.Errorf("explicit path = %q, want /tmp/x.txt", got)
	}
	t.Setenv("XDG_STATE_HOME", "/state")
	if got := reportPath(""); got != "/state/ryoku/doctor-report.txt" {
		t.Errorf("default path = %q, want /state/ryoku/doctor-report.txt", got)
	}
}

func TestRecStatusLabels(t *testing.T) {
	for s, want := range map[recStatus]string{recOK: "ok", recFixed: "fixed", recWouldFix: "todo", recWarn: "warn", recFailed: "fail"} {
		if got := s.label(); got != want {
			t.Errorf("label(%d) = %q, want %q", s, got, want)
		}
	}
}

func TestGatherReportIncludesFindings(t *testing.T) {
	fs := []finding{{"swap kept out of snapshots", warnRes("swapfile in @").withFix("ryoku doctor")}}
	rep := gatherReport(fs)
	for _, want := range []string{"Ryoku diagnostic report", "swap kept out of snapshots", "swapfile in @", "fix: ryoku doctor", "## system", "## packages"} {
		if !strings.Contains(rep, want) {
			t.Errorf("report missing %q", want)
		}
	}
}

func TestShellDaemonReachable(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", dir)
	if shellDaemonReachable() {
		t.Fatal("with no socket the daemon must read as unreachable")
	}
	ln, err := net.Listen("unix", filepath.Join(dir, "ryoku-shell.sock"))
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	defer ln.Close()
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			b := make([]byte, 64)
			n, _ := c.Read(b)
			if strings.HasPrefix(strings.TrimSpace(string(b[:n])), "ping") {
				fmt.Fprintln(c, "ok")
			}
			c.Close()
		}
	}()
	if !shellDaemonReachable() {
		t.Fatal("a daemon answering ping with ok must read as reachable")
	}
}

func TestReconcileShellDaemonOutsideSession(t *testing.T) {
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "")
	if r := reconcileShellDaemon(true); r.status != recOK {
		t.Fatalf("outside a Hyprland session the daemon check must be ok, got %q: %s", r.status.label(), r.detail)
	}
}

func TestHyprLuaSane(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want bool
	}{
		{"valid monitor", "hl.monitor({ output = \"\", mode = \"highrr\", scale = 1 })\n", true},
		{"comment only", "-- managed by ryoku-monitor\n", true},
		{"truncated mid-call", "hl.monitor({ output = \"DP-1\", mode = \"hi", false},
		{"empty", "   \n\n", false},
	}
	for _, c := range cases {
		if got := hyprLuaSane(c.in); got != c.want {
			t.Errorf("%s: hyprLuaSane()=%v, want %v", c.name, got, c.want)
		}
	}
}

// torn generated drop-in -> detected and repaired to a parseable safe seed;
// a valid sibling stays untouched, and the fix is idempotent. PATH is wiped
// so the test never touches luac/hyprctl/ryoku-monitor: just the structural
// check + the safe-seed fallback, deterministically.
func TestReconcileHyprlandConfigRepairsCorruptDropin(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("PATH", "")

	hypr := filepath.Join(home, ".config", "hypr")
	if err := os.MkdirAll(hypr, 0o755); err != nil {
		t.Fatal(err)
	}
	put := func(name, body string) {
		if err := os.WriteFile(filepath.Join(hypr, name), []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	get := func(name string) string {
		b, err := os.ReadFile(filepath.Join(hypr, name))
		if err != nil {
			t.Fatal(err)
		}
		return string(b)
	}
	put("hyprland.lua", "pcall(require, \"monitors\")\n")
	put("monitors.lua", "hl.monitor({ output = \"DP-1\", mode = \"hi") // truncated mid-write
	put("gpu.lua", "-- placeholder\n")                                 // valid

	if r := reconcileHyprlandConfig(true); r.status != recWouldFix {
		t.Fatalf("check-only: status=%s detail=%q, want todo", r.status.label(), r.detail)
	}
	if !strings.Contains(get("monitors.lua"), "mode = \"hi") {
		t.Fatal("check-only must not modify the drop-in")
	}

	if r := reconcileHyprlandConfig(false); r.status != recFixed {
		t.Fatalf("fix: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}
	if got := get("monitors.lua"); !hyprLuaSane(got) {
		t.Fatalf("monitors.lua not parseable after repair: %q", got)
	}
	if got := get("gpu.lua"); got != "-- placeholder\n" {
		t.Fatalf("valid gpu.lua must be left untouched, got %q", got)
	}

	if r := reconcileHyprlandConfig(false); r.status != recOK {
		t.Fatalf("second run: status=%s, want ok", r.status.label())
	}
}

func TestReconcileHyprlandConfigNoConfig(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("PATH", "")
	if r := reconcileHyprlandConfig(false); r.status != recOK {
		t.Fatalf("no hyprland.lua: status=%s, want ok", r.status.label())
	}
}

// the snapper reconciler's decision logic lives in planSnapper, a pure
// function of an observed snapperState. exercising it directly stays
// hermetic: no real /etc, no snapper or btrfs invocation, just the branch
// table reconcileSnapper switches on.
func TestPlanSnapper(t *testing.T) {
	consistent := snapperState{
		rootIsBtrfs:         true,
		configExists:        true,
		snapshotsExists:     true,
		snapshotsIsSubvol:   true,
		snapshotsMode:       0o750,
		confdExists:         true,
		confdContents:       "SNAPPER_CONFIGS=\"root\"\n",
		snapperInstalled:    true,
		snapPacInstalled:    true,
		limineSyncInstalled: true,
	}
	withMode := func(m os.FileMode) snapperState { s := consistent; s.snapshotsMode = m; return s }
	withConfd := func(c string) snapperState { s := consistent; s.confdContents = c; return s }
	plainSnapshotsDir := func() snapperState { s := consistent; s.snapshotsIsSubvol = false; return s }
	noSnapPac := func() snapperState { s := consistent; s.snapPacInstalled = false; return s }
	noLimineSync := func() snapperState { s := consistent; s.limineSyncInstalled = false; return s }

	cases := []struct {
		name        string
		in          snapperState
		want        snapperOutcome
		wantProblem string // substring expected in problems, empty when none
	}{
		{"missing config + btrfs + snapper installed converges with create", snapperState{rootIsBtrfs: true, snapperInstalled: true}, snapperCreate, ""},
		{"missing config + btrfs + snapper not installed recommends install", snapperState{rootIsBtrfs: true}, snapperWarnMissingPkgs, ""},
		{"missing config + non-btrfs root warns honestly", snapperState{rootIsBtrfs: false}, snapperWarnNotBtrfs, ""},
		{"present + consistent reads ok", consistent, snapperOK, ""},
		{"/.snapshots wrong mode warns inconsistent", withMode(0o755), snapperWarnInconsistent, "mode 0755"},
		{"conf.d missing root warns inconsistent", withConfd("SNAPPER_CONFIGS=\"home\"\n"), snapperWarnInconsistent, "does not list the root config"},
		{"/.snapshots is plain dir warns inconsistent", plainSnapshotsDir(), snapperWarnInconsistent, "plain directory"},
		{"configured but snap-pac missing recommends it", noSnapPac(), snapperWarnInconsistent, "snap-pac"},
		{"configured but limine-snapper-sync missing recommends it", noLimineSync(), snapperWarnInconsistent, "limine-snapper-sync"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, problems := planSnapper(c.in)
			if got != c.want {
				t.Fatalf("planSnapper outcome = %d, want %d (problems=%v)", got, c.want, problems)
			}
			if c.wantProblem == "" {
				if len(problems) != 0 {
					t.Errorf("unexpected problems: %v", problems)
				}
				return
			}
			joined := strings.Join(problems, " | ")
			if !strings.Contains(joined, c.wantProblem) {
				t.Errorf("problems = %q, want one containing %q", joined, c.wantProblem)
			}
		})
	}
}

// mergedConfdRoot decides how /etc/conf.d/snapper changes when doctor writes
// the snapper root config. it must add "root" without dropping anything a
// human (or another tool) already put in the file.
func TestMergedConfdRoot(t *testing.T) {
	// missing file: doctor writes the canonical snippet.
	out, changed := mergedConfdRoot(false, "")
	if !changed || !strings.Contains(out, `SNAPPER_CONFIGS="root"`) {
		t.Errorf("missing file: changed=%v out=%q, want canonical content with root", changed, out)
	}

	// already lists root: leave the file alone (idempotent doctor).
	in := "SNAPPER_CONFIGS=\"root\"\n"
	if out, changed := mergedConfdRoot(true, in); changed || out != in {
		t.Errorf("present+root: changed=%v out=%q, want unchanged", changed, out)
	}

	// lists another config: append root, keep the existing one.
	in = "SNAPPER_CONFIGS=\"home\"\n"
	out, changed = mergedConfdRoot(true, in)
	if !changed || !strings.Contains(out, `SNAPPER_CONFIGS="home root"`) {
		t.Errorf("present+home: changed=%v out=%q, want root appended after home", changed, out)
	}

	// no SNAPPER_CONFIGS line at all: add one, keep surrounding lines.
	in = "# user comment\n"
	out, changed = mergedConfdRoot(true, in)
	if !changed || !strings.Contains(out, `SNAPPER_CONFIGS="root"`) || !strings.Contains(out, "# user comment") {
		t.Errorf("no SNAPPER_CONFIGS line: changed=%v out=%q, want root line added and comment kept", changed, out)
	}
}

// reconcileDisplayModes delegates to `ryoku-monitor settle`; stub both it
// and hyprctl on PATH so hyprLive() + the settle outcomes stay deterministic.
func TestReconcileDisplayModes(t *testing.T) {
	bin := t.TempDir()
	mkExec := func(name, body string) {
		t.Helper()
		if err := os.WriteFile(filepath.Join(bin, name), []byte(body), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	// a present, answering hyprctl makes hyprLive() report a live session.
	mkExec("hyprctl", "#!/bin/sh\nexit 0\n")
	// ryoku-monitor stub: `settle --check` exits $CHK, `settle` exits $SET.
	mkExec("ryoku-monitor", "#!/bin/sh\n"+
		"if [ \"$1\" = settle ] && [ \"$2\" = --check ]; then exit ${CHK:-0}; fi\n"+
		"if [ \"$1\" = settle ]; then exit ${SET:-0}; fi\nexit 0\n")
	t.Setenv("PATH", bin)

	t.Setenv("CHK", "0") // every display at its best available mode
	if r := reconcileDisplayModes(false); r.status != recOK {
		t.Fatalf("settled: got %s (%q), want ok", r.status.label(), r.detail)
	}
	t.Setenv("CHK", "1") // a display is below its available resolution
	if r := reconcileDisplayModes(true); r.status != recWouldFix {
		t.Fatalf("drift check-only: got %s, want todo", r.status.label())
	}
	t.Setenv("SET", "0") // settle recovers it
	if r := reconcileDisplayModes(false); r.status != recFixed {
		t.Fatalf("drift apply: got %s, want fixed", r.status.label())
	}
	t.Setenv("SET", "1") // settle cannot recover it
	if r := reconcileDisplayModes(false); r.status != recWarn {
		t.Fatalf("settle failed: got %s, want warn", r.status.label())
	}
	t.Setenv("PATH", t.TempDir()) // no hyprctl -> no live session
	if r := reconcileDisplayModes(false); r.status != recOK {
		t.Fatalf("no session: got %s, want ok", r.status.label())
	}
}

// off a Hyprland desktop the cursor-theme check must stay quiet -- no nagging
// a server or a non-Ryoku box to install a desktop cursor theme.
func TestReconcileCursorThemeNotDesktop(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("PATH", t.TempDir()) // no Hyprland on PATH
	if r := reconcileCursorTheme(true); r.status != recOK {
		t.Fatalf("off a Hyprland desktop the cursor check must be ok, got %q: %s", r.status.label(), r.detail)
	}
}
