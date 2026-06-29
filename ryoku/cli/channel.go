package main

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// Update channel = a git branch (main for everyone) a Ryoku checkout tracks.
// `ryoku status` reports how far the deployed commit (the running system) is
// behind origin/<channel>; `ryoku update` pulls the channel in and redeploys.
// A packaged install has no checkout, so these report "no channel" and the
// caller falls back to the pacman view of the [ryoku] repo.

// ryokuChannel: the branch update tracks. RYOKU_CHANNEL overrides it for
// tests; every real Ryoku machine follows main.
func ryokuChannel() string {
	if c := strings.TrimSpace(os.Getenv("RYOKU_CHANNEL")); c != "" {
		return c
	}
	return "main"
}

// repoPathFile records where the live-mirror checkout sits. The deployed
// `ryoku` binary lives on PATH with no path back to the repo, so the dev
// deploy (ryoku/shell/deploy.sh) writes the checkout root here.
func repoPathFile() string {
	return filepath.Join(xdg("XDG_STATE_HOME", ".local/state"), "ryoku", "repo")
}

// resolveRepo returns the Ryoku checkout to track, or "" when there is none
// (packaged install). RYOKU_REPO wins (so `ryoku deploy` and tests can point
// it explicitly); else the path the last deploy recorded. Anything that
// isn't a git work tree is ignored.
func resolveRepo() string {
	for _, p := range []string{strings.TrimSpace(os.Getenv("RYOKU_REPO")), recordedRepo()} {
		if p == "" {
			continue
		}
		if _, err := runOut("git", "-C", p, "rev-parse", "--git-dir"); err == nil {
			return p
		}
	}
	return ""
}

