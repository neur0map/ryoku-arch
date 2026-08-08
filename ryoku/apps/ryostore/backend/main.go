// ryostore is the Go data plane for the Ryostore app: it normalizes every
// product catalogue into one JSON contract and installs items without
// activating them. The Quickshell front end shells out to these subcommands.
//
//	ryostore catalog [--refresh] [--category <id>]   normalized catalogue, JSON
//	ryostore install <category> <id>                 install-only, no activation
//	ryostore remove <category> <id>                  receipt-owned removal
//
// A full catalog answers from a disk snapshot so every launch after the first is
// instant; --refresh rebuilds it live. --category always probes live.
//
// The internal namespace holds calls the extras actuator and Settings make
// directly; later tasks register those subcommands under it.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	if err := dispatch(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "ryostore:", err)
		os.Exit(1)
	}
}

// dispatch routes one command. It returns an error for every bad invocation so
// the caller reports one useful line and exits nonzero.
func dispatch(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("no command; expected catalog, install, remove, open, settings, or internal")
	}
	switch args[0] {
	case "catalog":
		return runCatalog(os.Stdout, providers(), args[1:])
	case "install":
		return runInstall(providers(), args[1:])
	case "remove":
		return runRemove(providers(), args[1:])
	case "open":
		return runOpen(args[1:])
	case "settings":
		return runSettings(args[1:])
	case "internal":
		return runInternal(args[1:])
	default:
		return fmt.Errorf("unknown command %q; expected catalog, install, remove, open, settings, or internal", args[0])
	}
}

func runCatalog(w io.Writer, provs []Provider, args []string) error {
	refresh := false
	category := ""
	haveCategory := false
	rest := args
	for len(rest) > 0 {
		switch rest[0] {
		case "--refresh":
			refresh = true
			rest = rest[1:]
		case "--category":
			if len(rest) < 2 {
				return fmt.Errorf("--category needs a category id")
			}
			category = rest[1]
			haveCategory = true
			rest = rest[2:]
		default:
			return fmt.Errorf("unknown catalog flag %q", rest[0])
		}
	}
	if haveCategory {
		if category == "" {
			return fmt.Errorf("--category needs a non-empty id")
		}
		p, ok := providerFor(provs, category)
		if !ok {
			return fmt.Errorf("unknown category %q", category)
		}
		// A single-category probe is a subset of the store, never the snapshot.
		cat := BuildCatalog(context.Background(), []Provider{p}, refresh)
		return json.NewEncoder(w).Encode(cat)
	}
	// The full catalogue is snapshotted so a launch is instant and works offline;
	// the store's refresh button (--refresh) rebuilds it live and rewrites it.
	snapshot := filepath.Join(extrasCacheDir(), "catalog.json")
	if !refresh {
		if data, err := os.ReadFile(snapshot); err == nil && len(data) > 0 {
			_, err := w.Write(data)
			return err
		}
	}
	cat := BuildCatalog(context.Background(), provs, refresh)
	data, err := json.Marshal(cat)
	if err != nil {
		return err
	}
	data = append(data, '\n')
	// Only snapshot a catalogue that produced items, so a failed first fetch is
	// retried live next launch instead of caching an empty store.
	if len(cat.Items) > 0 {
		_ = atomicWrite(snapshot, data, 0o644)
	}
	_, err = w.Write(data)
	return err
}

func runInstall(provs []Provider, args []string) error {
	dither := false
	var only []string
	rest := make([]string, 0, len(args))
	i := 0
	for i < len(args) {
		a := args[i]
		i++
		switch a {
		case "--dither":
			dither = true
		case "--only":
			if i < len(args) {
				for _, n := range strings.Split(args[i], ",") {
					if n = strings.TrimSpace(n); n != "" {
						only = append(only, n)
					}
				}
				i++
			}
		default:
			rest = append(rest, a)
		}
	}
	if len(rest) != 2 {
		return fmt.Errorf("install needs <category> <id>")
	}
	category, id := rest[0], rest[1]
	p, ok := providerFor(provs, category)
	if !ok {
		return fmt.Errorf("unknown category %q", category)
	}
	if len(only) > 0 {
		if ci, ok := p.(componentInstaller); ok {
			return ci.InstallComponents(context.Background(), id, only)
		}
	}
	if dither {
		if vi, ok := p.(variantInstaller); ok {
			return vi.InstallVariant(context.Background(), id, true)
		}
	}
	return p.Install(context.Background(), id)
}

// variantInstaller is a provider that offers install-time variants (the decors
// dither toggle). Providers that do not implement it ignore --dither.
type variantInstaller interface {
	InstallVariant(ctx context.Context, id string, dither bool) error
}

// componentInstaller is a provider that can install a named subset of a
// product's components (the bundles manual selection). Providers that do not
// implement it ignore --only.
type componentInstaller interface {
	InstallComponents(ctx context.Context, id string, only []string) error
}

func runRemove(provs []Provider, args []string) error {
	if len(args) != 2 {
		return fmt.Errorf("remove needs <category> <id>")
	}
	category, id := args[0], args[1]
	p, ok := providerFor(provs, category)
	if !ok {
		return fmt.Errorf("unknown category %q", category)
	}
	return p.Remove(context.Background(), id)
}

// runInternal namespaces commands the extras actuator and Settings call
// directly: the browse cache directory, an on-demand script installer path, and
// the guest install/remove primitives. These are not public UI commands.
func runInternal(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("internal needs a subcommand")
	}
	switch args[0] {
	case "cache":
		fmt.Println(extrasCacheDir())
		return nil
	case "installer":
		if len(args) < 2 {
			return fmt.Errorf("internal installer needs a name")
		}
		p, err := ensureInstaller(args[1])
		if err != nil {
			return err
		}
		fmt.Println(p)
		return nil
	case "bundle":
		if len(args) < 2 {
			return fmt.Errorf("internal bundle needs an id")
		}
		p, err := ensureBundleManifest(args[1])
		if err != nil {
			return err
		}
		fmt.Println(p)
		return nil
	case "install-guest":
		if len(args) < 3 {
			return fmt.Errorf("internal install-guest needs <kind> <id>")
		}
		return installGuest(args[1], args[2])
	case "remove-guest":
		if len(args) < 3 {
			return fmt.Errorf("internal remove-guest needs <kind> <id>")
		}
		return removeGuest(args[1], args[2])
	case "apply-fastfetch":
		if len(args) != 2 {
			return fmt.Errorf("internal apply-fastfetch needs <id>")
		}
		return applyFastfetchStyle(args[1])
	default:
		return fmt.Errorf("unknown internal command %q", args[0])
	}
}
