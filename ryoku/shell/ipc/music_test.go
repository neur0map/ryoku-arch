package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestMusicSourceOf(t *testing.T) {
	cases := []struct {
		name   string
		track  musicTrack
		expect string
	}{
		{"spotify client", musicTrack{Player: "org.mpris.MediaPlayer2.spotify"}, musSrcSpotify},
		{"ytmusic page", musicTrack{
			Player: "org.mpris.MediaPlayer2.firefox.instance_1_10",
			URL:    "https://music.youtube.com/watch?v=dQw4w9WgXcQ",
		}, musSrcYtMusic},
		{"youtube page", musicTrack{
			Player: "org.mpris.MediaPlayer2.chromium.instance_2",
			URL:    "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
		}, musSrcYouTube},
		{"local file", musicTrack{Player: "org.mpris.MediaPlayer2.mpv", URL: "file:///music/a.flac"}, musSrcLocal},
		{"bare browser", musicTrack{Player: "org.mpris.MediaPlayer2.firefox.instance_3"}, musSrcBrowser},
		{"unknown player", musicTrack{Player: "org.mpris.MediaPlayer2.cmus"}, musSrcOther},
	}
	for _, c := range cases {
		if got := musicSourceOf(c.track); got != c.expect {
			t.Errorf("%s: musicSourceOf = %q, want %q", c.name, got, c.expect)
		}
	}
}

func TestMusicUpgradeArtSpotify(t *testing.T) {
	// A client that cached the 300 px rendition still yields the 640 px one.
	got := musicUpgradeArt("https://i.scdn.co/image/ab67616d00001e024a2b1e9b0e8ab0f5f0a3d1c2")
	want := "https://i.scdn.co/image/ab67616d0000b2734a2b1e9b0e8ab0f5f0a3d1c2"
	if len(got) != 2 || got[0] != want {
		t.Fatalf("spotify upgrade = %v, want %q first", got, want)
	}
	if got[1] != "https://i.scdn.co/image/ab67616d00001e024a2b1e9b0e8ab0f5f0a3d1c2" {
		t.Errorf("original URL must stay as the fallback, got %q", got[1])
	}
	// The already-full URL is not duplicated.
	if got := musicUpgradeArt(want); len(got) != 1 || got[0] != want {
		t.Errorf("full-size spotify URL rewritten: %v", got)
	}
}

