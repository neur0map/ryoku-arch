package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"time"
)

// termserve.go runs terminal asks INSIDE the daemon (POST /api/term): the
// launcher's fast lane with a terminal persona, terminal context (cwd, last
// command), and one action tool, propose, whose validated output is the
// command plan the rashin CLI renders and fish injects at the prompt. Heavy
// asks escalate to the hermes session exactly like /api/ask. The daemon
// never executes a proposed command; the user is the executor.

const termPattern = `You are Rashin, the resident agent of this Ryoku (Arch Linux, Hyprland) machine, answering inside the user's terminal (fish in kitty).

You have read-only tools for live state (system_query, read_file, list_dir, search_code, fetch_url) and ONE action tool: propose.

Rules:
- When the ask calls for terminal action (navigate, inspect, move or rename files, install, configure), call propose ONCE with the exact command(s). Prefer a single chained line (oneliner true) when the steps chain safely; otherwise ordered steps.
- Use this machine's real paths and installed tools; the maps and habits below are current. Prefer the user's stack: fd over find, rg over grep, eza over ls, bat over cat.
- Commands must be real and complete: correct flags, absolute or ~ paths, no placeholders. If something is unknowable, look it up with your read tools first, then propose.
- After propose, reply with ONE terse sentence of context. For pure questions, answer directly: one or two sentences, no markdown headers.
- Escalate by replying exactly TOOLS_REQUIRED only when the request needs the full agent: editing file contents, generating images, an interactive browser, running a hermes skill, or multi-step work the user wants done for them rather than handed back as commands.`

type termReq struct {
	Q          string `json:"q"`
	Cwd        string `json:"cwd,omitempty"`
	LastCmd    string `json:"lastCmd,omitempty"`
	LastStatus *int   `json:"lastStatus,omitempty"`
	Cont       bool   `json:"continue,omitempty"`
}

// termCommand is one validated proposed command.
type termCommand struct {
	Run    string   `json:"run"`
	Why    string   `json:"why,omitempty"`
	Tier   string   `json:"tier"`
	Reason string   `json:"reason,omitempty"`
	Notes  []string `json:"notes,omitempty"`
}

type termPlan struct {
	Intent   string        `json:"intent,omitempty"`
	Oneliner bool          `json:"oneliner"`
	Commands []termCommand `json:"commands"`
}

// proposeSchema is the action tool the terminal lane adds to the read-only
// set: the model shapes commands, the daemon validates them, the user runs
// them.
func proposeSchema() map[string]any {
	return map[string]any{
		"type": "function",
		"function": map[string]any{
			"name":        "propose",
			"description": "Propose the shell command(s) that accomplish the user's request. Call at most once, with everything in one call.",
			"parameters": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"intent":   map[string]any{"type": "string", "description": "what the commands accomplish, a few words"},
					"oneliner": map[string]any{"type": "boolean", "description": "true when the commands chain safely as one line"},
					"commands": map[string]any{
						"type": "array",
						"items": map[string]any{
							"type": "object",
							"properties": map[string]any{
								"run": map[string]any{"type": "string", "description": "the exact command"},
								"why": map[string]any{"type": "string", "description": "one short clause of rationale"},
							},
							"required": []string{"run"},
						},
					},
				},
				"required": []string{"commands"},
			},
		},
	}
}

// validatePlan annotates each command in place: danger tier, missing
// binaries, and missing source paths. Notes inform; they never block, because
// the user is the executor and a wrong note must never hide a command.
func validatePlan(p *termPlan) {
	kept := p.Commands[:0]
	for _, c := range p.Commands {
		c.Run = strings.TrimSpace(c.Run)
		if c.Run == "" {
			continue
		}
		tier, reason := classify(c.Run)
		c.Tier, c.Reason = tier.String(), reason
		c.Notes = append(c.Notes, commandNotes(c.Run)...)
		kept = append(kept, c)
	}
	p.Commands = kept
	if len(p.Commands) != 1 && p.Oneliner {
		p.Oneliner = len(p.Commands) == 1
	}
	if len(p.Commands) == 1 {
		p.Oneliner = true
	}
}

// srcCheckers name commands whose first non-flag argument is a source path
// that must already exist for the command to mean anything.
var srcCheckers = map[string]bool{
	"cd": true, "cat": true, "bat": true, "ls": true, "eza": true, "mv": true,
	"cp": true, "rm": true, "du": true, "stat": true, "file": true, "tar": true,
	"unzip": true, "head": true, "tail": true, "nvim": true, "less": true,
}

