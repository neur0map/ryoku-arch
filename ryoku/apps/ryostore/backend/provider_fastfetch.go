package main

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"path/filepath"
)

const fastfetchConfig = "config.jsonc"

type fastfetchProvider struct {
	cache      *Cache
	configPath string
}

func newFastfetchProvider(cache *Cache) fastfetchProvider {
	return fastfetchProvider{
		cache:      cache,
		configPath: filepath.Join(configHome(), "fastfetch", fastfetchConfig),
	}
}

func (fastfetchProvider) Category() Category {
	return Category{
		ID:          "fastfetch",
		Name:        "Fastfetch",
		Group:       "wear",
		Description: "Install terminal readout styles, then apply one explicitly in Ryoku Settings.",
	}
}

func (p fastfetchProvider) Load(ctx context.Context, refresh bool) ([]Item, SourceState, error) {
	entries, state, err := loadProductRegistry(ctx, p.cache, "fastfetch", refresh)
	if err != nil {
		return nil, state, err
	}
	current, currentErr := os.ReadFile(p.configPath)
	if currentErr != nil && !os.IsNotExist(currentErr) {
		return nil, state, currentErr
	}
	items := make([]Item, 0, len(entries))
	for _, entry := range entries {
		item, err := productEntryItem(p.cache.base, "fastfetch", entry)
		if err != nil {
			return nil, state, err
		}
		if item.Installed && currentErr == nil {
			active, err := fastfetchStyleMatchesCurrent(entry.ID, current)
			if err != nil {
				return nil, state, err
			}
			item.Active = active
		}
		items = append(items, item)
	}
	return items, state, nil
}

func (p fastfetchProvider) Install(ctx context.Context, id string) error {
	entries, _, err := loadProductRegistry(ctx, p.cache, "fastfetch", false)
	if err != nil {
		return err
	}
	entry, err := findProductEntry(entries, id)
	if err != nil {
		return err
	}
	return installProduct(ctx, p.cache, "fastfetch", entry)
}

func fastfetchStyleMatchesCurrent(id string, current []byte) (bool, error) {
	dst, _, err := productDestination("fastfetch", id)
	if err != nil {
		return false, err
	}
	receipt, err := readReceipt("fastfetch", id)
	if err != nil {
		return false, err
	}
	if !receiptOwnsFile(receipt, fastfetchConfig) {
		return false, fmt.Errorf("fastfetch/%s: receipt does not own %s", id, fastfetchConfig)
	}
	if err := verifyInstalledReceipt(dst, receipt); err != nil {
		return false, err
	}
	installed, err := os.ReadFile(filepath.Join(dst, fastfetchConfig))
	if err != nil {
		return false, err
	}
	return bytes.Equal(current, installed), nil
}

func applyFastfetchStyle(id string) error {
	if !productIDPattern.MatchString(id) {
		return fmt.Errorf("invalid fastfetch product id %q", id)
	}
	dst, expectedDestination, err := productDestination("fastfetch", id)
	if err != nil {
		return err
	}
	receipt, err := readReceipt("fastfetch", id)
	if err != nil {
		return fmt.Errorf("fastfetch/%s is not installed: %w", id, err)
	}
	if receipt.Destination != expectedDestination {
		return fmt.Errorf("fastfetch/%s: receipt destination mismatch", id)
	}
	if !receiptOwnsFile(receipt, fastfetchConfig) {
		return fmt.Errorf("fastfetch/%s: receipt does not own %s", id, fastfetchConfig)
	}
	if err := verifyInstalledReceipt(dst, receipt); err != nil {
		return err
	}
	raw, err := os.ReadFile(filepath.Join(dst, fastfetchConfig))
	if err != nil {
		return err
	}
	return atomicWrite(filepath.Join(configHome(), "fastfetch", fastfetchConfig), raw, 0o644)
}
