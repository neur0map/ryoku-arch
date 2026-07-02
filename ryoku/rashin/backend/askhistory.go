package main

import (
	"bufio"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// askhistory.go persists recent quick asks so the launcher's "\resume" can
// list them and recall a cached answer instantly, no model call. It is a
// small append-capped JSONL under XDG_STATE_HOME, newest last.

type askRecord struct {
	At       string      `json:"at"` // RFC3339
	Question string      `json:"q"`
	Answer   string      `json:"a"`
	Images   []string    `json:"images,omitempty"`
	Actions  []askAction `json:"actions,omitempty"`
}

const askHistoryCap = 40

func askHistoryPath() string {
	return filepath.Join(xdgState(), "ryoku", "rashin-asks.jsonl")
}

var askHistoryMu sync.Mutex

// recordAsk appends one completed ask, trimming the file to the cap.
func recordAsk(rec askRecord) {
	if strings.TrimSpace(rec.Answer) == "" || strings.HasPrefix(rec.Answer, "(no answer") {
		return
	}
	askHistoryMu.Lock()
	defer askHistoryMu.Unlock()

	recs := readAskHistoryLocked()
	recs = append(recs, rec)
	if len(recs) > askHistoryCap {
		recs = recs[len(recs)-askHistoryCap:]
	}
	p := askHistoryPath()
	if os.MkdirAll(filepath.Dir(p), 0o755) != nil {
		return
	}
	var b strings.Builder
	enc := json.NewEncoder(&b)
	for _, r := range recs {
		_ = enc.Encode(r)
	}
	tmp := p + ".tmp"
	if os.WriteFile(tmp, []byte(b.String()), 0o644) == nil {
		_ = os.Rename(tmp, p)
	}
}

func readAskHistoryLocked() []askRecord {
	f, err := os.Open(askHistoryPath())
	if err != nil {
		return nil
	}
	defer f.Close()
	var out []askRecord
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 64*1024), 4<<20)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		var r askRecord
		if json.Unmarshal([]byte(line), &r) == nil && r.Question != "" {
			out = append(out, r)
		}
	}
	return out
}

// RecentAsks returns up to n asks, newest first, for the resume list.
func RecentAsks(n int) []askRecord {
	askHistoryMu.Lock()
	recs := readAskHistoryLocked()
	askHistoryMu.Unlock()
	// newest first
	for i, j := 0, len(recs)-1; i < j; i, j = i+1, j-1 {
		recs[i], recs[j] = recs[j], recs[i]
	}
	if n > 0 && len(recs) > n {
		recs = recs[:n]
	}
	return recs
}

func nowRFC3339() string { return time.Now().Format(time.RFC3339) }
