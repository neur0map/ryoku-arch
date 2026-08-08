package main

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"sync/atomic"
	"testing"
)

func (fakeProvider) Remove(context.Context, string) error     { return nil }
func (blockingProvider) Remove(context.Context, string) error { return nil }

func setTransactionXDG(t *testing.T) {
	t.Helper()
	root := t.TempDir()
	t.Setenv("HOME", root)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(root, "config"))
	t.Setenv("XDG_DATA_HOME", filepath.Join(root, "data"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "state"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(root, "cache"))
	bin := filepath.Join(root, "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatal(err)
	}
	place := filepath.Join(bin, "ryoku-plugins-place")
	if err := os.WriteFile(place, []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
}

func readRevisionForTest(t *testing.T) StoreRevision {
	t.Helper()
	raw, err := os.ReadFile(storeRevisionPath())
	if err != nil {
		t.Fatal(err)
	}
	var revision StoreRevision
	if err := json.Unmarshal(raw, &revision); err != nil {
		t.Fatalf("decode revision: %v", err)
	}
	return revision
}

func TestStoreRevisionMonotonic(t *testing.T) {
	setTransactionXDG(t)
	changes := []StoreRevision{
		{Category: "plugins", ID: "demo", Version: "1.0.0", Operation: "install"},
		{Category: "plugins", ID: "demo", Version: "2.0.0", Operation: "update"},
		{Category: "plugins", ID: "demo", Version: "2.0.0", Operation: "remove"},
	}
	for index, change := range changes {
		if err := writeStoreRevision(change); err != nil {
			t.Fatalf("writeStoreRevision(%s): %v", change.Operation, err)
		}
		got := readRevisionForTest(t)
		if got.Revision != uint64(index+1) || got.Operation != change.Operation || got.Category != change.Category || got.ID != change.ID || got.Version != change.Version {
			t.Fatalf("revision = %#v, want revision %d and change %#v", got, index+1, change)
		}
	}
	if err := writeStoreRevision(StoreRevision{Category: "plugins", ID: "demo", Version: "2.0.0", Operation: "replace"}); err == nil {
		t.Fatal("writeStoreRevision accepted an unknown operation")
	}
}

func TestReceiptAtomicity(t *testing.T) {
	setTransactionXDG(t)
	initial := Receipt{Category: "plugins", ID: "demo", Version: "0", Destination: "ryoku/plugins/demo"}
	if err := writeReceipt(initial); err != nil {
		t.Fatal(err)
	}

	stop := make(chan struct{})
	ready := make(chan struct{})
	errors := make(chan error, 1)
	var observations atomic.Int64
	var readyOnce sync.Once
	var readers sync.WaitGroup
	readers.Add(1)
	go func() {
		defer readers.Done()
		for {
			select {
			case <-stop:
				return
			default:
			}
			raw, err := os.ReadFile(receiptPath("plugins", "demo"))
			if err != nil {
				select {
				case errors <- err:
				default:
				}
				return
			}
			var receipt Receipt
			if err := json.Unmarshal(raw, &receipt); err != nil {
				select {
				case errors <- err:
				default:
				}
				return
			}
			observations.Add(1)
			readyOnce.Do(func() { close(ready) })
		}
	}()
	defer func() {
		close(stop)
		readers.Wait()
	}()

	select {
	case <-ready:
	case err := <-errors:
		t.Fatalf("receipt reader failed before writes: %v", err)
	}
	for revision := 1; revision <= 100; revision++ {
		before := observations.Load()
		receipt := initial
		receipt.Version = string(rune('a' + revision%26))
		if err := writeReceipt(receipt); err != nil {
			t.Fatal(err)
		}
		for observations.Load() == before {
			select {
			case err := <-errors:
				t.Fatalf("reader observed a partial receipt: %v", err)
			default:
				runtime.Gosched()
			}
		}
	}
	if observations.Load() < 101 {
		t.Fatalf("receipt reader made only %d observations", observations.Load())
	}
	select {
	case err := <-errors:
		t.Fatalf("reader observed a partial receipt: %v", err)
	default:
	}
}
