// The lockscreen provider adapts the canonical ryoku-extras registry into the
// Store contract. The built-in clockwork/orbital fallback never enters this
// catalogue; only receipt-owned optional themes can be installed or removed.
package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type lockProvider struct {
	cache    *Cache
	prefPath string
}

func newLockProvider(cache *Cache) lockProvider {
	if cache == nil {
		cache = newCache()
	}
	return lockProvider{
		cache:    cache,
		prefPath: filepath.Join(configHome(), "qylock", "theme"),
	}
}

func (lockProvider) Category() Category {
	return Category{
		ID:          "lockscreens",
		Name:        "Lockscreens",
		Group:       "wear",
		Description: "Complete qylock scenes for the session lock and sign-in screen.",
	}
}

func (p lockProvider) Load(ctx context.Context, refresh bool) ([]Item, SourceState, error) {
	if err := adoptLegacyTape(); err != nil {
		return nil, SourceState{}, fmt.Errorf("lockscreens: adopt legacy Tape: %w", err)
	}
	entries, state, err := loadProductRegistry(ctx, p.cache, "lockscreens", refresh)
	if err != nil {
		return nil, state, err
	}
	activeBytes, _ := os.ReadFile(p.prefPath)
	active := strings.TrimSpace(string(activeBytes))
	items := make([]Item, 0, len(entries))
	for _, entry := range entries {
		item, err := productEntryItem(p.cache.base, "lockscreens", entry)
		if err != nil {
			return nil, state, fmt.Errorf("lockscreens/%s: installed state: %w", entry.ID, err)
		}
		item.Active = entry.ID == active
		items = append(items, item)
	}
	sort.SliceStable(items, func(i, j int) bool {
		if items[i].Active != items[j].Active {
			return items[i].Active
		}
		if items[i].Installed != items[j].Installed {
			return items[i].Installed
		}
		return items[i].Name < items[j].Name
	})
	return items, state, nil
}

func (p lockProvider) Install(ctx context.Context, id string) error {
	entries, _, err := loadProductRegistry(ctx, p.cache, "lockscreens", false)
	if err != nil {
		return err
	}
	entry, err := findProductEntry(entries, id)
	if err != nil {
		return err
	}
	return installProduct(ctx, p.cache, "lockscreens", entry)
}

func (lockProvider) Remove(ctx context.Context, id string) error {
	if id == "clockwork-orbital" {
		return fmt.Errorf("the core lockscreen fallback is not removable")
	}
	return removeProduct(ctx, "lockscreens", id)
}
