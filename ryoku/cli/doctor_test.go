package main

import (
	"encoding/json"
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
		limineInstalled:     true,
		limineSyncInstalled: true,
		limineSyncEnabled:   true,
	}
	withMode := func(m os.FileMode) snapperState { s := consistent; s.snapshotsMode = m; return s }
	withConfd := func(c string) snapperState { s := consistent; s.confdContents = c; return s }
	plainSnapshotsDir := func() snapperState { s := consistent; s.snapshotsIsSubvol = false; return s }
	noSnapPac := func() snapperState { s := consistent; s.snapPacInstalled = false; return s }
	nonLimine := func() snapperState {
		s := consistent
		s.limineInstalled, s.limineSyncInstalled, s.limineSyncEnabled = false, false, false
		return s
	}
	noLimineSync := func() snapperState {
		s := consistent
		s.limineSyncInstalled = false
		s.limineSyncEnabled = false
		return s
	}
	syncDisabled := func() snapperState { s := consistent; s.limineSyncEnabled = false; return s }

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
		{"sync installed but service disabled tells the exact enable", syncDisabled(), snapperWarnInconsistent, "limine-snapper-sync.service is disabled"},
		{"non-limine box is healthy without the sync package", nonLimine(), snapperOK, ""},
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

// The sddm greeter (neither owner nor group member of the theme) reads it only
// through the world bits, and the dir must be root-owned. The broken case the
// reconciler heals is a catalogue skin left 0700 user-owned by an old `cp -a`.
func TestGreeterThemeHealthy(t *testing.T) {
	cases := []struct {
		name     string
		uid      uint32
		dir, qml os.FileMode
		want     bool
	}{
		{"root-owned, world-readable (fresh install)", 0, 0o755, 0o644, true},
		{"user-owned 0700 catalogue skin (the bug)", 1000, 0o700, 0o644, false},
		{"user-owned but world-readable: still wrong owner", 1000, 0o755, 0o644, false},
		{"root-owned but dir not traversable by other", 0, 0o700, 0o644, false},
		{"root-owned but Main.qml not world-readable", 0, 0o755, 0o600, false},
		{"root-owned group-only: sddm is other, not group", 0, 0o750, 0o640, false},
	}
	for _, c := range cases {
		if got := greeterThemeHealthy(c.uid, c.dir, c.qml); got != c.want {
			t.Errorf("%s: greeterThemeHealthy(%d, %o, %o) = %v, want %v", c.name, c.uid, c.dir, c.qml, got, c.want)
		}
	}
}

