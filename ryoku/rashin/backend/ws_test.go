package main

import "testing"

func TestTranscriptRecordsConversationOnly(t *testing.T) {
	h := newChatHub()
	h.broadcast(wsOut{Type: "state", State: "busy"})
	h.broadcast(wsOut{Type: "user_text", Text: "q"})
	h.broadcast(wsOut{Type: "agent_text", Text: "a"})
	h.broadcast(wsOut{Type: "usage", Size: 10, Used: 1})
	h.broadcast(wsOut{Type: "tool", ID: "t1", Status: "completed"})
	h.broadcast(wsOut{Type: "turn_end", StopReason: "end_turn"})

	if len(h.transcript) != 4 {
		t.Fatalf("transcript = %d frames, want 4 (no state/usage)", len(h.transcript))
	}
	if h.transcript[0].Type != "user_text" || h.transcript[3].Type != "turn_end" {
		t.Fatalf("transcript order wrong: %+v", h.transcript)
	}
}

func TestTranscriptCapKeepsTail(t *testing.T) {
	h := newChatHub()
	for i := 0; i < transcriptCap+10; i++ {
		h.broadcast(wsOut{Type: "agent_text", Text: "x"})
	}
	if len(h.transcript) > transcriptCap {
		t.Fatalf("transcript grew past cap: %d", len(h.transcript))
	}
}

func TestExtractImagesFindsRealFilesOnly(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HOME", dir)
	real := dir + "/shot.png"
	if err := writeFile(real, []byte("png")); err != nil {
		t.Fatal(err)
	}
	text := "Saved to " + real + " and also /nope/missing.png plus ~/shot.png"
	got := extractImages(text)
	if len(got) != 1 || got[0] != real {
		t.Fatalf("images = %v, want just %q", got, real)
	}
}

func writeFile(p string, b []byte) error {
	return atomicWrite(p, b, 0o644)
}