// commandNotes checks what is cheap and certain: unknown binaries and
// missing source paths. Glob arguments are skipped (the shell expands them).
func commandNotes(run string) []string {
	var notes []string
	seen := map[string]bool{}
	for _, seg := range splitSegments(run) {
		argv := unwrap(stripEnvAssignments(shellFields(seg.text)))
		if len(argv) == 0 {
			continue
		}
		if sudoLike[argv[0]] {
			argv = unwrap(stripEnvAssignments(argv[1:]))
			if len(argv) == 0 {
				continue
			}
		}
		name := argv[0]
		if !strings.Contains(name, "/") && !seen[name] {
			seen[name] = true
			if _, err := exec.LookPath(name); err != nil && !fishBuiltins[name] {
				notes = append(notes, name+": not installed")
			}
		}
		if srcCheckers[filepath.Base(name)] {
			if p := firstPathArg(argv); p != "" && !strings.ContainsAny(p, "*?[{") &&
				filepath.IsAbs(p) {
				if _, err := os.Stat(p); err != nil {
					notes = append(notes, "path does not exist: "+p)
				}
			}
		}
	}
	return notes
}

// fishBuiltins never resolve on PATH but run fine at the prompt.
var fishBuiltins = map[string]bool{
	"cd": true, "z": true, "set": true, "source": true, "abbr": true,
	"alias": true, "type": true, "functions": true, "string": true, "test": true,
	"read": true, "command": true, "and": true, "or": true, "not": true,
	"for": true, "while": true, "if": true, "begin": true, "end": true,
}

// termContext renders the per-request terminal facts the pattern rides on.
func termContext(req termReq) string {
	var b strings.Builder
	b.WriteString("# Terminal\n\n")
	if req.Cwd != "" {
		b.WriteString("- cwd: " + req.Cwd + "\n")
	}
	if req.LastCmd != "" {
		line := "- last command: `" + req.LastCmd + "`"
		if req.LastStatus != nil && *req.LastStatus != 0 {
			line += fmt.Sprintf(" (exit %d)", *req.LastStatus)
		}
		b.WriteString(line + "\n")
	}
	if b.Len() == len("# Terminal\n\n") {
		b.WriteString("- no context passed\n")
	}
	return b.String()
}

// termPreamble rides in front of session-lane escalations so hermes answers
// tersely and formats commands where planFromText can lift them.
func termPreamble(req termReq) string {
	loc := ""
	if req.Cwd != "" {
		loc = " from " + req.Cwd
	}
	return "[terminal ask" + loc + ": you propose commands for the user to run " +
		"in their terminal, you do not do the work yourself. If the request changes " +
		"files or the system (move, rename, delete, install, configure), do NOT run " +
		"it: put the exact command(s) in one fenced code block, one per line, and " +
		"stop. For a question or a location, answer straight from the system vault " +
		"(AGENTS.md, desktop.md, habits.md) in one or two sentences, without running " +
		"tools unless you truly cannot answer otherwise] "
}

var termIDCounter atomic.Uint64