func TestMusicUpgradeArtYouTubeAndGoogle(t *testing.T) {
	got := musicUpgradeArt("https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
	if len(got) == 0 || got[0] != "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg" {
		t.Fatalf("youtube upgrade = %v, want maxresdefault first", got)
	}
	google := musicUpgradeArt("https://lh3.googleusercontent.com/abc123=w60-h60-l90-rj")
	if len(google) != 2 || google[0] != "https://lh3.googleusercontent.com/abc123=w1000-h1000-l90-rj" {
		t.Fatalf("google upgrade = %v", google)
	}
	if got := musicUpgradeArt("file:///home/u/.cache/art.jpg"); len(got) != 1 {
		t.Errorf("a local URL must not be rewritten: %v", got)
	}
	if got := musicUpgradeArt(""); got != nil {
		t.Errorf("empty art URL yields no candidate, got %v", got)
	}
}

func TestMusicArtCandidatesDerivesYouTubeThumbnail(t *testing.T) {
	// mpv and some browser integrations publish no art at all; the page URL is
	// the only route to a cover.
	got := musicArtCandidates(musicTrack{URL: "https://youtu.be/dQw4w9WgXcQ?t=10"})
	want := []string{
		"https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
		"https://i.ytimg.com/vi/dQw4w9WgXcQ/sddefault.jpg",
		"https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
	}
	if len(got) != len(want) {
		t.Fatalf("candidates = %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("candidates = %v, want %v", got, want)
		}
	}
}

func TestMusicSearchTerms(t *testing.T) {
	cases := []struct {
		name         string
		track        musicTrack
		title, artis string
	}{
		{
			name:  "youtube video title carries the artist",
			track: musicTrack{Title: "Nothing But Thieves - Afterlife (Official Video)"},
			title: "Afterlife", artis: "Nothing But Thieves",
		},
		{
			name:  "topic channel is not an artist name",
			track: musicTrack{Title: "Afterlife", Artist: "Nothing But Thieves - Topic"},
			title: "Afterlife", artis: "Nothing But Thieves",
		},
		{
			name:  "a real track keeps its dash",
			track: musicTrack{Title: "Song - Live", Artist: "Someone Else"},
			title: "Song - Live", artis: "Someone Else",
		},
		{
			name:  "feature credit is dropped",
			track: musicTrack{Title: "Sunrise (feat. Someone)", Artist: "Band"},
			title: "Sunrise", artis: "Band",
		},
		{
			name:  "collaboration searches on the first artist",
			track: musicTrack{Title: "Duet", Artist: "First, Second"},
			title: "Duet", artis: "First",
		},
		{
			name:  "lyric video decoration is dropped",
			track: musicTrack{Title: "Afterlife [Lyrics]", Artist: "Nothing But Thieves"},
			title: "Afterlife", artis: "Nothing But Thieves",
		},
	}
	for _, c := range cases {
		title, artist := musicSearchTerms(c.track)
		if title != c.title || artist != c.artis {
			t.Errorf("%s: musicSearchTerms = (%q, %q), want (%q, %q)", c.name, title, artist, c.title, c.artis)
		}
	}
}

func TestMusicParseLRC(t *testing.T) {
	lines := musicParseLRC("[ti:x]\n[00:12.50]first\n[01:05.10][02:10.00]chorus\nnoise\n[00:30.00]")
	want := []musicLine{
		{T: 12.5, Text: "first"},
		{T: 30, Text: ""},
		{T: 65.1, Text: "chorus"},
		{T: 130, Text: "chorus"},
	}
	if len(lines) != len(want) {
		t.Fatalf("parsed %d lines (%v), want %d", len(lines), lines, len(want))
	}
	for i := range want {
		if lines[i] != want[i] {
			t.Fatalf("line %d = %+v, want %+v", i, lines[i], want[i])
		}
	}
}

func TestMusicPlainLines(t *testing.T) {
	got := musicPlainLines("\n\nfirst\n\n\nsecond\n\n")
	want := []string{"first", "", "second"}
	if len(got) != len(want) {
		t.Fatalf("plain lines = %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("plain lines = %v, want %v", got, want)
		}
	}
}

func TestMusicLyricsMatch(t *testing.T) {
	base := lrclibTrack{TrackName: "Afterlife", ArtistName: "Nothing But Thieves", Duration: 284, SyncedLyrics: "[00:01.00]x"}
	if !musicLyricsMatch(base, "Afterlife", "Nothing But Thieves", 284) {
		t.Error("the exact record must match")
	}
	if musicLyricsMatch(base, "Afterlife", "Nothing But Thieves", 150) {
		t.Error("a record 134 s off must be rejected: it would scroll out of sync")
	}
	if musicLyricsMatch(base, "Afterlife", "Avenged Sevenfold", 284) {
		t.Error("another band's song of the same name must be rejected")
	}
	instrumental := base
	instrumental.Instrumental = true
	if musicLyricsMatch(instrumental, "Afterlife", "Nothing But Thieves", 284) {
		t.Error("an instrumental has nothing to show")
	}
	empty := base
	empty.SyncedLyrics = ""
	if musicLyricsMatch(empty, "Afterlife", "Nothing But Thieves", 284) {
		t.Error("a record with neither synced nor plain lyrics must be rejected")
	}
}

func TestMusicLyricsScorePrefersSynced(t *testing.T) {
	synced := lrclibTrack{Duration: 200, SyncedLyrics: "[00:01.00]x"}
	plain := lrclibTrack{Duration: 200, PlainLyrics: "x"}
	if musicLyricsScore(synced, 200) <= musicLyricsScore(plain, 200) {
		t.Error("synced lyrics must outrank plain")
	}
	near := lrclibTrack{Duration: 201, SyncedLyrics: "x"}
	far := lrclibTrack{Duration: 208, SyncedLyrics: "x"}
	if musicLyricsScore(near, 200) <= musicLyricsScore(far, 200) {
		t.Error("the closer duration must outrank the looser one")
	}
}

func TestMusicTrackKeyIgnoresRepeatedMetadata(t *testing.T) {
	a := musicTrack{Title: " Afterlife ", Artist: "Nothing But Thieves", Album: "Moral Panic", Length: 284.4}
	b := musicTrack{Title: "Afterlife", Artist: "Nothing But Thieves", Album: "Moral Panic", Length: 284.2}
	if musicTrackKey(a) != musicTrackKey(b) {
		t.Error("the same track re-announced by MPRIS must keep its key")
	}
	c := b
	c.ArtURL = "https://i.scdn.co/image/x"
	if musicTrackKey(b) == musicTrackKey(c) {
		t.Error("a different cover is a different track")
	}
}

func TestMusicLyricsCacheRoundTrip(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "lyrics.json")
	lines := []musicLine{{T: 1, Text: "a"}}
	musicWriteLyricsCache(path, lines, nil, musOK)
	got, _, status, ok := musicReadLyricsCache(path)
	if !ok || status != musOK || len(got) != 1 || got[0] != lines[0] {
		t.Fatalf("cache round trip = (%v, %q, %v)", got, status, ok)
	}

	// A stale miss is retried rather than served forever.
	stale, err := json.Marshal(musicLyricsCache{Status: musNone, At: time.Now().Add(-8 * 24 * time.Hour).Unix()})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, stale, 0o644); err != nil {
		t.Fatal(err)
	}
	if _, _, _, ok := musicReadLyricsCache(path); ok {
		t.Error("a week-old miss must be refetched")
	}
}

