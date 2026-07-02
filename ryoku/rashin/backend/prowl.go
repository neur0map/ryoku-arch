package main

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// prowl.go surfaces prowl-agent (the code-intelligence indexer) on the
// dashboard: index state, doctor counts, hotspots, and search over the Ryoku
// checkout. prowl is an optional, user-installed tool (no license for
// redistribution yet), so every path degrades gracefully when it or the
// index is absent.

type ProwlReport struct {
	Installed bool   `json:"installed"`
	Version   string `json:"version,omitempty"`
	Repo      string `json:"repo,omitempty"`
	Indexed   bool   `json:"indexed"`
	Files     int    `json:"files,omitempty"`
	Symbols   int    `json:"symbols,omitempty"`
	Doctor    *struct {
		Errors int `json:"errors"`
		Warns  int `json:"warns"`
		Infos  int `json:"infos"`
	} `json:"doctor,omitempty"`
	Hotspots []ProwlHotspot `json:"hotspots,omitempty"`
}

type ProwlHotspot struct {
	File string `json:"file"`
	In   int    `json:"in"`
}

type ProwlHit struct {
	File string `json:"file"`
	Line int    `json:"line"`
	Text string `json:"text"`
}

func findProwl() (string, bool) {
	p, err := exec.LookPath("prowl-agent")
	return p, err == nil
}

// prowlRepo picks the repo the dashboard reports on: an explicit override,
// else the Ryoku checkout when it carries an index.
func prowlRepo() string {
	if v := os.Getenv("RYOKU_RASHIN_REPO"); v != "" {
		if dirExists(filepath.Join(v, ".prowl")) {
			return v
		}
	}
	for _, cand := range []string{
		filepath.Join(home(), "Work", "ryoku-arch"),
		filepath.Join(home(), "ryoku-arch"),
	} {
		if dirExists(filepath.Join(cand, ".prowl")) {
			return cand
		}
	}
	return ""
}

func prowlExec(repo string, timeout time.Duration, args ...string) ([]byte, error) {
	bin, ok := findProwl()
	if !ok {
		return nil, os.ErrNotExist
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, args...)
	cmd.Dir = repo
	return cmd.Output()
}

// prowlCache: the report execs three prowl calls; a 60s cache keeps the
// overview cheap under the dashboard's polling.
var prowlCache struct {
	mu   sync.Mutex
	at   time.Time
	data ProwlReport
}

func ProwlReportNow() ProwlReport {
	prowlCache.mu.Lock()
	defer prowlCache.mu.Unlock()
	if time.Since(prowlCache.at) < 60*time.Second {
		return prowlCache.data
	}
	rep := buildProwlReport()
	prowlCache.at, prowlCache.data = time.Now(), rep
	return rep
}

func buildProwlReport() ProwlReport {
	var rep ProwlReport
	bin, ok := findProwl()
	if !ok {
		return rep
	}
	rep.Installed = true
	if out, err := exec.Command(bin, "version").Output(); err == nil {
		rep.Version = strings.TrimSpace(firstLine(string(out)))
	}
	repo := prowlRepo()
	if repo == "" {
		return rep
	}
	rep.Repo = repo

	// status: file and symbol counts prove the index is live.
	if out, err := prowlExec(repo, 15*time.Second, "status", "--json"); err == nil {
		var st struct {
			Files   int `json:"files"`
			Symbols int `json:"symbols"`
			Counts  struct {
				Files   int `json:"files"`
				Symbols int `json:"symbols"`
			} `json:"counts"`
		}
		if json.Unmarshal(out, &st) == nil {
			rep.Files = max(st.Files, st.Counts.Files)
			rep.Symbols = max(st.Symbols, st.Counts.Symbols)
			rep.Indexed = rep.Files > 0
		}
	}
	if !rep.Indexed {
		return rep
	}

	// doctor: finding counts only; the 0-100 score saturates on big repos.
	if out, err := prowlExec(repo, 20*time.Second, "doctor", "--json"); err == nil {
		var doc struct {
			Findings []struct {
				Severity string `json:"severity"`
			} `json:"findings"`
		}
		if json.Unmarshal(out, &doc) == nil {
			d := &struct {
				Errors int `json:"errors"`
				Warns  int `json:"warns"`
				Infos  int `json:"infos"`
			}{}
			for _, f := range doc.Findings {
				switch strings.ToLower(f.Severity) {
				case "error":
					d.Errors++
				case "warn", "warning":
					d.Warns++
				default:
					d.Infos++
				}
			}
			rep.Doctor = d
		}
	}

	// hotspots --json = {fan_in:[{file,in}], largest:[...], ...}
	if out, err := prowlExec(repo, 15*time.Second, "hotspots", "--json"); err == nil {
		var hs struct {
			FanIn []struct {
				File string `json:"file"`
				In   int    `json:"in"`
			} `json:"fan_in"`
		}
		if json.Unmarshal(out, &hs) == nil {
			for i, h := range hs.FanIn {
				if i >= 5 {
					break
				}
				rep.Hotspots = append(rep.Hotspots, ProwlHotspot{File: h.File, In: h.In})
			}
		}
	}
	return rep
}

// ProwlSearch runs a compact content search over the indexed repo.
func ProwlSearch(query string) []ProwlHit {
	repo := prowlRepo()
	if repo == "" || strings.TrimSpace(query) == "" {
		return nil
	}
	// search --json --compact = [{file,start_line,end_line,snippet?}]
	out, err := prowlExec(repo, 15*time.Second, "search", query, "--json", "--limit", "20")
	if err != nil {
		return nil
	}
	var hits []struct {
		File      string `json:"file"`
		StartLine int    `json:"start_line"`
		Snippet   string `json:"snippet"`
	}
	if json.Unmarshal(out, &hits) != nil {
		return nil
	}
	res := make([]ProwlHit, 0, len(hits))
	for _, h := range hits {
		text := strings.TrimSpace(h.Snippet)
		if len(text) > 160 {
			text = text[:160]
		}
		res = append(res, ProwlHit{File: h.File, Line: h.StartLine, Text: text})
	}
	return res
}
