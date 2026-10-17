package updater

// Nix integration safety boundary: do not copy, fork or prune through a user's
// directory link. Leaf preference links remain governed by native seed rules.
import (
	"fmt"
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"strings"
)

func guardMaterializeDirectories(base, dest, state string) error {
	dest = filepath.Clean(dest)
	rels, err := walkRel(base)
	if err != nil {
		return err
	}
	rels = append(rels, readManifest(state)...)
	edits, err := sys.UserEditFiles()
	if err != nil {
		return err
	}
	rels = append(rels, edits...)
	overlay, err := filepath.Rel(dest, sys.UserEditsDir())
	if err != nil {
		return err
	}
	// These roots can be created/pruned even when the base ships no file there.
	rels = append(rels, "ryoku/.guard", "quickshell/.guard", wpDropInDir+"/.guard", overlay+"/.guard")
	dirs := map[string]bool{dest: true}
	for _, rel := range rels {
		clean := filepath.Clean(rel)
		if filepath.IsAbs(clean) || clean == ".." || strings.HasPrefix(clean, ".."+string(filepath.Separator)) {
			return fmt.Errorf("unsafe materialization destination: %s", rel)
		}
		for _, root := range []string{dest, sys.UserEditsDir()} {
			for path := filepath.Dir(filepath.Join(root, clean)); ; path = filepath.Dir(path) {
				dirs[path] = true
				if path == dest {
					break
				}
			}
		}
	}
	for path := range dirs {
		info, err := os.Lstat(path)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("Ryoku: preserved personal directory link %s; use a writable directory before materializing", path)
		}
		if !info.IsDir() {
			return fmt.Errorf("materialization needs a directory: %s", path)
		}
	}
	return nil
}
