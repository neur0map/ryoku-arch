package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/BurntSushi/toml"
)

// Config is the Hub's persisted state, stored as TOML at
// ~/.config/ryoku/hub.toml. Sections add their own typed tables here as they
// graduate from "under construction"; for now the UI table just remembers the
// last open section so the Hub reopens where you left it.
type Config struct {
	UI UIConfig `toml:"ui"`
}

type UIConfig struct {
	Section string `toml:"section"`
}

func defaultConfig() Config {
	return Config{UI: UIConfig{Section: "keybinds"}}
}

func configPath() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	return filepath.Join(base, "ryoku", "hub.toml")
}

func loadConfig() Config {
	c := defaultConfig()
	if b, err := os.ReadFile(configPath()); err == nil {
		_ = toml.Unmarshal(b, &c)
	}
	return c
}

// saveConfig writes the config atomically (temp file + rename) so a crash mid
// write never leaves a truncated TOML the next load would silently reset.
func saveConfig(c Config) error {
	p := configPath()
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	f, err := os.CreateTemp(filepath.Dir(p), "hub-*.toml")
	if err != nil {
		return err
	}
	tmp := f.Name()
	if err := toml.NewEncoder(f).Encode(c); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := f.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, p)
}

func configGet(key string) (string, bool) {
	c := loadConfig()
	switch key {
	case "section":
		return c.UI.Section, true
	}
	return "", false
}

func configSet(key, value string) error {
	c := loadConfig()
	switch key {
	case "section":
		c.UI.Section = value
	default:
		return fmt.Errorf("unknown config key: %s", key)
	}
	return saveConfig(c)
}
