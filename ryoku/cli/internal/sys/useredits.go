package sys

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// The fork ledger records, per path the user has forked (taken over a whole base
// file), the base hash at the moment they took it over. materialize writes it;
// doctor reads it to report an upstream fix that has since landed on a file the
// user now owns. Lines are "rel<TAB>basehash", beside the materialize manifest
// under ~/.local/state/ryoku.
func ForkLedgerPath() string { return filepath.Join(StateDir(), "user-edits-forks") }

func ReadForkLedger() map[string]string {
	m := map[string]string{}
	b, err := os.ReadFile(ForkLedgerPath())
	if err != nil {
		return m
	}
	for _, line := range strings.Split(string(b), "\n") {
		if line = strings.TrimSpace(line); line == "" {
			continue
		}
		if i := strings.IndexByte(line, '\t'); i > 0 {
			m[line[:i]] = line[i+1:]
		}
	}
	return m
}

func WriteForkLedger(m map[string]string) error {
	path := ForkLedgerPath()
	if len(m) == 0 {
		_ = os.Remove(path)
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	rels := make([]string, 0, len(m))
	for rel := range m {
		rels = append(rels, rel)
	}
	sort.Strings(rels)
	var b strings.Builder
	for _, rel := range rels {
		fmt.Fprintf(&b, "%s\t%s\n", rel, m[rel])
	}
	return os.WriteFile(path, []byte(b.String()), 0o644)
}