func TestMusicFetchLyricsPrefersSyncedRecord(t *testing.T) {
	var searched bool
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if r.URL.Path == "/api/get" {
			// The exact record exists but carries only plain lyrics.
			_ = json.NewEncoder(w).Encode(lrclibTrack{
				TrackName: "Afterlife", ArtistName: "Nothing But Thieves",
				Duration: 284, PlainLyrics: "no timestamps",
			})
			return
		}
		searched = true
		_ = json.NewEncoder(w).Encode([]lrclibTrack{
			{TrackName: "Afterlife", ArtistName: "Other Band", Duration: 284, SyncedLyrics: "[00:02.00]wrong"},
			{TrackName: "Afterlife", ArtistName: "Nothing But Thieves", Duration: 284, SyncedLyrics: "[00:01.00]right"},
		})
	}))
	defer srv.Close()

	s := &musicState{client: srv.Client(), dir: t.TempDir()}
	lines, plain, status, err := s.fetchLyricsFrom(srv.URL+"/api/get", srv.URL+"/api/search",
		"Afterlife", "Nothing But Thieves", "Moral Panic", 284)
	if err != nil {
		t.Fatalf("fetchLyrics: %v", err)
	}
	if !searched {
		t.Error("a plain-only exact record must still trigger the search for synced lyrics")
	}
	if status != musOK || len(lines) != 1 || lines[0].Text != "right" || plain != nil {
		t.Fatalf("lyrics = (%v, %v, %q)", lines, plain, status)
	}
}

func TestMusicFetchLyricsFallsBackToPlain(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if r.URL.Path == "/api/get" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		_ = json.NewEncoder(w).Encode([]lrclibTrack{
			{TrackName: "Afterlife", ArtistName: "Nothing But Thieves", Duration: 284, PlainLyrics: "one\ntwo"},
		})
	}))
	defer srv.Close()

	s := &musicState{client: srv.Client(), dir: t.TempDir()}
	lines, plain, status, err := s.fetchLyricsFrom(srv.URL+"/api/get", srv.URL+"/api/search",
		"Afterlife", "Nothing But Thieves", "Moral Panic", 284)
	if err != nil {
		t.Fatalf("fetchLyrics: %v", err)
	}
	if status != musPlain || len(lines) != 0 || len(plain) != 2 {
		t.Fatalf("lyrics = (%v, %v, %q), want two plain lines", lines, plain, status)
	}
}

func TestMusicFetchLyricsUnreachableIsAnError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()

	s := &musicState{client: srv.Client(), dir: t.TempDir()}
	if _, _, status, err := s.fetchLyricsFrom(srv.URL+"/api/get", srv.URL+"/api/search",
		"Afterlife", "Nothing But Thieves", "Moral Panic", 284); err == nil || status != musError {
		t.Fatalf("a down provider must report an error, got (%q, %v)", status, err)
	}
}

