package updater

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

	if err := channelUpdate(); err != nil {
		t.Fatalf("channelUpdate: %v", err)
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

	// A maintainer mid-dev: a feature branch with its own commit origin/main lacks.
	mustGit(t, work, "checkout", "-b", "feature-branch")
	writeFile(t, filepath.Join(work, "wip"), "z\n")
	mustGit(t, work, "add", "-A")
	mustGit(t, work, "commit", "-m", "local wip")
	feature := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD"))

	// origin/main advances independently, so the branch and origin/main diverge.
	other := filepath.Join(root, "other")
	mustGit(t, "", "clone", origin, other)
	commitPush(t, other, "feature", "x\n", "add feature", "main")

	t.Setenv("RYOKU_REPO", work)
	t.Setenv("RYOKU_CHANNEL", "main")
	t.Setenv("XDG_RUNTIME_DIR", root)

	// The git path still redeploys, but a diverged feature branch keeps its
	// commits: branch management stays with the maintainer.
	if err := channelUpdate(); err != nil {
		t.Fatalf("channelUpdate off-channel: err=%v, want nil", err)
	}
	if got := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD")); got != feature {
		t.Errorf("off-channel update moved the maintainer's branch (HEAD %s, want %s)", got, feature)
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
	if err := channelUpdate(); err != nil {
		t.Fatalf("channelUpdate dirty: err=%v, want nil", err)
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

	if err := channelUpdate(); err != nil {
		t.Fatalf("channelUpdate on a diverged checkout: %v", err)
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

func TestSyncChannelFastForwardsNonMainBranch(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")
	mustGit(t, "", "init", "--bare", "-b", "main", origin)
	mustGit(t, "", "clone", origin, work)
	commitPush(t, work, "README", "one\n", "first commit", "main")

	// The dev box develops on unstable-dev, branched from the first commit; its
	// update channel is still main.
	mustGit(t, work, "checkout", "-b", "unstable-dev")

	// origin/main advances two commits ahead of the dev checkout.
	other := filepath.Join(root, "other")
	mustGit(t, "", "clone", origin, other)
	commitPush(t, other, "f1", "x\n", "release commit one", "main")
	commitPush(t, other, "f2", "y\n", "release commit two", "main")
	mustGit(t, work, "fetch", "origin", "main")

	if err := syncChannel(work, "main"); err != nil {
		t.Fatalf("syncChannel: %v", err)
	}

	head := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD"))
	want := strings.TrimSpace(mustGit(t, work, "rev-parse", "refs/remotes/origin/main"))
	if head != want {
		t.Errorf("HEAD = %s, want origin/main %s: a clean non-main branch must fast-forward onto the channel", head, want)
	}
	if br := strings.TrimSpace(mustGit(t, work, "symbolic-ref", "--short", "HEAD")); br != "unstable-dev" {
		t.Errorf("branch = %s, want unstable-dev: the fast-forward must not switch branches", br)
	}
}

func TestSyncChannelPreservesDivergedBranch(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")
	mustGit(t, "", "init", "--bare", "-b", "main", origin)
	mustGit(t, "", "clone", origin, work)
	commitPush(t, work, "README", "one\n", "first commit", "main")

	// A maintainer mid-dev: a feature branch with its own unpushed commit.
	mustGit(t, work, "checkout", "-b", "feature")
	writeFile(t, filepath.Join(work, "wip"), "z\n")
	mustGit(t, work, "add", "-A")
	mustGit(t, work, "commit", "-m", "local wip")
	wip := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD"))

	// origin/main advances independently, so feature and origin/main diverge.
	other := filepath.Join(root, "other")
	mustGit(t, "", "clone", origin, other)
	commitPush(t, other, "f1", "x\n", "upstream commit", "main")
	mustGit(t, work, "fetch", "origin", "main")

	if err := syncChannel(work, "main"); err != nil {
		t.Fatalf("syncChannel: %v", err)
	}
	if head := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD")); head != wip {
		t.Errorf("HEAD = %s, want the local wip %s: a diverged feature branch must not be moved", head, wip)
	}
}

func TestSyncChannelResetsDivergedChannelBranch(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")
	mustGit(t, "", "init", "--bare", "-b", "main", origin)
	mustGit(t, "", "clone", origin, work)
	commitPush(t, work, "README", "one\n", "first commit", "main")

	// A stray local commit on the channel branch that was never pushed.
	writeFile(t, filepath.Join(work, "local"), "l\n")
	mustGit(t, work, "add", "-A")
	mustGit(t, work, "commit", "-m", "stray local main commit")

	// origin/main advances differently, so local main and origin/main diverge.
	other := filepath.Join(root, "other")
	mustGit(t, "", "clone", origin, other)
	commitPush(t, other, "f1", "x\n", "upstream commit", "main")
	mustGit(t, work, "fetch", "origin", "main")

	if err := syncChannel(work, "main"); err != nil {
		t.Fatalf("syncChannel: %v", err)
	}
	// The channel branch mirrors upstream: it is reset onto origin/main, dropping
	// the stray commit.
	head := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD"))
	want := strings.TrimSpace(mustGit(t, work, "rev-parse", "refs/remotes/origin/main"))
	if head != want {
		t.Errorf("HEAD = %s, want origin/main %s: a diverged channel branch resets onto upstream", head, want)
	}
}

func TestSyncChannelLeavesDirtyTree(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")
	mustGit(t, "", "init", "--bare", "-b", "main", origin)
	mustGit(t, "", "clone", origin, work)
	commitPush(t, work, "README", "one\n", "first commit", "main")
	before := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD"))

	// origin/main advances; the checkout is behind but has uncommitted changes.
	other := filepath.Join(root, "other")
	mustGit(t, "", "clone", origin, other)
	commitPush(t, other, "f1", "x\n", "upstream commit", "main")
	mustGit(t, work, "fetch", "origin", "main")
	writeFile(t, filepath.Join(work, "README"), "dirty edit\n")

	if err := syncChannel(work, "main"); err != nil {
		t.Fatalf("syncChannel: %v", err)
	}
	if head := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD")); head != before {
		t.Errorf("HEAD = %s, want unchanged %s: a dirty tree must not be fast-forwarded", head, before)
	}
}

func TestSyncChannelNoOpWhenCurrent(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")
	mustGit(t, "", "init", "--bare", "-b", "main", origin)
	mustGit(t, "", "clone", origin, work)
	commitPush(t, work, "README", "one\n", "first commit", "main")
	mustGit(t, work, "fetch", "origin", "main")
	before := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD"))

	if err := syncChannel(work, "main"); err != nil {
		t.Fatalf("syncChannel: %v", err)
	}
	if head := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD")); head != before {
		t.Errorf("HEAD = %s, want unchanged %s: a current checkout is a no-op", head, before)
	}
}

