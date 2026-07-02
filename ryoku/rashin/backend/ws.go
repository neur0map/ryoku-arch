package main

import (
	"context"
	"encoding/json"
	"strconv"
	"sync"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

// ws.go fans one shared hermes ACP session out to every dashboard chat
// socket, and pushes vitals samples. The session is lazy: hermes spawns on
// the first chat client, survives client disconnects, and is restarted on
// the next user message after a death.

type wsOut struct {
	Type       string        `json:"type"`
	State      string        `json:"state,omitempty"`
	Error      string        `json:"error,omitempty"`
	Text       string        `json:"text,omitempty"`
	ID         string        `json:"id,omitempty"`
	Title      string        `json:"title,omitempty"`
	Kind       string        `json:"kind,omitempty"`
	Status     string        `json:"status,omitempty"`
	RequestID  string        `json:"requestId,omitempty"`
	Options    []PermOption  `json:"options,omitempty"`
	StopReason string        `json:"stopReason,omitempty"`
	Models     []ModelInfo   `json:"models,omitempty"`
	Current    string        `json:"current,omitempty"`
	Commands   []CommandInfo `json:"commands,omitempty"`
	SessionID  string        `json:"sessionId,omitempty"`
	Size       int           `json:"size,omitempty"`
	Used       int           `json:"used,omitempty"`
	Sessions   []SessionMeta `json:"sessions,omitempty"`
}

type wsIn struct {
	Type      string        `json:"type"`
	Text      string        `json:"text"`
	RequestID string        `json:"requestId"`
	OptionID  string        `json:"optionId"`
	Images    []PromptImage `json:"images"`
	ModelID   string        `json:"modelId"`
	SessionID string        `json:"sessionId"`
}

type chatClient struct {
	ws  *websocket.Conn
	out chan wsOut
}

type chatHub struct {
	mu       sync.Mutex
	conn     *acpConn
	clients  map[*chatClient]bool
	last     wsOut // last state frame, replayed to joiners
	models   wsOut // last models frame, replayed to joiners
	commands wsOut // last commands frame, replayed to joiners
}

func newChatHub() *chatHub {
	return &chatHub{
		clients: map[*chatClient]bool{},
		last:    wsOut{Type: "state", State: "starting"},
	}
}

func (h *chatHub) broadcast(m wsOut) {
	h.mu.Lock()
	if m.Type == "state" {
		h.last = m
	}
	for c := range h.clients {
		select {
		case c.out <- m:
		default: // slow client: drop frame rather than block the hub
		}
	}
	h.mu.Unlock()
}

// ensureConn starts hermes if there is no live session. Called with h.mu held.
func (h *chatHub) ensureConnLocked() {
	if h.conn != nil {
		return
	}
	h.last = wsOut{Type: "state", State: "starting"}
	conn, err := startACP(VaultDir())
	if err != nil {
		h.conn = nil
		h.last = wsOut{Type: "state", State: "dead", Error: err.Error()}
		go h.broadcast(h.last)
		return
	}
	h.conn = conn
	go func() {
		if err := conn.Initialize(VaultDir()); err != nil {
			h.broadcast(wsOut{Type: "state", State: "dead", Error: err.Error()})
			h.dropConn(conn)
			return
		}
		h.broadcast(wsOut{Type: "state", State: "ready"})
	}()
	go h.pump(conn)
}

func (h *chatHub) dropConn(c *acpConn) {
	h.mu.Lock()
	if h.conn == c {
		h.conn = nil
	}
	h.mu.Unlock()
	c.Close()
}

func (h *chatHub) pump(c *acpConn) {
	for ev := range c.Events() {
		switch ev.Type {
		case "state":
			h.broadcast(wsOut{Type: "state", State: ev.State, Error: ev.Err})
			if ev.State == "dead" {
				h.dropConn(c)
			}
		case "agent_text":
			h.broadcast(wsOut{Type: "agent_text", Text: ev.Text})
		case "agent_thought":
			h.broadcast(wsOut{Type: "agent_thought", Text: ev.Text})
		case "user_text":
			h.broadcast(wsOut{Type: "user_text", Text: ev.Text})
		case "tool":
			h.broadcast(wsOut{Type: "tool", ID: ev.ToolID, Title: ev.ToolTitle, Kind: ev.ToolKind, Status: ev.ToolStatus})
		case "permission":
			h.broadcast(wsOut{Type: "permission", RequestID: ev.RequestID, Title: ev.PermTitle, Options: ev.Options})
		case "turn_end":
			h.broadcast(wsOut{Type: "turn_end", StopReason: ev.StopReason})
			h.broadcast(wsOut{Type: "state", State: "ready"})
		case "models":
			m := wsOut{Type: "models", Models: ev.Models, Current: ev.CurrentModel}
			h.mu.Lock()
			h.models = m
			h.mu.Unlock()
			h.broadcast(m)
		case "commands":
			m := wsOut{Type: "commands", Commands: ev.Commands}
			h.mu.Lock()
			h.commands = m
			h.mu.Unlock()
			h.broadcast(m)
		case "session_info":
			h.broadcast(wsOut{Type: "session_info", SessionID: ev.SessionID, Title: ev.SessionTitle})
		case "usage":
			h.broadcast(wsOut{Type: "usage", Size: ev.UsageSize, Used: ev.UsageUsed})
		case "replay_start":
			h.broadcast(wsOut{Type: "replay_start"})
		case "replay_end":
			h.broadcast(wsOut{Type: "replay_end"})
		}
	}
	h.dropConn(c)
}

func (h *chatHub) handle(ctx context.Context, ws *websocket.Conn) {
	cl := &chatClient{ws: ws, out: make(chan wsOut, 128)}
	h.mu.Lock()
	h.clients[cl] = true
	h.ensureConnLocked()
	greeting := []wsOut{h.last}
	if h.models.Type != "" {
		greeting = append(greeting, h.models)
	}
	if h.commands.Type != "" {
		greeting = append(greeting, h.commands)
	}
	h.mu.Unlock()

	writerDone := make(chan struct{})
	go func() {
		defer close(writerDone)
		for _, g := range greeting {
			_ = wsjson.Write(ctx, ws, g)
		}
		for m := range cl.out {
			if wsjson.Write(ctx, ws, m) != nil {
				return
			}
		}
	}()

	for {
		var in wsIn
		if wsjson.Read(ctx, ws, &in) != nil {
			break
		}
		h.mu.Lock()
		if h.conn == nil && in.Type == "user" {
			h.ensureConnLocked()
		}
		conn := h.conn
		h.mu.Unlock()
		if conn == nil {
			continue
		}
		switch in.Type {
		case "user":
			h.broadcast(wsOut{Type: "state", State: "busy"})
			conn.Prompt(in.Text, in.Images)
		case "cancel":
			conn.Cancel()
		case "permission":
			if id, err := strconv.ParseInt(in.RequestID, 10, 64); err == nil {
				conn.RespondPermission(id, in.OptionID)
			}
		case "set_model":
			if in.ModelID != "" {
				go func(c *acpConn, id string) {
					if err := c.SetModel(id); err == nil {
						h.mu.Lock()
						m := h.models
						m.Current = id
						h.models = m
						h.mu.Unlock()
						h.broadcast(m)
					}
				}(conn, in.ModelID)
			}
		case "history":
			go func(c *acpConn, target *chatClient) {
				sessions := c.ListSessions()
				h.mu.Lock()
				if h.clients[target] {
					select {
					case target.out <- wsOut{Type: "history", Sessions: sessions}:
					default:
					}
				}
				h.mu.Unlock()
			}(conn, cl)
		case "load":
			if in.SessionID != "" {
				go func(c *acpConn, id string) {
					h.broadcast(wsOut{Type: "state", State: "busy"})
					if err := c.LoadSession(id); err != nil {
						h.broadcast(wsOut{Type: "state", State: "ready", Error: "load failed: " + err.Error()})
						return
					}
					h.broadcast(wsOut{Type: "state", State: "ready"})
				}(conn, in.SessionID)
			}
		case "new":
			go func(c *acpConn) {
				h.broadcast(wsOut{Type: "replay_start"})
				h.broadcast(wsOut{Type: "replay_end"})
				if err := c.NewSession(); err != nil {
					h.broadcast(wsOut{Type: "state", State: "dead", Error: err.Error()})
					return
				}
				h.broadcast(wsOut{Type: "state", State: "ready"})
			}(conn)
		}
	}

	h.mu.Lock()
	delete(h.clients, cl)
	close(cl.out)
	h.mu.Unlock()
	<-writerDone
}

func serveVitalsWS(ctx context.Context, ws *websocket.Conn) {
	t := time.NewTicker(2 * time.Second)
	defer t.Stop()
	send := func() bool {
		b, err := json.Marshal(SampleVitals())
		if err != nil {
			return false
		}
		return ws.Write(ctx, websocket.MessageText, b) == nil
	}
	if !send() {
		return
	}
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if !send() {
				return
			}
		}
	}
}
