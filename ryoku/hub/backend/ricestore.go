package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// the ryoku-extras rice store: browse a catalogue, install a rice locally, and
// publish a local rice into the store structure ready to commit. reuses
// extras.go's fetch / fetchOrCache and lockcatalog.go's downloadFile, so the
// rice store shares the extras store's offline-cache and CDN-busting behaviour.

// riceStoreEntry mirrors one entry in ryoku-extras/rices/registry.json. text
// (manifest, poster, palette, screenshots) is raw in-repo; the wallpaper and
// hero binaries are GitHub Release assets referenced by absolute URL, matching
// how livewalls ships its videos.
type riceStoreEntry struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Author      string   `json:"author,omitempty"`
	Blurb       string   `json:"blurb,omitempty"`
	Tags        []string `json:"tags,omitempty"`
	CreatedWith string   `json:"createdWith,omitempty"`
	Color       string   `json:"color,omitempty"`
	Manifest    string   `json:"manifest,omitempty"`
	Poster      string   `json:"poster,omitempty"`
	Screenshots []string `json:"screenshots,omitempty"`
	Palette     string   `json:"palette,omitempty"`
	Wallpaper   string   `json:"wallpaper,omitempty"`
	Hero        string   `json:"hero,omitempty"`
}

type riceRegistry struct {
	Version int              `json:"version"`
	Rices   []riceStoreEntry `json:"rices"`
}

// riceCatalogItem is a store entry annotated for the Hub: absolute asset URLs,
// compatibility vs the running Ryoku, and whether it is already installed.
type riceCatalogItem struct {
	riceStoreEntry
	PosterURL string   `json:"posterUrl,omitempty"`
	ShotURLs  []string `json:"shotUrls,omitempty"`
	Compat    string   `json:"compat"`
	Installed bool     `json:"installed"`
}

func parseRiceRegistry(raw []byte) ([]riceStoreEntry, error) {
	var reg riceRegistry
	if err := json.Unmarshal(raw, &reg); err != nil {
		return nil, err
	}
	return reg.Rices, nil
}

// rawURL turns an in-repo path into an absolute raw URL; an already-absolute
// URL (a Release asset) passes through.
func rawURL(rel string) string {
	if rel == "" {
		return ""
	}
	if strings.HasPrefix(rel, "http://") || strings.HasPrefix(rel, "https://") {
		return rel
	}
	return extrasBase() + "/" + strings.TrimLeft(rel, "/")
}

func catalogRices() ([]riceCatalogItem, error) {
	raw, err := fetchOrCache("rices/registry.json")
	if err != nil {
		return nil, err
	}
	entries, err := parseRiceRegistry(raw)
	if err != nil {
		return nil, err
	}
	out := []riceCatalogItem{}
	for _, e := range entries {
		item := riceCatalogItem{
			riceStoreEntry: e,
			PosterURL:      rawURL(e.Poster),
			Compat:         riceCompat(e.CreatedWith),
			Installed:      isFile(ricePath(e.ID)),
		}
		for _, s := range e.Screenshots {
			item.ShotURLs = append(item.ShotURLs, rawURL(s))
		}
		out = append(out, item)
	}
	return out, nil
}

// installRice downloads a store rice (manifest + palette + wallpaper + hero)
// into ~/.config/ryoku/rices/<id>/, ready to apply or fork. install and apply
// are separate so a rice can be previewed and forked before it changes anything.
func installRice(id string) error {
	if !validRiceSlug(id) {
		return fmt.Errorf("bad rice id %q", id)
	}
	raw, err := fetchOrCache("rices/registry.json")
	if err != nil {
		return err
	}
	entries, err := parseRiceRegistry(raw)
	if err != nil {
		return err
	}
	var e *riceStoreEntry
	for i := range entries {
		if entries[i].ID == id {
			e = &entries[i]
			break
		}
	}
	if e == nil {
		return fmt.Errorf("rice %q is not in the store", id)
	}

	dir := filepath.Join(ricesDir(), id)
	manifestRel := e.Manifest
	if manifestRel == "" {
		manifestRel = "rices/" + id + "/rice.json"
	}
	mb, err := fetch(rawURL(manifestRel))
	if err != nil {
		return fmt.Errorf("fetch manifest: %w", err)
	}
	var r Rice
	if err := json.Unmarshal(mb, &r); err != nil {
		return fmt.Errorf("parse manifest: %w", err)
	}
	r.Slug = id
	if err := saveRice(r); err != nil {
		return err
	}
	if e.Palette != "" {
		if pb, err := fetch(rawURL(e.Palette)); err == nil {
			_ = atomicWrite(filepath.Join(dir, "palette.json"), pb, 0o644)
		}
	}
	if e.Wallpaper != "" && r.Assets.Wallpaper != "" {
		_ = downloadFile(rawURL(e.Wallpaper), filepath.Join(dir, r.Assets.Wallpaper))
	}
	if e.Hero != "" && r.Assets.Hero != "" {
		_ = downloadFile(rawURL(e.Hero), filepath.Join(dir, r.Assets.Hero))
	}
	return nil
}

