package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

type pluginIndexRow struct {
	ID      string `json:"id"`
	Version string `json:"version"`
	View    string `json:"view"`
}

func pluginIndexPath() string {
	return filepath.Join(storeStateDir(), "plugins.json")
}

func rebuildPluginIndex() ([]pluginIndexRow, error) {
	unlock, err := lockTree(storeTransactionLockPath())
	if err != nil {
		return nil, err
	}
	defer unlock()
	if err := recoverStoreTransactions(); err != nil {
		return nil, err
	}
	return rebuildPluginIndexLocked()
}

func writePluginIndexLocked() error {
	_, err := rebuildPluginIndexLocked()
	return err
}

func rebuildPluginIndexLocked() ([]pluginIndexRow, error) {
	receiptDir := filepath.Join(storeStateDir(), "plugins")
	entries, err := os.ReadDir(receiptDir)
	if os.IsNotExist(err) {
		entries = nil
	} else if err != nil {
		return nil, err
	}
	rows := make([]pluginIndexRow, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".json" {
			continue
		}
		id := strings.TrimSuffix(entry.Name(), ".json")
		if !productIDPattern.MatchString(id) {
			return nil, fmt.Errorf("invalid plugin receipt name %q", entry.Name())
		}
		receipt, err := readReceipt("plugins", id)
		if err != nil {
			return nil, err
		}
		destination, _, err := productDestination("plugins", id)
		if err != nil {
			return nil, err
		}
		if !receiptOwnsFile(receipt, "manifest.json") {
			return nil, fmt.Errorf("plugins/%s: receipt does not own manifest.json", id)
		}
		if err := verifyInstalledReceipt(destination, receipt); err != nil {
			return nil, fmt.Errorf("plugins/%s: %w", id, err)
		}
		row := pluginIndexRow{ID: id, Version: receipt.Version}
		row.View = pluginView(row, receipt)
		if err := ensurePluginView(row, receipt); err != nil {
			return nil, err
		}
		rows = append(rows, row)
	}
	raw, err := json.Marshal(rows)
	if err != nil {
		return nil, err
	}
	if err := atomicWrite(pluginIndexPath(), append(raw, '\n'), 0o600); err != nil {
		return nil, err
	}
	return rows, nil
}

// Every receipt-owned file contributes to the view identity. QML resolves
// relative imports without inheriting an entry-point query string, so only a
// content-specific directory URL invalidates the complete dependency graph.
func pluginView(row pluginIndexRow, receipt Receipt) string {
	digest := sha256.New()
	_, _ = digest.Write([]byte(row.ID))
	_, _ = digest.Write([]byte{0})
	_, _ = digest.Write([]byte(receipt.Version))
	for _, file := range receipt.Files {
		_, _ = digest.Write([]byte{0})
		_, _ = digest.Write([]byte(file.Destination))
		_, _ = digest.Write([]byte{0})
		_, _ = digest.Write([]byte(file.SHA256))
	}
	return filepath.ToSlash(filepath.Join("plugin-views", row.ID, fmt.Sprintf("%x", digest.Sum(nil))))
}

func ensurePluginView(row pluginIndexRow, receipt Receipt) error {
	destination, _, err := productDestination("plugins", row.ID)
	if err != nil {
		return err
	}
	if row.View != pluginView(row, receipt) {
		return fmt.Errorf("plugins/%s changed while rebuilding its view", row.ID)
	}
	view := filepath.Join(storeStateDir(), filepath.FromSlash(row.View))
	viewExists := false
	if _, err := os.Lstat(view); err == nil {
		viewExists = true
		if validatePluginView(view, receipt) == nil {
			return nil
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(view), 0o700); err != nil {
		return err
	}
	temporary := view + ".tmp"
	backup := view + ".old"
	if err := os.RemoveAll(temporary); err != nil {
		return err
	}
	if err := os.RemoveAll(backup); err != nil {
		return err
	}
	if err := os.MkdirAll(temporary, 0o700); err != nil {
		return err
	}
	defer os.RemoveAll(temporary)
	for _, file := range receipt.Files {
		source := filepath.Join(destination, filepath.FromSlash(file.Destination))
		target := filepath.Join(temporary, filepath.FromSlash(file.Destination))
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return err
		}
		mode := os.FileMode(0o644)
		if file.Mode == "0755" {
			mode = 0o755
		}
		if err := copyPluginViewFile(source, target, mode); err != nil {
			return err
		}
	}
	if err := validatePluginView(temporary, receipt); err != nil {
		return err
	}
	if viewExists {
		if err := os.Rename(view, backup); err != nil {
			return err
		}
		defer os.Rename(backup, view)
	}
	if err := os.Rename(temporary, view); err != nil {
		return err
	}
	return os.RemoveAll(backup)
}

func validatePluginView(view string, receipt Receipt) error {
	info, err := os.Lstat(view)
	if err != nil {
		return err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("plugin view is not a directory: %s", view)
	}
	for _, file := range receipt.Files {
		path := filepath.Join(view, filepath.FromSlash(file.Destination))
		info, err := os.Lstat(path)
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("plugin view file is not regular: %s", path)
		}
		raw, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if err := validateProductPayload(raw, file.Size, file.SHA256); err != nil {
			return fmt.Errorf("%s: %w", path, err)
		}
	}
	return nil
}

func copyPluginViewFile(source, target string, mode os.FileMode) error {
	input, err := os.Open(source)
	if err != nil {
		return err
	}
	defer input.Close()
	output, err := os.OpenFile(target, os.O_CREATE|os.O_EXCL|os.O_WRONLY, mode)
	if err != nil {
		return err
	}
	_, copyErr := io.Copy(output, input)
	closeErr := output.Close()
	if copyErr != nil {
		return copyErr
	}
	return closeErr
}