// handleTerm is POST /api/term. The turn runs on a background context so a
// closed terminal never aborts the work; only /api/term/cancel?id= or the
// timeout stops it.
func (h *chatHub) handleTerm(w http.ResponseWriter, r *http.Request) {
	var req termReq
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 64*1024)).Decode(&req); err != nil {
		http.Error(w, "bad request body", http.StatusBadRequest)
		return
	}
	req.Q = strings.TrimSpace(req.Q)
	if req.Q == "" {
		http.Error(w, "missing q", http.StatusBadRequest)
		return
	}
	f, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "no streaming", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	sink := &askSink{w: w, f: f, permJSON: true}

	id := "t" + strconv.FormatUint(termIDCounter.Add(1), 10) + "-" + strconv.FormatInt(time.Now().Unix(), 36)
	sink.marker("id", id)

	ctx, cancel := context.WithTimeout(context.Background(), quickTimeout+2*time.Minute)
	defer cancel()
	h.mu.Lock()
	h.termCancels[id] = cancel
	h.mu.Unlock()
	defer func() {
		h.mu.Lock()
		delete(h.termCancels, id)
		h.mu.Unlock()
	}()

	// The terminal ask joins the shared transcript, so "continue in the
	// dashboard" (and \resume in the launcher) already have it.
	h.broadcast(wsOut{Type: "user_text", Text: req.Q})
	h.broadcast(wsOut{Type: "state", State: "busy"})

	var plan *termPlan
	if target, err := resolveQuickTarget(LoadConfig()); err == nil {
		sink.marker("working", "thinking ("+target.Label+")")
		spec := h.termSpec(req, &plan)
		qctx, qcancel := context.WithTimeout(ctx, quickTimeout)
		answer, qerr := laneComplete(qctx, target, spec, req.Q, func(delta string) {
			if !sink.started {
				sink.started = true
				sink.marker("working", "writing")
			}
			h.broadcast(wsOut{Type: "agent_text", Text: delta})
		}, func(tid, title, status string) {
			if status == "in_progress" {
				sink.marker("working", title)
			}
			h.broadcast(wsOut{Type: "tool", ID: tid, Title: title, Kind: "quick", Status: status})
		})
		qcancel()
		switch {
		case qerr == nil:
			h.broadcast(wsOut{Type: "turn_end", StopReason: "end_turn"})
			h.broadcast(wsOut{Type: "state", State: "ready"})
			h.finishTerm(sink, req, answer, plan)
			return
		case qerr == errNeedsTools:
			sink.marker("working", "needs tools, waking the full agent")
		case ctx.Err() != nil:
			h.broadcast(wsOut{Type: "state", State: "ready"})
			sink.marker("error", "cancelled")
			return
		default:
			sink.marker("working", "fast lane unavailable, waking the full agent")
		}
	} else {
		sink.marker("working", "waking the needle")
	}

	if answer, ok := h.sessionAsk(ctx, sink, termPreamble(req), req.Q); ok {
		h.finishTerm(sink, req, answer, plan)
	}
}

// finishTerm closes out a term turn on either lane: lift a plan from fenced
// text when propose never fired, validate, persist, hint on repetition, and
// emit @plan then @answer.
func (h *chatHub) finishTerm(sink *askSink, req termReq, answer string, plan *termPlan) {
	if plan == nil {
		if p := planFromText(answer); p != nil {
			plan = p
			// The commands render as the plan; strip the fenced block so the
			// prose does not show them a second time as raw markdown.
			answer = stripCodeFences(answer)
		}
	}
	if plan != nil {
		validatePlan(plan)
		if len(plan.Commands) == 0 {
			plan = nil
		}
	}
	if plan != nil {
		if b, err := json.Marshal(plan); err == nil {
			sink.marker("plan", string(b))
		}
	}
	// Repetition is the recipe signal: count before recording, so the third
	// similar ask (two already stored) trips the hint.
	if n := countSimilarAsks(req.Q); n >= 2 {
		sink.marker("hint", fmt.Sprintf(`{"kind":"repeat","n":%d}`, n+1))
	}
	rec := askRecord{At: nowRFC3339(), Kind: "term", Question: req.Q, Answer: answer,
		Images: extractImages(answer), Plan: plan}
	recordAsk(rec)
	recordLastTerm(lastTerm{At: rec.At, Q: req.Q, Answer: answer, Plan: plan})

	// Continuation memory: the next `rashin -c` sees this exchange, with the
	// proposed commands inline so the model recalls exactly what it said.
	hist := answer
	if plan != nil {
		var runs []string
		for _, c := range plan.Commands {
			runs = append(runs, c.Run)
		}
		hist += "\n[proposed: " + strings.Join(runs, " ; ") + "]"
	}
	h.mu.Lock()
	h.termHist = []chatMessage{{Role: "user", Content: req.Q}, {Role: "assistant", Content: hist}}
	h.mu.Unlock()

	sink.marker("answer", mustAskJSON(answer))
}

// termSpec builds the terminal lane: persona + terminal context + machine
// maps, the read-only tools plus propose, and the previous exchange when the
// ask continues it.
func (h *chatHub) termSpec(req termReq, plan **termPlan) laneSpec {
	spec := laneSpec{
		system: termPattern + "\n\n" + termContext(req) + "\n# The machine map\n\n" + vaultQuickContext(),
		tools:  append(quickToolSchemas(), proposeSchema()),
		exec: func(ctx context.Context, name, args string) string {
			if name != "propose" {
				return execQuickTool(ctx, name, args)
			}
			var p termPlan
			if err := json.Unmarshal([]byte(args), &p); err != nil || len(p.Commands) == 0 {
				return "propose failed: send {intent, oneliner, commands:[{run, why}]}"
			}
			*plan = &p
			return "recorded. Now reply with one terse sentence of context for the user; do not repeat the commands."
		},
	}
	if req.Cont {
		h.mu.Lock()
		spec.history = h.termHist
		h.mu.Unlock()
		if len(spec.history) == 0 {
			if last, err := loadLastTerm(); err == nil && last.Q != "" {
				spec.history = []chatMessage{
					{Role: "user", Content: last.Q},
					{Role: "assistant", Content: last.Answer},
				}
			}
		}
	}
	return spec
}