func extrasReleaseURL(asset string) string {
	return "https://github.com/neur0map/ryoku-extras/releases/download/rices/" + asset
}

// publishRice lays a local rice into a ryoku-extras checkout's store structure
// and upserts its registry entry, leaving only the Release-asset upload and the
// git commit to the author. this is the "extract configs, commit to extras"
// path: everything mechanical is done, the human just reviews and pushes.
func publishRice(slug, storeDir string) error {
	if !validRiceSlug(slug) {
		return fmt.Errorf("bad rice slug %q", slug)
	}
	r, dir, err := loadRice(slug)
	if err != nil {
		return err
	}
	riceOut := filepath.Join(storeDir, "rices", slug)
	if err := os.MkdirAll(riceOut, 0o755); err != nil {
		return err
	}
	if err := atomicWrite(filepath.Join(riceOut, "rice.json"), mustJSON(r), 0o644); err != nil {
		return err
	}

	poster := ""
	if src := filepath.Join(dir, "preview.png"); isFile(src) {
		if copyFile(src, filepath.Join(riceOut, "poster.png")) == nil {
			poster = "rices/" + slug + "/poster.png"
		}
	}
	palette := ""
	if src := filepath.Join(dir, "palette.json"); isFile(src) {
		if copyFile(src, filepath.Join(riceOut, "palette.json")) == nil {
			palette = "rices/" + slug + "/palette.json"
		}
	}

	regPath := filepath.Join(storeDir, "rices", "registry.json")
	reg := riceRegistry{Version: 1}
	if b, err := os.ReadFile(regPath); err == nil {
		_ = json.Unmarshal(b, &reg)
	}
	entry := riceStoreEntry{
		ID: slug, Name: r.Name, Author: r.Author, Blurb: r.Blurb, Tags: r.Tags,
		CreatedWith: r.CreatedWith, Color: r.Color.Mode,
		Manifest: "rices/" + slug + "/rice.json",
		Poster:   poster, Palette: palette,
	}
	if r.Assets.Wallpaper != "" {
		entry.Wallpaper = extrasReleaseURL(slug + "-" + r.Assets.Wallpaper)
	}
	if r.Assets.Hero != "" {
		entry.Hero = extrasReleaseURL(slug + "-" + r.Assets.Hero)
	}
	replaced := false
	for i := range reg.Rices {
		if reg.Rices[i].ID == slug {
			reg.Rices[i] = entry
			replaced = true
			break
		}
	}
	if !replaced {
		reg.Rices = append(reg.Rices, entry)
	}
	if err := atomicWrite(regPath, mustJSON(reg), 0o644); err != nil {
		return err
	}

	fmt.Printf("published %q to %s\n", slug, riceOut)
	if r.Assets.Wallpaper != "" || r.Assets.Hero != "" {
		fmt.Println("upload as Release assets under the 'rices' tag:")
		if r.Assets.Wallpaper != "" {
			fmt.Printf("  %s  (from %s)\n", slug+"-"+r.Assets.Wallpaper, filepath.Join(dir, r.Assets.Wallpaper))
		}
		if r.Assets.Hero != "" {
			fmt.Printf("  %s  (from %s)\n", slug+"-"+r.Assets.Hero, filepath.Join(dir, r.Assets.Hero))
		}
	}
	fmt.Printf("then add screenshots under rices/%s/screenshots/ and git commit in the store.\n", slug)
	return nil
}
