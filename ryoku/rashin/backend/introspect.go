package main

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// introspect.go reads Hermes's install (skills, toolsets, memory provider,
// session history) so the dashboard can show what the resident agent knows
// and has grown, all without running hermes itself.

const rashinVersion = "0.2.0"

// ---- skills ----------------------------------------------------------------

type Skill struct {
	Name        string `json:"name"`
	Dir         string `json:"dir"`
	Description string `json:"description"`
	Version     string `json:"version,omitempty"`
	Origin      string `json:"origin"` // bundled | hub | agent
}

type SkillCategory struct {
	Name   string  `json:"name"`
	Skills []Skill `json:"skills"`
}

type ToolFamily struct {
	Family string   `json:"family"`
	Tools  []string `json:"tools"`
}

type SkillsReport struct {
	Counts     map[string]int  `json:"counts"`
	Categories []SkillCategory `json:"categories"`
	Toolbelt   []ToolFamily    `json:"toolbelt"`
}

func hermesSkillsDir() string { return filepath.Join(home(), ".hermes", "skills") }

// bundledSkillNames parses skills/.bundled_manifest (name:md5 per line).
func bundledSkillNames() map[string]bool {
	out := map[string]bool{}
	b, err := os.ReadFile(filepath.Join(hermesSkillsDir(), ".bundled_manifest"))
	if err != nil {
		return out
	}
	for _, line := range strings.Split(string(b), "\n") {
		if name, _, ok := strings.Cut(strings.TrimSpace(line), ":"); ok && name != "" {
			out[name] = true
		}
	}
	return out
}

// hubSkillNames parses skills/.hub/lock.json when the skills hub is in use.
func hubSkillNames() map[string]bool {
	out := map[string]bool{}
	b, err := os.ReadFile(filepath.Join(hermesSkillsDir(), ".hub", "lock.json"))
	if err != nil {
		return out
	}
	var doc map[string]any
	if json.Unmarshal(b, &doc) != nil {
		return out
	}
	for k := range doc {
		out[k] = true
	}
	return out
}

// skillFrontmatter pulls name/description/version from a SKILL.md header.
func skillFrontmatter(path string) (name, desc, version string) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "", "", ""
	}
	s := string(b)
	if !strings.HasPrefix(s, "---") {
		return "", "", ""
	}
	body := s[3:]
	end := strings.Index(body, "\n---")
	if end < 0 {
		return "", "", ""
	}
	for _, line := range strings.Split(body[:end], "\n") {
		t := strings.TrimSpace(line)
		if v, ok := strings.CutPrefix(t, "name:"); ok && name == "" {
			name = strings.Trim(strings.TrimSpace(v), `"'`)
		}
		if v, ok := strings.CutPrefix(t, "description:"); ok && desc == "" {
			desc = strings.Trim(strings.TrimSpace(v), `"'`)
		}
		if v, ok := strings.CutPrefix(t, "version:"); ok && version == "" {
			version = strings.Trim(strings.TrimSpace(v), `"'`)
		}
	}
	return name, desc, version
}

// SkillsReportNow walks ~/.hermes/skills: both <cat>/<skill>/SKILL.md and
// loose <skill>/SKILL.md layouts. Provenance is by name: bundled manifest
// first, hub lock second, anything else is agent-grown.
func SkillsReportNow() SkillsReport {
	rep := SkillsReport{
		Counts:   map[string]int{"bundled": 0, "hub": 0, "agent": 0},
		Toolbelt: toolbeltNow(),
	}
	root := hermesSkillsDir()
	if !dirExists(root) {
		return rep
	}
	bundled, hub := bundledSkillNames(), hubSkillNames()
	cats := map[string][]Skill{}

	addSkill := func(cat, dir, skillMD string) {
		name, desc, version := skillFrontmatter(skillMD)
		if name == "" {
			name = filepath.Base(dir)
		}
		origin := "agent"
		if bundled[name] || bundled[filepath.Base(dir)] {
			origin = "bundled"
		} else if hub[name] || hub[filepath.Base(dir)] {
			origin = "hub"
		}
		rep.Counts[origin]++
		rel, _ := filepath.Rel(root, dir)
		cats[cat] = append(cats[cat], Skill{
			Name: name, Dir: rel, Description: desc, Version: version, Origin: origin,
		})
	}

	_ = filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() && strings.HasPrefix(d.Name(), ".") {
			return filepath.SkipDir
		}
		if d.IsDir() || d.Name() != "SKILL.md" {
			return nil
		}
		dir := filepath.Dir(p)
		rel, rerr := filepath.Rel(root, dir)
		if rerr != nil {
			return nil
		}
		cat := "general"
		if parts := strings.Split(rel, string(filepath.Separator)); len(parts) > 1 {
			cat = parts[0]
		}
		addSkill(cat, dir, p)
		return filepath.SkipDir // one skill per directory; skip nested rescans
	})

	names := make([]string, 0, len(cats))
	for k := range cats {
		names = append(names, k)
	}
	sort.Strings(names)
	for _, n := range names {
		sort.Slice(cats[n], func(i, j int) bool { return cats[n][i].Name < cats[n][j].Name })
		rep.Categories = append(rep.Categories, SkillCategory{Name: n, Skills: cats[n]})
	}
	return rep
}

