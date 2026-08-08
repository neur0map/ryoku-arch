// The bundles provider adapts the ryoku-extras bundle registry into the store
// contract. Browsing fetches bundles/registry.json only: each entry carries its
// inline components (type, name, detect, tier, interactive, summary), so no
// per-bundle definition or installer is fetched to render the catalogue.
// Installed state is joined from `ryoku-extras-install status`, which reads the
// same inline components. Install launches the actuator in a floating terminal,
// which fetches the selected bundle's full definition on demand and owns the
// privileged package work; Settings owns installed bundle status and removal.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"syscall"
)

type registryEntry struct {
	ID          string            `json:"id"`
	Name        string            `json:"name"`
	Description string            `json:"description"`
	Tagline     string            `json:"tagline,omitempty"`
	Sources     string            `json:"sources,omitempty"`
	Icon        string            `json:"icon,omitempty"`
	Accent      string            `json:"accent,omitempty"`
	Preview     string            `json:"preview,omitempty"`
	Screenshots []string          `json:"screenshots,omitempty"`
	Path        string            `json:"path"`
	Components  []bundleComponent `json:"components"`
}

type registry struct {
	Version int             `json:"version"`
	Bundles []registryEntry `json:"bundles"`
}

// bundleComponent is one item as carried inline in the registry: enough to
// render the catalogue and detect installed state without fetching bundle.json.
type bundleComponent struct {
	Type        string `json:"type"`
	Name        string `json:"name"`
	Detect      string `json:"detect,omitempty"`
	Tier        string `json:"tier,omitempty"`
	Interactive bool   `json:"interactive,omitempty"`
	Summary     string `json:"summary,omitempty"`
}

type bundleProvider struct {
	cache  *Cache
	status func(context.Context) map[string]map[string]bool
	launch func(id string, only []string) error
}

func (bundleProvider) Category() Category {
	return Category{
		ID:          "bundles",
		Name:        "Bundles",
		Group:       "EXTEND",
		Description: "Curated sets of packages, scripts, and guests installed together.",
	}
}

func (p bundleProvider) Load(ctx context.Context, refresh bool) ([]Item, SourceState, error) {
	raw, state, err := p.cache.Fetch(ctx, "bundles/registry.json", refresh)
	if err != nil {
		return nil, state, err
	}
	var reg registry
	if err := json.Unmarshal(raw, &reg); err != nil {
		return nil, state, fmt.Errorf("bundles/registry.json: %w", err)
	}

	type built struct {
		item  Item
		items []bundleComponent
	}
	out := make([]built, 0, len(reg.Bundles))
	for _, e := range reg.Bundles {
		if !validComponent(e.ID) {
			return nil, state, fmt.Errorf("bundle has invalid id %q", e.ID)
		}
		path := e.Path
		if path == "" {
			path = "bundles/" + e.ID
		}
		if !validLocalPath(path) {
			return nil, state, fmt.Errorf("bundle %q has invalid path %q", e.ID, path)
		}
		if len(e.Components) == 0 {
			return nil, state, fmt.Errorf("bundle %q has no components", e.ID)
		}

		md := map[string]any{}
		if e.Sources != "" {
			md["sources"] = e.Sources
		}
		if e.Icon != "" {
			md["icon"] = e.Icon
		}
		if e.Accent != "" {
			md["accent"] = e.Accent
		}
		comps := make([]map[string]any, len(e.Components))
		for i, c := range e.Components {
			comp := map[string]any{"type": c.Type, "name": c.Name}
			if c.Summary != "" {
				comp["summary"] = c.Summary
			}
			if c.Tier != "" {
				comp["tier"] = c.Tier
			}
			comps[i] = comp
		}
		md["items"] = comps

		out = append(out, built{
			item: Item{
				ID:          e.ID,
				Category:    "bundles",
				Name:        e.Name,
				Summary:     e.Tagline,
				Description: e.Description,
				Art:         resolveAsset(extrasBase(), path, e.Preview),
				Screenshots: resolveAssets(extrasBase(), path, e.Screenshots),
				TotalCount:  len(e.Components),
				Metadata:    md,
			},
			items: e.Components,
		})
	}

	// join installed state; the actuator reads the same inline components from
	// the cached registry. A missing or failed status source degrades to nothing
	// installed rather than an error.
	var status map[string]map[string]bool
	if p.status != nil {
		status = p.status(ctx)
	}
	items := make([]Item, len(out))
	for i, b := range out {
		it := b.item
		present := status[it.ID]
		components, _ := it.Metadata["items"].([]map[string]any)
		for j, comp := range b.items {
			installed := present[comp.Name]
			if installed {
				it.InstalledCount++
			}
			if j < len(components) {
				components[j]["installed"] = installed
			}
		}
		it.Installed = it.TotalCount > 0 && it.InstalledCount == it.TotalCount
		items[i] = it
	}
	return items, state, nil
}

func (p bundleProvider) Install(ctx context.Context, id string) error {
	return p.launch(id, nil)
}

// InstallComponents installs only the named components (the store's manual
// selection); an empty list falls back to the whole-bundle install.
func (p bundleProvider) InstallComponents(ctx context.Context, id string, only []string) error {
	return p.launch(id, only)
}

// defaultBundleStatus queries the actuator for every bundle's item state and
// indexes it by bundle id then item name. Any failure yields no status rather
// than an error, so a broken actuator cannot blank the catalogue.
func defaultBundleStatus(ctx context.Context) map[string]map[string]bool {
	out, err := exec.CommandContext(ctx, "ryoku-extras-install", "status").Output()
	if err != nil {
		return nil
	}
	var parsed struct {
		Bundles []struct {
			ID    string `json:"id"`
			Items []struct {
				Name   string `json:"name"`
				Status string `json:"status"`
			} `json:"items"`
		} `json:"bundles"`
	}
	if json.Unmarshal(out, &parsed) != nil {
		return nil
	}
	m := make(map[string]map[string]bool, len(parsed.Bundles))
	for _, b := range parsed.Bundles {
		present := make(map[string]bool, len(b.Items))
		for _, it := range b.Items {
			present[it.Name] = it.Status == "present"
		}
		m[b.ID] = present
	}
	return m
}

// launchBundleInstall runs the actuator's bundle install in a floating kitty
// terminal, detached into its own session so it owns the sudo prompt and
// long-running output independently of this short-lived process.
func launchBundleInstall(id string, only []string) error {
	args := []string{"--class", "ryoku-extras", "-e", "ryoku-extras-install", "install", "bundle", id}
	if len(only) > 0 {
		args = append(args, "--only", strings.Join(only, ","))
	}
	cmd := exec.Command("kitty", args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		return err
	}
	return cmd.Process.Release()
}
