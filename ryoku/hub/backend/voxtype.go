package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Voxtype dictation backend for Ryoku Settings' Dictation page. Ryoku owns the
// Super+` keybind and the pill mic-wave, so the config here keeps Voxtype's own
// hotkey and OSD off and lets the shell drive `voxtype record`. config.toml is
// regenerated from the chosen preset, so hand edits are overwritten on save.
//
//	ryoku-hub voxtype get         print presets + current state as JSON
//	ryoku-hub voxtype set <json>  apply a preset (writes config, manages service)
//	ryoku-hub voxtype ensure      seed a default config + service (autostart)

// voxtypePreset is one curated engine/model the Dictation page offers. The
// lower-case fields map it to config.toml; the exported ones drive the UI.
type voxtypePreset struct {
	Key      string `json:"key"`
	Label    string `json:"label"`
	Provider string `json:"provider"`
	Detail   string `json:"detail"`
	Size     string `json:"size"`
	Cloud    bool   `json:"cloud"`    // sends audio off-device, needs an API key
	KeyKind  string `json:"keyKind"`  // "openai", "soniox", or ""
	Present  bool   `json:"present"`  // local model downloaded (get only; cloud = true)

	engine string // top-level engine
	model  string // model within the engine (remote_model for cloud whisper)
	lang   string // language for whisper-local presets
}

// The curated set: local models from official providers, then the paid cloud
// backends. Voxtype supports more engines; these are the ones worth surfacing.
func voxtypePresets() []voxtypePreset {
	return []voxtypePreset{
		{Key: "whisper-fast", Label: "Whisper — Fast", Provider: "OpenAI", Detail: "English only, quickest to load. A solid everyday default.", Size: "142 MB", engine: "whisper", model: "base.en", lang: "en"},
		{Key: "whisper-accurate", Label: "Whisper — Accurate", Provider: "OpenAI", Detail: "Multilingual, higher accuracy, larger download.", Size: "1.6 GB", engine: "whisper", model: "large-v3-turbo", lang: "auto"},
		{Key: "parakeet", Label: "Parakeet", Provider: "NVIDIA", Detail: "25 European languages with built-in punctuation.", Size: "670 MB", engine: "parakeet", model: "parakeet-tdt-0.6b-v3-int8"},
		{Key: "cohere", Label: "Cohere Transcribe", Provider: "Cohere", Detail: "Most accurate offline engine, with punctuation and casing.", Size: "1.5 GB", engine: "cohere", model: "cohere-transcribe-q4f16"},
		{Key: "openai", Label: "OpenAI API", Provider: "OpenAI", Detail: "Cloud Whisper. Needs an OpenAI API key; audio leaves your machine.", Size: "cloud", Cloud: true, KeyKind: "openai", engine: "whisper", model: "whisper-1"},
		{Key: "soniox", Label: "Soniox", Provider: "Soniox", Detail: "Cloud streaming, 60+ languages. Needs a Soniox API key; audio leaves your machine.", Size: "cloud", Cloud: true, KeyKind: "soniox", engine: "soniox", model: "stt-async-v4"},
	}
}

func presetByKey(k string) (voxtypePreset, bool) {
	for _, p := range voxtypePresets() {
		if p.Key == k {
			return p, true
		}
	}
	return voxtypePreset{}, false
}

func configHome() string {
	if b := os.Getenv("XDG_CONFIG_HOME"); b != "" {
		return b
	}
	return filepath.Join(os.Getenv("HOME"), ".config")
}

func dataHome() string {
	if b := os.Getenv("XDG_DATA_HOME"); b != "" {
		return b
	}
	return filepath.Join(os.Getenv("HOME"), ".local", "share")
}

func voxtypeConfigPath() string { return filepath.Join(configHome(), "voxtype", "config.toml") }
func voxtypeUnitPath() string {
	return filepath.Join(configHome(), "systemd", "user", "voxtype.service")
}

func runVoxtype(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("voxtype needs get|set|ensure")
	}
	switch args[0] {
	case "get":
		return voxtypeGet()
	case "set":
		if len(args) < 2 {
			return fmt.Errorf("voxtype set needs a JSON argument")
		}
		return voxtypeSet(args[1])
	case "ensure":
		return voxtypeEnsure()
	default:
		return fmt.Errorf("unknown voxtype command: %s", args[0])
	}
}