// toolFamilies maps hermes toolset names into display families.
var toolFamilies = []struct {
	family string
	sets   []string
}{
	{"System & Code", []string{"terminal", "file", "code_execution", "computer_use"}},
	{"Web", []string{"web", "browser"}},
	{"Mind", []string{"memory", "session_search", "skills", "todo", "clarify"}},
	{"Media", []string{"image_gen", "vision", "tts", "voice"}},
	{"Orchestration", []string{"delegation", "cronjob", "gateway"}},
}

// toolbeltNow parses platform_toolsets.cli from config.yaml (block list form).
func toolbeltNow() []ToolFamily {
	b, err := os.ReadFile(hermesConfig())
	if err != nil {
		return nil
	}
	enabled := map[string]bool{}
	lines := strings.Split(string(b), "\n")
	inPlatform, inCLI := false, false
	for _, line := range lines {
		t := strings.TrimSpace(line)
		indent := len(line) - len(strings.TrimLeft(line, " \t"))
		switch {
		case strings.HasPrefix(t, "platform_toolsets:"):
			inPlatform, inCLI = true, false
		case inPlatform && indent == 0 && t != "":
			inPlatform, inCLI = false, false
		case inPlatform && strings.HasPrefix(t, "cli:"):
			inCLI = true
		case inPlatform && inCLI && strings.HasPrefix(t, "- "):
			enabled[strings.TrimSpace(strings.TrimPrefix(t, "- "))] = true
		case inPlatform && inCLI && t != "" && !strings.HasPrefix(t, "- "):
			inCLI = false
		}
	}
	if len(enabled) == 0 {
		return nil
	}
	var out []ToolFamily
	seen := map[string]bool{}
	for _, f := range toolFamilies {
		var tools []string
		for _, s := range f.sets {
			if enabled[s] {
				tools = append(tools, s)
				seen[s] = true
			}
		}
		if len(tools) > 0 {
			out = append(out, ToolFamily{Family: f.family, Tools: tools})
		}
	}
	var rest []string
	for s := range enabled {
		if !seen[s] {
			rest = append(rest, s)
		}
	}
	if len(rest) > 0 {
		sort.Strings(rest)
		out = append(out, ToolFamily{Family: "Other", Tools: rest})
	}
	return out
}

// ---- memory ----------------------------------------------------------------

type MemoryReport struct {
	Provider struct {
		Kind          string `json:"kind"`
		ObsidianVault string `json:"obsidianVault,omitempty"`
	} `json:"provider"`
	Files struct {
		MemoryMd    bool  `json:"memoryMd"`
		MemoryBytes int64 `json:"memoryBytes"`
		UserMd      bool  `json:"userMd"`
	} `json:"files"`
	Graph    GraphModel     `json:"graph"`
	Heatmap  []HeatmapDay   `json:"heatmap"`
	Sessions []SessionEntry `json:"sessions"`
}

type GraphNode struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Group string `json:"group"`
	Size  int64  `json:"size"`
}

type GraphLink struct {
	Source string `json:"source"`
	Target string `json:"target"`
}

type GraphModel struct {
	Nodes []GraphNode `json:"nodes"`
	Links []GraphLink `json:"links"`
}

