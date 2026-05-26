package theme

import (
	"encoding/json"
	"path/filepath"
)

type LastApplyManifest struct {
	Marker  string                   `json:"_comment"`
	ThemeID string                   `json:"themeID"`
	Mode    string                   `json:"mode"`
	Writes  []LastApplyManifestWrite `json:"writes"`
}

type LastApplyManifestWrite struct {
	Target     string `json:"target"`
	Path       string `json:"path"`
	BackupPath string `json:"backupPath,omitempty"`
}

func LastApplyManifestPath(stateHome string) string {
	return filepath.Join(stateHome, "orgm-hypr", "theme", "last-apply.json")
}

func SaveLastApplyManifest(stateHome string, manifest LastApplyManifest) error {
	manifest.Marker = GeneratedMarker
	data, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return err
	}
	_, err = (AtomicWriter{Marker: GeneratedMarker}).Write(LastApplyManifestPath(stateHome), append(data, '\n'), 0o600)
	return err
}
