package updater

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// An in-flight `ryoku update` publishes its progress to a run-state file the
// shell's update island and the Hub's Updates page watch
// ($XDG_RUNTIME_DIR/ryoku-update.json). The file carries the ordered steps,
// the current human label, a rolling log tail, and, on failure, the error and
// the pre-update snapshot id, so the GUI renders a determinate multi-step run
// (and a one-click rollback) instead of a fake progress wave. Every write is
// atomic (temp + rename), so a watcher never reads a half-written file, and
// best-effort, so a write failure never blocks the update.

const runLogCap = 12

type stepState string

const (
	stepPending stepState = "pending"
	stepRunning stepState = "running"
	stepDone    stepState = "ok"
	stepFailed  stepState = "failed"
	stepSkipped stepState = "skipped"
)

type runStep struct {
	Key   string    `json:"key"`
	Label string    `json:"label"`
	State stepState `json:"state"`
}

type promptSpec struct {
	ID      string   `json:"id"`
	Title   string   `json:"title"`
	Detail  string   `json:"detail"`
	Options []string `json:"options"`
}

// runState is the JSON document the GUI reads. phase and progress stay for
// older readers; steps/label/log/error/snapshot are the richer surface.
type runState struct {
	Phase    string      `json:"phase"` // idle | running | prompt | done | error
	Step     string      `json:"step"`
	Label    string      `json:"label"`
	Progress float64     `json:"progress"`
	Steps    []runStep   `json:"steps,omitempty"`
	Log      []string    `json:"log,omitempty"`
	Error    string      `json:"error,omitempty"`
	Snapshot string      `json:"snapshot,omitempty"`
	Prompt   *promptSpec `json:"prompt,omitempty"`
}

// progress is the singleton run-state publisher for the update in this process.
// An update is single-threaded, so no locking is needed.
var progress = &publisher{}

type publisher struct {
	steps    []runStep
	log      []string
	snapshot string
}

func runStatePath() string {
	d := os.Getenv("XDG_RUNTIME_DIR")
	if d == "" {
		d = "/tmp"
	}
	return filepath.Join(d, "ryoku-update.json")
}

func writeState(st runState) {
	b, err := json.Marshal(st)
	if err != nil {
		return
	}
	path := runStatePath()
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return
	}
	_ = os.Rename(tmp, path)
}

// begin sets the ordered step list for this run (all pending) and marks the
// run running. A stage2 re-begins the same list and marks the earlier steps
// done, so the exec handoff keeps one continuous bar.
func (p *publisher) begin(steps []runStep) {
	p.steps = make([]runStep, len(steps))
	copy(p.steps, steps)
	for i := range p.steps {
		p.steps[i].State = stepPending
	}
	p.log = nil
	p.publish("running")
}

func (p *publisher) indexOf(key string) int {
	for i := range p.steps {
		if p.steps[i].Key == key {
			return i
		}
	}
	return -1
}

// at marks the step with key running and every earlier still-open step done,
// then publishes. The current label and progress follow from the step states.
func (p *publisher) at(key string) {
	idx := p.indexOf(key)
	if idx < 0 {
		return
	}
	for i := range idx {
		if p.steps[i].State == stepPending || p.steps[i].State == stepRunning {
			p.steps[i].State = stepDone
		}
	}
	p.steps[idx].State = stepRunning
	p.publish("running")
}

// markDone forces the named steps done (used by stage2 for the steps stage1
// already ran before the exec handoff).
func (p *publisher) markDone(keys ...string) {
	for _, k := range keys {
		if i := p.indexOf(k); i >= 0 {
			p.steps[i].State = stepDone
		}
	}
}

// skip marks a step skipped (e.g. the AUR step on a box with no yay).
func (p *publisher) skip(key string) {
	if i := p.indexOf(key); i >= 0 {
		p.steps[i].State = stepSkipped
	}
}

// logf prints an "==> " status line to the terminal and rings it into the
// run-state log so the GUI shows the same narrative, then republishes.
func (p *publisher) logf(format string, a ...any) {
	line := fmt.Sprintf(format, a...)
	fmt.Println("==> " + line)
	p.log = append(p.log, line)
	if len(p.log) > runLogCap {
		p.log = p.log[len(p.log)-runLogCap:]
	}
	p.publish("running")
}

func (p *publisher) setSnapshot(id string) { p.snapshot = id }

// publish serializes the current state with the given phase; progress is
// derived from the step states so the bar is determinate.
func (p *publisher) publish(phase string) {
	st := runState{Phase: phase, Steps: p.steps, Log: p.log, Snapshot: p.snapshot}
	var done float64
	for _, s := range p.steps {
		switch s.State {
		case stepDone, stepSkipped, stepFailed:
			done++
		case stepRunning:
			done += 0.5
			st.Step = s.Key
			st.Label = s.Label
		}
	}
	if n := len(p.steps); n > 0 {
		st.Progress = done / float64(n)
	}
	writeState(st)
}

// finish marks every open step done and publishes a terminal "done" state.
func (p *publisher) finish() {
	for i := range p.steps {
		if p.steps[i].State != stepSkipped && p.steps[i].State != stepFailed {
			p.steps[i].State = stepDone
		}
	}
	writeState(runState{Phase: "done", Progress: 1, Steps: p.steps, Log: p.log, Snapshot: p.snapshot})
}

// fail marks the running step failed and publishes an "error" state carrying
// the reason and the pre-update snapshot the GUI offers to roll back to.
func (p *publisher) fail(err error) {
	for i := range p.steps {
		if p.steps[i].State == stepRunning {
			p.steps[i].State = stepFailed
		}
	}
	st := runState{Phase: "error", Steps: p.steps, Log: p.log, Snapshot: p.snapshot, Error: err.Error()}
	var done float64
	for _, s := range p.steps {
		if s.State == stepDone || s.State == stepSkipped || s.State == stepFailed {
			done++
		}
	}
	if n := len(p.steps); n > 0 {
		st.Progress = done / float64(n)
	}
	writeState(st)
}

// idle clears the run state so the island folds away.
func (p *publisher) idle() { writeState(runState{Phase: "idle"}) }

// answerPath is the back-channel a prompt phase is answered on: the Hub (or a
// terminal) writes the chosen option label here, and `ryoku update` reads it.
func answerPath() string {
	d := os.Getenv("XDG_RUNTIME_DIR")
	if d == "" {
		d = "/tmp"
	}
	return filepath.Join(d, "ryoku-update-answer")
}

// publishPrompt writes a "prompt" phase the Hub renders as a question with
// option buttons, keeping the current steps + log for context. Any prior
// answer is cleared first so a stale click cannot satisfy this prompt.
func publishPrompt(id, title, detail string, options []string) {
	_ = os.Remove(answerPath())
	writeState(runState{
		Phase:    "prompt",
		Steps:    progress.steps,
		Log:      progress.log,
		Snapshot: progress.snapshot,
		Prompt:   &promptSpec{ID: id, Title: title, Detail: detail, Options: options},
	})
}

// awaitAnswer blocks until the back-channel carries a choice or timeout
// elapses, then clears it. Returns the chosen option label and true, or "" and
// false on timeout (the caller treats that as a decline).
func awaitAnswer(timeout time.Duration) (string, bool) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if b, err := os.ReadFile(answerPath()); err == nil {
			choice := strings.TrimSpace(string(b))
			_ = os.Remove(answerPath())
			if choice != "" {
				return choice, true
			}
		}
		time.Sleep(300 * time.Millisecond)
	}
	return "", false
}
