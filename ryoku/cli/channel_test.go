package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// mustGit runs git in dir with an isolated identity and config, failing the test
// on error. dir "" runs without -C (for clone/init that take an explicit path).
func mustGit(t *testing.T, dir string, args ...string) string {
	t.Helper()
	full := args
	if dir != "" {
		full = append([]string{"-C", dir}, args...)
	}
	cmd := exec.Command("git", full...)
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=test", "GIT_AUTHOR_EMAIL=test@example.com",
		"GIT_COMMITTER_NAME=test", "GIT_COMMITTER_EMAIL=test@example.com",
		"GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_SYSTEM=/dev/null")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return string(out)
}

func writeFile(t *testing.T, path, body string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

// commitPush writes a file in work, commits it, and pushes the channel branch.
func commitPush(t *testing.T, work, name, body, msg, branch string) {
	t.Helper()
	writeFile(t, filepath.Join(work, name), body)
	mustGit(t, work, "add", "-A")
	mustGit(t, work, "commit", "-m", msg)
	mustGit(t, work, "push", "origin", branch)
}

func TestChannelStatus(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")

	mustGit(t, "", "init", "--bare", "-b", "main", origin)
	mustGit(t, "", "clone", origin, work)
	commitPush(t, work, "README", "one\n", "first commit", "main")

	t.Setenv("RYOKU_REPO", work)
	t.Setenv("RYOKU_CHANNEL", "main")
	t.Setenv("XDG_STATE_HOME", t.TempDir()) // baseline falls back to HEAD, no recorded deploy

	// A fresh checkout in sync with its channel: nothing behind.
	r, ok := channelStatus()
	if !ok {
		t.Fatal("channelStatus not ok with a checkout present")
	}
	if r.Channel != "main" {
		t.Errorf("channel = %q, want main", r.Channel)
	}
	if !r.Git {
		t.Error("report should be flagged as git-sourced")
	}
	if r.Available || r.Behind != 0 || len(r.Updates) != 0 {
		t.Errorf("fresh checkout should be up to date: behind=%d available=%v updates=%d",
			r.Behind, r.Available, len(r.Updates))
	}

	// A second clone advances origin/main by two commits (a push to the channel).
	other := filepath.Join(root, "other")
	mustGit(t, "", "clone", origin, other)
	commitPush(t, other, "feature", "x\n", "add feature", "main")
	commitPush(t, other, "feature2", "y\n", "tweak feature", "main")

	// The checkout is now two commits behind; channelStatus fetches and reports it.
	r, ok = channelStatus()
	if !ok {
		t.Fatal("channelStatus not ok after the remote advanced")
	}
	if !r.Available || r.Behind != 2 {
		t.Errorf("behind = %d available = %v, want 2 / true", r.Behind, r.Available)
	}
	if len(r.Updates) != 2 {
		t.Fatalf("updates = %d, want 2", len(r.Updates))
	}
	// Newest first; subject in Name, short hash in New, no from/to pair.
	if got := r.Updates[0].Name; got != "tweak feature" {
		t.Errorf("updates[0].Name = %q, want %q", got, "tweak feature")
	}
	if r.Updates[0].New == "" || r.Updates[0].Old != "" {
		t.Errorf("commit row wants a short hash in New and empty Old, got %+v", r.Updates[0])
	}
	if r.Latest == r.Installed {
		t.Errorf("latest (%q) should differ from installed (%q) when behind", r.Latest, r.Installed)
	}
}

func TestChannelStatusNoCheckout(t *testing.T) {
	t.Setenv("RYOKU_REPO", "")
	t.Setenv("XDG_STATE_HOME", t.TempDir()) // no recorded repo here
	if _, ok := channelStatus(); ok {
		t.Error("channelStatus should report not-ok without a checkout")
	}
}

func TestChannelStatusUsesDeployedBaseline(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")
	state := t.TempDir()

	mustGit(t, "", "init", "--bare", "-b", "main", origin)
	mustGit(t, "", "clone", origin, work)
	commitPush(t, work, "README", "one\n", "first commit", "main")
	deployed := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD"))

	// Advance both HEAD and origin/main two commits past the deployed commit.
	commitPush(t, work, "f1", "x\n", "second commit", "main")
	commitPush(t, work, "f2", "y\n", "third commit", "main")

	t.Setenv("RYOKU_REPO", work)
	t.Setenv("RYOKU_CHANNEL", "main")
	t.Setenv("XDG_STATE_HOME", state)
	writeFile(t, filepath.Join(state, "ryoku", "deployed"), deployed+"\n")

	// HEAD == origin/main now, so a HEAD baseline would report 0; the deployed
	// baseline (two commits back, what is actually running) must report 2.
	r, ok := channelStatus()
	if !ok {
		t.Fatal("channelStatus not ok")
	}
	if !r.Available || r.Behind != 2 {
		t.Errorf("deployed baseline: behind=%d available=%v, want 2/true", r.Behind, r.Available)
	}
}

func TestChannelStatusVersionIsChannelTip(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")

	mustGit(t, "", "init", "--bare", "-b", "main", origin)
	mustGit(t, "", "clone", origin, work)
	commitPush(t, work, "README", "one\n", "first commit", "main")
	tip := strings.TrimSpace(mustGit(t, work, "rev-parse", "--short", "main"))

	// A local commit ahead of main that is never pushed (a maintainer's WIP), the
	// shape that made the Hub show a commit the repo did not have.
	writeFile(t, filepath.Join(work, "wip"), "z\n")
	mustGit(t, work, "add", "-A")
	mustGit(t, work, "commit", "-m", "local work ahead of main")

	t.Setenv("RYOKU_REPO", work)
	t.Setenv("RYOKU_CHANNEL", "main")
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	r, ok := channelStatus()
	if !ok {
		t.Fatal("channelStatus not ok")
	}
	// Ahead of the channel: up to date, and the version is the channel tip (what
	// the repo shows on main), not the local commit ahead of it.
	if r.Available || r.Behind != 0 {
		t.Errorf("ahead of channel should be up to date: behind=%d available=%v", r.Behind, r.Available)
	}
	if r.Installed != tip || r.Latest != tip {
		t.Errorf("version should be the channel tip %s, got installed=%s latest=%s", tip, r.Installed, r.Latest)
	}
}

func TestChannelUpdateFastForwards(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")

	mustGit(t, "", "init", "--bare", "-b", "main", origin)
	mustGit(t, "", "clone", origin, work)
	// A stub deploy script stands in for the real one channelUpdate runs.
	writeFile(t, filepath.Join(work, "ryoku", "shell", "deploy.sh"), "#!/bin/sh\nexit 0\n")
	if err := os.Chmod(filepath.Join(work, "ryoku", "shell", "deploy.sh"), 0o755); err != nil {
		t.Fatal(err)
	}
	mustGit(t, work, "add", "-A")
	mustGit(t, work, "commit", "-m", "seed with deploy stub")
	mustGit(t, work, "push", "origin", "main")

	other := filepath.Join(root, "other")
	mustGit(t, "", "clone", origin, other)
	commitPush(t, other, "feature", "x\n", "add feature", "main")

	t.Setenv("RYOKU_REPO", work)
	t.Setenv("RYOKU_CHANNEL", "main")
	t.Setenv("XDG_RUNTIME_DIR", root) // contain publishRun's state file
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	handled, err := channelUpdate()
	if err != nil {
		t.Fatalf("channelUpdate: %v", err)
	}
	if !handled {
		t.Fatal("channelUpdate should handle a clean checkout on the channel")
	}
	if got := mustGit(t, work, "rev-parse", "HEAD"); got != mustGit(t, work, "rev-parse", "refs/remotes/origin/main") {
		t.Error("checkout did not fast-forward to origin/main")
	}
	if r, _ := channelStatus(); r.Behind != 0 {
		t.Errorf("after update, behind = %d, want 0", r.Behind)
	}
}

func TestChannelUpdateDeploysWithoutFastForwardOffChannel(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")

	mustGit(t, "", "init", "--bare", "-b", "main", origin)
	mustGit(t, "", "clone", origin, work)
	writeFile(t, filepath.Join(work, "ryoku", "shell", "deploy.sh"), "#!/bin/sh\nexit 0\n")
	if err := os.Chmod(filepath.Join(work, "ryoku", "shell", "deploy.sh"), 0o755); err != nil {
		t.Fatal(err)
	}
	mustGit(t, work, "add", "-A")
	mustGit(t, work, "commit", "-m", "seed with deploy stub")
	mustGit(t, work, "push", "origin", "main")
	mustGit(t, work, "checkout", "-b", "feature-branch")
	feature := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD"))

	// origin/main advances while the maintainer stays on a feature branch.
	other := filepath.Join(root, "other")
	mustGit(t, "", "clone", origin, other)
	commitPush(t, other, "feature", "x\n", "add feature", "main")

	t.Setenv("RYOKU_REPO", work)
	t.Setenv("RYOKU_CHANNEL", "main")
	t.Setenv("XDG_RUNTIME_DIR", root)

	// The git path still handles the update (redeploys), but must not move the
	// maintainer's branch: branch management stays with git.
	handled, err := channelUpdate()
	if err != nil || !handled {
		t.Fatalf("channelUpdate off-channel: handled=%v err=%v, want true/nil", handled, err)
	}
	if got := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD")); got != feature {
		t.Errorf("off-channel update fast-forwarded the branch (HEAD %s, want %s)", got, feature)
	}
}

