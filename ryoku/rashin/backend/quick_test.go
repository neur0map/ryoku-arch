package main

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func seedQuickHermes(t *testing.T, model string, env string) {
	t.Helper()
	h := t.TempDir()
	t.Setenv("HOME", h)
	dir := filepath.Join(h, ".hermes")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(dir, "config.yaml"), []byte(model), 0o644)
	os.WriteFile(filepath.Join(dir, ".env"), []byte(env), 0o644)
}

func TestResolveQuickTargetFromHermesProvider(t *testing.T) {
	seedQuickHermes(t,
		"model:\n  provider: openrouter\n  default: anthropic/claude-sonnet-4.5\n",
		"OPENROUTER_API_KEY=sk-or-test\n")
	tgt, err := resolveQuickTarget(defaultConfig())
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(tgt.BaseURL, "openrouter.ai") || tgt.Key != "sk-or-test" {
		t.Fatalf("target %+v", tgt)
	}
	if tgt.Model != "anthropic/claude-sonnet-4.5" {
		t.Fatalf("model %q", tgt.Model)
	}
}

func TestResolveQuickTargetRejectsOAuthBackends(t *testing.T) {
	seedQuickHermes(t,
		"model:\n  provider: openai-codex\n  base_url: https://chatgpt.com/backend-api/codex\n  default: gpt-5.5\n", "")
	if _, err := resolveQuickTarget(defaultConfig()); err == nil {
		t.Fatal("codex OAuth backend must not resolve to a direct target")
	}
}

func TestResolveQuickTargetConfigOverrideWins(t *testing.T) {
	seedQuickHermes(t, "model:\n  provider: openai-codex\n  default: gpt-5.5\n", "")
	cfg := defaultConfig()
	cfg.Quick.Model = "llama3.2"
	cfg.Quick.BaseURL = "http://127.0.0.1:11434/v1"
	tgt, err := resolveQuickTarget(cfg)
	if err != nil {
		t.Fatal(err)
	}
	if tgt.Model != "llama3.2" || !isLocalURL(tgt.BaseURL) {
		t.Fatalf("target %+v", tgt)
	}
}

func sseServer(t *testing.T, deltas []string) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		for _, d := range deltas {
			fmt.Fprintf(w, "data: {\"choices\":[{\"delta\":{\"content\":%q}}]}\n\n", d)
		}
		fmt.Fprint(w, "data: [DONE]\n\n")
	}))
}

func TestQuickCompleteStreamsAnswer(t *testing.T) {
	t.Setenv("RYOKU_RASHIN_VAULT", t.TempDir())
	srv := sseServer(t, []string{"The kernel ", "is 7.0.12."})
	defer srv.Close()
	var streamed strings.Builder
	got, err := quickComplete(context.Background(),
		quickTarget{BaseURL: srv.URL, Model: "m", Key: "k"},
		"kernel?", func(d string) { streamed.WriteString(d) }, nil)
	if err != nil {
		t.Fatal(err)
	}
	if got != "The kernel is 7.0.12." || streamed.String() != got {
		t.Fatalf("answer %q streamed %q", got, streamed.String())
	}
}

func TestQuickCompleteSentinelEscalates(t *testing.T) {
	t.Setenv("RYOKU_RASHIN_VAULT", t.TempDir())
	srv := sseServer(t, []string{"TOOLS_", "REQUIRED"})
	defer srv.Close()
	streamedAny := false
	_, err := quickComplete(context.Background(),
		quickTarget{BaseURL: srv.URL, Model: "m", Key: "k"},
		"summarize this video", func(string) { streamedAny = true }, nil)
	if err != errNeedsTools {
		t.Fatalf("err = %v, want errNeedsTools", err)
	}
	if streamedAny {
		t.Fatal("sentinel must never stream to the transcript")
	}
}

func TestQuickCompleteToolLoop(t *testing.T) {
	t.Setenv("RYOKU_RASHIN_VAULT", t.TempDir())
	// First call: stream a tool_call. Second call: stream the answer.
	var calls int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		if calls == 0 {
			calls++
			fmt.Fprint(w, `data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"c1","function":{"name":"system_query","arguments":"{\"topic\":\"kernel\"}"}}]}}]}`+"\n\n")
			fmt.Fprint(w, "data: [DONE]\n\n")
			return
		}
		fmt.Fprint(w, `data: {"choices":[{"delta":{"content":"Kernel is current."}}]}`+"\n\n")
		fmt.Fprint(w, "data: [DONE]\n\n")
	}))
	defer srv.Close()

	var tools []string
	got, err := quickComplete(context.Background(),
		quickTarget{BaseURL: srv.URL, Model: "m", Key: "k"},
		"what kernel?", nil,
		func(id, title, status string) {
			if status == "in_progress" {
				tools = append(tools, title)
			}
		})
	if err != nil {
		t.Fatal(err)
	}
	if got != "Kernel is current." {
		t.Fatalf("answer %q", got)
	}
	if len(tools) != 1 || !strings.Contains(tools[0], "kernel") {
		t.Fatalf("tool events %v", tools)
	}
}
