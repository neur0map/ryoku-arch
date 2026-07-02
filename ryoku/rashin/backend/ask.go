package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

// ask.go is the launcher's one-shot: it joins the daemon's chat hub as one
// more WebSocket client (the SAME hermes session the dashboard shows), sends
// one terse-mode question, streams progress markers to stdout, and exits at
// turn end. The launcher parses the markers; "continue in dashboard" then
// opens the very conversation this started.
//
// stdout protocol (one marker per line):
//   @working <label>   what the agent is doing right now
//   @perm <title>      a permission is waiting (answer it in the dashboard)
//   @answer <json>     {"text":"...","images":["/abs.png"]} final answer
//   @error <message>   terminal failure

// quickPreamble rides in front of the question so the model answers tersely.
// The hub records the RAW question for the transcript; only hermes sees this.
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

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	origin := fmt.Sprintf("http://127.0.0.1:%d", cfg.Port)
	ws, _, err := websocket.Dial(ctx, origin+"/ws/chat", &websocket.DialOptions{
		HTTPHeader: http.Header{"Origin": []string{origin}},
	})
	if err != nil {
		emitAsk("error", "cannot reach the daemon: "+err.Error())
		os.Exit(1)
	}
	defer ws.Close(websocket.StatusNormalClosure, "done")
	// The final answer can exceed the default 32KiB read cap.
	ws.SetReadLimit(4 << 20)

	emitAsk("working", "waking the needle")
	if err := runAskTurn(ctx, ws, question); err != nil {
		emitAsk("error", err.Error())
		os.Exit(1)
	}
	return nil
}

// runAskTurn drives one question through the shared session: wait for a
// usable state, skip any join replay, send, then stream until turn_end.
func runAskTurn(ctx context.Context, ws *websocket.Conn, question string) error {
	sent := false
	replaying := false
	answer := &strings.Builder{}
	sawText := false

	for {
		var f wsOut
		if err := wsjson.Read(ctx, ws, &f); err != nil {
			if ctx.Err() != nil {
				return fmt.Errorf("timed out waiting for the answer")
			}
			return fmt.Errorf("connection lost: %v", err)
		}
		switch f.Type {
		case "replay_start":
			replaying = true
		case "replay_end":
			replaying = false
		case "state":
			switch f.State {
			case "dead":
				msg := "hermes is unavailable"
				if f.Error != "" {
					msg += ": " + f.Error
				}
				return fmt.Errorf("%s", msg)
			case "starting":
				emitAsk("working", "waking the needle")
			default:
				if !sent && !replaying {
					if err := wsjson.Write(ctx, ws, map[string]any{
						"type": "user", "text": question, "quick": true,
					}); err != nil {
						return err
					}
					sent = true
					emitAsk("working", "thinking")
				}
			}
		case "agent_thought":
			if sent && !replaying {
				emitAsk("working", "thinking")
			}
		case "tool":
			if sent && !replaying && (f.Status == "pending" || f.Status == "in_progress") {
				label := f.Title
				if label == "" {
					label = "running a tool"
				}
				emitAsk("working", label)
			}
		case "agent_text":
			if sent && !replaying {
				answer.WriteString(f.Text)
				if !sawText {
					sawText = true
					emitAsk("working", "writing")
				}
			}
		case "permission":
			if sent && !replaying {
				emitAsk("perm", f.Title)
			}
		case "turn_end":
			if sent && !replaying {
				return emitAnswer(answer.String())
			}
		}
	}
}

type askAnswer struct {
	Text   string   `json:"text"`
	Images []string `json:"images,omitempty"`
}

var imagePathRe = regexp.MustCompile(`(?:~|/)[^\s"'` + "`" + `)\]]*\.(?:png|jpe?g|webp|gif)`)

// extractImages pulls existing image files out of the answer text, so the
// launcher can preview what image_gen (or a screenshot tool) just produced.
func extractImages(text string) []string {
	var out []string
	seen := map[string]bool{}
	for _, m := range imagePathRe.FindAllString(text, 6) {
		p := m
		if strings.HasPrefix(p, "~") {
			p = home() + p[1:]
		}
		if seen[p] || !fileExists(p) {
			continue
		}
		seen[p] = true
		out = append(out, p)
	}
	return out
}

func emitAnswer(text string) error {
	text = strings.TrimSpace(text)
	if text == "" {
		text = "(no answer)"
	}
	b, err := json.Marshal(askAnswer{Text: text, Images: extractImages(text)})
	if err != nil {
		return err
	}
	fmt.Println("@answer " + string(b))
	return nil
}

func emitAsk(kind, detail string) {
	fmt.Println("@" + kind + " " + strings.ReplaceAll(detail, "\n", " "))
}
