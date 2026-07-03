package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// cmdVersion prints the running Ryoku version. Plain form feeds fastfetch's OS
// line ("Ryoku v0.1.0-beta.14"); `--branch` feeds its BRANCH line as
// "<channel> · <sha>" (e.g. "main · dcd7b80"). Deliberately fast: it runs on
// every shell launch, so it never touches the network or `pacman -Sl`. A
// checkout reads git, a packaged box parses the local pacman version. Any
// unknown piece degrades gracefully rather than erroring.
func cmdVersion(args []string) error {
	branch := false
	for _, a := range args {
		if a == "--branch" {
			branch = true
		}
	}
	base, sha := versionParts()

	if branch {
		ch := ryokuChannel()
		if sha != "" {
			fmt.Printf("%s · %s\n", ch, sha)
		} else {
			fmt.Println(ch)
		}
		return nil
	}

	if base == "" {
		base = "dev"
		fmt.Println(base)
		return nil
	}
	fmt.Printf("v%s\n", base)
	return nil
}

// versionParts returns (base semver, short sha) for the running Ryoku. On a
// checkout: the VERSION file + git HEAD. On a packaged install: parsed from the
// pacman version "<core>.r<count>.g<sha>-<rel>" the repo build embeds (the
// r<count> token is skipped). Any field comes back "" when undeterminable.
func versionParts() (base, sha string) {
	if repo := resolveRepo(); repo != "" {
		if b, err := os.ReadFile(filepath.Join(repo, "VERSION")); err == nil {
			base = strings.TrimSpace(string(b))
		}
		if out, err := runOut("git", "-C", repo, "rev-parse", "--short=7", "HEAD"); err == nil {
			sha = strings.TrimSpace(out)
		}
		return base, sha
	}

	// packaged: split off the pkgrel, then read the g<sha> token the PKGBUILD
	// pkgver appends; the leading dot-parts before r<count>/g<sha> are the core.
	ver := strings.SplitN(installedVersion(), "-", 2)[0]
	var core []string
	seen := false
	for _, tok := range strings.Split(ver, ".") {
		switch {
		case len(tok) >= 2 && tok[0] == 'r' && isDigits(tok[1:]):
			seen = true
		case len(tok) >= 8 && tok[0] == 'g' && isHex(tok[1:]):
			sha = tok[1:]
			seen = true
		default:
			if !seen {
				core = append(core, tok)
			}
		}
	}
	return strings.Join(core, "."), sha
}

func isDigits(s string) bool {
	for _, c := range s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return s != ""
}