type HeatmapDay struct {
	Date  string `json:"date"`
	Count int    `json:"count"`
}

type SessionEntry struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Model     string `json:"model"`
	Messages  int    `json:"messages"`
	StartedAt string `json:"startedAt"`
	Source    string `json:"source"`
}

// memoryProviderKind reads memory.provider from config.yaml; builtin when unset.
func memoryProviderKind() (kind, obsidianVault string) {
	kind = "builtin"
	b, err := os.ReadFile(hermesConfig())
	if err != nil {
		return kind, ""
	}
	lines := strings.Split(string(b), "\n")
	inMemory := false
	for _, line := range lines {
		t := strings.TrimSpace(line)
		indent := len(line) - len(strings.TrimLeft(line, " \t"))
		switch {
		case strings.HasPrefix(t, "memory:") && indent == 0:
			inMemory = true
		case inMemory && indent == 0 && t != "":
			inMemory = false
		case inMemory:
			if v, ok := strings.CutPrefix(t, "provider:"); ok {
				if p := strings.Trim(strings.TrimSpace(v), `"'`); p != "" && !strings.HasPrefix(p, "#") {
					kind = p
				}
			}
		}
	}
	if v := os.Getenv("OBSIDIAN_VAULT_PATH"); v != "" {
		obsidianVault = v
	} else if env, err := os.ReadFile(filepath.Join(home(), ".hermes", ".env")); err == nil {
		for _, line := range strings.Split(string(env), "\n") {
			if v, ok := strings.CutPrefix(strings.TrimSpace(line), "OBSIDIAN_VAULT_PATH="); ok {
				obsidianVault = strings.Trim(v, `"'`)
			}
		}
	}
	return kind, obsidianVault
}

// buildMemoryGraph turns the vault into nodes and reference links: markdown
// files are nodes, a mention of another vault file's name is an edge.
func buildMemoryGraph() GraphModel {
	g := GraphModel{}
	files, err := VaultTree()
	if err != nil {
		return g
	}
	group := func(rel string) string {
		switch {
		case rel == "AGENTS.md" || rel == "CLAUDE.md":
			return "hub"
		case strings.HasPrefix(rel, "memory/"):
			return "memory"
		case strings.HasPrefix(rel, "journal/"):
			return "journal"
		default:
			return "generated"
		}
	}
	var nodes []GraphNode
	byBase := map[string]string{} // base name -> id
	for _, f := range files {
		if !strings.HasSuffix(f.Path, ".md") || f.Path == "CLAUDE.md" {
			continue
		}
		id := f.Path
		nodes = append(nodes, GraphNode{
			ID:    id,
			Label: strings.TrimSuffix(filepath.Base(id), ".md"),
			Group: group(id),
			Size:  f.Size,
		})
		byBase[filepath.Base(id)] = id
	}
	// Hermes memory joins the graph as its own node when present.
	memPath := hermesMemory()
	if fi, err := os.Stat(memPath); err == nil {
		nodes = append(nodes, GraphNode{ID: "hermes:MEMORY.md", Label: "hermes MEMORY", Group: "hermes", Size: fi.Size()})
		byBase["MEMORY.md"] = "hermes:MEMORY.md"
	}

	var links []GraphLink
	seen := map[string]bool{}
	addLink := func(a, b string) {
		if a == b {
			return
		}
		key := a + "->" + b
		if !seen[key] {
			seen[key] = true
			links = append(links, GraphLink{Source: a, Target: b})
		}
	}
	for _, n := range nodes {
		var content []byte
		if n.ID == "hermes:MEMORY.md" {
			content, _ = os.ReadFile(memPath)
		} else {
			content, _ = ReadVaultFile(n.ID)
		}
		if len(content) == 0 || len(content) > 512*1024 {
			continue
		}
		text := string(content)
		for base, id := range byBase {
			if id == n.ID {
				continue
			}
			if strings.Contains(text, base) {
				addLink(n.ID, id)
			}
		}
	}
	g.Nodes, g.Links = nodes, links
	return g
}

