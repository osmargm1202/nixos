package theme

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
)

type AtomicWriter struct {
	Marker string
}

type WriteResult struct {
	Path       string
	BackupPath string
	Changed    bool
}

func (w AtomicWriter) Write(path string, content []byte, mode int) (WriteResult, error) {
	result := WriteResult{Path: path}
	marker := w.Marker
	if marker == "" {
		marker = GeneratedMarker
	}
	current, existed, err := readGeneratedCurrent(path, []byte(marker))
	if err != nil {
		return result, err
	}
	if existed && bytes.Equal(current, content) {
		return result, nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return result, err
	}
	if existed && len(current) > 0 {
		backupPath := path + ".bak"
		if err := os.WriteFile(backupPath, current, 0o600); err != nil {
			return result, err
		}
		result.BackupPath = backupPath
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".orgm-hypr-*")
	if err != nil {
		return result, err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	if _, err := tmp.Write(content); err != nil {
		tmp.Close()
		return result, err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return result, err
	}
	if err := tmp.Close(); err != nil {
		return result, err
	}
	if mode == 0 {
		mode = 0o600
	}
	if err := os.Chmod(tmpPath, os.FileMode(mode)); err != nil {
		return result, err
	}
	if err := os.Rename(tmpPath, path); err != nil {
		return result, err
	}
	result.Changed = true
	return result, nil
}

func readGeneratedCurrent(path string, marker []byte) ([]byte, bool, error) {
	current, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, false, nil
		}
		return nil, false, err
	}
	if len(current) == 0 || bytes.Contains(current, marker) {
		return current, true, nil
	}
	return nil, true, fmt.Errorf("refusing to overwrite unmarked existing file %s", path)
}