func TestChannelUpdateDeploysWithoutFastForwardWhenDirty(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")

	mustGit(t, "", "init", "--bare", "-b", "main", origin)
	mustGit(t, "", "clone", origin, work)
	writeFile(t, filepath.Join(work, "ryoku", "shell", "deploy.sh"), "#!/bin/sh\nexit 0\n")
	if err := os.Chmod(filepath.Join(work, "ryoku", "shell", "deploy.sh"), 0o755); err != nil {
		t.Fatal(err)
	}
	mustGit(t, work, "add", "-A")
	mustGit(t, work, "commit", "-m", "seed with deploy stub")
	mustGit(t, work, "push", "origin", "main")
	on := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD"))

	other := filepath.Join(root, "other")
	mustGit(t, "", "clone", origin, other)
	commitPush(t, other, "feature", "x\n", "add feature", "main")

	writeFile(t, filepath.Join(work, "README"), "dirty\n") // uncommitted change

	t.Setenv("RYOKU_REPO", work)
	t.Setenv("RYOKU_CHANNEL", "main")
	t.Setenv("XDG_RUNTIME_DIR", root)

	// A dirty tree must not be fast-forwarded (it would clobber work in progress),
	// but the redeploy still runs.
	handled, err := channelUpdate()
	if err != nil || !handled {
		t.Fatalf("channelUpdate dirty: handled=%v err=%v, want true/nil", handled, err)
	}
	if got := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD")); got != on {
		t.Errorf("dirty update fast-forwarded the tree (HEAD %s, want %s)", got, on)
	}
}