// buildHeatmap counts activity per day over the trailing 26 weeks: journal
// files by name date, sessions by started_at.
func buildHeatmap(sessions []SessionEntry) []HeatmapDay {
	counts := map[string]int{}
	if entries, err := os.ReadDir(filepath.Join(VaultDir(), "journal")); err == nil {
		for _, e := range entries {
			name := strings.TrimSuffix(e.Name(), ".md")
			if _, err := time.Parse("2006-01-02", name); err == nil {
				counts[name]++
			}
		}
	}
	for _, s := range sessions {
		if t, err := time.Parse(time.RFC3339, s.StartedAt); err == nil {
			counts[t.Format("2006-01-02")]++
		}
	}
	days := 26 * 7
	out := make([]HeatmapDay, 0, days)
	today := time.Now()
	for i := days - 1; i >= 0; i-- {
		d := today.AddDate(0, 0, -i).Format("2006-01-02")
		out = append(out, HeatmapDay{Date: d, Count: counts[d]})
	}
	return out
}

// hermesSessions reads session metadata from ~/.hermes/state.db via the
// sqlite3 CLI (base install on Arch), read-only so the live daemon's WAL
// handle is never disturbed. Missing sqlite3 or db degrades to empty.
func hermesSessions(limit int) []SessionEntry {
	db := filepath.Join(home(), ".hermes", "state.db")
	if !fileExists(db) {
		return nil
	}
	bin, err := exec.LookPath("sqlite3")
	if err != nil {
		return nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	q := "SELECT id, COALESCE(title,'') AS title, COALESCE(model,'') AS model, message_count, started_at, source FROM sessions WHERE archived IS NOT 1 ORDER BY started_at DESC LIMIT " + itoa(limit)
	out, err := exec.CommandContext(ctx, bin, "-readonly", "-json", "file:"+db+"?mode=ro", q).Output()
	if err != nil || len(out) == 0 {
		return nil
	}
	var rows []struct {
		ID       string  `json:"id"`
		Title    string  `json:"title"`
		Model    string  `json:"model"`
		Messages int     `json:"message_count"`
		Started  float64 `json:"started_at"`
		Source   string  `json:"source"`
	}
	if json.Unmarshal(out, &rows) != nil {
		return nil
	}
	entries := make([]SessionEntry, 0, len(rows))
	for _, r := range rows {
		entries = append(entries, SessionEntry{
			ID: r.ID, Title: r.Title, Model: r.Model, Messages: r.Messages,
			StartedAt: time.Unix(int64(r.Started), 0).Format(time.RFC3339),
			Source:    r.Source,
		})
	}
	return entries
}

func MemoryReportNow() MemoryReport {
	var rep MemoryReport
	rep.Provider.Kind, rep.Provider.ObsidianVault = memoryProviderKind()
	if fi, err := os.Stat(hermesMemory()); err == nil {
		rep.Files.MemoryMd, rep.Files.MemoryBytes = true, fi.Size()
	}
	rep.Files.UserMd = fileExists(filepath.Join(home(), ".hermes", "memories", "USER.md"))
	rep.Sessions = hermesSessions(50)
	rep.Graph = buildMemoryGraph()
	rep.Heatmap = buildHeatmap(rep.Sessions)
	return rep
}

// ---- about -----------------------------------------------------------------

type AboutReport struct {
	Version string `json:"version"`
	Port    int    `json:"port"`
	Vault   string `json:"vault"`
	Hermes  struct {
		Installed  bool   `json:"installed"`
		Version    string `json:"version"`
		Configured bool   `json:"configured"`
		Provider   string `json:"provider"`
		Model      string `json:"model"`
	} `json:"hermes"`
	Prowl struct {
		Installed bool `json:"installed"`
	} `json:"prowl"`
}

func AboutReportNow(cfg Config) AboutReport {
	var rep AboutReport
	rep.Version = rashinVersion
	rep.Port = cfg.Port
	rep.Vault = VaultDir()
	hs := HermesStatus()
	rep.Hermes.Installed = hs.Installed
	rep.Hermes.Version = hs.Version
	rep.Hermes.Configured = hs.Configured
	rep.Hermes.Provider, rep.Hermes.Model, _ = hermesModel()
	_, rep.Prowl.Installed = findProwl()
	return rep
}

func fileExists(p string) bool {
	fi, err := os.Stat(p)
	return err == nil && !fi.IsDir()
}

func itoa(n int) string {
	if n <= 0 {
		return "50"
	}
	b := [20]byte{}
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	return string(b[i:])
}
