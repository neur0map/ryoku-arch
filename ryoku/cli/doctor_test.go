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
	// A second file must block the auto-fix so surgery never runs on a shared dir.
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

// A crash-truncated generated drop-in is detected and repaired to a parseable
// safe seed, while a valid sibling is left untouched and the fix is idempotent.
// PATH is emptied so the test never touches luac/hyprctl/ryoku-monitor: it
// exercises the structural check and the safe-seed fallback deterministically.
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
