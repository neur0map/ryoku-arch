package main

import (
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func migrationReceipt(body []byte) Receipt {
	return Receipt{
		Category:    "lockscreens",
		ID:          "demo",
		Version:     "1.0.0",
		Destination: "qylock/themes/demo",
		Files: []ReceiptFile{{
			Source: "content/Main.qml", Destination: "Main.qml",
			SHA256: fmt.Sprintf("%x", sha256.Sum256(body)), Mode: "0644", Size: int64(len(body)),
		}},
	}
}

func TestAdoptExactReceiptClaimsOnlyExactPayload(t *testing.T) {
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	body := []byte("known payload")
	receipt := migrationReceipt(body)
	dst := filepath.Join(dataHome(), filepath.FromSlash(receipt.Destination))
	if err := os.MkdirAll(dst, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dst, "Main.qml"), body, 0o644); err != nil {
		t.Fatal(err)
	}

	if err := adoptExactReceipt(dst, receipt); err != nil {
		t.Fatal(err)
	}
	got, err := readReceipt(receipt.Category, receipt.ID)
	if err != nil {
		t.Fatal(err)
	}
	if got.Version != receipt.Version || len(got.Files) != 1 {
		t.Fatalf("adopted receipt = %+v", got)
	}
}

func TestAdoptExactReceiptRejectsChangedOrAdditionalFiles(t *testing.T) {
	for name, mutate := range map[string]func(string) error{
		"changed": func(dst string) error {
			return os.WriteFile(filepath.Join(dst, "Main.qml"), []byte("changed"), 0o644)
		},
		"additional": func(dst string) error {
			return os.WriteFile(filepath.Join(dst, "personal.qml"), []byte("mine"), 0o644)
		},
	} {
		t.Run(name, func(t *testing.T) {
			t.Setenv("XDG_STATE_HOME", t.TempDir())
			t.Setenv("XDG_DATA_HOME", t.TempDir())
			body := []byte("known payload")
			receipt := migrationReceipt(body)
			dst := filepath.Join(dataHome(), filepath.FromSlash(receipt.Destination))
			if err := os.MkdirAll(dst, 0o755); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(filepath.Join(dst, "Main.qml"), body, 0o644); err != nil {
				t.Fatal(err)
			}
			if err := mutate(dst); err != nil {
				t.Fatal(err)
			}

			if err := adoptExactReceipt(dst, receipt); err != nil {
				t.Fatal(err)
			}
			if _, err := readReceipt(receipt.Category, receipt.ID); !os.IsNotExist(err) {
				t.Fatalf("receipt adopted for %s payload: %v", name, err)
			}
		})
	}
}

func TestAdoptExactReceiptRejectsSymlinkedParent(t *testing.T) {
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	data := t.TempDir()
	t.Setenv("XDG_DATA_HOME", data)
	outside := t.TempDir()
	if err := os.Symlink(outside, filepath.Join(data, "qylock")); err != nil {
		t.Fatal(err)
	}
	body := []byte("known payload")
	receipt := migrationReceipt(body)
	dst := filepath.Join(dataHome(), filepath.FromSlash(receipt.Destination))
	if err := os.MkdirAll(dst, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dst, "Main.qml"), body, 0o644); err != nil {
		t.Fatal(err)
	}

	if err := adoptExactReceipt(dst, receipt); err == nil {
		t.Fatal("adoptExactReceipt() accepted a symlinked destination parent")
	}
	if _, err := readReceipt(receipt.Category, receipt.ID); !os.IsNotExist(err) {
		t.Fatalf("receipt adopted through symlinked parent: %v", err)
	}
}
