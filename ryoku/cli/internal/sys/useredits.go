package sys

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// UserEditFiles lists the layable files in the overlay: regular files under
// UserEditsDir, slash-relative and sorted, skipping symlinks, .md notes (the
// guide and anything a user keeps beside their edits), and the overlay's own
// nested path. The overlay lays these over ~/.config; doctor reads the same set
// to spot forks; reset walks it to clear everything. Absent overlay -> no files.
func UserEditFiles() ([]string, error) {
	root := UserEditsDir()
	if _, err := os.Stat(root); err != nil {
		return nil, nil
	}
	var rels []string
	err := filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || d.Type()&os.ModeSymlink != 0 || strings.HasSuffix(d.Name(), ".md") {
			return nil
		}
		rel, err := filepath.Rel(root, p)
		if err != nil {
			return err
		}
		rel = filepath.ToSlash(rel)
		if strings.HasPrefix(rel, "ryoku/user_edits/") {
			return nil // never mirror the overlay tree into itself
		}
		rels = append(rels, rel)
		return nil
	})
	sort.Strings(rels)
	return rels, err
}
