package sys

import (
	"os"
	"path/filepath"
	"strings"
)

// repoPathFile records where the live-mirror checkout sits. The deployed
// `ryoku` binary lives on PATH with no path back to the repo, so the dev
// deploy (ryoku/shell/deploy.sh) writes the checkout root here.
func repoPathFile() string { return filepath.Join(StateDir(), "repo") }

func recordedRepo() string {
	b, err := os.ReadFile(repoPathFile())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// ResolveRepo returns the Ryoku checkout root to track, or "" when there is
// none (a packaged install). RYOKU_REPO wins (so `ryoku deploy` and tests can
// point it explicitly); else the path the last deploy recorded. Anything that
// is not a git work tree is ignored.
func ResolveRepo() string {
	for _, p := range []string{strings.TrimSpace(os.Getenv("RYOKU_REPO")), recordedRepo()} {
		if p == "" {
			continue
		}
		if _, err := RunOut("git", "-C", p, "rev-parse", "--git-dir"); err == nil {
			return p
		}
	}
	return ""
}
