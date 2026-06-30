package dotmanifest

import "testing"

func TestContainsNested(t *testing.T) {
	paths := []string{".config/fish", ".tmux.conf"}
	for _, rel := range []string{".config/fish", ".config/fish/config.fish", ".tmux.conf"} {
		if !ContainsNested(paths, rel) {
			t.Fatalf("expected %q to be contained", rel)
		}
	}
	if ContainsNested(paths, ".config/fish2/config.fish") {
		t.Fatal("similar prefix should not match")
	}
}

func TestAddUniqueAndRemove(t *testing.T) {
	paths := AddUnique([]string{"b", "a", "b"}, "c")
	want := []string{"a", "b", "c"}
	for i := range want {
		if paths[i] != want[i] {
			t.Fatalf("AddUnique mismatch: got %#v want %#v", paths, want)
		}
	}
	paths = Remove(paths, "b")
	want = []string{"a", "c"}
	for i := range want {
		if paths[i] != want[i] {
			t.Fatalf("Remove mismatch: got %#v want %#v", paths, want)
		}
	}
}
