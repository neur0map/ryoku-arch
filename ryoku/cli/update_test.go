package main

import (
	"os"
	"strings"
	"testing"
	"time"
)

// wantedSnapperHelpers gates the offer: no snapshots without btrfs + snapper, and
// limine-snapper-sync only when Limine is the bootloader.
func TestWantedSnapperHelpers(t *testing.T) {
	ready := snapperState{rootIsBtrfs: true, snapperInstalled: true}

	if got := wantedSnapperHelpers(ready, true); len(got) != 2 || got[0] != "snap-pac" || got[1] != "limine-snapper-sync" {
		t.Fatalf("both missing + limine: got %v, want [snap-pac limine-snapper-sync]", got)
	}
	if got := wantedSnapperHelpers(ready, false); len(got) != 1 || got[0] != "snap-pac" {
		t.Fatalf("no limine: got %v, want [snap-pac]", got)
	}

	hasSnapPac := ready
	hasSnapPac.snapPacInstalled = true
	if got := wantedSnapperHelpers(hasSnapPac, true); len(got) != 1 || got[0] != "limine-snapper-sync" {
		t.Fatalf("snap-pac present: got %v, want [limine-snapper-sync]", got)
	}

	allPresent := hasSnapPac
	allPresent.limineSyncInstalled = true
	if got := wantedSnapperHelpers(allPresent, true); got != nil {
		t.Fatalf("all present: got %v, want nil", got)
	}

	if got := wantedSnapperHelpers(snapperState{snapperInstalled: true}, true); got != nil {
		t.Fatalf("non-btrfs root must offer nothing, got %v", got)
	}
	if got := wantedSnapperHelpers(snapperState{rootIsBtrfs: true}, true); got != nil {
		t.Fatalf("snapper absent must offer nothing (a separate doctor warn), got %v", got)
	}
}

// publishPrompt/awaitAnswer is the Hub consent back-channel: a prompt clears any
// stale answer, the run-state carries it, and a fresh answer is read and consumed.
func TestPromptAnswerRoundTrip(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())

	// A stale answer from a previous prompt must not satisfy this one.
	if err := os.WriteFile(answerPath(), []byte("Install"), 0o644); err != nil {
		t.Fatal(err)
	}
	publishPrompt("snapper-helpers", "Enable snapshot helpers?", "detail", []string{"Install", "Skip"})
	if _, err := os.Stat(answerPath()); !os.IsNotExist(err) {
		t.Fatal("publishPrompt must clear a stale answer")
	}

	b, err := os.ReadFile(runStatePath())
	if err != nil || !strings.Contains(string(b), `"phase":"prompt"`) || !strings.Contains(string(b), "snapper-helpers") {
		t.Fatalf("run-state missing the prompt: %s (err %v)", b, err)
	}

	// No answer within the window is a decline.
	if choice, ok := awaitAnswer(150 * time.Millisecond); ok {
		t.Fatalf("awaitAnswer should time out with no answer, got %q", choice)
	}

	// A written answer is read and then consumed.
	if err := os.WriteFile(answerPath(), []byte("Install\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if choice, ok := awaitAnswer(2 * time.Second); !ok || choice != "Install" {
		t.Fatalf("awaitAnswer = %q, %v; want Install, true", choice, ok)
	}
	if _, err := os.Stat(answerPath()); !os.IsNotExist(err) {
		t.Fatal("awaitAnswer must consume the answer file")
	}
}