// jpegBody is the smallest byte string musicIsImage accepts as a JPEG, padded
// past the placeholder floor.
func jpegBody() []byte {
	body := make([]byte, musMinArtBytes+16)
	body[0], body[1], body[2] = 0xff, 0xd8, 0xff
	return body
}

func TestMusicCacheArtRejectsNonImage(t *testing.T) {
	var hits int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits++
		if r.URL.Path == "/missing.jpg" {
			// YouTube answers an absent thumbnail size with an HTML page.
			w.Write([]byte("<html>404</html>"))
			return
		}
		w.Write(jpegBody())
	}))
	defer srv.Close()

	s := &musicState{client: srv.Client(), dir: t.TempDir()}
	if _, err := s.cacheArt(srv.URL + "/missing.jpg"); err == nil {
		t.Error("an HTML body must not cache as a cover")
	}
	path, err := s.cacheArt(srv.URL + "/cover.jpg")
	if err != nil {
		t.Fatalf("cacheArt: %v", err)
	}
	if info, err := os.Stat(path); err != nil || info.Size() < musMinArtBytes {
		t.Fatalf("cover not written: %v", err)
	}
	before := hits
	if again, err := s.cacheArt(srv.URL + "/cover.jpg"); err != nil || again != path {
		t.Fatalf("second call = (%q, %v), want the cached path", again, err)
	}
	if hits != before {
		t.Error("a cached cover must not be downloaded again")
	}
}

func TestMusicLocalArtNeedsARealFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "cover.jpg")
	if err := os.WriteFile(path, jpegBody(), 0o644); err != nil {
		t.Fatal(err)
	}
	if got, ok := musicLocalArt("file://" + path); !ok || got != path {
		t.Fatalf("local art = (%q, %v), want %q", got, ok, path)
	}
	if _, ok := musicLocalArt("file://" + filepath.Join(dir, "gone.jpg")); ok {
		t.Error("a missing file must not be published as art")
	}
	if _, ok := musicLocalArt("https://example.com/a.jpg"); ok {
		t.Error("a remote URL is not local art")
	}
}

func TestMusicITunesFullSize(t *testing.T) {
	got := musicITunesFullSize("https://is1-ssl.mzstatic.com/image/thumb/x/100x100bb.jpg")
	if got != "https://is1-ssl.mzstatic.com/image/thumb/x/1000x1000bb.jpg" {
		t.Errorf("itunes upgrade = %q", got)
	}
}

func TestSpotifyTrackID(t *testing.T) {
	cases := []struct{ url, want string }{
		{"https://open.spotify.com/track/5RBOcBpJXaNnHCGViJmYhh", "5RBOcBpJXaNnHCGViJmYhh"},
		{"https://open.spotify.com/track/5RBOcBpJXaNnHCGViJmYhh?si=abc", "5RBOcBpJXaNnHCGViJmYhh"},
		{"spotify:track:5RBOcBpJXaNnHCGViJmYhh", "5RBOcBpJXaNnHCGViJmYhh"},
		{"https://music.youtube.com/watch?v=x", ""},
		{"", ""},
	}
	for _, c := range cases {
		if got := spotifyTrackID(musicTrack{URL: c.url}); got != c.want {
			t.Errorf("spotifyTrackID(%q) = %q, want %q", c.url, got, c.want)
		}
	}
}

func TestCanvasFileFor(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	id := "5RBOcBpJXaNnHCGViJmYhh"
	if got := canvasFileFor(id); got != "" {
		t.Fatalf("empty library: got %q, want empty", got)
	}
	cdir := filepath.Join(dir, "ryoku", "canvas")
	if err := os.MkdirAll(cdir, 0o755); err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(cdir, id+".mp4")
	if err := os.WriteFile(want, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := canvasFileFor(id); got != want {
		t.Errorf("canvasFileFor(%q) = %q, want %q", id, got, want)
	}
	if got := canvasFileFor(""); got != "" {
		t.Errorf("empty id: got %q, want empty", got)
	}
}
