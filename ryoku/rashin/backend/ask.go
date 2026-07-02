package main

import (
	"bufio"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// ask.go is the launcher's one-shot CLI: it POSTs the question to the running
// daemon's /api/ask and pipes the streamed marker lines straight to stdout.
// The daemon does the thinking (fast lane or hermes session) and records the
// conversation in the shared transcript, so "continue in dashboard" opens the
// very conversation this started.
//
// stdout protocol (one marker per line):
//   @working <label>   what the agent is doing right now
//   @perm <title>      a permission is waiting (answer it in the dashboard)
//   @answer <json>     {"text":"...","images":["/abs.png"]} final answer
//   @error <message>   terminal failure

// quickPreamble rides in front of session-lane questions so the model answers
// tersely. The transcript records the RAW question; only hermes sees this.
const quickPreamble = "[quick ask from the launcher: reply with just the answer, " +
	"one or two sentences or a tight list, no preamble, no follow-up questions] "

func cmdAsk(question string) error {
	question = strings.TrimSpace(question)
	if question == "" {
		return fmt.Errorf("usage: ryoku-rashin ask <question>")
	}
	cfg := LoadConfig()
	if !pingDaemon(cfg.Port) {
		emitAsk("error", "rashin is not running; enable it in Ryoku Settings, Advanced, Rashin")
		os.Exit(1)
	}

	client := http.Client{Timeout: 5 * time.Minute}
	resp, err := client.Post(fmt.Sprintf(
		"http://127.0.0.1:%d/api/ask?q=%s", cfg.Port, url.QueryEscape(question)), "", nil)
	if err != nil {
		emitAsk("error", "cannot reach the daemon: "+err.Error())
		os.Exit(1)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		emitAsk("error", fmt.Sprintf("daemon answered %d", resp.StatusCode))
		os.Exit(1)
	}
	sc := bufio.NewScanner(resp.Body)
	sc.Buffer(make([]byte, 64*1024), 4<<20)
	for sc.Scan() {
		fmt.Println(sc.Text())
	}
	return nil
}

type askAnswer struct {
	Text    string      `json:"text"`
	Images  []string    `json:"images,omitempty"`
	Actions []askAction `json:"actions,omitempty"`
}

// askAction is one actionable entity found in an answer. The launcher renders
// them as chips: kind picks the verb (edit / browse / files / copy / swatch),
// value is the payload, label is display copy.
type askAction struct {
	Kind  string `json:"kind"` // file | dir | url | cmd | color
	Value string `json:"value"`
	Label string `json:"label"`
}

var (
	imagePathRe = regexp.MustCompile(`(?:~|/)[^\s"'` + "`" + `)\]]*\.(?:png|jpe?g|webp|gif)`)
	pathRe      = regexp.MustCompile(`(?:~|/)[A-Za-z0-9._+@%/-]+`)
	urlRe       = regexp.MustCompile(`https?://[^\s"'` + "`" + `<>)\]]+`)
	tickRe      = regexp.MustCompile("`([^`\n]{2,120})`")
	colorRe     = regexp.MustCompile(`#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b`)
)

// extractImages pulls existing image files out of the answer text, so the
// launcher can preview what image_gen (or a screenshot tool) just produced.
func extractImages(text string) []string {
	var out []string
	seen := map[string]bool{}
	for _, m := range imagePathRe.FindAllString(text, 6) {
		p := expandHome(strings.TrimRight(m, ".,;:!?"))
		if seen[p] || !fileExists(p) {
			continue
		}
		seen[p] = true
		out = append(out, p)
	}
	return out
}

func expandHome(p string) string {
	if strings.HasPrefix(p, "~") {
		return home() + p[1:]
	}
	return p
}

// extractActions finds the entities an answer talks about and turns each into
// one launcher chip: real files open in nvim, real directories in the file
// manager, URLs in the browser, runnable commands and colors copy.
func extractActions(text string) []askAction {
	var out []askAction
	seen := map[string]bool{}
	add := func(kind, value, label string) {
		if value == "" || seen[kind+"\x00"+value] || len(out) >= 6 {
			return
		}
		seen[kind+"\x00"+value] = true
		out = append(out, askAction{Kind: kind, Value: value, Label: label})
	}

	// URLs first: an answer that cites a page should open it in one key.
	for _, m := range urlRe.FindAllString(text, 4) {
		u := strings.TrimRight(m, ".,;:!?)")
		label := u
		if i := strings.Index(u, "://"); i >= 0 {
			label = u[i+3:]
		}
		if len(label) > 40 {
			label = label[:40] + "..."
		}
		add("url", u, label)
	}

	// Paths that really exist on this machine: files edit, directories browse.
	// The vault's own doc names count too (agents cite them bare).
	for _, m := range pathRe.FindAllString(text, 12) {
		p := expandHome(strings.TrimRight(m, ".,;:!?"))
		if len(p) < 2 || seen["file\x00"+p] || seen["dir\x00"+p] {
			continue
		}
		fi, err := os.Stat(p)
		if err != nil {
			continue
		}
		base := filepath.Base(p)
		if fi.IsDir() {
			add("dir", p, base+"/")
		} else {
			add("file", p, base)
		}
	}

	// Backtick spans whose first word is a real executable: copyable commands.
	for _, m := range tickRe.FindAllStringSubmatch(text, 8) {
		span := strings.TrimSpace(m[1])
		first := strings.Fields(span)
		if len(first) == 0 || strings.ContainsAny(span, "\n") {
			continue
		}
		if _, err := exec.LookPath(first[0]); err != nil {
			continue
		}
		label := span
		if len(label) > 34 {
			label = label[:34] + "..."
		}
		add("cmd", span, label)
	}

	// Hex colors: this is a ricing distro, swatches earn their place.
	for _, m := range colorRe.FindAllString(text, 4) {
		add("color", m, m)
	}
	return out
}

func emitAsk(kind, detail string) {
	fmt.Println("@" + kind + " " + strings.ReplaceAll(detail, "\n", " "))
}
