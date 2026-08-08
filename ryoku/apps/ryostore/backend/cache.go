package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// Cache is the shared fetch every provider uses to pull a relative path from the
// extras base. It answers a repeated path from an in-process memo, writes each
// live result to disk atomically, and falls back to the last disk copy (flagged
// Offline, with the cache's timestamp) when the fetch fails, so a dead source
// degrades to its archive instead of blanking the catalogue.
type Cache struct {
	client *http.Client
	base   string
	dir    string
	mu     sync.Mutex
	memo   map[string]memoEntry
}

// memoEntry is a path's answer for this process: the bytes plus the source state
// they were served with, so a repeated fetch reports the same online/offline
// verdict instead of silently reverting to online after a known outage.
type memoEntry struct {
	data  []byte
	state SourceState
}

const (
	// cacheTimeout bounds a single fetch so one slow source cannot stall a probe.
	cacheTimeout = 12 * time.Second
	// maxBody caps a response so a runaway or misrouted URL can neither exhaust
	// memory nor truncate a registry into the cache as a false success.
	maxBody = 4 << 20
)

func newCache() *Cache {
	return &Cache{
		client: &http.Client{Timeout: cacheTimeout},
		base:   extrasBase(),
		dir:    extrasCacheDir(),
		memo:   map[string]memoEntry{},
	}
}

// Fetch returns the bytes at rel. rel must be a clean, relative, in-tree path;
// an empty, dotted, absolute, or traversing key is refused before any memo,
// network, or disk use so a registry-derived path cannot escape the cache.
// Without refresh a path already pulled this process answers from the memo with
// its recorded state. Otherwise it fetches live, caches the result atomically,
// and memoizes it online. A failed fetch serves the disk archive with Offline
// set and memoizes that offline state; with no archive it returns the original
// fetch error so a caller can classify the failure. refresh bypasses the memo.
func (c *Cache) Fetch(ctx context.Context, rel string, refresh bool) ([]byte, SourceState, error) {
	if rel == "" || rel == "." || !filepath.IsLocal(rel) || filepath.Clean(rel) != rel {
		return nil, SourceState{}, fmt.Errorf("invalid cache key %q", rel)
	}
	if !refresh {
		c.mu.Lock()
		e, ok := c.memo[rel]
		c.mu.Unlock()
		if ok {
			return e.data, e.state, nil
		}
	}
	b, ferr := c.get(ctx, rel)
	if ferr == nil {
		c.writeDisk(rel, b)
		c.setMemo(rel, b, SourceState{})
		return b, SourceState{}, nil
	}
	if disk, state, ok := c.readDisk(rel); ok {
		c.setMemo(rel, disk, state)
		return disk, state, nil
	}
	return nil, SourceState{}, ferr
}

func (c *Cache) setMemo(rel string, data []byte, state SourceState) {
	c.mu.Lock()
	c.memo[rel] = memoEntry{data: data, state: state}
	c.mu.Unlock()
}

// readDisk returns the cached copy of rel and its Offline state, timestamped
// from the cache file, or ok=false when nothing is cached for rel.
func (c *Cache) readDisk(rel string) ([]byte, SourceState, bool) {
	p := filepath.Join(c.dir, rel)
	b, err := os.ReadFile(p)
	if err != nil {
		return nil, SourceState{}, false
	}
	state := SourceState{Offline: true}
	if fi, err := os.Stat(p); err == nil {
		state.CachedAt = fi.ModTime().UTC().Format(time.RFC3339)
	}
	return b, state, true
}

// get pulls rel live. A unique query parameter and a no-cache header defeat the
// raw GitHub (Fastly) CDN, which otherwise keeps serving a pre-push copy for
// minutes and makes a refresh look broken. A body past maxBody is an error, not
// a truncated success, so it never replaces a valid cache.
func (c *Cache) get(ctx context.Context, rel string) ([]byte, error) {
	if root, ok := localBase(c.base); ok {
		data, err := os.ReadFile(filepath.Join(root, filepath.FromSlash(rel)))
		if err != nil {
			return nil, err
		}
		if len(data) > maxBody {
			return nil, fmt.Errorf("%s: response exceeds %d bytes", rel, maxBody)
		}
		return data, nil
	}
	url := c.base + "/" + rel
	sep := "?"
	if strings.Contains(url, "?") {
		sep = "&"
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("%s%s_=%d", url, sep, time.Now().UnixNano()), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Cache-Control", "no-cache")
	resp, err := c.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, &HTTPStatusError{URL: url, Status: resp.StatusCode}
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, maxBody+1))
	if err != nil {
		return nil, err
	}
	if len(b) > maxBody {
		return nil, fmt.Errorf("%s: response exceeds %d bytes", url, maxBody)
	}
	return b, nil
}

// HTTPStatusError is a non-OK HTTP response from a live fetch, kept typed so a
// provider can tell an uncached 404 (an honest empty category) from a network
// failure via errors.As.
type HTTPStatusError struct {
	URL    string
	Status int
}

func (e *HTTPStatusError) Error() string {
	return fmt.Sprintf("%s: HTTP %d", e.URL, e.Status)
}

// writeDisk caches data at rel via a same-directory temp file and rename, so a
// reader never sees a half-written cache. Best effort: a cache write failure
// must not fail the fetch that already has the bytes.
func (c *Cache) writeDisk(rel string, data []byte) {
	p := filepath.Join(c.dir, rel)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return
	}
	tmp, err := os.CreateTemp(filepath.Dir(p), ".tmp-*")
	if err != nil {
		return
	}
	name := tmp.Name()
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		os.Remove(name)
		return
	}
	if err := tmp.Close(); err != nil {
		os.Remove(name)
		return
	}
	os.Rename(name, p)
}