// voxtypeGet reports the catalog plus current state so the page can render.
func voxtypeGet() error {
	text := readFileString(voxtypeConfigPath())
	presets := voxtypePresets()
	for i := range presets {
		presets[i].Present = presets[i].Cloud || modelPresent(presets[i])
	}
	out := map[string]any{
		"installed":    onPath("voxtype"),
		"selected":     selectedPreset(text),
		"enabled":      voxtypeServiceEnabled(),
		"openaiKeySet": extractConfigString(text, "remote_api_key") != "" || os.Getenv("VOXTYPE_WHISPER_API_KEY") != "",
		"sonioxKeySet": extractConfigString(text, "api_key") != "" || os.Getenv("SONIOX_API_KEY") != "",
		"presets":      presets,
	}
	b, err := json.Marshal(out)
	if err != nil {
		return err
	}
	os.Stdout.Write(b)
	fmt.Println()
	return nil
}

type voxtypeSetReq struct {
	Preset    string `json:"preset"`
	Enabled   bool   `json:"enabled"`
	OpenAIKey string `json:"openaiKey"` // empty keeps the stored key
	SonioxKey string `json:"sonioxKey"` // empty keeps the stored key
}

// voxtypeSet writes config.toml for the chosen preset and brings the service to
// the requested state.
func voxtypeSet(arg string) error {
	var req voxtypeSetReq
	if err := json.Unmarshal([]byte(arg), &req); err != nil {
		return fmt.Errorf("bad JSON: %w", err)
	}
	p, ok := presetByKey(req.Preset)
	if !ok {
		return fmt.Errorf("unknown preset: %s", req.Preset)
	}
	// keep the stored key when the page leaves the field blank, so a re-save
	// after a restart does not wipe a key the user already entered.
	prev := readFileString(voxtypeConfigPath())
	openaiKey := req.OpenAIKey
	if openaiKey == "" {
		openaiKey = extractConfigString(prev, "remote_api_key")
	}
	sonioxKey := req.SonioxKey
	if sonioxKey == "" {
		sonioxKey = extractConfigString(prev, "api_key")
	}
	if err := atomicWrite(voxtypeConfigPath(), []byte(buildVoxtypeConfig(p, openaiKey, sonioxKey)), 0o600); err != nil {
		return err
	}
	if req.Enabled {
		ensureVoxtypeUnit()
		_ = userctl("enable", "voxtype.service")
		_ = userctl("restart", "voxtype.service")
	} else {
		_ = userctl("disable", "--now", "voxtype.service")
	}
	fmt.Println("ok")
	return nil
}

// voxtypeEnsure seeds a default config and the user service on first run, and is
// idempotent so the Hyprland autostart can call it every login. It never forces
// the service on when the user turned dictation off in the Hub.
func voxtypeEnsure() error {
	if _, err := os.Stat(voxtypeConfigPath()); err != nil {
		p, _ := presetByKey("whisper-fast")
		if err := atomicWrite(voxtypeConfigPath(), []byte(buildVoxtypeConfig(p, "", "")), 0o600); err != nil {
			return err
		}
	}
	ensureVoxtypeUnit()
	if voxtypeServiceEnabled() {
		_ = userctl("start", "voxtype.service")
	}
	return nil
}

