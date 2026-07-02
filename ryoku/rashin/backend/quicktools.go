package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// quicktools.go is the fast lane's toolset: a small set of READ-ONLY,
// Go-native tools that run in milliseconds, so a quick ask can look things up
// without spinning hermes's full Python agent. Anything heavier (image
// generation, a real browser, running skills, writing files) is not here on
// purpose: the model escalates those to the hermes session with the
// TOOLS_REQUIRED sentinel. Every tool is safe by construction, so no approval
// gate is needed on this path.

// quickToolSchemas is the OpenAI function-calling schema advertised to the
// model on the fast lane.
func quickToolSchemas() []map[string]any {
	strProp := func(desc string) map[string]any {
		return map[string]any{"type": "string", "description": desc}
	}
	fn := func(name, desc string, props map[string]any, required []string) map[string]any {
		return map[string]any{
			"type": "function",
			"function": map[string]any{
				"name":        name,
				"description": desc,
				"parameters": map[string]any{
					"type":       "object",
					"properties": props,
					"required":   required,
				},
			},
		}
	}
	return []map[string]any{
		fn("system_query", "Read live system state on this Ryoku (Arch) machine.",
			map[string]any{"topic": map[string]any{
				"type":        "string",
				"enum":        []string{"packages", "updates", "service", "processes", "disk", "kernel", "gpu", "network"},
				"description": "what to look up",
			}, "arg": strProp("optional filter, e.g. a package or service name")},
			[]string{"topic"}),
		fn("read_file", "Read a text file under $HOME, /etc, /usr/share, or /proc.",
			map[string]any{"path": strProp("absolute or ~ path")}, []string{"path"}),
		fn("list_dir", "List a directory under $HOME or /etc.",
			map[string]any{"path": strProp("absolute or ~ path")}, []string{"path"}),
		fn("search_code", "Search the Ryoku source with prowl-agent (when indexed).",
			map[string]any{"query": strProp("free text or a symbol name")}, []string{"query"}),
		fn("fetch_url", "Fetch a public http(s) URL as text (readable content).",
			map[string]any{"url": strProp("an http or https URL")}, []string{"url"}),
	}
}

// execQuickTool runs one tool call and returns a compact text result. It never
// errors out the turn: a failure is returned as text the model can read.
func execQuickTool(ctx context.Context, name, argsJSON string) string {
	var a struct {
		Topic string `json:"topic"`
		Arg   string `json:"arg"`
		Path  string `json:"path"`
		Query string `json:"query"`
		URL   string `json:"url"`
	}
	_ = json.Unmarshal([]byte(argsJSON), &a)
	switch name {
	case "system_query":
		return toolSystemQuery(ctx, a.Topic, a.Arg)
	case "read_file":
		return toolReadFile(a.Path)
	case "list_dir":
		return toolListDir(a.Path)
	case "search_code":
		return toolSearchCode(a.Query)
	case "fetch_url":
		return toolFetchURL(ctx, a.URL)
	default:
		return "error: unknown tool " + name
	}
}

func runCapped(ctx context.Context, cap int, name string, args ...string) string {
	c, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	out, err := exec.CommandContext(c, name, args...).CombinedOutput()
	s := string(out)
	if len(s) > cap {
		s = s[:cap] + "\n...(truncated)"
	}
	if err != nil && strings.TrimSpace(s) == "" {
		return "error: " + err.Error()
	}
	return strings.TrimSpace(s)
}

func toolSystemQuery(ctx context.Context, topic, arg string) string {
	switch topic {
	case "packages":
		if arg != "" {
			return runCapped(ctx, 4096, "pacman", "-Qi", arg)
		}
		return runCapped(ctx, 2048, "sh", "-c", "pacman -Qq | wc -l")
	case "updates":
		return runCapped(ctx, 4096, "sh", "-c", "checkupdates 2>/dev/null | head -50 || echo 'no updates or checkupdates unavailable'")
	case "service":
		if arg == "" {
			return "error: service topic needs a name in arg"
		}
		return runCapped(ctx, 4096, "systemctl", "status", "--no-pager", "--lines=5", arg)
	case "processes":
		return runCapped(ctx, 4096, "sh", "-c", "ps -eo pid,pcpu,pmem,comm --sort=-pcpu | head -16")
	case "disk":
		return runCapped(ctx, 2048, "df", "-h", "--output=source,size,used,avail,pcent,target", "/", "/home")
	case "kernel":
		return runCapped(ctx, 512, "uname", "-r")
	case "gpu":
		if _, err := exec.LookPath("ryoku-gpu"); err == nil {
			return runCapped(ctx, 2048, "ryoku-gpu", "status")
		}
		return runCapped(ctx, 2048, "sh", "-c", "lspci | grep -iE 'vga|3d'")
	case "network":
		return runCapped(ctx, 2048, "sh", "-c", "ip -brief addr 2>/dev/null | head -12")
	default:
		return "error: unknown topic " + topic
	}
}