// planFromText lifts commands out of a prose answer when the model skipped
// propose: fenced blocks first, else `$ `-prefixed lines. Comment and prose
// lines inside a fence are dropped.
func planFromText(answer string) *termPlan {
	var cmds []string
	if i := strings.Index(answer, "```"); i >= 0 {
		rest := answer[i+3:]
		if nl := strings.IndexByte(rest, '\n'); nl >= 0 {
			rest = rest[nl+1:] // drop the language tag line
		}
		if j := strings.Index(rest, "```"); j >= 0 {
			for _, line := range strings.Split(rest[:j], "\n") {
				line = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(line), "$ "))
				if line == "" || strings.HasPrefix(line, "#") {
					continue
				}
				cmds = append(cmds, line)
			}
		}
	} else {
		for _, line := range strings.Split(answer, "\n") {
			if cmd, ok := strings.CutPrefix(strings.TrimSpace(line), "$ "); ok {
				cmds = append(cmds, strings.TrimSpace(cmd))
			}
		}
	}
	if len(cmds) == 0 {
		return nil
	}
	p := &termPlan{Oneliner: len(cmds) == 1}
	for _, c := range cmds {
		p.Commands = append(p.Commands, termCommand{Run: c})
	}
	return p
}

// stripCodeFences removes fenced code blocks and $-prefixed command lines from
// a prose answer, so text a plan was lifted from does not render the commands
// twice. Prose outside the fences is kept and blank runs are collapsed.
func stripCodeFences(answer string) string {
	var out []string
	inFence := false
	for _, line := range strings.Split(answer, "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), "```") {
			inFence = !inFence
			continue
		}
		if inFence {
			continue
		}
		if strings.HasPrefix(strings.TrimSpace(line), "$ ") {
			continue
		}
		out = append(out, line)
	}
	// Collapse blank runs and trim so a fence-only answer becomes empty.
	var b strings.Builder
	blank := false
	for _, line := range out {
		if strings.TrimSpace(line) == "" {
			blank = true
			continue
		}
		if b.Len() > 0 && blank {
			b.WriteByte('\n')
		}
		blank = false
		if b.Len() > 0 {
			b.WriteByte('\n')
		}
		b.WriteString(strings.TrimRight(line, " "))
	}
	return strings.TrimSpace(b.String())
}

// handleTermCancel stops one term request by id; other terminals' asks keep
// running.
func (h *chatHub) handleTermCancel(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	h.mu.Lock()
	cancel := h.termCancels[id]
	conn := h.conn
	h.mu.Unlock()
	if cancel != nil {
		cancel()
		if conn != nil {
			conn.Cancel() // a session-lane turn needs the ACP cancel too
		}
	}
	w.WriteHeader(http.StatusNoContent)
}

// handleTermRan is the learning feedback: shell post-command hooks (and --run)
// report what actually ran after a rashin proposal, and how it exited.
func (h *chatHub) handleTermRan(w http.ResponseWriter, r *http.Request) {
	var rec runRecord
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 16*1024)).Decode(&rec); err != nil {
		http.Error(w, "bad request body", http.StatusBadRequest)
		return
	}
	rec.At = nowRFC3339()
	recordRun(rec)
	w.WriteHeader(http.StatusNoContent)
}

// handlePerm answers a pending session-lane permission request from any
// surface (the terminal, primarily). The ACP conn guards double answers, so
// racing the dashboard is safe.
func (h *chatHub) handlePerm(w http.ResponseWriter, r *http.Request) {
	var in struct {
		RequestID string `json:"requestId"`
		OptionID  string `json:"optionId"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4*1024)).Decode(&in); err != nil {
		http.Error(w, "bad request body", http.StatusBadRequest)
		return
	}
	h.mu.Lock()
	conn := h.conn
	h.mu.Unlock()
	if conn == nil {
		http.Error(w, "no session", http.StatusConflict)
		return
	}
	id, err := strconv.ParseInt(in.RequestID, 10, 64)
	if err != nil {
		http.Error(w, "bad requestId", http.StatusBadRequest)
		return
	}
	conn.RespondPermission(id, in.OptionID)
	w.WriteHeader(http.StatusNoContent)
}