// the limine layout reconciler's decision logic lives in planLimineLayout, a
// pure function of an observed limineLayoutState: no real /boot, no
// efibootmgr. the config surgery (mergeLimineConf) is exercised on literal
// configs shaped like the old installer's shadow file and like
// limine-mkinitcpio-hook's generated tree.
func TestPlanLimineLayout(t *testing.T) {
	treeConf := "timeout: 3\ndefault_entry: 2\n\n/+Ryoku\n    comment: Ryoku\n//linux\n    protocol: efi\n"
	flatConf := "timeout: 3\ndefault_entry: 1\n\n/Ryoku Linux\n    protocol: linux\n"

	cases := []struct {
		name       string
		in         limineLayoutState
		want       limineLayoutOutcome
		wantAction string // substring expected in the actions, empty when none
	}{
		{"no limine package skips", limineLayoutState{}, limineLayoutSkip, ""},
		{"limine installed but no configs under /boot skips",
			limineLayoutState{limineInstalled: true}, limineLayoutSkip, ""},
		{"healthy tool-managed layout reads ok",
			limineLayoutState{limineInstalled: true, espConfExists: true, espConfReadable: true, espConf: treeConf, toolEFIExists: true},
			limineLayoutOK, ""},
		{"shadow config must merge",
			limineLayoutState{limineInstalled: true, espConfExists: true, espConfReadable: true, espConf: treeConf, shadowExists: true, shadowReadable: true, shadowConf: flatConf},
			limineLayoutMigrate, "shadows the generated boot entries"},
		{"shadow without esp conf still merges (offline box)",
			limineLayoutState{limineInstalled: true, shadowExists: true, shadowReadable: true, shadowConf: flatConf},
			limineLayoutMigrate, "merge"},
		{"tree with default_entry 1 repoints the default",
			limineLayoutState{limineInstalled: true, espConfExists: true, espConfReadable: true, espConf: strings.Replace(treeConf, "default_entry: 2", "default_entry: 1", 1)},
			limineLayoutMigrate, "default_entry"},
		{"legacy hand-copied binary is retired",
			limineLayoutState{limineInstalled: true, espConfExists: true, espConfReadable: true, espConf: treeConf, legacyEFIExists: true},
			limineLayoutMigrate, "stale hand-copied bootloader"},
		{"unreadable configs punt to sudo",
			limineLayoutState{limineInstalled: true, espConfExists: true},
			limineLayoutUnreadable, ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, actions := planLimineLayout(c.in)
			if got != c.want {
				t.Fatalf("planLimineLayout = %d, want %d (actions=%v)", got, c.want, actions)
			}
			if c.wantAction == "" {
				if len(actions) != 0 {
					t.Errorf("unexpected actions: %v", actions)
				}
				return
			}
			joined := strings.Join(actions, " | ")
			if !strings.Contains(joined, c.wantAction) {
				t.Errorf("actions = %q, want one containing %q", joined, c.wantAction)
			}
		})
	}
}

// mergeLimineConf must (a) never lose generated entries, (b) put the Ryoku
// branding in charge of the globals, (c) keep foreign globals a user or the
// tool added, and (d) pick a bootable default_entry for the resulting menu
// shape.
func TestMergeLimineConf(t *testing.T) {
	shadow := `# Ryoku limine config = global look + branding only.
timeout: 3
default_entry: 1
interface_branding: Ryoku Bootloader
term_background: 171717

/Ryoku Linux
    protocol: linux
    kernel_path: boot():/vmlinuz-linux

# >>> ryoku-windows-entry (managed) >>>
/Windows
    comment: Boot into Windows
    protocol: efi_chainload
    path: uuid(abc):/EFI/Microsoft/Boot/bootmgfw.efi
# <<< ryoku-windows-entry (managed) <<<
`
	tree := `### Read more at the config document
timeout: 3
default_entry: 2
remember_last_entry: yes

/+Ryoku
    comment: Ryoku
//linux
    protocol: efi
    path: boot():/EFI/Linux/ryoku_linux.efi
//+Snapshots
///ID=42 2026-07-01
    protocol: efi
`

	t.Run("tool tree as base keeps entries and snapshots", func(t *testing.T) {
		got := mergeLimineConf(tree, shadow)
		for _, want := range []string{"/+Ryoku", "//+Snapshots", "interface_branding: Ryoku Bootloader", "remember_last_entry: yes", "default_entry: 2"} {
			if !strings.Contains(got, want) {
				t.Errorf("merged config missing %q:\n%s", want, got)
			}
		}
		if strings.Contains(got, "/Ryoku Linux") {
			t.Errorf("flat shadow entry leaked into the tool-managed merge:\n%s", got)
		}
		if strings.Count(got, "default_entry:") != 1 || strings.Count(got, "timeout:") != 1 {
			t.Errorf("branded globals duplicated:\n%s", got)
		}
	})

	t.Run("flat shadow as base stays bootable with default 1", func(t *testing.T) {
		got := mergeLimineConf("", shadow)
		for _, want := range []string{"/Ryoku Linux", "/Windows", "default_entry: 1", "# >>> ryoku-windows-entry (managed) >>>"} {
			if !strings.Contains(got, want) {
				t.Errorf("merged config missing %q:\n%s", want, got)
			}
		}
		if strings.Contains(got, "default_entry: 2") {
			t.Errorf("flat menu must not default past the first entry (Windows would autoboot):\n%s", got)
		}
	})
}

