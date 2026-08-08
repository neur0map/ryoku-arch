package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestCalendarRegionUsesLocaleAndOverride(t *testing.T) {
	t.Setenv("LC_ALL", "")
	t.Setenv("LC_MESSAGES", "")
	t.Setenv("LANG", "en_US.UTF-8")
	country, subdivision, valid := resolveCalendarRegion("")
	if !valid || country != "US" || subdivision != "" {
		t.Fatalf("auto region = %q %q %v, want US empty true", country, subdivision, valid)
	}
	country, subdivision, valid = resolveCalendarRegion("us-ca")
	if !valid || country != "US" || subdivision != "US-CA" {
		t.Fatalf("override = %q %q %v, want US US-CA true", country, subdivision, valid)
	}
}

func TestCalendarRegionRejectsMalformedOverride(t *testing.T) {
	if _, _, valid := resolveCalendarRegion("california"); valid {
		t.Fatal("malformed override accepted")
	}
}

func TestCalendarHolidayFiltering(t *testing.T) {
	raw := []nagerHoliday{
		{Date: "2026-01-01", Name: "National", NationalHoliday: true, HolidayTypes: []string{"Public"}},
		{Date: "2026-03-31", Name: "California", SubdivisionCodes: []string{"US-CA"}},
		{Date: "2026-03-31", Name: "Nevada", SubdivisionCodes: []string{"US-NV"}},
	}
	got := filterCalendarHolidays(raw, "US-CA")
	if len(got) != 2 || got[0].Name != "National" || got[1].Name != "California" {
		t.Fatalf("filtered holidays = %#v", got)
	}
}

func TestCalendarYearFetchCachesAndReusesResponse(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`[{"date":"2026-01-01","name":"New Year","countryCode":"US","nationalHoliday":true,"holidayTypes":["Public"]}]`))
	}))
	defer server.Close()

	s := &calendarState{client: server.Client(), baseURL: server.URL, cacheDir: t.TempDir(), now: time.Now}
	first, source, err := s.loadYear("US", "", 2026)
	if err != nil || source != "network" || len(first) != 1 {
		t.Fatalf("first load = %#v %q %v", first, source, err)
	}
	second, source, err := s.loadYear("US", "", 2026)
	if err != nil || source != "cache" || len(second) != 1 || calls != 1 {
		t.Fatalf("cached load = %#v %q %v, calls %d", second, source, err, calls)
	}
}

func TestCalendarFailedRefreshKeepsStaleCache(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "US", "2026.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	body := `[{"date":"2026-01-01","name":"Cached","countryCode":"US","nationalHoliday":true,"holidayTypes":["Public"]}]`
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	old := time.Now().Add(-48 * time.Hour)
	if err := os.Chtimes(path, old, old); err != nil {
		t.Fatal(err)
	}

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { http.Error(w, "down", http.StatusServiceUnavailable) }))
	defer server.Close()
	s := &calendarState{client: server.Client(), baseURL: server.URL, cacheDir: dir, now: time.Now}
	got, source, err := s.loadYear("US", "", 2026)
	if err == nil || source != "stale-cache" || len(got) != 1 || got[0].Name != "Cached" {
		t.Fatalf("stale fallback = %#v %q %v", got, source, err)
	}
}
