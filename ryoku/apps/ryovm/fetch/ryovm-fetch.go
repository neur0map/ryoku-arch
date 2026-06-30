// ryovm-fetch: a small, fast, dependency-free downloader for the ryovm app. It
// fetches one URL to a file using parallel ranged connections when the server
// supports them (HTTP Range), falling back to a single stream, and prints one
// JSON progress line per tick to stdout so the app can draw a live bar. On
// SIGTERM/SIGINT (the app's Cancel, or the app closing) it stops at once and
// removes the partial file, so a cancelled download never leaves a half-image
// the way the old detached terminal did.
//
// Usage: ryovm-fetch <url> <dest-file>
// Output (stdout, one JSON object per line):
//
//	{"event":"start","total":<bytes>,"parallel":<bool>}
//	{"event":"progress","recv":<bytes>,"total":<bytes>,"bps":<bytes/sec>}
//	{"event":"done","path":"<dest>"}
//	{"event":"error","message":"<why>"}
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

const (
	workers   = 6                // parallel connections when ranged
	minChunk  = 8 << 20          // don't parallelise downloads smaller than this
	uaString  = "ryovm-fetch/1"  // a plain UA; some mirrors reject empty ones
	tickEvery = 250 * time.Millisecond
)

func emit(v map[string]any) {
	b, _ := json.Marshal(v)
	fmt.Println(string(b))
}

// partialPath is the file being written; fail() removes it before exiting, since
// os.Exit skips deferred cleanup (a cancel must never leave a half-image).
var partialPath string

func fail(msg string) {
	if partialPath != "" {
		os.Remove(partialPath)
	}
	emit(map[string]any{"event": "error", "message": msg})
	os.Exit(1)
}

func main() {
	if len(os.Args) != 3 {
		fail("usage: ryovm-fetch <url> <dest>")
	}
	url, dest := os.Args[1], os.Args[2]

	ctx, cancel := context.WithCancel(context.Background())
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sig
		cancel()
	}()

	size, ranged := probe(ctx, url)

	out, err := os.Create(dest)
	if err != nil {
		fail("create " + dest + ": " + err.Error())
	}
	// remove the partial file on any non-success exit (error or cancellation).
	partialPath = dest
	ok := false
	defer func() {
		out.Close()
		if !ok {
			os.Remove(dest)
		}
	}()

	var recv int64
	done := make(chan struct{})
	go reporter(ctx, &recv, size, done)

	if ranged && size >= minChunk {
		emit(map[string]any{"event": "start", "total": size, "parallel": true})
		err = downloadParallel(ctx, url, out, size, &recv)
	} else {
		emit(map[string]any{"event": "start", "total": size, "parallel": false})
		err = downloadSingle(ctx, url, out, &recv)
	}
	close(done)

	if err != nil {
		if ctx.Err() != nil {
			fail("cancelled")
		}
		fail(err.Error())
	}
	if err := out.Sync(); err != nil {
		fail("sync: " + err.Error())
	}
	ok = true
	emit(map[string]any{"event": "progress", "recv": atomic.LoadInt64(&recv), "total": size, "bps": 0})
	emit(map[string]any{"event": "done", "path": dest})
}

// probe asks the server for the content length and whether it accepts ranges, so
// the caller can decide between parallel and single-stream.
func probe(ctx context.Context, url string) (size int64, ranged bool) {
	req, err := http.NewRequestWithContext(ctx, http.MethodHead, url, nil)
	if err != nil {
		return 0, false
	}
	req.Header.Set("User-Agent", uaString)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return 0, false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 0, false
	}
	return resp.ContentLength, resp.Header.Get("Accept-Ranges") == "bytes" && resp.ContentLength > 0
}

// reporter prints a progress line every tick with an instantaneous rate.
func reporter(ctx context.Context, recv *int64, total int64, done <-chan struct{}) {
	t := time.NewTicker(tickEvery)
	defer t.Stop()
	last := int64(0)
	lastAt := time.Now()
	for {
		select {
		case <-done:
			return
		case <-ctx.Done():
			return
		case now := <-t.C:
			cur := atomic.LoadInt64(recv)
			dt := now.Sub(lastAt).Seconds()
			bps := int64(0)
			if dt > 0 {
				bps = int64(float64(cur-last) / dt)
			}
			emit(map[string]any{"event": "progress", "recv": cur, "total": total, "bps": bps})
			last, lastAt = cur, now
		}
	}
}

func downloadSingle(ctx context.Context, url string, out *os.File, recv *int64) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", uaString)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("server replied %s", resp.Status)
	}
	buf := make([]byte, 256<<10)
	for {
		n, rerr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := out.Write(buf[:n]); werr != nil {
				return werr
			}
			atomic.AddInt64(recv, int64(n))
		}
		if rerr == io.EOF {
			return nil
		}
		if rerr != nil {
			return rerr
		}
	}
}

// downloadParallel splits the file into one contiguous span per worker and
// writes each span at its offset with WriteAt, so the connections never block
// one another and the file is assembled in place.
func downloadParallel(ctx context.Context, url string, out *os.File, size int64, recv *int64) error {
	span := size / workers
	var wg sync.WaitGroup
	errc := make(chan error, workers)
	for i := range workers {
		start := int64(i) * span
		end := start + span - 1
		if i == workers-1 {
			end = size - 1
		}
		wg.Add(1)
		go func(start, end int64) {
			defer wg.Done()
			if err := fetchRange(ctx, url, out, start, end, recv); err != nil {
				errc <- err
			}
		}(start, end)
	}
	wg.Wait()
	close(errc)
	for err := range errc {
		if err != nil {
			return err
		}
	}
	return nil
}

func fetchRange(ctx context.Context, url string, out *os.File, start, end int64, recv *int64) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", uaString)
	req.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", start, end))
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusPartialContent {
		return fmt.Errorf("range request rejected (%s)", resp.Status)
	}
	buf := make([]byte, 256<<10)
	off := start
	for {
		n, rerr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := out.WriteAt(buf[:n], off); werr != nil {
				return werr
			}
			off += int64(n)
			atomic.AddInt64(recv, int64(n))
		}
		if rerr == io.EOF {
			return nil
		}
		if rerr != nil {
			return rerr
		}
	}
}
