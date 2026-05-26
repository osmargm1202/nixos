package theme

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAtomicWriterWritesNewFileAndReplacesGeneratedFile(t *testing.T) {
	writer := AtomicWriter{Marker: GeneratedMarker}
	path := filepath.Join(t.TempDir(), "theme", "palette.json")
	first := []byte(GeneratedMarker + "\nfirst\n")
	second := []byte(GeneratedMarker + "\nsecond\n")

	newResult, err := writer.Write(path, first, 0o600)
	if err != nil {
		t.Fatalf("Write(new) error = %v", err)
	}
	if got := newResult.BackupPath; got != "" {
		t.Fatalf("new backup path = %q, want empty", got)
	}
	if got, want := readFileString(t, path), string(first); got != want {
		t.Fatalf("new content = %q, want %q", got, want)
	}
	replaceResult, err := writer.Write(path, second, 0o600)
	if err != nil {
		t.Fatalf("Write(generated) error = %v", err)
	}
	if got, want := readFileString(t, path), string(second); got != want {
		t.Fatalf("replacement content = %q, want %q", got, want)
	}
	if got, want := replaceResult.BackupPath, path+".bak"; got != want {
		t.Fatalf("replacement backup path = %q, want %q", got, want)
	}
	if got, want := readFileString(t, replaceResult.BackupPath), string(first); got != want {
		t.Fatalf("backup content = %q, want previous content %q", got, want)
	}
}

func TestAtomicWriterRefusesUnmarkedExistingFileAndAllowsEmptyFile(t *testing.T) {
	writer := AtomicWriter{Marker: GeneratedMarker}
	dir := t.TempDir()
	manualPath := filepath.Join(dir, "manual.conf")
	emptyPath := filepath.Join(dir, "empty.conf")
	if err := os.WriteFile(manualPath, []byte("hand edited\n"), 0o600); err != nil {
		t.Fatalf("WriteFile(manual) error = %v", err)
	}
	if err := os.WriteFile(emptyPath, nil, 0o600); err != nil {
		t.Fatalf("WriteFile(empty) error = %v", err)
	}

	_, err := writer.Write(manualPath, []byte(GeneratedMarker+"\nnew\n"), 0o600)
	if err == nil {
		t.Fatal("Write(manual) error = nil, want generated guard error")
	}
	if got, want := err.Error(), "refusing to overwrite unmarked existing file"; !strings.Contains(got, want) {
		t.Fatalf("error = %q, want substring %q", got, want)
	}
	if got, want := readFileString(t, manualPath), "hand edited\n"; got != want {
		t.Fatalf("manual content = %q, want %q", got, want)
	}
	if _, err := os.Stat(manualPath + ".bak"); !os.IsNotExist(err) {
		t.Fatalf("manual backup stat error = %v, want not exist", err)
	}
	emptyResult, err := writer.Write(emptyPath, []byte(GeneratedMarker+"\nnew\n"), 0o600)
	if err != nil {
		t.Fatalf("Write(empty) error = %v", err)
	}
	if got := emptyResult.BackupPath; got != "" {
		t.Fatalf("empty file backup path = %q, want empty", got)
	}
	if got, want := readFileString(t, emptyPath), GeneratedMarker+"\nnew\n"; got != want {
		t.Fatalf("empty replacement = %q, want %q", got, want)
	}
}

func readFileString(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("ReadFile(%s) error = %v", path, err)
	}
	return string(data)
}
