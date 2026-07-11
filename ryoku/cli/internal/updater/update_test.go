package updater

import (
	"os"
	"strings"
	"testing"
	"time"
)

// wantedSnapperHelpers gates the offer. no btrfs+snapper -> nothing,
// limine-snapper-sync only on Limine.
func TestWantedSnapperHelpers(t *testing.T) {
	ready := snapHelpers{rootBtrfs: true, snapper: true}

	both := ready
	both.limine = true
	if got := wantedSnapperHelpers(both); len(got) != 2 || got[0] != "snap-pac" || got[1] != "limine-snapper-sync" {
		t.Fatalf("both missing + limine: got %v, want [snap-pac limine-snapper-sync]", got)
	}
	if got := wantedSnapperHelpers(ready); len(got) != 1 || got[0] != "snap-pac" {
		t.Fatalf("no limine: got %v, want [snap-pac]", got)
	}

	hasSnapPac := both
	hasSnapPac.snapPac = true
	if got := wantedSnapperHelpers(hasSnapPac); len(got) != 1 || got[0] != "limine-snapper-sync" {
		t.Fatalf("snap-pac present: got %v, want [limine-snapper-sync]", got)
	}

	allPresent := hasSnapPac
	allPresent.limineSync = true
	if got := wantedSnapperHelpers(allPresent); got != nil {
		t.Fatalf("all present: got %v, want nil", got)
	}

	if got := wantedSnapperHelpers(snapHelpers{snapper: true}); got != nil {
		t.Fatalf("non-btrfs root must offer nothing, got %v", got)
	}
	if got := wantedSnapperHelpers(snapHelpers{rootBtrfs: true}); got != nil {
		t.Fatalf("snapper absent must offer nothing (a separate doctor warn), got %v", got)
	}
}

// publishPrompt/awaitAnswer = the Hub consent back-channel. publish clears
// stale answers, run-state carries the prompt, awaitAnswer reads + consumes.
func TestPromptAnswerRoundTrip(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())

	// stale answer from a previous prompt must not satisfy this one.
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

	// no answer in the window = decline.
	if choice, ok := awaitAnswer(150 * time.Millisecond); ok {
		t.Fatalf("awaitAnswer should time out with no answer, got %q", choice)
	}

	// written answer: read, then consume.
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
