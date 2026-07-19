package updater

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"strings"
)

// Reset drops user overrides from ~/.config/ryoku/user_edits so a customization
// returns to the Ryoku-shipped default. With paths it resets exactly those
// (relative to ~/.config, e.g. hypr/modules/binds.lua); with none it clears the
// whole overlay after a confirm (-y skips it). It touches only overlay files, not
// the Hub's stores.
//
// On a packaged box the live copy is removed and the base re-laid, so a base file
// is re-copied, a seed re-seeds, and an additive overlay (no base default) simply
// stays gone. On a dev checkout there is no base tree to re-lay from, so the
// override is dropped and `ryoku deploy` re-composes live from the repo.
func Reset(args []string) error {
	yes := false
	var paths []string
	for _, a := range args {
		if a == "-y" || a == "--yes" {
			yes = true
			continue
		}
		paths = append(paths, a)
	}

	edits := sys.UserEditsDir()
	if _, err := os.Stat(edits); err != nil {
		fmt.Println("no user edits to reset")
		return nil
	}

	var targets []string
	if len(paths) == 0 {
		if !yes && !confirmReset(fmt.Sprintf("Reset ALL user edits under %s to Ryoku defaults?", edits)) {
			fmt.Println("cancelled")
			return nil
		}
		rels, err := walkRelFiles(edits)
		if err != nil {
			return err
		}
		targets = rels
	} else {
		for _, p := range paths {
			targets = append(targets, filepath.ToSlash(strings.TrimPrefix(p, "./")))
		}
	}

	baseOK := false
	if info, err := os.Stat(sys.BaseConfigDir()); err == nil && info.IsDir() {
		baseOK = true
	}

	ledger := sys.ReadForkLedger()
	removed := 0
	for _, rel := range targets {
		p := filepath.Join(edits, rel)
		if !sys.Exists(p) {
			fmt.Printf("  not overridden: %s\n", rel)
			continue
		}
		if err := os.Remove(p); err != nil {
			return fmt.Errorf("reset %s: %w", rel, err)
		}
		pruneEmptyParents(edits, filepath.Dir(rel))
		// on a packaged box, clear the live copy so the re-materialize restores the
		// shipped default; on dev, leave it for `ryoku deploy` to re-lay.
		if baseOK {
			_ = os.Remove(filepath.Join(sys.ConfigHome(), rel))
		}
		delete(ledger, rel)
		removed++
		fmt.Printf("  reset %s\n", rel)
	}
	_ = sys.WriteForkLedger(ledger)
	if removed == 0 {
		return nil
	}

	if baseOK {
		return Materialize()
	}
	fmt.Println("run `ryoku deploy` (dev) or `ryoku materialize` to re-lay the base")
	return nil
}

func confirmReset(prompt string) bool {
	fmt.Printf("%s [y/N] ", prompt)
	line, _ := bufio.NewReader(os.Stdin).ReadString('\n')
	line = strings.TrimSpace(strings.ToLower(line))
	return line == "y" || line == "yes"
}