// buildVoxtypeConfig renders a complete config.toml for the preset. It is fully
// generated (with a preset marker the Hub reads back), so it always reflects the
// current choice and never accumulates stale sections.
func buildVoxtypeConfig(p voxtypePreset, openaiKey, sonioxKey string) string {
	var b strings.Builder
	b.WriteString("# Ryoku dictation config for Voxtype. Managed by Ryoku Settings > Dictation\n")
	b.WriteString("# (ryoku-hub voxtype); hand edits are overwritten when you change it there.\n")
	b.WriteString("# The shell owns Super+` and the pill mic-wave, so the built-in hotkey is off\n")
	b.WriteString("# and the GTK4 OSD stays unused (gtk4-layer-shell is not installed).\n")
	fmt.Fprintf(&b, "# ryoku-preset: %s\n\n", p.Key)
	fmt.Fprintf(&b, "engine = %q\n", p.engine)
	b.WriteString("state_file = \"auto\"\n\n")
	b.WriteString("[hotkey]\nenabled = false\n\n")
	b.WriteString("[audio]\ndevice = \"default\"\nsample_rate = 16000\n\n")
	b.WriteString("[output]\nmode = \"type\"\nfallback_to_clipboard = true\ntype_delay_ms = 1\n\n")
	b.WriteString("[output.notification]\non_recording_start = false\non_recording_stop = false\non_transcription = false\n\n")

	switch p.engine {
	case "whisper":
		b.WriteString("[whisper]\n")
		if p.Key == "openai" {
			b.WriteString("backend = \"remote\"\n")
			b.WriteString("remote_endpoint = \"https://api.openai.com\"\n")
			fmt.Fprintf(&b, "remote_model = %q\n", p.model)
			if openaiKey != "" {
				fmt.Fprintf(&b, "remote_api_key = %q\n", openaiKey)
			}
		} else {
			b.WriteString("backend = \"local\"\n")
			fmt.Fprintf(&b, "model = %q\n", p.model)
			fmt.Fprintf(&b, "language = %q\n", p.lang)
		}
	case "parakeet":
		fmt.Fprintf(&b, "[parakeet]\nmodel = %q\n", p.model)
	case "cohere":
		fmt.Fprintf(&b, "[cohere]\nmodel = %q\nlanguage = \"en\"\n", p.model)
	case "soniox":
		b.WriteString("[soniox]\n")
		fmt.Fprintf(&b, "model = %q\n", p.model)
		b.WriteString("async_api = true\n") // record start/stop -> record then transcribe on stop
		b.WriteString("language_hints = [\"en\"]\n")
		if sonioxKey != "" {
			fmt.Fprintf(&b, "api_key = %q\n", sonioxKey)
		}
	}
	return b.String()
}

// --- small helpers -------------------------------------------------------

func readFileString(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return string(b)
}

func onPath(bin string) bool {
	_, err := exec.LookPath(bin)
	return err == nil
}

// selectedPreset reads the marker the generator wrote; defaults to the first.
func selectedPreset(configText string) string {
	for _, ln := range strings.Split(configText, "\n") {
		ln = strings.TrimSpace(ln)
		if strings.HasPrefix(ln, "# ryoku-preset:") {
			return strings.TrimSpace(strings.TrimPrefix(ln, "# ryoku-preset:"))
		}
	}
	return "whisper-fast"
}

// extractConfigString pulls a simple `key = "value"` string out of the config.
// Whisper's remote key is `remote_api_key` and Soniox's is `api_key`, so the key
// name alone disambiguates them without full TOML parsing.
func extractConfigString(configText, key string) string {
	for _, ln := range strings.Split(configText, "\n") {
		t := strings.TrimSpace(ln)
		if strings.HasPrefix(t, key+" =") || strings.HasPrefix(t, key+"=") {
			v := strings.TrimSpace(t[strings.Index(t, "=")+1:])
			return strings.Trim(v, "\"")
		}
	}
	return ""
}

// modelPresent is a best-effort check for a downloaded local model: Voxtype
// stores models under ~/.local/share/voxtype/models. A miss just means the page
// offers a (harmless, idempotent) download.
func modelPresent(p voxtypePreset) bool {
	if p.model == "" {
		return false
	}
	dir := filepath.Join(dataHome(), "voxtype", "models")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return false
	}
	// whisper stores ggml-<model>.bin; ONNX engines store a <model>/ directory.
	needle := strings.TrimSuffix(p.model, ".en")
	for _, e := range entries {
		if strings.Contains(e.Name(), p.model) || strings.Contains(e.Name(), needle) {
			return true
		}
	}
	return false
}

func userctl(args ...string) error {
	return exec.Command("systemctl", append([]string{"--user"}, args...)...).Run()
}

func voxtypeServiceEnabled() bool {
	return userctl("is-enabled", "--quiet", "voxtype.service") == nil
}

// ensureVoxtypeUnit installs the user service the first time (voxtype setup
// systemd writes ~/.config/systemd/user/voxtype.service and enables it). Guarded
// on the unit file so a later Hub "off" (which disables it) is not undone.
func ensureVoxtypeUnit() {
	if _, err := os.Stat(voxtypeUnitPath()); err == nil {
		return
	}
	if !onPath("voxtype") {
		return
	}
	_ = exec.Command("voxtype", "setup", "systemd").Run()
}
