package doctor

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/big"
	"os"
	"path/filepath"

	"ryoku-cli/internal/sys"
)

const launcherLocalFrostMigration = "launcher-local-frost-default"

func launcherLocalFrostMarker() string {
	return filepath.Join(sys.StateDir(), "migrations", launcherLocalFrostMigration)
}

// reconcileLauncherLocalFrostDefault moves only the launcher's retired shipped
// blur value. The marker makes a later user-selected 12 px value authoritative.
func reconcileLauncherLocalFrostDefault(checkOnly bool) recResult {
	marker := launcherLocalFrostMarker()
	if sys.Exists(marker) {
		return okRes("launcher local-frost default already reconciled")
	}

	path := filepath.Join(sys.ConfigHome(), "ryoku", "launcher.json")
	raw, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		if checkOnly {
			return okRes("no saved launcher config; local frost uses the current default")
		}
		if err := markLauncherLocalFrost(marker); err != nil {
			return failRes("could not record the launcher local-frost migration: %v", err)
		}
		return okRes("no saved launcher config; local frost uses the current default")
	}
	if err != nil {
		return warnRes("could not read %s for the local-frost migration: %v", path, err).
			withFix("fix the file permissions, then run `ryoku doctor`")
	}

	migrated, changed, err := migrateLauncherLocalFrost(raw)
	if err != nil {
		return warnRes("launcher.json cannot be safely migrated (%v); it was left untouched", err).
			withFix("repair the bgBlur value, then run `ryoku doctor`")
	}
	if changed && checkOnly {
		return wouldRes("launcher.json still uses the retired 12 px global-blur default").
			withFix("ryoku doctor changes it to the 2 px card-local frost default")
	}
	if !changed {
		if checkOnly {
			return okRes("launcher blur is user-selected or already uses the local-frost default")
		}
		if err := markLauncherLocalFrost(marker); err != nil {
			return failRes("could not record the launcher local-frost migration: %v", err)
		}
		return okRes("launcher blur is user-selected or already uses the local-frost default")
	}

	if err := replaceLauncherConfig(path, migrated); err != nil {
		return failRes("could not migrate %s: %v", path, err).
			withFix("fix the file permissions, then run `ryoku doctor`")
	}
	if err := markLauncherLocalFrost(marker); err != nil {
		return failRes("launcher frost was updated, but its migration marker could not be written: %v", err).
			withFix("run `ryoku doctor` again")
	}
	return fixedRes("moved launcher blur from the retired 12 px global default to 2 px local frost")
}

// migrateLauncherLocalFrost is deliberately narrow: exact numeric 12 becomes
// 2, while every other valid value is treated as a user choice.
func migrateLauncherLocalFrost(raw []byte) ([]byte, bool, error) {
	var cfg map[string]json.RawMessage
	if err := json.Unmarshal(raw, &cfg); err != nil {
		return nil, false, err
	}
	if cfg == nil {
		return nil, false, errors.New("top level must be a JSON object")
	}
	blurRaw, ok := cfg["bgBlur"]
	if !ok {
		return nil, false, nil
	}

	decoder := json.NewDecoder(bytes.NewReader(blurRaw))
	decoder.UseNumber()
	var blurValue any
	if err := decoder.Decode(&blurValue); err != nil {
		return nil, false, fmt.Errorf("bgBlur does not parse: %w", err)
	}
	if err := ensureJSONEnd(decoder); err != nil {
		return nil, false, fmt.Errorf("bgBlur does not parse: %w", err)
	}
	blur, ok := blurValue.(json.Number)
	if !ok {
		return nil, false, fmt.Errorf("bgBlur must be numeric, got %s", string(blurRaw))
	}
	value, ok := new(big.Rat).SetString(string(blur))
	if !ok {
		return nil, false, fmt.Errorf("bgBlur must be a finite number, got %s", blur)
	}
	if value.Cmp(big.NewRat(12, 1)) != 0 {
		return nil, false, nil
	}

	cfg["bgBlur"] = json.RawMessage("2")
	out, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return nil, false, err
	}
	return append(out, '\n'), true, nil
}

func ensureJSONEnd(decoder *json.Decoder) error {
	var extra any
	if err := decoder.Decode(&extra); !errors.Is(err, io.EOF) {
		if err == nil {
			return errors.New("contains more than one value")
		}
		return err
	}
	return nil
}

func replaceLauncherConfig(path string, data []byte) error {
	target := path
	linkInfo, err := os.Lstat(path)
	if err != nil {
		return err
	}
	if linkInfo.Mode()&os.ModeSymlink != 0 {
		target, err = filepath.EvalSymlinks(path)
		if err != nil {
			return err
		}
	}

	info, err := os.Stat(target)
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(target), ".launcher.json.ryoku-*")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)

	if err := tmp.Chmod(info.Mode().Perm()); err != nil {
		tmp.Close()
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpPath, target)
}

func markLauncherLocalFrost(marker string) error {
	dir := filepath.Dir(marker)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(dir, "."+filepath.Base(marker)+".ryoku-*")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	if err := tmp.Chmod(0o644); err != nil {
		tmp.Close()
		return err
	}
	if _, err := tmp.Write([]byte("done\n")); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpPath, marker)
}