// safeReadRoots bounds read_file to config, system share, and /proc: enough to
// answer real questions, nothing under the user's private data by accident.
var safeReadRoots = []string{"/etc", "/usr/share", "/proc", "/sys/class"}

func withinSafeRoot(p string) bool {
	if strings.HasPrefix(p, home()) {
		return true
	}
	for _, r := range safeReadRoots {
		if p == r || strings.HasPrefix(p, r+"/") {
			return true
		}
	}
	return false
}

func toolReadFile(path string) string {
	p := filepath.Clean(expandHome(strings.TrimSpace(path)))
	if !withinSafeRoot(p) {
		return "error: reads are limited to $HOME, /etc, /usr/share, /proc"
	}
	fi, err := os.Stat(p)
	if err != nil {
		return "error: " + err.Error()
	}
	if fi.IsDir() {
		return "error: that is a directory, use list_dir"
	}
	b, err := os.ReadFile(p)
	if err != nil {
		return "error: " + err.Error()
	}
	if len(b) > 32*1024 {
		b = b[:32*1024]
		return string(b) + "\n...(truncated at 32KB)"
	}
	return string(b)
}

func toolListDir(path string) string {
	p := filepath.Clean(expandHome(strings.TrimSpace(path)))
	if !strings.HasPrefix(p, home()) && !strings.HasPrefix(p, "/etc") {
		return "error: listing is limited to $HOME and /etc"
	}
	entries, err := os.ReadDir(p)
	if err != nil {
		return "error: " + err.Error()
	}
	var b strings.Builder
	for i, e := range entries {
		if i >= 200 {
			fmt.Fprintf(&b, "...(%d more)\n", len(entries)-200)
			break
		}
		name := e.Name()
		if e.IsDir() {
			name += "/"
		}
		b.WriteString(name + "\n")
	}
	return strings.TrimSpace(b.String())
}

func toolSearchCode(query string) string {
	hits := ProwlSearch(query)
	if len(hits) == 0 {
		if _, ok := findProwl(); !ok {
			return "prowl-agent is not installed; code search is unavailable"
		}
		return "no matches"
	}
	var b strings.Builder
	for i, h := range hits {
		if i >= 12 {
			break
		}
		fmt.Fprintf(&b, "%s:%d  %s\n", h.File, h.Line, h.Text)
	}
	return strings.TrimSpace(b.String())
}

// toolFetchURL reads a public URL as text, refusing loopback and private
// ranges so the fast lane cannot be pointed at the daemon or the LAN.
func toolFetchURL(ctx context.Context, raw string) string {
	raw = strings.TrimSpace(raw)
	if !strings.HasPrefix(raw, "http://") && !strings.HasPrefix(raw, "https://") {
		return "error: only http(s) URLs"
	}
	if isPrivateURL(raw) {
		return "error: refusing loopback or private-network URLs"
	}
	c, cancel := context.WithTimeout(ctx, 12*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(c, http.MethodGet, raw, nil)
	if err != nil {
		return "error: " + err.Error()
	}
	req.Header.Set("User-Agent", "ryoku-rashin/quick")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "error: " + err.Error()
	}
	defer resp.Body.Close()
	buf := make([]byte, 24*1024)
	n, _ := resp.Body.Read(buf)
	text := stripTags(string(buf[:n]))
	if len(text) > 8*1024 {
		text = text[:8*1024] + "\n...(truncated)"
	}
	return fmt.Sprintf("[%d] %s\n%s", resp.StatusCode, raw, strings.TrimSpace(text))
}

func isPrivateURL(raw string) bool {
	host := raw
	if i := strings.Index(host, "://"); i >= 0 {
		host = host[i+3:]
	}
	if i := strings.IndexAny(host, "/:"); i >= 0 {
		host = host[:i]
	}
	if host == "localhost" {
		return true
	}
	ips, err := net.LookupIP(host)
	if err != nil {
		return false // let the request fail naturally rather than block a real host
	}
	for _, ip := range ips {
		if ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() {
			return true
		}
	}
	return false
}

// stripTags is a crude html-to-text: drop tags and script/style bodies so a
// fetched page reads as content, not markup.
func stripTags(s string) string {
	for _, tag := range []string{"script", "style"} {
		for {
			lo := strings.Index(strings.ToLower(s), "<"+tag)
			if lo < 0 {
				break
			}
			hi := strings.Index(strings.ToLower(s[lo:]), "</"+tag+">")
			if hi < 0 {
				s = s[:lo]
				break
			}
			s = s[:lo] + s[lo+hi+len(tag)+3:]
		}
	}
	var b strings.Builder
	depth := 0
	for _, r := range s {
		switch r {
		case '<':
			depth++
		case '>':
			if depth > 0 {
				depth--
			}
		default:
			if depth == 0 {
				b.WriteRune(r)
			}
		}
	}
	lines := strings.Split(b.String(), "\n")
	var keep []string
	for _, ln := range lines {
		if t := strings.TrimSpace(ln); t != "" {
			keep = append(keep, t)
		}
	}
	return strings.Join(keep, "\n")
}
