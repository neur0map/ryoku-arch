package main

import (
	"context"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/coder/websocket"
)

//go:embed web
var webFS embed.FS

// Serve runs the dashboard and the agent bridge on 127.0.0.1.
func Serve(cfg Config) error {
	rt := RuntimeDir()
	if err := os.MkdirAll(rt, 0o700); err != nil {
		return err
	}
	lock, err := os.OpenFile(filepath.Join(rt, "daemon.lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return err
	}
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		return errors.New("another ryoku-rashin daemon is already running")
	}
	pidfile := filepath.Join(rt, "daemon.pid")
	if err := os.WriteFile(pidfile, []byte(strconv.Itoa(os.Getpid())), 0o600); err != nil {
		return err
	}
	defer os.Remove(pidfile)

	if err := EnsureVault(); err != nil {
		return err
	}
	// Re-apply wiring lost to agent onboarding rewrites; drift heals on start.
	if HermesStatus().Installed {
		_ = WireHermesMemory()
	}
	go func() {
		if err := Reindex(); err != nil {
			fmt.Fprintln(os.Stderr, "ryoku-rashin: index:", err)
		}
	}()
	go func() {
		for range time.Tick(6 * time.Hour) {
			_ = Reindex()
		}
	}()
	// User-owned changes reindex separately: a cheap fingerprint of the live
	// config every 2 minutes, the full diff only when it moves.
	go func() {
		last := userConfigFingerprint()
		for range time.Tick(2 * time.Minute) {
			cur := userConfigFingerprint()
			if cur != last {
				last = cur
				_ = ReindexUser()
			}
		}
	}()

	hub := newChatHub()
	mux := http.NewServeMux()

	sub, err := fs.Sub(webFS, "web")
	if err != nil {
		return err
	}
	mux.Handle("/", http.FileServerFS(sub))

	mux.HandleFunc("GET /api/ping", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, "ok")
	})
	mux.HandleFunc("GET /api/status", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, BuildStatus(cfg))
	})
	mux.HandleFunc("GET /api/vitals", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, SampleVitals())
	})
	mux.HandleFunc("GET /api/vault", func(w http.ResponseWriter, r *http.Request) {
		files, err := VaultTree()
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, map[string]any{"root": VaultDir(), "files": files})
	})
	mux.HandleFunc("GET /api/vault/file", func(w http.ResponseWriter, r *http.Request) {
		b, err := ReadVaultFile(r.URL.Query().Get("p"))
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "text/markdown; charset=utf-8")
		_, _ = w.Write(b)
	})
	mux.HandleFunc("POST /api/index", func(w http.ResponseWriter, r *http.Request) {
		if err := Reindex(); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, map[string]bool{"ok": true})
	})
	mux.HandleFunc("GET /api/agents", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, DetectAgents())
	})
	mux.HandleFunc("POST /api/agents/wire", agentMutation(Wire))
	mux.HandleFunc("POST /api/agents/unwire", agentMutation(Unwire))

	mux.HandleFunc("GET /api/hermes/skills", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, SkillsReportNow())
	})
	mux.HandleFunc("GET /api/hermes/memory", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, MemoryReportNow())
	})
	mux.HandleFunc("GET /api/prowl", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, ProwlReportNow())
	})
	mux.HandleFunc("GET /api/prowl/search", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]any{"hits": ProwlSearch(r.URL.Query().Get("q"))})
	})
	mux.HandleFunc("GET /api/about", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, AboutReportNow(cfg))
	})

	mux.HandleFunc("GET /ws/vitals", func(w http.ResponseWriter, r *http.Request) {
		ws, err := acceptWS(w, r)
		if err != nil {
			return
		}
		defer ws.CloseNow()
		serveVitalsWS(r.Context(), ws)
	})
	mux.HandleFunc("GET /ws/chat", func(w http.ResponseWriter, r *http.Request) {
		ws, err := acceptWS(w, r)
		if err != nil {
			return
		}
		defer ws.CloseNow()
		hub.handle(r.Context(), ws)
	})

	srv := &http.Server{
		Addr:              net.JoinHostPort("127.0.0.1", strconv.Itoa(cfg.Port)),
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	errCh := make(chan error, 1)
	go func() { errCh <- srv.ListenAndServe() }()
	fmt.Printf("ryoku-rashin: dashboard on http://%s\n", srv.Addr)

	select {
	case <-ctx.Done():
		shutCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		return srv.Shutdown(shutCtx)
	case err := <-errCh:
		return err
	}
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}

func agentMutation(f func(string) error) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			ID string `json:"id"`
		}
		if json.NewDecoder(r.Body).Decode(&body) != nil || body.ID == "" {
			http.Error(w, "missing agent id", http.StatusBadRequest)
			return
		}
		if err := f(body.ID); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		for _, a := range DetectAgents() {
			if a.ID == body.ID {
				writeJSON(w, a)
				return
			}
		}
		http.Error(w, "unknown agent", http.StatusBadRequest)
	}
}

// acceptWS upgrades only when the Origin is this machine's own dashboard.
func acceptWS(w http.ResponseWriter, r *http.Request) (*websocket.Conn, error) {
	if o := r.Header.Get("Origin"); o != "" {
		u, err := url.Parse(o)
		if err != nil || (u.Hostname() != "127.0.0.1" && u.Hostname() != "localhost") {
			http.Error(w, "forbidden origin", http.StatusForbidden)
			return nil, errors.New("bad origin")
		}
	}
	return websocket.Accept(w, r, &websocket.AcceptOptions{
		OriginPatterns: []string{"127.0.0.1:*", "localhost:*"},
	})
}

func cmdServe(ifEnabled bool) error {
	cfg := LoadConfig()
	if ifEnabled && !cfg.Enabled {
		return nil
	}
	return Serve(cfg)
}

func cmdEnable() error {
	cfg := LoadConfig()
	cfg.Enabled = true
	if err := SaveConfig(cfg); err != nil {
		return err
	}
	if !pingDaemon(cfg.Port) {
		self, err := os.Executable()
		if err != nil {
			return err
		}
		cmd := exec.Command(self, "serve")
		cmd.Stdout = nil
		cmd.Stderr = nil
		cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
		if err := cmd.Start(); err != nil {
			return err
		}
		_ = cmd.Process.Release()
	}
	fmt.Println("rashin enabled")
	return nil
}

func cmdDisable() error {
	cfg := LoadConfig()
	cfg.Enabled = false
	if err := SaveConfig(cfg); err != nil {
		return err
	}
	b, err := os.ReadFile(filepath.Join(RuntimeDir(), "daemon.pid"))
	if err == nil {
		if pid, perr := strconv.Atoi(strings.TrimSpace(string(b))); perr == nil {
			_ = syscall.Kill(pid, syscall.SIGTERM)
		}
	}
	fmt.Println("rashin disabled")
	return nil
}

func pingDaemon(port int) bool {
	c := http.Client{Timeout: 500 * time.Millisecond}
	resp, err := c.Get(fmt.Sprintf("http://127.0.0.1:%d/api/ping", port))
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == http.StatusOK
}
