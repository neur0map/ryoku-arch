package main

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

var legacyTapeReceipt = Receipt{
	Category:    "lockscreens",
	ID:          "clockwork-tape",
	Version:     "1.0.0",
	Destination: "qylock/themes/clockwork-tape",
	Files: []ReceiptFile{
		{Source: "LICENSE", Destination: "LICENSE", SHA256: "3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986", Mode: "0644", Size: 35149},
		{Source: "PROVENANCE.txt", Destination: "PROVENANCE.txt", SHA256: "4675deccea61a8fa5ea16fd345ee09ba379cd1d0acaff3befa8bc595707bb094", Mode: "0644", Size: 369},
		{Source: "content/Main.qml", Destination: "Main.qml", SHA256: "106fee628bb634e2b7ee87a4851532a42cbe635ae745d385fc5296e9098dc015", Mode: "0644", Size: 24355},
		{Source: "content/font/Outfit-Black.ttf", Destination: "font/Outfit-Black.ttf", SHA256: "f240e6128c31a75aa3f456ea1ff3b0fda382176681788ae3d244d08e3fa7d6cd", Mode: "0644", Size: 55372},
		{Source: "content/metadata.desktop", Destination: "metadata.desktop", SHA256: "37615671bab45ab45979cc9938c0bb8892f58760bd865a5286f58c342dacdf97", Mode: "0644", Size: 155},
		{Source: "content/theme.conf", Destination: "theme.conf", SHA256: "002c24b024b3e0788052f178acd7c6cec25f08e2486b4bfb123c7c8b1b8a4475", Mode: "0644", Size: 62},
	},
}

// adoptLegacyTape turns the one payload formerly shipped by install-qylock into
// receipt-owned Store state. The installer moves only the exact known tree; this
// second exact comparison prevents arbitrary local themes from being adopted.
func adoptLegacyTape() error {
	dst, _, err := productDestination("lockscreens", "clockwork-tape")
	if err != nil {
		return err
	}
	return adoptExactReceipt(dst, legacyTapeReceipt)
}

func adoptExactReceipt(dst string, receipt Receipt) error {
	if err := validateReceipt(receipt.Category, receipt.ID, receipt); err != nil {
		return err
	}
	if _, err := readReceipt(receipt.Category, receipt.ID); err == nil {
		return nil
	} else if !os.IsNotExist(err) {
		return err
	}
	root := productDestinationRoot(receipt.Category)
	relative := filepath.FromSlash(receipt.Destination)
	if err := rejectSymlinkPath(root, relative); err != nil {
		return err
	}

	unlockGlobal, err := lockTree(storeTransactionLockPath())
	if err != nil {
		return err
	}
	defer unlockGlobal()
	if err := rejectSymlinkPath(root, relative); err != nil {
		return err
	}
	unlockProduct, err := lockTree(dst)
	if err != nil {
		return err
	}
	defer unlockProduct()

	if _, err := readReceipt(receipt.Category, receipt.ID); err == nil {
		return nil
	} else if !os.IsNotExist(err) {
		return err
	}
	matches, err := destinationMatchesReceipt(dst, receipt)
	if err != nil || !matches {
		return err
	}
	return writeReceipt(receipt)
}

func destinationMatchesReceipt(dst string, receipt Receipt) (bool, error) {
	if err := validateReceipt(receipt.Category, receipt.ID, receipt); err != nil {
		return false, err
	}
	info, err := os.Lstat(dst)
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return false, nil
	}

	expected := make(map[string]ReceiptFile, len(receipt.Files))
	for _, file := range receipt.Files {
		expected[file.Destination] = file
	}
	mismatch := false
	err = filepath.WalkDir(dst, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if path == dst || entry.IsDir() {
			return nil
		}
		if entry.Type()&os.ModeSymlink != 0 || !entry.Type().IsRegular() {
			mismatch = true
			return fs.SkipAll
		}
		relative, err := filepath.Rel(dst, path)
		if err != nil {
			return err
		}
		relative = filepath.ToSlash(relative)
		file, ok := expected[relative]
		if !ok {
			mismatch = true
			return fs.SkipAll
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if fmt.Sprintf("%04o", info.Mode().Perm()) != file.Mode {
			mismatch = true
			return fs.SkipAll
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if err := validateProductPayload(data, file.Size, file.SHA256); err != nil {
			mismatch = true
			return fs.SkipAll
		}
		delete(expected, relative)
		return nil
	})
	return err == nil && !mismatch && len(expected) == 0, err
}