func recordedRepo() string {
	b, err := os.ReadFile(repoPathFile())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// deployedFile records the commit the last deploy laid down. The channel is
// measured from that, not from whatever branch happens to be checked out, so
// a commit pushed upstream shows as an update until the machine redeploys onto it.
func deployedFile() string {
	return filepath.Join(xdg("XDG_STATE_HOME", ".local/state"), "ryoku", "deployed")
}

// deployedBase returns the recorded deployed commit if it still resolves in
// repo, else HEAD (a checkout that has never deployed through this CLI).
// Baseline for the channel comparison: what is running.
func deployedBase(repo string) string {
	if b, err := os.ReadFile(deployedFile()); err == nil {
		if c := strings.TrimSpace(string(b)); c != "" {
			if _, err := runOut("git", "-C", repo, "rev-parse", "--verify", "--quiet", c+"^{commit}"); err == nil {
				return c
			}
		}
	}
	return "HEAD"
}

// channelStatus reports how far the deployed commit is behind the channel:
// the commits origin/<channel> has that the running system doesn't. ok=false
// when there's no checkout to track or the remote has no such branch, so the
// caller falls back to the pacman view. Fetch is best-effort and bounded so
// an offline or auth-walled remote never hangs a status query; on a fetch
// failure the cached remote-tracking ref stands.
func channelStatus() (statusReport, bool) {
	repo := resolveRepo()
	if repo == "" {
		return statusReport{}, false
	}
	ch := ryokuChannel()
	remote := "refs/remotes/origin/" + ch

	gitFetch(repo, ch)

	if _, err := runOut("git", "-C", repo, "rev-parse", "--verify", "--quiet", remote); err != nil {
		return statusReport{}, false
	}
	base := deployedBase(repo)
	behind := gitCount(repo, base+".."+remote)

	// Version = the channel's latest commit, so the Hub matches what main
	// shows. When behind, surface the running commit too, so the header reads
	// "running X -> latest Y"; when current, both are the channel tip.
	latest := gitShort(repo, remote)
	installed := latest
	if behind > 0 {
		installed = gitShort(repo, base)
	}
	return statusReport{
		Installed: installed,
		Latest:    latest,
		Available: behind > 0,
		Behind:    behind,
		Updates:   gitLog(repo, base+".."+remote),
		Channel:   ch,
		Snapshots: snapshotCount(),
		Git:       true,
	}, true
}

// channelUpdate brings the checkout's channel up to origin/<channel> and
// redeploys: the git equivalent of a package upgrade. Clean checkout on the
// channel branch -> fast-forward first; feature branch (a maintainer
// mid-dev) or dirty tree -> leave branch management to git, just redeploy.
// Either way the checkout is handled (returns true), so the pacman path,
// which a dev checkout can't satisfy, never runs there. Returns false only
// on a packaged install with no checkout.
func channelUpdate() (bool, error) {
	repo := resolveRepo()
	if repo == "" {
		return false, nil
	}
	ch := ryokuChannel()

	fmt.Printf("==> Updating Ryoku (channel: %s)\n", ch)
	gitFetch(repo, ch)
	publishRun("running", 0.4)

	head, _ := runOut("git", "-C", repo, "symbolic-ref", "--short", "--quiet", "HEAD")
	dirty, _ := runOut("git", "-C", repo, "status", "--porcelain")
	if strings.TrimSpace(head) == ch && strings.TrimSpace(dirty) == "" {
		if err := run("git", "-C", repo, "merge", "--ff-only", "refs/remotes/origin/"+ch); err != nil {
			// Diverged: HEAD holds commits origin/<ch> lacks, so ff is impossible
			// and the update would dead-end forever. <ch> mirrors upstream (a dirty
			// tree already skipped above), so reset onto it.
			fmt.Printf("==> Channel history diverged; reconciling %s onto origin/%s\n", ch, ch)
			if err := run("git", "-C", repo, "reset", "--hard", "refs/remotes/origin/"+ch); err != nil {
				return true, fmt.Errorf("reconcile to origin/%s failed: %w", ch, err)
			}
		}
	}
	publishRun("running", 0.6)

	fmt.Println("==> Deploying desktop from the checkout")
	if err := run(filepath.Join(repo, "ryoku", "shell", "deploy.sh")); err != nil {
		return true, fmt.Errorf("deploy from %s failed: %w", repo, err)
	}
	publishRun("running", 0.95)
	return true, nil
}

// gitFetch updates the remote-tracking ref for one branch, best-effort.
// Never prompts for credentials and is bounded, so a private or unreachable
// remote fails fast and the cached ref stands.
func gitFetch(repo, branch string) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "git", "-C", repo, "fetch", "--quiet", "--no-tags", "origin", branch)
	cmd.Env = append(os.Environ(), "GIT_TERMINAL_PROMPT=0")
	_ = cmd.Run()
}

func gitCount(repo, rng string) int {
	out, err := runOut("git", "-C", repo, "rev-list", "--count", rng)
	if err != nil {
		return 0
	}
	n, _ := strconv.Atoi(strings.TrimSpace(out))
	return n
}

// gitShort: abbreviated commit hash of ref, the bare identifier the Hub
// shows as the version. 7-char floor matches GitHub's short hashes (git
// extends if a collision ever appears, as GitHub does).
func gitShort(repo, ref string) string {
	out, err := runOut("git", "-C", repo, "rev-parse", "--short=7", ref)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(out)
}

// gitLog: commits in rng newest-first as display rows. Subject in Name,
// short hash in New (a commit has no from/to pair, so Old stays empty).
func gitLog(repo, rng string) []updateItem {
	ups := []updateItem{}
	out, err := runOut("git", "-C", repo, "log", "--abbrev=7", "--format=%h%x1f%s", rng)
	if err != nil {
		return ups
	}
	sc := bufio.NewScanner(strings.NewReader(out))
	for sc.Scan() {
		f := strings.SplitN(sc.Text(), "\x1f", 2)
		if len(f) == 2 {
			ups = append(ups, updateItem{Name: f[1], New: f[0]})
		}
	}
	return ups
}