func TestStaleLimineBootNums(t *testing.T) {
	out := `BootCurrent: 0003
Timeout: 1 seconds
BootOrder: 0003,0001,0000
Boot0000* Windows Boot Manager	HD(1,GPT,aaa)/\EFI\Microsoft\Boot\bootmgfw.efi
Boot0001* Limine	HD(1,GPT,bbb)/\EFI\limine\limine_x64.efi
Boot0003* Ryoku	HD(1,GPT,bbb)/\EFI\limine\limine.efi
`
	got := staleLimineBootNums(out)
	if len(got) != 1 || got[0] != "0003" {
		t.Fatalf("staleLimineBootNums = %v, want [0003] (only the legacy limine.efi, never limine_x64.efi)", got)
	}
	if got := staleLimineBootNums(""); len(got) != 0 {
		t.Fatalf("empty efibootmgr output must yield nothing, got %v", got)
	}
}

func TestLimineConfProbes(t *testing.T) {
	tree := "default_entry: 2\n/+Ryoku\n//linux\n"
	flat := "default_entry: 1\n/Ryoku Linux\n    protocol: linux\n"
	if !limineHasBootTree(tree) || limineHasBootTree(flat) {
		t.Error("boot-tree probe must key on the /+ directory marker only")
	}
	if limineDefaultEntry(tree) != "2" || limineDefaultEntry(flat) != "1" || limineDefaultEntry("") != "" {
		t.Error("default_entry probe misparsed")
	}
}

// fastfetchLogoSource lifts the single logo image path out of the JSONC
// config the reconciler keys on. it must read the value verbatim, skip a
// "source" that only appears inside a // comment, and report absence rather
// than guess -- an absent source is how the reconciler recognizes a box with
// no Ryoku fastfetch logo to defend.
func TestFastfetchLogoSource(t *testing.T) {
	cases := []struct {
		name   string
		cfg    string
		want   string
		wantOK bool
	}{
		{
			name: "logo block source is read verbatim",
			cfg: "{\n" +
				"    \"logo\": {\n" +
				"        \"type\": \"kitty-direct\",\n" +
				"        \"source\": \"~/.config/fastfetch/fastfetch-emblem.png\",\n" +
				"        \"width\": 30\n" +
				"    }\n" +
				"}\n",
			want:   "~/.config/fastfetch/fastfetch-emblem.png",
			wantOK: true,
		},
		{
			name: "commented-out source is skipped",
			cfg: "{\n" +
				"    \"logo\": {\n" +
				"        // \"source\": \"~/.config/fastfetch/fastfetch-emblem.png\",\n" +
				"        \"type\": \"builtin\"\n" +
				"    }\n" +
				"}\n",
			wantOK: false,
		},
		{
			name: "no source line",
			cfg: "{\n" +
				"    \"logo\": {\n" +
				"        \"type\": \"builtin\",\n" +
				"        \"width\": 30\n" +
				"    }\n" +
				"}\n",
			wantOK: false,
		},
		{name: "empty config", cfg: "", wantOK: false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, ok := fastfetchLogoSource(c.cfg)
			if ok != c.wantOK {
				t.Fatalf("ok = %v, want %v (got source %q)", ok, c.wantOK, got)
			}
			if ok && got != c.want {
				t.Errorf("source = %q, want %q", got, c.want)
			}
		})
	}
}

// expandTilde must resolve a leading ~ against the home dir the way fastfetch
// does at runtime, and leave an already-absolute path untouched. asserting
// against home() (rather than a literal) keeps it robust to how home() is
// resolved while still pinning the mapping: bare ~ -> home, ~/x/y -> joined,
// absolute -> verbatim.
func TestExpandTilde(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	h := home()
	if got := expandTilde("~"); got != h {
		t.Errorf("expandTilde(\"~\") = %q, want %q", got, h)
	}
	if got, want := expandTilde("~/x/y"), filepath.Join(h, "x/y"); got != want {
		t.Errorf("expandTilde(\"~/x/y\") = %q, want %q", got, want)
	}
	if got := expandTilde("/usr/share/x.png"); got != "/usr/share/x.png" {
		t.Errorf("absolute path must pass through unchanged, got %q", got)
	}
}

