package orgmtheme

import (
	"os"
	"path/filepath"
)

// AtomicWriteFile writes content through a temp file in the destination
// directory, then renames it over the destination path.
func AtomicWriteFile(path string, content []byte, perm os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), "."+filepath.Base(path)+"-*.tmp")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)

	if _, err := tmp.Write(content); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Chmod(perm); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpPath, path)
}

func atomicWriteString(path, content string, perm os.FileMode) error {
	return AtomicWriteFile(path, []byte(content), perm)
}
