package main

import (
	"os"
	"strings"
	"testing"
)

// TestFishQuote pins the escaping contract: inside fish single quotes only \'
// and \\ are special, and the backslash must be escaped BEFORE the quote or
// the quote's own escape gets doubled and the token breaks.
func TestFishQuote(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want string
	}{
		{"plain", "abc", `'abc'`},
		{"backslash only", `a\b`, `'a\\b'`},
		{"quote only", "a'b", `'a\'b'`},
		// order matters: \ escaped first, then ' -> exactly one escape each.
		{"backslash and quote", `a\b'c`, `'a\\b\'c'`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := fishQuote(tc.in); got != tc.want {
				t.Errorf("fishQuote(%q) = %q, want %q", tc.in, got, tc.want)
			}
		})
	}
}

// TestRecipeRoundTrip covers the save -> load -> remove lifecycle under a
// sandboxed XDG_STATE_HOME, plus the generated fish abbreviation file.
func TestRecipeRoundTrip(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	if err := SaveRecipe("k", "abc", "because"); err != nil {
		t.Fatalf("SaveRecipe: %v", err)
	}

	rs := LoadRecipes()
	if len(rs) != 1 || rs[0].Name != "k" || rs[0].Run != "abc" {
		t.Fatalf("LoadRecipes = %+v, want one recipe k=abc", rs)
	}

	fish, err := os.ReadFile(RecipesFishPath())
	if err != nil {
		t.Fatalf("recipes fish file not written: %v", err)
	}
	// The abbreviation is prefixed rr- and the command is fish-quoted.
	if !strings.Contains(string(fish), "abbr -a -- rr-k ") {
		t.Errorf("fish file missing rr-k abbreviation:\n%s", fish)
	}
	if !strings.Contains(string(fish), `'abc'`) {
		t.Errorf("fish file missing quoted command:\n%s", fish)
	}

	for _, path := range []string{RecipesBashPath(), RecipesZshPath()} {
		b, err := os.ReadFile(path)
		if err != nil {
			t.Fatalf("recipe file not written: %s: %v", path, err)
		}
		if !strings.Contains(string(b), "rr-k") || !strings.Contains(string(b), "abc") {
			t.Errorf("recipe file missing rr-k command: %s\n%s", path, b)
		}
	}

	if err := RemoveRecipe("k"); err != nil {
		t.Fatalf("RemoveRecipe: %v", err)
	}
	if rs := LoadRecipes(); len(rs) != 0 {
		t.Fatalf("after remove LoadRecipes = %+v, want empty", rs)
	}
	// Removing an already-gone name must error so a typo is visible.
	if err := RemoveRecipe("k"); err == nil {
		t.Error("RemoveRecipe on unknown name must error")
	}
}

// TestSaveRecipeRejectsBadInput guards the name/command validation: names must
// be short lowercase [a-z0-9-] and the command must be non-empty.
func TestSaveRecipeRejectsBadInput(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	cases := []struct {
		name       string
		recipeName string
		run        string
	}{
		{"uppercase and space", "Bad Name", "ls"},
		{"too long", strings.Repeat("a", 30), "ls"},
		{"empty command", "ok", "   "},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if err := SaveRecipe(tc.recipeName, tc.run, ""); err == nil {
				t.Errorf("SaveRecipe(%q, %q) succeeded, want error", tc.recipeName, tc.run)
			}
		})
	}
	// A rejected save must not leave a recipe behind.
	if rs := LoadRecipes(); len(rs) != 0 {
		t.Fatalf("rejected saves persisted recipes: %+v", rs)
	}
}

// TestRemoveUnknownRecipe: removing from an empty store errors.
func TestRemoveUnknownRecipe(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	if err := RemoveRecipe("ghost"); err == nil {
		t.Error("RemoveRecipe on empty store must error")
	}
}