// reconcileFastfetchEmblem keeps the branded readout off the stock Arch logo.
// exercised end to end through real IO in temp dirs (config + packaged base
// tree), driven entirely by env so it never touches the real HOME or system
// paths. one subtest per branch of the reconciler's decision.
func TestReconcileFastfetchEmblem(t *testing.T) {
	const emblemSrc = "~/.config/fastfetch/fastfetch-emblem.png"
	baseBytes := []byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n', 0, 1, 2, 3}

	type dirs struct{ home, base string }
	setup := func(t *testing.T) dirs {
		home, base := t.TempDir(), t.TempDir()
		t.Setenv("HOME", home)
		t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
		t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
		t.Setenv("RYOKU_CONFIG_BASE", base)
		return dirs{home: home, base: base}
	}
	writeConfig := func(t *testing.T, home, source string) {
		dir := filepath.Join(home, ".config", "fastfetch")
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
		cfg := "{\n    \"logo\": {\n        \"type\": \"kitty-direct\",\n" +
			"        \"source\": \"" + source + "\"\n    }\n}\n"
		if err := os.WriteFile(filepath.Join(dir, "config.jsonc"), []byte(cfg), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	writeBlob := func(t *testing.T, path string, b []byte) {
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, b, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	baseEmblem := func(d dirs) string { return filepath.Join(d.base, "fastfetch", fastfetchEmblem) }

	t.Run("no config file is a quiet ok", func(t *testing.T) {
		setup(t)
		if r := reconcileFastfetchEmblem(false); r.status != recOK {
			t.Fatalf("status=%s detail=%q, want ok", r.status.label(), r.detail)
		}
	})

	t.Run("user-customized logo is left alone", func(t *testing.T) {
		d := setup(t)
		writeConfig(t, d.home, "~/.config/fastfetch/my-logo.png")
		writeBlob(t, baseEmblem(d), baseBytes) // present, and must still not be touched
		if r := reconcileFastfetchEmblem(false); r.status != recOK {
			t.Fatalf("status=%s detail=%q, want ok", r.status.label(), r.detail)
		}
		// the reconciler must create nothing: neither the custom logo it does
		// not own, nor the emblem beside the config.
		if p := expandTilde("~/.config/fastfetch/my-logo.png"); exists(p) {
			t.Errorf("must not create the user's logo at %s", p)
		}
		if p := expandTilde(emblemSrc); exists(p) {
			t.Errorf("must not drop an emblem into the config dir at %s", p)
		}
	})

	t.Run("emblem already present resolves ok", func(t *testing.T) {
		d := setup(t)
		writeConfig(t, d.home, emblemSrc)
		writeBlob(t, expandTilde(emblemSrc), baseBytes)
		if r := reconcileFastfetchEmblem(false); r.status != recOK {
			t.Fatalf("status=%s detail=%q, want ok", r.status.label(), r.detail)
		}
	})

	t.Run("check-only reports the fix without applying it", func(t *testing.T) {
		d := setup(t)
		writeConfig(t, d.home, emblemSrc)
		writeBlob(t, baseEmblem(d), baseBytes)
		r := reconcileFastfetchEmblem(true)
		if r.status != recWouldFix {
			t.Fatalf("status=%s detail=%q, want todo", r.status.label(), r.detail)
		}
		if r.remedy != "ryoku materialize" {
			t.Errorf("remedy = %q, want \"ryoku materialize\"", r.remedy)
		}
		if dst := expandTilde(emblemSrc); exists(dst) {
			t.Errorf("check-only must not create the emblem at %s", dst)
		}
	})

	t.Run("missing emblem is restored from the base tree", func(t *testing.T) {
		d := setup(t)
		writeConfig(t, d.home, emblemSrc)
		writeBlob(t, baseEmblem(d), baseBytes)
		if r := reconcileFastfetchEmblem(false); r.status != recFixed {
			t.Fatalf("status=%s detail=%q, want fixed", r.status.label(), r.detail)
		}
		dst := expandTilde(emblemSrc)
		got, err := os.ReadFile(dst)
		if err != nil {
			t.Fatalf("emblem not restored at %s: %v", dst, err)
		}
		if string(got) != string(baseBytes) {
			t.Errorf("restored bytes = %v, want the base copy %v", got, baseBytes)
		}
		// idempotent: with the emblem now present, a second run is a no-op ok.
		if r := reconcileFastfetchEmblem(false); r.status != recOK {
			t.Fatalf("second run status=%s, want ok (idempotent)", r.status.label())
		}
	})

	// The recurring "doctor overwrites my custom fastfetch" report: prove the
	// reconciler only ever restores the emblem PNG and never rewrites config.jsonc.
	t.Run("restoring the emblem never rewrites config.jsonc", func(t *testing.T) {
		d := setup(t)
		writeConfig(t, d.home, emblemSrc)
		writeBlob(t, baseEmblem(d), baseBytes)
		cfgPath := filepath.Join(d.home, ".config", "fastfetch", "config.jsonc")
		before, err := os.ReadFile(cfgPath)
		if err != nil {
			t.Fatal(err)
		}
		if r := reconcileFastfetchEmblem(false); r.status != recFixed {
			t.Fatalf("status=%s, want fixed (emblem restored)", r.status.label())
		}
		after, err := os.ReadFile(cfgPath)
		if err != nil {
			t.Fatal(err)
		}
		if string(before) != string(after) {
			t.Errorf("config.jsonc was modified by the emblem reconciler:\n before=%q\n after=%q", before, after)
		}
	})

	t.Run("base tree lacking the emblem warns to update", func(t *testing.T) {
		d := setup(t)
		writeConfig(t, d.home, emblemSrc)
		// no base emblem: pre-fix package, cure is to pull it first.
		r := reconcileFastfetchEmblem(false)
		if r.status != recWarn {
			t.Fatalf("status=%s detail=%q, want warn", r.status.label(), r.detail)
		}
		if r.remedy != "ryoku update" {
			t.Errorf("remedy = %q, want \"ryoku update\"", r.remedy)
		}
		if dst := expandTilde(emblemSrc); exists(dst) {
			t.Errorf("nothing to copy: must not create %s", dst)
		}
	})
}

// hasRyokuBootEntry answers the boot-critical guard: does some ACTIVE NVRAM
// entry already boot the package-refreshed limine, so `ryoku update` may retire
// the legacy entry / the healing reconciler can stand down? "present" means an
// active entry (BootXXXX* ...) either loads \limine_x64.efi or carries the
// limine-install label "Limine" (VenHw, no file path). The legacy \limine.efi
// entry, inactive entries, foreign entries, and empty output must all read NOT
// present. Fixtures mirror real efibootmgr: a header block, then one entry per
// line with a TAB between label and device path.
func TestHasRyokuBootEntry(t *testing.T) {
	const header = "BootCurrent: 0004\nTimeout: 3\nBootOrder: 0004,0002\n"
	const legacy = "Boot0003* Ryoku\tHD(1,GPT,abcd)/File(\\EFI\\limine\\limine.efi)\n"
	cases := []struct {
		name       string
		efibootmgr string
		want       bool
	}{
		{
			"limine-install VenHw entry, label Limine, no file path",
			header + "Boot0004* Limine\tVenHw(99e275e7-75a0-4b37-a2e6-c5385e6c00cb)\n",
			true,
		},
		{
			"installer Ryoku entry loading limine_x64.efi",
			header + "Boot0002* Ryoku\tHD(1,GPT,abcd)/File(\\EFI\\limine\\limine_x64.efi)\n",
			true,
		},
		{
			"only the legacy limine.efi entry: migration owns it, not present",
			header + legacy,
			false,
		},
		{
			"inactive limine entry only (no *): not active, not present",
			header + "Boot0005  Limine\tVenHw(99e275e7-75a0-4b37-a2e6-c5385e6c00cb)\n",
			false,
		},
		{
			"only a foreign Windows Boot Manager entry",
			header + "Boot0000* Windows Boot Manager\tHD(1,GPT,aaa)/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)\n",
			false,
		},
		{"empty efibootmgr output", "", false},
	}
	for _, c := range cases {
		if got := hasRyokuBootEntry(c.efibootmgr); got != c.want {
			t.Errorf("%s: hasRyokuBootEntry = %v, want %v", c.name, got, c.want)
		}
	}

	// the legacy-only fixture is exactly what staleLimineBootNums must claim, so
	// the layout migration (not the healing reconciler) converts it.
	if got := staleLimineBootNums(header + legacy); len(got) != 1 || got[0] != "0003" {
		t.Errorf("staleLimineBootNums(legacy) = %v, want [0003]", got)
	}
}

// limineBootLabel extracts the label field of an efibootmgr line: the text
// after BootXXXX and an optional *, up to the first TAB (space-separated
// fallback when there is no tab). A label with spaces must survive intact
// (run to the tab, not the first space), and a non-entry header line must yield
// "" because isHex4(line[4:8]) fails.
func TestLimineBootLabel(t *testing.T) {
	cases := []struct {
		name string
		line string
		want string
	}{
		{"limine-install label", "Boot0004* Limine\tVenHw(99e275e7-75a0-4b37-a2e6-c5385e6c00cb)", "Limine"},
		{"installer label", "Boot0002* Ryoku\tHD(1,GPT,abcd)/File(\\EFI\\limine\\limine_x64.efi)", "Ryoku"},
		{"spaced label runs to the tab", "Boot0000* Windows Boot Manager\tHD(1,GPT,aaa)/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)", "Windows Boot Manager"},
		{"space-separated fallback, no tab", "Boot0006* Limine VenHw(x)", "Limine"},
		{"BootOrder header is not an entry", "BootOrder: 0004,0002", ""},
		{"BootCurrent header is not an entry", "BootCurrent: 0004", ""},
	}
	for _, c := range cases {
		if got := limineBootLabel(c.line); got != c.want {
			t.Errorf("%s: limineBootLabel(%q) = %q, want %q", c.name, c.line, got, c.want)
		}
	}
}

// parseEspDiskPart derives the efibootmgr --disk/--part pair the boot-entry
// writer needs. It trims all three inputs and refuses (ok=false) unless the
// mount source is under /dev/ and both the parent-disk name and partition
// number are non-empty; on success the disk is "/dev/"+pkname and the part is
// the trimmed partition number.
func TestParseEspDiskPart(t *testing.T) {
	cases := []struct {
		name                 string
		source, pkname, part string
		wantDisk, wantPart   string
		wantOK               bool
	}{
		{"nvme, part has trailing newline", "/dev/nvme0n1p1", "nvme0n1", "1\n", "/dev/nvme0n1", "1", true},
		{"sata, padded part number", "/dev/sda2", "sda", " 2 ", "/dev/sda", "2", true},
		{"source not under /dev", "mapper/foo", "sda", "1", "", "", false},
		{"empty pkname", "/dev/sda1", "", "1", "", "", false},
		{"empty partition", "/dev/sda1", "sda", "", "", "", false},
	}
	for _, c := range cases {
		disk, part, ok := parseEspDiskPart(c.source, c.pkname, c.part)
		if ok != c.wantOK || disk != c.wantDisk || part != c.wantPart {
			t.Errorf("%s: parseEspDiskPart(%q,%q,%q) = (%q,%q,%v), want (%q,%q,%v)",
				c.name, c.source, c.pkname, c.part, disk, part, ok, c.wantDisk, c.wantPart, c.wantOK)
		}
	}
}

// hyprSetFollowMouse must flip only input.followMouse and preserve every other
// field, so the healed JSON round-trips cleanly through `ryoku-hub hypr save`.
func TestHyprFollowMouseRewrite(t *testing.T) {
	raw := `{"input":{"kbLayout":"us","followMouse":1,"tapToClick":true},"appearance":{"gapsIn":5}}`
	if fm, ok := hyprGetFollowMouse(raw); !ok || fm != 1 {
		t.Fatalf("get: got (%d,%v), want (1,true)", fm, ok)
	}
	fixed, err := hyprSetFollowMouse(raw, 2)
	if err != nil {
		t.Fatalf("set: %v", err)
	}
	if fm, ok := hyprGetFollowMouse(fixed); !ok || fm != 2 {
		t.Errorf("after set: got (%d,%v), want (2,true)", fm, ok)
	}
	// untouched fields survive.
	for _, want := range []string{`"kbLayout":"us"`, `"tapToClick":true`, `"gapsIn":5`} {
		if !strings.Contains(fixed, want) {
			t.Errorf("healed JSON dropped %s: %s", want, fixed)
		}
	}
}

// A config that never held the retired default (or has no followMouse) is a no-op.
func TestHyprFollowMouseNotDefault(t *testing.T) {
	if fm, ok := hyprGetFollowMouse(`{"input":{"followMouse":2}}`); !ok || fm != 2 {
		t.Errorf("followMouse=2: got (%d,%v)", fm, ok)
	}
	if _, ok := hyprGetFollowMouse(`{"input":{}}`); ok {
		t.Errorf("missing followMouse should report absent")
	}
}

// migrateShellConfig: pill-era files lose the island knobs and get the bar
// back; out-of-range geometry clamps; a current-schema file is left alone.
func TestMigrateShellConfig(t *testing.T) {
	legacy := []byte(`{
		"islandStyle": "floating", "islandWidth": 109, "islandAutohide": true,
		"barEnabled": false, "barHeight": 26,
		"frameBorder": 59, "fontScale": 1.3
	}`)
	out, changes, err := migrateShellConfig(legacy)
	if err != nil || len(changes) == 0 {
		t.Fatalf("legacy file should migrate: changes=%v err=%v", changes, err)
	}
	var cfg map[string]any
	if err := json.Unmarshal(out, &cfg); err != nil {
		t.Fatalf("migrated JSON does not parse: %v", err)
	}
	for _, k := range legacyIslandKeys {
		if _, ok := cfg[k]; ok {
			t.Errorf("retired key %s survived the migration", k)
		}
	}
	if on, _ := cfg["barEnabled"].(bool); !on {
		t.Error("legacy barEnabled:false must flip on (the island face is gone)")
	}
	if pos, _ := cfg["barPosition"].(string); pos != "top" {
		t.Errorf("missing barPosition should seed to top, got %q", pos)
	}
	if v, _ := cfg["barHeight"].(float64); v != 26 {
		t.Errorf("in-range barHeight must be untouched, got %g", v)
	}

	clamped := []byte(`{"barPosition": "top", "frameBorder": 900, "barHeight": 4}`)
	out, changes, err = migrateShellConfig(clamped)
	if err != nil || len(changes) != 2 {
		t.Fatalf("out-of-range file should clamp twice: changes=%v err=%v", changes, err)
	}
	_ = json.Unmarshal(out, &cfg)
	if v, _ := cfg["frameBorder"].(float64); v != 120 {
		t.Errorf("frameBorder 900 should clamp to 120, got %g", v)
	}
	if v, _ := cfg["barHeight"].(float64); v != 16 {
		t.Errorf("barHeight 4 should clamp to 16, got %g", v)
	}

	modern := []byte(`{"barPosition": "bottom", "barEnabled": false, "barHeight": 30}`)
	if out, changes, err := migrateShellConfig(modern); out != nil || changes != nil || err != nil {
		t.Fatalf("current-schema file must pass through untouched: out=%s changes=%v err=%v", out, changes, err)
	}

	if _, _, err := migrateShellConfig([]byte("not json")); err == nil {
		t.Fatal("garbage must error, not silently rewrite")
	}
}