func TestChannelUpdateReconcilesDivergence(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")

	mustGit(t, "", "init", "--bare", "-b", "main", origin)
	mustGit(t, "", "clone", origin, work)
	writeFile(t, filepath.Join(work, "ryoku", "shell", "deploy.sh"), "#!/bin/sh\nexit 0\n")
	if err := os.Chmod(filepath.Join(work, "ryoku", "shell", "deploy.sh"), 0o755); err != nil {
		t.Fatal(err)
	}
	mustGit(t, work, "add", "-A")
	mustGit(t, work, "commit", "-m", "seed with deploy stub")
	mustGit(t, work, "push", "origin", "main")

	// origin/main advances...
	other := filepath.Join(root, "other")
	mustGit(t, "", "clone", origin, other)
	commitPush(t, other, "upstream", "u\n", "upstream fix", "main")

	// ...while local main diverges onto a commit origin/main lacks: no ff possible.
	writeFile(t, filepath.Join(work, "stray"), "s\n")
	mustGit(t, work, "add", "-A")
	mustGit(t, work, "commit", "-m", "stray local commit")

	t.Setenv("RYOKU_REPO", work)
	t.Setenv("RYOKU_CHANNEL", "main")
	t.Setenv("XDG_RUNTIME_DIR", root)
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	handled, err := channelUpdate()
	if err != nil {
		t.Fatalf("channelUpdate on a diverged checkout: %v", err)
	}
	if !handled {
		t.Fatal("channelUpdate should handle a diverged checkout on the channel")
	}
	head := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD"))
	want := strings.TrimSpace(mustGit(t, work, "rev-parse", "refs/remotes/origin/main"))
	if head != want {
		t.Errorf("diverged checkout was not reconciled to origin/main (HEAD %s, want %s)", head, want)
	}
	if r, _ := channelStatus(); r.Behind != 0 {
		t.Errorf("after reconcile, behind = %d, want 0", r.Behind)
	}
}

func TestRyokuChannelDefaultAndOverride(t *testing.T) {
	t.Setenv("RYOKU_CHANNEL", "")
	if got := ryokuChannel(); got != "main" {
		t.Errorf("default channel = %q, want main", got)
	}
	t.Setenv("RYOKU_CHANNEL", "unstable-dev")
	if got := ryokuChannel(); got != "unstable-dev" {
		t.Errorf("override channel = %q, want unstable-dev", got)
	}
}

// shortCommit pulls the gNNNN commit token out of the repo-built package version
// (the form that lets the Hub and `ryoku status` show the exact commit), and
// leaves a version without that token (a hand-pinned 0.1.0-3, a bare hash) alone.
func TestShortCommit(t *testing.T) {
	cases := []struct{ in, want string }{
		{"0.1.0.r241.g07bf14d-1", "07bf14d"},
		{"0.1.0.r241.g07bf14d", "07bf14d"},
		{"1.2.3.r5.gabcdef0", "abcdef0"},
		{"0.1.0-3", "0.1.0-3"},
		{"0.1.0", "0.1.0"},
		{"07bf14d", "07bf14d"},
		{"", ""},
	}
	for _, c := range cases {
		if got := shortCommit(c.in); got != c.want {
			t.Errorf("shortCommit(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}
