package main

import (
	"bytes"
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
)

type Fingerprint struct {
	Kind string
	Mode os.FileMode
	Hash [32]byte
	Link string
}
type Change struct {
	Code string `json:"code"`
	Path string `json:"path"`
}

func inventory(root string, paths []string) (map[string]Fingerprint, error) {
	files := map[string]Fingerprint{}
	for _, path := range paths {
		full := filepath.Join(root, path)
		if err := noLinkedParents(root, full, false); err != nil {
			return nil, err
		}
		if present, err := exists(full); err != nil {
			return nil, err
		} else if !present {
			continue
		}
		err := filepath.WalkDir(full, func(p string, d os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			info, err := d.Info()
			if err != nil {
				return err
			}
			rel, err := filepath.Rel(root, p)
			if err != nil {
				return err
			}
			fp := Fingerprint{Mode: info.Mode().Perm() & 0111}
			switch {
			case info.IsDir():
				fp.Kind = "directory"
			case info.Mode()&os.ModeSymlink != 0:
				fp.Kind = "link"
				fp.Link, err = os.Readlink(p)
				if err != nil {
					return err
				}
			case info.Mode().IsRegular():
				fp.Kind = "file"
				f, err := os.Open(p)
				if err != nil {
					return err
				}
				h := sha256.New()
				_, err = io.Copy(h, f)
				f.Close()
				if err != nil {
					return err
				}
				copy(fp.Hash[:], h.Sum(nil))
			default:
				return fmt.Errorf("special file: %s", p)
			}
			files[rel] = fp
			return nil
		})
		if err != nil {
			return nil, err
		}
	}
	return files, nil
}

// A/M/D describe the effect of pull: repository -> home. Directory entries
// include empty directories and type changes; executable-bit changes count.
func differences(source, home string, paths []string) ([]Change, error) {
	a, err := inventory(source, paths)
	if err != nil {
		return nil, err
	}
	b, err := inventory(home, paths)
	if err != nil {
		return nil, err
	}
	keys := map[string]bool{}
	for k := range a {
		keys[k] = true
	}
	for k := range b {
		keys[k] = true
	}
	changes := []Change{}
	for _, path := range sortedKeys(keys) {
		x, ax := a[path]
		y, by := b[path]
		code := ""
		switch {
		case !ax:
			code = "D"
		case !by:
			code = "A"
		case x != y:
			code = "M"
		}
		if code != "" {
			changes = append(changes, Change{code, path})
		}
	}
	return changes, nil
}

func printPatch(source, home string, changes []Change) error {
	for _, change := range changes {
		a, b := filepath.Join(home, change.Path), filepath.Join(source, change.Path)
		ai, ae := os.Lstat(a)
		bi, be := os.Lstat(b)
		if ae != nil {
			a = "/dev/null"
		} else if !ai.Mode().IsRegular() {
			continue
		}
		if be != nil {
			b = "/dev/null"
		} else if !bi.Mode().IsRegular() {
			continue
		}
		cmd := exec.Command("diff", "-u", "--label", "home/"+change.Path, "--label", "repo/"+change.Path, "--", a, b)
		var output bytes.Buffer
		cmd.Stdout = &output
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			if e, ok := err.(*exec.ExitError); !ok || e.ExitCode() != 1 {
				return err
			}
		}
		if _, err := os.Stdout.Write(output.Bytes()); err != nil {
			return err
		}
	}
	return nil
}
