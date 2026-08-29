package main

import (
	"context"
	"testing"
)

func TestBeginReloadCoverUsesLauncherToken(t *testing.T) {
	old := reloadCoverBegin
	t.Cleanup(func() { reloadCoverBegin = old })
	reloadCoverBegin = func() string { return "token-123" }
	if got := beginReloadCover(); got != "token-123" {
		t.Fatalf("beginReloadCover() = %q, want token", got)
	}
}

func TestBeginReloadCoverFallsBackOnFailure(t *testing.T) {
	old := reloadCoverBegin
	t.Cleanup(func() { reloadCoverBegin = old })
	reloadCoverBegin = func() string { return "" }
	if got := beginReloadCover(); got != "" {
		t.Fatalf("beginReloadCover() = %q, want empty fallback token", got)
	}
}

func TestReloadCoverBeginHasDeadline(t *testing.T) {
	old := reloadCoverOutput
	t.Cleanup(func() { reloadCoverOutput = old })
	reloadCoverOutput = func(ctx context.Context) ([]byte, error) {
		if _, ok := ctx.Deadline(); !ok {
			t.Fatal("reload cover launcher has no deadline")
		}
		return []byte("token-456\n"), nil
	}
	if got := reloadCoverBegin(); got != "token-456" {
		t.Fatalf("reloadCoverBegin() = %q, want token", got)
	}
}