// TestUpdateClearsBehindOnDevBranch is the regression guard for the reported
// symptom: a dev box on unstable-dev, behind origin/main, kept reporting updates
// after every `ryoku update`. It runs the channel sync `ryoku update` does and
// records the deployed commit the way deploy.sh does, then asserts status reads
// up to date.
func TestUpdateClearsBehindOnDevBranch(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")
	mustGit(t, "", "init", "--bare", "-b", "main", origin)
	mustGit(t, "", "clone", origin, work)
	commitPush(t, work, "README", "one\n", "first commit", "main")
	mustGit(t, work, "checkout", "-b", "unstable-dev")

	other := filepath.Join(root, "other")
	mustGit(t, "", "clone", origin, other)
	commitPush(t, other, "f1", "x\n", "release commit one", "main")
	commitPush(t, other, "f2", "y\n", "release commit two", "main")

	t.Setenv("RYOKU_REPO", work)
	t.Setenv("RYOKU_CHANNEL", "main")
	state := t.TempDir()
	t.Setenv("XDG_STATE_HOME", state)

	// Before the update: the dev box is behind the channel.
	if r, ok := channelStatus(); !ok || !r.Available || r.Behind == 0 {
		t.Fatalf("precondition: expected behind, got ok=%v available=%v behind=%d", ok, r.Available, r.Behind)
	}

	// The channel sync `ryoku update` runs, then deploy.sh records HEAD as the
	// deployed commit.
	if err := syncChannel(work, "main"); err != nil {
		t.Fatalf("syncChannel: %v", err)
	}
	head := strings.TrimSpace(mustGit(t, work, "rev-parse", "HEAD"))
	writeFile(t, filepath.Join(state, "ryoku", "deployed"), head+"\n")

	// After the update: nothing left behind.
	r, ok := channelStatus()
	if !ok {
		t.Fatal("channelStatus not ok after the sync")
	}
	if r.Available || r.Behind != 0 || len(r.Updates) != 0 {
		t.Errorf("after update want up to date, got available=%v behind=%d updates=%d", r.Available, r.Behind, len(r.Updates))
	}
}
